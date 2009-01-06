#include <map>
#include <deque>
#include <ctime>
#include <vector>
#include "sha.h"
#include "tame.h"
#include "tame_rpcserver.h"
#include "parseopt.h"
#include "arpc.h"
#include "async.h"
#include "../craq_rpc.h"
#include "../Node.h"
#include "../ID_Value.h"
#include "../connection_pool.H"
#include <tclap/CmdLine.h>
#include "../zoo_craq.h"

using namespace CryptoPP;
using namespace std;

int NUM_SECS;
unsigned int MSGS_PER_SEC;
unsigned int MESSAGE_SIZE;
unsigned int NUM_MESSAGES;
vector<string> DATA_CENTERS;
string CHAIN_NAME;
string KEY_NAME;
unsigned int CHAIN_SIZE;

struct key_value {
	ID_Value chain_id;
	ID_Value id;
	blob msg;
	Node head;
	Node tail;
	map<ID_Value, Node>::iterator head_it;
};

map<ID_Value, Node> ring;

tamed static void read_it(key_value * to_send) {
	tvars {
		int fd, fd2, i;
		ptr<axprt_stream> x;
		ptr<aclnt> cli;
		clnt_stat e;
		rpc_node node;
		u_int put_ret;
		timeval started;
		timeval cur_time;
		long sec_diff;
		long usec_diff;
		rpc_hash arg;
		blob ret;
	}

	gettimeofday(&started, NULL);
	twait { get_rpc_cli (to_send->head.getIp().c_str(),to_send->head.getPort(), &cli, &chain_node_1, mkevent(fd)); }
	if(fd < 0) {
		return;
	}
	arg = to_send->id.get_rpc_id();
	twait {	cli->call(TAIL_READ, &arg, &ret,  mkevent(e)); }
	if(e || ret.size() != MESSAGE_SIZE) {
		fatal << "Read failed!\n";
		return;
	}

	gettimeofday(&cur_time, NULL);
	warn << "R\t";
	warn << cur_time.tv_sec << "\t" << cur_time.tv_usec << "\t";
	sec_diff = cur_time.tv_sec - started.tv_sec;
	if(sec_diff == 0) {
		usec_diff = cur_time.tv_usec - started.tv_usec;
	} else {
		usec_diff = (1000000 - started.tv_usec) + cur_time.tv_usec;
		sec_diff--;
		sec_diff += (usec_diff / 1000000);
		usec_diff = usec_diff % 1000000;
	}
	warn << sec_diff << "\t" << usec_diff << "\n";
	return;

}

ID_Value get_sha1(string msg)
{
	byte buffer[SHA::DIGESTSIZE];
	SHA().CalculateDigest(buffer, (byte *)msg.c_str(), msg.length());
	ID_Value ret(buffer);
 	return ret;
}

ID_Value get_sha1(blob msg)
{
	byte buffer[SHA::DIGESTSIZE];
	byte data[msg.size()];
	for(int i=0; i<msg.size(); i++) {
		data[i] = msg[i];
	}
	SHA().CalculateDigest(buffer, data, msg.size());
	ID_Value ret(buffer);
 	return ret;
}

double time_diff( timeval first, timeval second ) {
	double sec_diff = second.tv_sec - first.tv_sec;
	sec_diff += ((double)second.tv_usec - (double)first.tv_usec) / 1000000;
	return sec_diff;
}

