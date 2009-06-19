#include <string>
#include <algorithm>
#include <set>
#include <ctime>
#include "sha.h"
#include "tame.h"
#include "tame_rpcserver.h"
#include "parseopt.h"
#include "tame_io.h"
#include "arpc.h"
#include "async.h"
#include "../craq_rpc.h"
#include "../Node.h"
#include "../ID_Value.h"
#include <tclap/CmdLine.h>
#include "../zoo_craq.h"
#include "connection_pool.TH"

using namespace CryptoPP;
using namespace std;

int NUM_SECS;
unsigned int MSGS_PER_SEC;
unsigned int MESSAGE_SIZE;
string CHAIN_NAME;
string KEY_NAME;
unsigned int CHAIN_SIZE;
unsigned long WINDOW_SIZE;
bool DO_READ;

typedef enum { READ, WRITE } ev_t;
typedef callback<void, string>::ref cbstr;
typedef callback<void, ptr<blob> >::ref cb_blob_ptr;
typedef callback<void, add_chain_ret>::ref cb_addchain;
const unsigned int MAX_BUF = 2000;
bool ring_init = false;
typedef map<ID_Value, Node>::iterator ring_iter;
map<ID_Value, Node> ring;
string datacenter;
struct chain_meta {
	unsigned int chain_size;
	vector<string> data_centers;
};
map<ID_Value, chain_meta> chain_meta_list;

map<ID_Value, blob> keys;

static void nothing() {}

double time_diff( timeval first, timeval second ) {
	double sec_diff = second.tv_sec - first.tv_sec;
	sec_diff += ((double)second.tv_usec - (double)first.tv_usec) / 1000000;
	return sec_diff;
}

blob make_blob(const char * str) {
	blob to_ret;
	to_ret.setsize(strlen(str));
	for(int i=0; i<strlen(str); i++) {
		to_ret[i] = str[i];
	}
	return to_ret;
}

ID_Value get_sha1(string msg)
{
	byte buffer[SHA::DIGESTSIZE];
	SHA().CalculateDigest(buffer, (byte *)msg.c_str(), msg.length());
	ID_Value ret(buffer);
 	return ret;
}

ring_iter ring_succ(ID_Value id) {
	ring_iter it = ring.lower_bound(id);
	if(it == ring.end())
		it = ring.begin();
	return it;
}

void ring_incr(ring_iter * it) {
	(*it)++;
	if( (*it)==ring.end() ) {
		(*it) = ring.begin();
	}
}

tamed static void get_chain_info(ID_Value * chain_id, ptr<callback<void, ptr<chain_meta> > > cb) {
	tvars {
		ptr<chain_meta> ret;
		string * val;
		istringstream iss;
		string dc;
		map<ID_Value, chain_meta>::iterator it;
	}

	it = chain_meta_list.find(*chain_id);
	if(it != chain_meta_list.end()) {
		ret = New refcounted<chain_meta>;
		*ret = it->second;
		TRIGGER(cb, ret);
		return;
	}

	twait{ czoo_get("/keys/" + chain_id->toString(), mkevent(val)); }
	if(val == NULL) {
		ret = NULL;
		TRIGGER(cb, ret);
		return;
	}

	ret = New refcounted<chain_meta>;
	iss.str(*val);
	delete val;
	if(!(iss >> ret->chain_size)) {
		fatal << "Got bad value back from zookeeper chain node!\n";
	}
	while(!iss.eof()) {
		iss >> dc;
		ret->data_centers.push_back(dc);
	}
	if(ret->data_centers.size() < 1) {
		fatal << "Got no data centers back from zookeeper chain node!\n";
	}

	chain_meta_list[*chain_id] = *ret;
	TRIGGER(cb, ret);

}

tamed static void add_chain(ID_Value * id, int chain_size, cb_addchain cb) {
	tvars {
		ring_iter succ;
		add_chain_arg add_arg;
		add_chain_ret add_ret;
		ptr<aclnt> cli;
		clnt_stat e;
		int fd;
	}

	succ = ring_succ(*id);

	twait { get_rpc_cli (succ->second.getIp().c_str(),succ->second.getPort(), &cli, &chain_node_1, mkevent(fd)); }
	if(fd < 0) {
		TRIGGER(cb, ADD_CHAIN_FAILURE);
		return;
	}

	add_arg.id = id->get_rpc_id();
	add_arg.chain_size = chain_size;
	add_arg.data_centers.setsize(1);
	add_arg.data_centers[0] = datacenter.c_str();

	twait { cli->call(ADD_CHAIN, &add_arg, &add_ret, mkevent(e)); }
	if(e) {
		TRIGGER(cb, ADD_CHAIN_FAILURE);
		return;
	}

	TRIGGER(cb, add_ret);
}

