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
#include "connection_pool.H"

using namespace CryptoPP;
using namespace std;

int NUM_SECS;
unsigned int MSGS_PER_SEC;
unsigned int MESSAGE_SIZE;
string CHAIN_NAME;
string KEY_NAME;
unsigned int CHAIN_SIZE;

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
		vector<TCLAP::Arg *> switches;
		ID_Value id;
		string chain_name;
		ring_iter loc;
		bool headSet;
		bool tailSet;
		bool interSet;
		ptr<chain_meta> chain_info;
		int i;
		int rnd;
	}

	try
	{
		TCLAP::CmdLine cmd("get_chain_info will return the head, tail, or a random interior node of the given chain", ' ', "0.2");

		TCLAP::ValueArg<string> zooKeeperList("z", "zookeeper_list", "List of ZooKeeper nodes (ie '127.0.0.1:2000,10.0.0.1:2100')", true, "", "string", cmd);
		TCLAP::ValueArg<string> dataCenter("d", "data_center", "Datacenter name", true, "", "string", cmd);

		TCLAP::ValueArg<string> chainName("a", "chain_name", "Identifier for chain (will be converted with SHA256)", true, "", "string", cmd);
		TCLAP::SwitchArg headSwitch("H", "head", "Returns the head", false);
		TCLAP::SwitchArg tailSwitch("T", "tail", "Returns the tail", false);
		TCLAP::SwitchArg interiorSwitch("I", "interior", "Returns a random interior node", false);
		switches.push_back(&headSwitch);
		switches.push_back(&tailSwitch);
		switches.push_back(&interiorSwitch);
		cmd.xorAdd(switches);

		cmd.parse(argc, argv);

		zookeeper_list = zooKeeperList.getValue();
		datacenter = dataCenter.getValue();
		chain_name = chainName.getValue();
		headSet = headSwitch.isSet();
		tailSet = tailSwitch.isSet();
		interSet = interiorSwitch.isSet();

	}
	catch (TCLAP::ArgException &e)  // catch any exceptions
	{
		fatal << "Error: " << e.error().c_str() << " for arg " << e.argId().c_str() << "\n";
	}


	twait { connect_to_manager(zookeeper_list, mkevent()); }

	id = get_sha1(chain_name);
	loc = ring_succ(id);
	if(headSet) {
		warn << loc->second.getIp().c_str() << "\n";
	} else {

		twait { get_chain_info(&id, mkevent(chain_info)); }
		if(chain_info == NULL) {
			exit(1);
		}

		if(tailSet) {
			for(i=0; i<chain_info->chain_size - 1; i++) {
				ring_incr(&loc);
			}
			warn << loc->second.getIp().c_str() << "\n";
		} else if(interSet) {
			srand(time(NULL));
			rnd = rand() % chain_info->chain_size;
			for( ; rnd>0; rnd--) {
				ring_incr(&loc);
			}
			warn << loc->second.getIp().c_str() << "\n";
		} else {
			exit(1);
		}

	}

	exit(0);

}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain();
}