tamed static void
connect_to_manager(str h, int port) {
	tvars {
		int fd;
		ptr<axprt_stream> x;
		ptr<aclnt> cli;
		clnt_stat e;
		u_int ver, i, j, k, nsent, nrecv, window_sz, num_secs;
		Node me, ret;
		rpc_node me_rpc;
		rpc_node_list cur_list;
		rpc_memb_delta delt;
		ID_Value id;
		string msg;
		map<ID_Value, Node>::iterator it;
		head_write_arg wrt_arg;
		rpc_hash rd_arg;
		bool wrt_ret;
		blob rd_ret;
		bool eqs;
		deque<key_value> keys;
		timeval cur_time, start_time, last_time;
		rendezvous_t<u_int, ptr<bool> > rv;
		ptr<bool> res;
		double persec;
		ostringstream ss, sss;
		int num_data;
		double sum_data;
		long sec_diff;
		long usec_diff;
		u_int wait_time;
		vector<string> * node_list;
		vector<string *> node_vals;
		string find;
		string search;
		string * found;
		add_chain_arg arg;
		add_chain_ret add_ret;
		bool rc;
		Node new_node;
	}

	srand ( time(NULL) );

	//warn << "chain id: " << get_sha1(KEY_NAME).toString().c_str() << "\n";

	ss << h << ":" << port;
	twait { czoo_init( ss.str().c_str(), mkevent(rc), ZOO_LOG_LEVEL_ERROR); }
	if(!rc) {
		fatal << "init failed!\n";
	}

	twait { czoo_get_children("/nodes/" + DATA_CENTERS[0], NULL, mkevent(node_list)); }
	if(node_list == NULL) {
		fatal << "retrieving node list failed!n";
	}

	node_vals.resize((*node_list).size());
	twait {
		for(i=0; i<(*node_list).size(); i++) {
			find = (*node_list)[i];
			search = "/nodes/" + DATA_CENTERS[0] + "/" + find;
			czoo_get(search, mkevent(node_vals[i]));
		}
	}
	//warn << "Checking node list return values... ";
	for(i=0; i<node_vals.size(); i++) {
		if(node_vals[i] == NULL) {
			fatal << "FAIL!\n";
		}
		new_node.set_from_string(*node_vals[i]);
		ring[new_node.getId()] = new_node;
		delete node_vals[i];
	}
	delete node_list;
	//warn << "SUCCESS\n";

	srand(9);
	keys.resize(1);
	i = 0;
	keys[i].msg.setsize(MESSAGE_SIZE);
	for(j=0; j<MESSAGE_SIZE; j++) {
		keys[i].msg[j] = rand() % 256;
	}
	keys[i].id = get_sha1(KEY_NAME);
	keys[i].chain_id = get_sha1(CHAIN_NAME);
	it = ring.lower_bound(keys[i].id);
	if(it == ring.end()) it = ring.begin();
	keys[i].head = it->second;
	keys[i].head_it = it;
	for(j=0; j<CHAIN_SIZE-1; j++) {
		it++;
		if(it == ring.end()) it = ring.begin();
	}
	keys[i].tail = it->second;

	twait { tcpconnect (it->second.getIp().c_str(), it->second.getPort(), mkevent(fd)); }
	if(fd < 0 ) {
		fatal << "Error connecting to node to add chain\n";
	}
	x = axprt_stream::alloc(fd);
	cli = aclnt::alloc(x, chain_node_1);
	arg.id = get_sha1(CHAIN_NAME).get_rpc_id();
	arg.chain_size = CHAIN_SIZE;
	arg.data_centers.setsize(DATA_CENTERS.size());
	for(i=0; i<DATA_CENTERS.size(); i++) {
		arg.data_centers[i] = DATA_CENTERS[i].c_str();
	}

	twait { cli->call(ADD_CHAIN, &arg, &add_ret, mkevent(e)); }
	if(e || add_ret == ADD_CHAIN_FAILURE) {
		fatal << "Error adding chain!\n";
	}

	twait { get_rpc_cli (keys[0].head.getIp().c_str(),keys[0].head.getPort(), &cli, &chain_node_1, mkevent(fd)); }
	if(fd < 0) {
		return;
	}
	wrt_arg.chain = keys[0].chain_id.get_rpc_id();
	wrt_arg.id =  keys[0].id.get_rpc_id();
	wrt_arg.data =  keys[0].msg;
	twait {	cli->call(HEAD_WRITE, &arg, &rc,  mkevent(e)); }
	if(e || !rc) {
		fatal << "Initial write failed!\n";
		return;
	}

	gettimeofday(&cur_time, NULL);
	start_time = cur_time;
	last_time = start_time;

	num_data = 0;
	sum_data = 0.0;
	i = 0;
	k = 0;
	nsent = 0;
	nrecv = 0;

	warn << cur_time.tv_sec << "\t" << cur_time.tv_usec << "\n";

	srand(time(NULL));
	//warn << "Starting reads...\n";
	num_secs = NUM_SECS;
	wait_time = 1000000000 / MSGS_PER_SEC;
	while ( time_diff(start_time, cur_time) < num_secs ) {
		gettimeofday(&cur_time, NULL);
		read_it(&keys[i]);
		/*i++;
		if(i > NUM_MESSAGES-1) {
			i = 0;
		}*/
		twait{ delaycb(0, wait_time, mkevent()); }
	}
	//ss.str("");
	//ss << (sum_data / (double)num_data);
	//warn << "Average: " << ss.str().c_str() << " replies/second\n";*/

	exit(0);

}

tamed static
void main2(int argc, char **argv) {
	tvars {
		string manager_hostname;
		int manager_port;
	}

	try
	{
		TCLAP::CmdLine cmd("reader creates a chain, and writes a key over and over", ' ', "0.1");
		TCLAP::ValueArg<string> managerHost("o", "manager_host", "Manager hostname", true, "", "string", cmd);
		TCLAP::ValueArg<int> managerPort("r", "manager_port", "Manager port number", true, 0, "int", cmd);
		TCLAP::MultiArg<string> dataCenters("d", "data_centers", "Data centers to spread the key to", true, "string", cmd );
		TCLAP::ValueArg<string> chainName("a", "chain_name", "Identifier for chain (will be converted with SHA256)", true, "", "string", cmd);
		TCLAP::ValueArg<string> keyName("k", "key_name", "Identifier for key (will be converted with SHA256)", true, "", "string", cmd);
		TCLAP::ValueArg<int> keySize("s", "key_size", "Size of key data to generate", true, 0, "int", cmd);
		TCLAP::ValueArg<int> chainSize("c", "chain_size", "Size of the chains within data centers", true, 0, "int", cmd);
		TCLAP::ValueArg<int> numSecs("n", "num_secs", "Number of seconds to run the test for", true, 0, "int", cmd);
		TCLAP::ValueArg<int> msgsPerSec("m", "msgs_per_sec", "Number of messages per second to read", true, 0, "int", cmd);
		cmd.parse(argc, argv);

		manager_hostname = managerHost.getValue();
		manager_port = managerPort.getValue();
		DATA_CENTERS = dataCenters.getValue();
		CHAIN_NAME = chainName.getValue();
		KEY_NAME = keyName.getValue();
		MESSAGE_SIZE = keySize.getValue();
		CHAIN_SIZE = chainSize.getValue();
		NUM_SECS = numSecs.getValue();
		MSGS_PER_SEC = msgsPerSec.getValue();

		connect_to_manager(manager_hostname.c_str(), manager_port);
	}
	catch (TCLAP::ArgException &e)  // catch any exceptions
	{
		fatal << "error: " << e.error().c_str() << " for arg " << e.argId().c_str() << "\n";
	}

}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain ();
}