tamed static void set_key(ID_Value * chain_id, ID_Value * id, cbb cb) {

	tvars {
		ring_iter succ;
		ptr<chain_meta> chain_info;
		ptr<aclnt> cli;
		ostringstream out;
		clnt_stat e;
		int fd;
		head_write_arg wrt_arg;
		bool rc;
		map<ID_Value, blob>::iterator it;
	}

	succ = ring_succ(*id);
	it = keys.find(*id);
	if(it == keys.end()) {
		TRIGGER(cb, false);
		return;
	}

	twait { get_rpc_cli (succ->second.getIp().c_str(),succ->second.getPort(), &cli, &chain_node_1, mkevent(fd)); }
	if(fd < 0) {
		TRIGGER(cb, false);
		return;
	}

	twait{ get_chain_info(chain_id, mkevent(chain_info)); }
	if(chain_info == NULL) {
		TRIGGER(cb, false);
		return;
	}

	wrt_arg.chain = chain_id->get_rpc_id();
	wrt_arg.id = id->get_rpc_id();
	wrt_arg.data = it->second;
	twait {	cli->call(HEAD_WRITE, &wrt_arg, &rc,  mkevent(e)); }
	if(e || !rc) {
		TRIGGER(cb, false);
		return;
	}

	TRIGGER(cb, true);
}

tamed static void get_key(ID_Value * chain_id, ID_Value * id, cb_blob_ptr cb) {

	tvars {
		ring_iter succ;
		ptr<chain_meta> chain_info;
		ptr<aclnt> cli;
		tail_read_ex_arg arg;
		tail_read_ex_ret ret;
		ostringstream out;
		clnt_stat e;
		int fd;
		int rnd;
		int i;
		ptr<blob> to_ret;
	}

	twait{ get_chain_info(chain_id, mkevent(chain_info)); }
	if(chain_info == NULL) {
		TRIGGER(cb, NULL);
		return;
	}

	succ = ring_succ(*id);
	rnd = rand() % chain_info->chain_size;
	for( ; rnd>0; rnd--) {
		ring_incr(&succ);
	}

	//warn << succ->second.getIp().c_str() << ":" << succ->second.getPort() << "\n";
	twait { get_rpc_cli (succ->second.getIp().c_str(),succ->second.getPort(), &cli, &chain_node_1, mkevent(fd)); }
	if(fd < 0) {
		TRIGGER(cb, NULL);
		return;
	}
	arg.id = id->get_rpc_id();
	arg.chain = chain_id->get_rpc_id();
	arg.dirty = false;
	twait {	cli->call(TAIL_READ_EX, &arg, &ret,  mkevent(e)); }
	if(e) {
		TRIGGER(cb, NULL);
		return;
	}

	to_ret = New refcounted<blob>;
	*to_ret = ret.data;
	TRIGGER(cb, to_ret);
}

tamed static void op(ID_Value * chain_id, ID_Value * id, cbv cb) {
	tvars {
		ptr<blob> ret;
		timeval start_time;
		timeval end_time;
		long sec_diff;
		long usec_diff;
		bool bret;
	}
	gettimeofday(&start_time, NULL);
	if(DO_READ) {
		while(ret == NULL || ret->size() != MESSAGE_SIZE) {
			twait { get_key(chain_id, id, mkevent(ret)); }
			//if(ret == NULL) {
			//	warn << "NULL\n";
			//} else if(ret->size() != MESSAGE_SIZE) {
			//	warn << "SIZE " << ret->size() << " " << MESSAGE_SIZE << "\n";
			//}
		}
	} else {
		bret = false;
		while(!bret) {
			twait { set_key(chain_id, id, mkevent(bret)); }
		}
	}
	gettimeofday(&end_time, NULL);
	if(DO_READ) {
		warn << "R\t";
	} else {
		warn << "W\t";
	}
	warn << start_time.tv_sec << "\t" << start_time.tv_usec << "\t";
	sec_diff = end_time.tv_sec - start_time.tv_sec;
	if(sec_diff == 0) {
		usec_diff = end_time.tv_usec - start_time.tv_usec;
	} else {
		usec_diff = (1000000 - start_time.tv_usec) + end_time.tv_usec;
		sec_diff--;
		sec_diff += (usec_diff / 1000000);
		usec_diff = usec_diff % 1000000;
	}
	warn << sec_diff << "\t" << usec_diff << "\n";
	TRIGGER(cb);
}

