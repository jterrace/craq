#include <map>
#include <deque>
#include <ctime>
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

using namespace CryptoPP;
using namespace std;

const unsigned int CHAIN_SIZE = 3;
int NUM_SECS;
unsigned int MSGS_PER_SEC;
unsigned int MESSAGE_SIZE;
unsigned int NUM_MESSAGES;

struct key_value {
	ID_Value id;
	blob msg;
	Node head;
	Node tail;
	map<ID_Value, Node>::iterator head_it;
};

map<ID_Value, Node> ring;

tamed static void write_it(key_value * to_send) {
	tvars {
		int fd, fd2, i;
		ptr<axprt_stream> x;
		ptr<aclnt> cli; 
		clnt_stat e;
		rpc_node node;
		head_write_arg arg;
		u_int put_ret;
		bool ret;
		timeval started;
		timeval cur_time;
		long sec_diff;
		long usec_diff;
	}
	
	gettimeofday(&started, NULL);
	twait { get_rpc_cli (to_send->head.getIp().c_str(),to_send->head.getPort(), &cli, &chain_node_1, mkevent(fd)); }
	if(fd < 0) {
		return;
	}
	arg.id = to_send->id.get_rpc_id();
	arg.data = to_send->msg;
	twait {	cli->call(HEAD_WRITE, &arg, &ret,  mkevent(e)); }
	if(e || !ret) {
		return;
	}
	
	gettimeofday(&cur_time, NULL);
	warn << "W\t";
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
	}

	gettimeofday(&cur_time, NULL);
	warn << cur_time.tv_sec << "\t" << cur_time.tv_usec << "\n";
	twait { tcpconnect (h, port, mkevent(fd)); }
	if(fd < 0) {
		fatal << "Couldn't connect to manager.\n";
	}
	//warn << " DONE\n";
	
	x = axprt_stream::alloc(fd);
	cli = aclnt::alloc(x, rpc_manager_1);
	
	//warn << "Getting node list...\n";
	twait { cli->call(GET_NODE_LIST, NULL, &cur_list, mkevent(e)); }
	if(e || cur_list.nodes.size() < CHAIN_SIZE) {
		fatal << "Invalid node list!\n";
	}
	//warn << " DONE\n";
	
	for(i=0; i<cur_list.nodes.size(); i++) {
		ret.set_from_rpc_node(cur_list.nodes[i]);
		ring[ret.getId()] = ret;
	}
	
	//warn << "Generating " << NUM_MESSAGES << " messages of size "
	//	 << MESSAGE_SIZE << "...\n";
	srand(9);
	keys.resize(NUM_MESSAGES);
	for(i=0; i<NUM_MESSAGES; i++) {
		keys[i].msg.setsize(MESSAGE_SIZE);
		for(j=0; j<MESSAGE_SIZE; j++) {
			keys[i].msg[j] = rand() % 256;
		}
		keys[i].id = get_sha1(keys[i].msg);
		it = ring.lower_bound(keys[i].id);
		if(it == ring.end()) it = ring.begin();
		keys[i].head = it->second;
		keys[i].head_it = it;
		for(j=0; j<CHAIN_SIZE-1; j++) {
			it++;
			if(it == ring.end()) it = ring.begin();
		}
		keys[i].tail = it->second;
	}
	//warn << " DONE\n";
	
	//warn << "Writing initial messages...\n";
	//warn << " DONE\n";
	
	//gettimeofday(&cur_time, NULL);
	start_time = cur_time;
	last_time = start_time;

	num_data = 0;
	sum_data = 0.0;
	i = 0;
	k = 0;
	nsent = 0;
	nrecv = 0;
	
	gettimeofday(&cur_time, NULL);
	warn << cur_time.tv_sec << "\t" << cur_time.tv_usec << "\n";
	
	srand(time(NULL));
	//warn << "Starting reads...\n";
	num_secs = NUM_SECS;
	wait_time = 1000000000 / MSGS_PER_SEC;
	while ( time_diff(start_time, cur_time) < num_secs ) {
		gettimeofday(&cur_time, NULL);
		write_it(&keys[i]);
		i++;
		if(i > NUM_MESSAGES-1) {
			i = 0;
		}
		twait{ delaycb(0, wait_time, mkevent()); }
	}
	//ss.str("");
	//ss << (sum_data / (double)num_data);
	//warn << "Average: " << ss.str().c_str() << " replies/second\n";
	
	exit(0);

}

tamed static
void main2(int argc, char **argv) {
	tvars {
		str manager_hostname;
		int manager_port;
		int i;
	}
	
	if (argc == 7 && convertint(argv[2], &manager_port) &&
		convertint(argv[3], &NUM_SECS) &&
		convertint(argv[4], &MESSAGE_SIZE) &&
		convertint(argv[5], &NUM_MESSAGES) &&
		convertint(argv[6], &MSGS_PER_SEC) ) {
			
	 	manager_hostname = argv[1];
		connect_to_manager(manager_hostname, manager_port);
	}
	else {
		fatal << "usage: writer <manager_hostname> <manager_port> <num_secs>\n"
			  << "              <message_size> <num_messages> <msgs_per_sec>\n";
		exit(1);
	}
}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain ();
}
