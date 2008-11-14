#include <map>
#include <deque>
#include <ctime>
#include <string>
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

str manager_hostname;
int manager_port;

const unsigned int CHAIN_SIZE = 3;
int NUM_SECS;
unsigned int WINDOW_SIZE;
bool CRAQ;

unsigned int node_list_version;

string glob_msg = "";
ID_Value glob_id;
blob msg_blob;
map<ID_Value, Node>::iterator glob_it;

void get_updates_stub();

struct key_value {
	ID_Value id;
	blob msg;
	Node head;
	Node tail;
	map<ID_Value, Node>::iterator head_it;
};

struct time_and_type {
	timeval t;
	bool read;
	int key;
	bool dirty;
};
map<ID_Value, Node> ring;

double time_diff( timeval first, timeval second ) {
	double sec_diff = second.tv_sec - first.tv_sec;
	sec_diff += ((double)second.tv_usec - (double)first.tv_usec) / 1000000;
	return sec_diff;
}

tamed static void read_it(cbb cb) {
	tvars {
		int fd, fd2, i, rnd;
		ptr<axprt_stream> x;
		ptr<aclnt> cli; 
		clnt_stat e;
		rpc_node node;
		rpc_hash arg_hash;
		u_int put_ret;
		tail_read_ex_ret ret;
		map<ID_Value, Node>::iterator it;
		Node getting;
	}
	
	it = glob_it;
	rnd = rand() % CHAIN_SIZE;
	for(i=0; i<rnd; i++) {
		it++;
		if(it == ring.end()) it = ring.begin();
	}
	getting = it->second;
	
	//warn << getting.getPort() << "\n";
	twait { get_rpc_cli (getting.getIp().c_str(),getting.getPort(), &cli, &chain_node_1, mkevent(fd)); }
	if(fd < 0) {
		(*cb)(false);
		return;
	}
	arg_hash = glob_id.get_rpc_id();
	twait {	cli->call(TAIL_READ_EX, &arg_hash, &ret,  mkevent(e)); }
	if(e) {
		invalidate_rpc_host(getting.getIp().c_str(), getting.getPort());
		(*cb)(false);
		return;
	}
	if(ret.data.size() != 500) {
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
		map<ID_Value, Node>::iterator it;
		head_write_arg wrt_arg;
		rpc_hash rd_arg;
		bool wrt_ret;
		blob rd_ret;
		bool eqs;
		timeval cur_time, start_time, last_time;
		rendezvous_t<u_int, ptr<bool> > rv;
		ptr<bool> res;
		double persec;
		ostringstream ss, sss;
		int num_data;
		double sum_data;
		time_and_type * req_start;
		long sec_diff;
		long usec_diff;
	}

	srand(time(NULL));

	gettimeofday(&cur_time, NULL);
	warn << cur_time.tv_sec << "\t" << cur_time.tv_usec << "\n";
	twait { tcpconnect (h, port, mkevent(fd)); }
	if(fd < 0) {
		fatal << "Couldn't connect to manager.\n";
	}
	//warn << " DONE\n";
	
	delaycb(0, 250 * 1000000, wrap(get_updates_stub));
	
	x = axprt_stream::alloc(fd);
	cli = aclnt::alloc(x, rpc_manager_1);
	
	//warn << "Getting node list...\n";
	twait { cli->call(GET_NODE_LIST, NULL, &cur_list, mkevent(e)); }
	if(e || cur_list.nodes.size() < CHAIN_SIZE) {
		fatal << "Invalid node list!\n";
	}
	//warn << " DONE\n";
	
	node_list_version = cur_list.ver;
	for(i=0; i<cur_list.nodes.size(); i++) {
		ret.set_from_rpc_node(cur_list.nodes[i]);
		ring[ret.getId()] = ret;
	}
	
	//warn << "Generating " << NUM_MESSAGES << " messages of size "
	//	 << MESSAGE_SIZE << "...\n";
	msg_blob.setsize(500);
	glob_msg.append(500, 'A');
	glob_id = get_sha1(glob_msg);
	
	for(i=0; i<500; i++) {
		msg_blob[i] = glob_msg[i];
	}
	
	it = ring.lower_bound(glob_id);
	if(it == ring.end()) it = ring.begin();
	glob_it = it;

	twait { get_rpc_cli (it->second.getIp().c_str(),it->second.getPort(), &cli, &chain_node_1, mkevent(fd)); }
	if(fd < 0) {
		fatal << "Couldn't connect to a node to write key!\n";
	}
	wrt_arg.id = glob_id.get_rpc_id();
	wrt_arg.data = msg_blob;
	twait {	cli->call(HEAD_WRITE, &wrt_arg, &wrt_ret,  mkevent(e)); }
	if(e || !wrt_ret) {
		fatal << "Error writing key to node\n";
	}
	
	num_data = 0;
	sum_data = 0.0;
	i = 0;
	k = 0;
	nsent = 0;
	nrecv = 0;
	window_sz = WINDOW_SIZE;
	
	gettimeofday(&cur_time, NULL);
	warn << cur_time.tv_sec << "\t" << cur_time.tv_usec << "\n";
	
	start_time = cur_time;
	last_time = start_time;
	
	num_secs = NUM_SECS;
	while ( time_diff(start_time, cur_time) < num_secs ) {
		gettimeofday(&cur_time, NULL);
		if((nsent-nrecv) < window_sz) {
			// Launch new calls since there is room in the window!
			res = New refcounted<bool> ();
			//warn << "Reading key " << i << "\n";
			req_start = new time_and_type;
			gettimeofday(&(req_start->t), NULL);
			read_it(mkevent(rv, (u_int)req_start, res, *res));
			i++;
			nsent++;
		} else {
			// Harvest
			twait(rv, k, res);
			req_start = (time_and_type *)k;
			if(*res) {
				nrecv++;
				warn << "C\t";
				warn << cur_time.tv_sec << "\t" << cur_time.tv_usec << "\t";
				sec_diff = cur_time.tv_sec - req_start->t.tv_sec;
				if(sec_diff == 0) {
					usec_diff = cur_time.tv_usec - req_start->t.tv_usec;
				} else {
					usec_diff = (1000000 - req_start->t.tv_usec) + cur_time.tv_usec;
					sec_diff--;
					sec_diff += (usec_diff / 1000000);
					usec_diff = usec_diff % 1000000;
				}
				warn << sec_diff << "\t" << usec_diff << "\n";
				delete req_start;
			} else {
				//warn << "================failed===============\n";
				res = New refcounted<bool> ();
				read_it(mkevent(rv, (u_int)req_start, res, *res));				
			}
		}
	}
	
	exit(0);

}