tamed static void run_test() {

	tvars {
		int i;
		blob data;
		ID_Value id;
		ID_Value chain_id;
		add_chain_ret add_ret;
		bool ret;
		timeval cur_time;
		timeval start_time;
		timeval last_time;
		unsigned int wait_time;
		unsigned long nsent;
		unsigned long nrecv;
		rendezvous_t<int> rv;
	}

	srand(9);
	data.setsize(MESSAGE_SIZE);
	for(i=0; i<MESSAGE_SIZE; i++) {
		data[i] = rand() % 94 + 32;
	}
	id = get_sha1(KEY_NAME);
	chain_id = get_sha1(CHAIN_NAME);
	keys[id] = data;

	twait { add_chain(&chain_id, CHAIN_SIZE, mkevent(add_ret)); }
	if(add_ret == ADD_CHAIN_FAILURE) {
		fatal << "Got failure for ADD_CHAIN\n";
	}

	twait { set_key(&chain_id, &id, mkevent(ret)); }
	if(!ret) {
		fatal << "Got failure for initial key write\n";
	}

	srand(time(NULL));
	gettimeofday(&cur_time, NULL);
	start_time = cur_time;
	last_time = start_time;

	warn << cur_time.tv_sec << "\t" << cur_time.tv_usec << "\n";

	nsent = 0;
	nrecv = 0;
	if(MSGS_PER_SEC != 0) {
		wait_time = 1000000000 / MSGS_PER_SEC;
	}
	while ( time_diff(start_time, cur_time) < NUM_SECS ) {
		gettimeofday(&cur_time, NULL);
		if(MSGS_PER_SEC == 0) {
			twait { op(&chain_id, &id, mkevent()); }
		} else if(MSGS_PER_SEC != -1) {
			op(&chain_id, &id, wrap(nothing));
			twait{ delaycb(0, wait_time, mkevent()); }
		} else if((nsent-nrecv) < WINDOW_SIZE) {
			op(&chain_id, &id, mkevent(rv, 0));
			nsent++;
		} else {
			twait(rv, i);
			nrecv++;
		}
	}

	exit(0);
}

tamed static void node_added(Node node_changed) {
	ring[node_changed.getId()] = node_changed;
}

tamed static void node_deleted(Node node_changed) {
	tvars {
		ring_iter it;
	}
	it = ring.find(node_changed.getId());
	if(it == ring.end()) {
		fatal << "Deleting node that we didn't know about! Should never happen... dying!\n";
	}
	//warn << "deleting " << it->second.getPort() << "\n";
	invalidate_rpc_host(it->second.getIp().c_str(), it->second.getPort());
	ring.erase(it);
}

tamed static void node_list_watcher(string path) {

	tvars {
		vector<string> * ret_node_list;
		set<string> new_list;
		int i, j;
		map<string, Node>::iterator old_it;
		set<string>::iterator new_it;
		set<string> to_add;
		set<string>::iterator it;
		vector<string *> add_rets;
		vector<string> add_ids;
		rendezvous_t<int> rv;
		string search;
		string * new_val;
		Node new_node;
	}

	if(!ring_init) {
    	//TODO: Fix this
    	fatal << "Updated node list while doing initial list. Not implemented.\n";
	}

	twait { czoo_get_children("/nodes/" + datacenter, &node_list_watcher, mkevent(ret_node_list)); }
	if(ret_node_list == NULL) {
		fatal << "Error retrieving updated node list!\n";
	}
	for(i=0; i<ret_node_list->size(); i++) {
		new_list.insert( (*ret_node_list)[i] );
	}
	delete ret_node_list;

	old_it = zoo_nodes.begin();
	new_it = new_list.begin();

	while(old_it != zoo_nodes.end() || new_it != new_list.end()) {
		if(old_it == zoo_nodes.end()) {
			to_add.insert(*new_it);
			new_it++;
		} else if( new_it == new_list.end() ) {
			node_deleted(old_it->second);
			zoo_nodes.erase(old_it++);
		}
		else if( old_it->first == *new_it ) {
			old_it++;
			new_it++;
		} else if( old_it->first < *new_it ) {
			node_deleted(old_it->second);
			zoo_nodes.erase(old_it++);
		} else if( old_it->first > *new_it ) {
			to_add.insert(*new_it);
			new_it++;
		}
	}

	add_ids.resize(to_add.size());
	add_rets.resize(to_add.size());
	for( i=0, it = to_add.begin(); it != to_add.end(); i++, it++ ) {
		search = "/nodes/" + datacenter + "/" + (*it);
		add_ids[i] = *it;
		czoo_get(search, mkevent(rv, i, add_rets[i]));
	}
	for(i=0; i<add_rets.size(); i++) {
		twait(rv, j);
		if(add_rets[j] == NULL) {
			fatal << "Failed to retrieve information about a node!\n";
		}
		new_node.set_from_string(*add_rets[j]);
		delete add_rets[j];
		zoo_nodes[add_ids[j]] = new_node;
		node_added(new_node);
	}

}

