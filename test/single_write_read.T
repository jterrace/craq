#include <map>
#include "sha.h"
#include "tame.h"
#include "tame_rpcserver.h"
#include "parseopt.h"
#include "arpc.h"
#include "async.h"
#include "../craq_rpc.h"
#include "../Node.h"
#include "../ID_Value.h"

using namespace CryptoPP;
using namespace std;

void assert_msg(bool val, const char * msg) {
	warn << msg;
	if(!val) {
		fatal << " FAIL!\n";
	}
	warn << " SUCCESS!\n";
}

ID_Value get_sha1(string msg)
{
	byte buffer[SHA::DIGESTSIZE];
	SHA().CalculateDigest(buffer, (byte *)msg.c_str(), msg.length());
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
		u_int ver, i;
		Node me, ret;
		rpc_node me_rpc;
		rpc_node_list cur_list;
		rpc_memb_delta delt;
		ID_Value id;
		string msg;
		map<ID_Value, Node> ring;
		map<ID_Value, Node>::iterator it;
		head_write_arg wrt_arg;
		bool wrt_ret;
	}

	twait { tcpconnect (h, port, mkevent(fd)); }
	assert_msg(fd>=0, "Connecting to manager...");
	
	x = axprt_stream::alloc(fd);
	cli = aclnt::alloc(x, rpc_manager_1);
	
	twait { cli->call(GET_NODE_LIST, NULL, &cur_list, mkevent(e)); }
	assert_msg(!e &&
			   cur_list.ver>0 && 
			   cur_list.nodes.size()>0, "Retrieving node list...");
	
	for(i=0; i<cur_list.nodes.size(); i++) {
		ret.set_from_rpc_node(cur_list.nodes[i]);
		ring[ret.getId()] = ret;
	}
	
	msg = "Hello Cruel World!";
	srand(time(NULL));
	for(i=0; i<10; i++) {
		msg += (char)(rand() % 26 + 65);
	}
	id = get_sha1(msg);
	warn << "Message: " << msg.c_str() << "\n";
	warn << "Id: " << id.toString().c_str() << "\n";
	
	it = ring.lower_bound(id);
	if(it == ring.end())
		it = ring.begin();
	
	twait { tcpconnect (it->second.getIp().c_str(), it->second.getPort(), mkevent(fd)); }
	assert_msg(fd>=0, "Connecting to head node...");
	
	x = axprt_stream::alloc(fd);
	cli = aclnt::alloc(x, chain_node_1);
	
	wrt_arg.id = id.get_rpc_id();
	wrt_arg.data = msg.c_str();
	twait { cli->call(HEAD_WRITE, &wrt_arg, &wrt_ret, mkevent(e)); }
	assert_msg(!e && wrt_ret, "Writing value...");
	
	warn << "All tests passed!\n";
	exit(0);

}

tamed static
void main2(int argc, char **argv) {
	str manager_hostname;
	int manager_port;
	
	if (argc == 3 && convertint(argv[2], &manager_port)) {
	 	manager_hostname = argv[1];
		connect_to_manager(manager_hostname, manager_port);
	}
	else {
		fatal << "usage: single_write_read <manager_hostname> <manager_port>\n"
			  << "               - connects to manager and\n"
			  << "                 issues a single write and\n" 
			  << "                 then reads the value back\n";
		exit(1);
	}
}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain ();
}