tamed static void get_updates() {

	tvars {
		int fd;
		ptr<aclnt> cli;
		clnt_stat e;
		u_int newest_ver;
		rpc_memb_delta delt;
		ID_Value id_changed;
		Node ret;
		ptr<axprt_stream> x;
		rpc_node_list cur_list;
		u_int i;
	}

	twait { get_rpc_cli (manager_hostname, manager_port, &cli, &rpc_manager_1, mkevent(fd)); }
	if(fd < 0) {
		fatal << "Couldn't connecting to manager... dying.\n";
	}

	twait { cli->call(GET_NODE_LIST_VERSION, NULL, &i, mkevent(e)); }

	//warn << "node list version\n";
	if(i > node_list_version) {
		node_list_version = i;
		twait { cli->call(GET_NODE_LIST, NULL, &cur_list, mkevent(e)); }
		if(e || cur_list.nodes.size() < CHAIN_SIZE) {
			fatal << "Invalid node list!\n";
		}
		
		ring.clear();
		for(i=0; i<cur_list.nodes.size(); i++) {
			ret.set_from_rpc_node(cur_list.nodes[i]);
			ring[ret.getId()] = ret;
		}
		//warn << "updating node list\n";
		if(ring.size() < CHAIN_SIZE) {
			fatal << "Chain size too small! exiting!\n";
		}
		
		glob_it = ring.lower_bound(glob_id);
		if(glob_it == ring.end()) glob_it = ring.begin();
		
	}
	
}

void get_updates_stub() {
	twait { get_updates(); }
	delaycb(0, 100 * 1000000, wrap(get_updates_stub));
}

tamed static
void main2(int argc, char **argv) {

	if (argc == 5 && convertint(argv[2], &manager_port) &&
		convertint(argv[3], &NUM_SECS) &&
		convertint(argv[4], &WINDOW_SIZE) ) {
	 	manager_hostname = argv[1];
		connect_to_manager(manager_hostname, manager_port);
	}
	else {
		fatal << "usage: single_reader <manager_hostname> <manager_port> <num_secs> <window_size>\n";
		exit(1);
	}
}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain ();
}