tamed static void connect_to_manager(string zookeeper_list, cbv cb) {
	tvars {
		bool rc;
		vector<string> * node_list;
		vector<string *> node_vals;
		int i;
		string find;
		string search;
		Node new_node;
	}

	twait { czoo_init( zookeeper_list.c_str(), mkevent(rc), ZOO_LOG_LEVEL_ERROR); }
	if(!rc) {
		fatal << "Couldn't initialize ZooKeeper. Dying.\n";
	}

	twait { czoo_get_children("/nodes/" + datacenter, &node_list_watcher, mkevent(node_list)); }
	if(node_list == NULL) {
		fatal << "Error retrieving initial node list!\n";
	}

	zoo_node_count = (*node_list).size();
	node_vals.resize((*node_list).size());
	twait {
		for(i=0; i<(*node_list).size(); i++) {
			find = (*node_list)[i];
			search = "/nodes/" + datacenter + "/" + find;
			czoo_get(search, mkevent(node_vals[i]));
		}
	}

	for(i=0; i<node_vals.size(); i++) {
		if(node_vals[i] == NULL) {
			fatal << "Error occurred retrieving initial node value!\n";
		}
		new_node.set_from_string(*node_vals[i]);
		ring[new_node.getId()] = new_node;
		zoo_nodes[(*node_list)[i]] = new_node;
		delete node_vals[i];
	}

	delete node_list;
	ring_init = true;

	TRIGGER(cb);
}

tamed static void main2(int argc, char **argv) {
	tvars {
		int listen_port;
		str type;
		string zookeeper_list;
		timeval cur_time;
	}

	gettimeofday(&cur_time, NULL);
	warn << cur_time.tv_sec << "\t" << cur_time.tv_usec << "\n";

	try
	{
		TCLAP::CmdLine cmd("read_write can read and write data to CRAQ", ' ', "0.2");

		TCLAP::ValueArg<string> zooKeeperList("z", "zookeeper_list", "List of ZooKeeper nodes (ie '127.0.0.1:2000,10.0.0.1:2100')", true, "", "string", cmd);
		TCLAP::ValueArg<string> dataCenter("d", "data_center", "Datacenter name", true, "", "string", cmd);

		TCLAP::ValueArg<string> chainName("a", "chain_name", "Identifier for chain (will be converted with SHA256)", true, "", "string", cmd);
		TCLAP::ValueArg<string> keyName("k", "key_name", "Identifier for key (will be converted with SHA256)", true, "", "string", cmd);
		TCLAP::ValueArg<int> keySize("s", "key_size", "Size of key data to generate", true, 0, "int", cmd);
		TCLAP::ValueArg<int> chainSize("c", "chain_size", "Size of the chain within the data center", true, 0, "int", cmd);
		TCLAP::ValueArg<int> numSecs("n", "num_secs", "Number of seconds to run the test for", true, 0, "int", cmd);

		TCLAP::ValueArg<int> msgsPerSec("m", "msgs_per_sec", "Number of messages per second to read or write (if 0, next operation will be run when previous completes)", false, -1, "int");
		TCLAP::ValueArg<int> wndSize("w", "window_size", "Maximum window size of outstanding requests", false, -1, "int");
		cmd.xorAdd(msgsPerSec, wndSize);

		TCLAP::SwitchArg rdSwitch("R", "read", "Sets this client as a reader", false);
		TCLAP::SwitchArg wrtSwitch("W", "write", "Sets this client as a writer", false);
		cmd.xorAdd(rdSwitch, wrtSwitch);

		cmd.parse(argc, argv);

		zookeeper_list = zooKeeperList.getValue();
		datacenter = dataCenter.getValue();
		CHAIN_NAME = chainName.getValue();
		KEY_NAME = keyName.getValue();
		MESSAGE_SIZE = keySize.getValue();
		CHAIN_SIZE = chainSize.getValue();
		NUM_SECS = numSecs.getValue();
		MSGS_PER_SEC = msgsPerSec.getValue();
		WINDOW_SIZE = wndSize.getValue();
		DO_READ = rdSwitch.isSet();
	}
	catch (TCLAP::ArgException &e)  // catch any exceptions
	{
		fatal << "Error: " << e.error().c_str() << " for arg " << e.argId().c_str() << "\n";
	}

	twait { connect_to_manager(zookeeper_list, mkevent()); }
	run_test();
}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain();
}
