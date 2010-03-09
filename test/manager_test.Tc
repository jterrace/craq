#include "tame.h"
#include "tame_rpcserver.h"
#include "parseopt.h"
#include "arpc.h"
#include "async.h"
#include "../craq_rpc.h"
#include "../Node.h"
#include "../ID_Value.h"

using namespace std;

void assert_msg(bool val, const char * msg) {
	warn << msg;
	if(!val) {
		warn << " FAIL!\n";
		exit(1);
	}
	warn << " SUCCESS!\n";
}

tamed static void 
connect_to_manager(str h, int port) {
	tvars {
		int fd;
		ptr<axprt_stream> x;
		ptr<aclnt> cli;
		clnt_stat e;
		u_int ver;
		ID_Value id;
		Node me, ret;
		rpc_node me_rpc;
		rpc_node_list cur_list;
		rpc_memb_delta delt;
		ID_Value id_ret;
	}

	twait { tcpconnect (h, port, mkevent(fd)); }
	if( fd<0 ) {
		fatal << "Connection failed (host:" << h << ",port:" << port << "\n";
		exit(1);
	}
	
	x = axprt_stream::alloc(fd);
	cli = aclnt::alloc(x, rpc_manager_1);

	twait {	cli->call(GET_NODE_LIST_VERSION, NULL, &ver, mkevent(e)); }
	assert_msg(!e && ver==0, "Checking starting version number...");
	
	me.setIp("127.0.0.1");
	me.setPort(5432);
	id.randomize();
	me.setId(id);
	me_rpc = me.get_rpc_node();
	twait { cli->call(REGISTER, &me_rpc, NULL, mkevent(e)); }
	assert_msg(!e, "Registering as a node...");
	
	twait {	cli->call(GET_NODE_LIST_VERSION, NULL, &ver, mkevent(e)); }
	assert_msg(!e && ver==1, "Verifying version number...");
	
	twait { cli->call(GET_NODE_LIST, NULL, &cur_list, mkevent(e)); }
	assert_msg(!e &&
			   cur_list.ver==1 && 
			   cur_list.nodes.size()==1, "Checking node list sanity...");
	ret.set_from_rpc_node(cur_list.nodes[0]);
	assert_msg(ret.getIp() == me.getIp() &&
			   ret.getId() == me.getId() &&
			   ret.getPort() == me.getPort(), "Making sure returned node matches...");
	
	ver = 0;
	twait { cli->call(GET_NODE_LIST_DELTA, &ver, &delt, mkevent(e)); }
	assert_msg(!e &&
			   delt.changes.size()==1, "Checking delta list sanity...");
	id_ret.set_from_rpc(delt.changes[0].node.id);
	assert_msg(delt.changes[0].ver==1 &&
			   delt.changes[0].event==EVENT_ADD &&
			   id_ret==id, "Making sure returned delta matches...");
	
	twait { cli->call(REPORT_BAD, &me_rpc, NULL, mkevent(e)); }
	assert_msg(!e, "Marking node as bad...");
	
	twait {	cli->call(GET_NODE_LIST_VERSION, NULL, &ver, mkevent(e)); }
	assert_msg(!e && ver==2, "Verifying version number...");
	
	twait { cli->call(GET_NODE_LIST, NULL, &cur_list, mkevent(e)); }
	assert_msg(!e &&
			   cur_list.ver==2 && 
			   cur_list.nodes.size()==0, "Checking node list sanity...");
	
	ver = 1;
	twait { cli->call(GET_NODE_LIST_DELTA, &ver, &delt, mkevent(e)); }
	assert_msg(!e &&
			   delt.changes.size()==1, "Checking delta list sanity...");
	id_ret.set_from_rpc(delt.changes[0].node.id);
	assert_msg(delt.changes[0].ver==2 &&
			   delt.changes[0].event==EVENT_DEL &&
			   id_ret==id, "Making sure returned delta matches...");
	
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
		fatal << "usage: manager_test <manager_hostname> <manager_port>\n"
			  << "               - connects to manager\n";
		exit(1);
	}
}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain ();
}
