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
unsigned int WINDOW_SIZE;
unsigned int MESSAGE_SIZE;
unsigned int NUM_MESSAGES;

struct key_value {
	ID_Value id;
	blob msg;
	Node head;
	Node tail;
};

double time_diff( timeval first, timeval second ) {
	double sec_diff = second.tv_sec - first.tv_sec;
	sec_diff += ((double)second.tv_usec - (double)first.tv_usec) / 1000000;
	return sec_diff;
}

tamed static void read_it(key_value * to_send, cbb cb) {
	tvars {
		int fd, fd2, i;
		ptr<axprt_stream> x;
		ptr<aclnt> cli; 
		clnt_stat e;
		rpc_node node;
		rpc_hash arg_hash;
		u_int put_ret;
		blob ret;
	}
	
	twait { get_rpc_cli (to_send->tail.getIp().c_str(),to_send->tail.getPort(), &cli, &chain_node_1, mkevent(fd)); }
	if(fd < 0) {
		(*cb)(false);
		return;
	}
	arg_hash = to_send->id.get_rpc_id();
	twait {	cli->call(TAIL_READ, &arg_hash, &ret,  mkevent(e)); }
	if(e || ret.size() != to_send->msg.size()) {
		(*cb)(false);
		return;
	}
	
	(*cb)(true);
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
		map<ID_Value, Node> ring;
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
		timeval * req_start;
		long sec_diff;
		long usec_diff;
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
		for(j=0; j<CHAIN_SIZE-1; j++) {
			it++;
			if(it == ring.end()) it = ring.begin();
		}
		keys[i].tail = it->second;
	}
	//warn << " DONE\n";
	
	//warn << "Writing initial messages...\n";
	for(i=0; i<NUM_MESSAGES; i++) {
		twait { get_rpc_cli (keys[i].head.getIp().c_str(),keys[i].head.getPort(), &cli, &chain_node_1, mkevent(fd)); }
		if(fd < 0) {
			fatal << "Couldn't connect to a node to write key!\n";
		}
		wrt_arg.id = keys[i].id.get_rpc_id();
		wrt_arg.data = keys[i].msg;
		twait {	cli->call(HEAD_WRITE, &wrt_arg, &wrt_ret,  mkevent(e)); }
		if(!wrt_ret) {
			fatal << "Error writing key to node\n";
		}
	}
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
	window_sz = WINDOW_SIZE;
	
	gettimeofday(&cur_time, NULL);
	warn << cur_time.tv_sec << "\t" << cur_time.tv_usec << "\n";
	
	//warn << "Starting reads...\n";
	num_secs = NUM_SECS;
	while ( time_diff(start_time, cur_time) < num_secs ) {
		if((nsent-nrecv) < window_sz) {
			// Launch new calls since there is room in the window!
			res = New refcounted<bool> ();
			//warn << "Reading key " << i << "\n";
			req_start = new timeval;
			gettimeofday(req_start, NULL);
			read_it(&keys[i], mkevent(rv, (u_int)req_start, res, *res));
			nsent++;
			i++;
			if(i > NUM_MESSAGES-1) {
				i = 0;
			}
		} else {
			// Harvest
			twait(rv, k, res);
			req_start = (timeval *)k;
			if(*res) {
				nrecv++;
				//k++;
				gettimeofday(&cur_time, NULL);
				warn << cur_time.tv_sec << "\t" << cur_time.tv_usec << "\t";
				
				sec_diff = cur_time.tv_sec - req_start->tv_sec;
				if(sec_diff == 0) {
					usec_diff = cur_time.tv_usec - req_start->tv_usec;
				} else {
					usec_diff = (1000000 - req_start->tv_usec) + cur_time.tv_usec;
					sec_diff--;
					sec_diff += (usec_diff / 1000000);
					usec_diff = usec_diff % 1000000;
				}
				warn << sec_diff << "\t" << usec_diff << "\n";
				
				delete req_start;
			} else {
				fatal << "Bad reply from reading!\n";
			}
		}
		/*gettimeofday(&cur_time, NULL);
		if( time_diff(last_time, cur_time) >= 1.0 ) {
			num_data++;
			ss.str("");
			ss << time_diff(last_time, cur_time);
			persec = (double)k / time_diff(last_time, cur_time);
			sum_data += (double)k / time_diff(last_time, cur_time);
			sss.str("");
			sss << persec;
			warn <<  ss.str().c_str() << " elapsed, " << k << " replies = " << sss.str().c_str() << " replies/second\n";
			k = 0;
			last_time = cur_time;
		}*/
	}
	//ss.str("");
	//ss << (sum_data / (double)num_data);
	//warn << "Average: " << ss.str().c_str() << " replies/second\n";
	
	exit(0);

}

tamed static
void main2(int argc, char **argv) {
	str manager_hostname;
	int manager_port;
	
	if (argc == 7 && convertint(argv[2], &manager_port) &&
		convertint(argv[3], &NUM_SECS) &&
		convertint(argv[4], &WINDOW_SIZE) &&
		convertint(argv[5], &MESSAGE_SIZE) &&
		convertint(argv[6], &NUM_MESSAGES) ) {
	 	manager_hostname = argv[1];
		connect_to_manager(manager_hostname, manager_port);
	}
	else {
		fatal << "usage: single_write_read <manager_hostname> <manager_port> <num_secs>\n"
			  << "                         <window_size> <message_size> <num_messages>\n"
			  << " - connects to the manager at <manager_hostname>:<manager_port> and\n"
			  << "   generates <num_messages> messages of size <messages_size> and \n"
			  << "   writes the messages. Then, for <num_secs> seconds, continually\n"
			  << "   reads the keys back, sending <window_size> requests before\n"
			  << "   waiting for a response.\n";
		exit(1);
	}
}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain ();
}
