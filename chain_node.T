#include <iostream>
#include <string>
#include <map>
#include <set>
#include <deque>
#include <sstream>
#include "tame.h"
#include "tame_rpcserver.h"
#include "parseopt.h"
#include "arpc.h"
#include "async.h"
#include "craq_rpc.h"
#include "ID_Value.h"
#include "Node.h"
#include "MemStorage.h"
#include "Storage.h"
#include "connection_pool.H"
#include "crypto++/sha.h"

using namespace CryptoPP;
using namespace std;

class rpc_server : public tame::server_t {
public:
  rpc_server (int fd, int v) : tame::server_t (fd, v) {}
  const rpc_program &get_prog () const { return chain_node_1; }
  void dispatch (svccb *sbp);
};

class rpc_server_factory : public tame::server_factory_t {
public:
  rpc_server_factory () : tame::server_factory_t () {}
  tame::server_t *alloc_server (int fd, int v) { return New rpc_server (fd, v); }
};

void get_updates_stub();
Storage * storage;

str manager_hostname;
int manager_port;
unsigned int known_version;

map<ID_Value, Node> ring;
Node my_node;
map<ID_Value, Node>::iterator my_node_ptr;
ID_Value my_id;

struct key_meta {
	unsigned int committed;
	unsigned int max_pending;
	map<int, blob> pending_list;
};
map<ID_Value, key_meta> key_meta_list;

str get_ip_address() {
        vec<in_addr> addrs;
        if (!myipaddrs(&addrs))
        fatal << "my_addr: cannot find my IP address.\n";

        in_addr *addr = addrs.base();
        in_addr *loopback = NULL;
        in_addr *touse = NULL;
        while (addr < addrs.lim ()) {
                if (ntohl (addr->s_addr) == INADDR_LOOPBACK) {
                        loopback = addr;
                }
                else touse = addr;
                addr++;
        }
        if (addr >= addrs.lim () && (loopback == NULL))
                fatal << "my_addr: cannot find my IP address.\n";
        if (touse == NULL) {
                fatal << "my_addr: use loopback address as my address\n";
                touse = loopback;
        }
        str ids = inet_ntoa (*touse);
        return ids;
}

ID_Value get_sha1(string msg)
{
	byte buffer[SHA::DIGESTSIZE];
	SHA().CalculateDigest(buffer, (byte *)msg.c_str(), msg.length());
	ID_Value ret(buffer);
 	return ret;
}

void rpc_server::dispatch(svccb * sbp) {
	if(!sbp){}
	
	u_int p = sbp->proc();
	switch(p) {
		case TAIL_READ:
			sbp->reject(PROC_UNAVAIL);
			break;
 		case HEAD_WRITE:
 			sbp->reject(PROC_UNAVAIL);
 			break;
 		case PROPAGATE:
 			sbp->reject(PROC_UNAVAIL);
 			break;
 		case QUERY_OBJ_VER:
 			sbp->reject(PROC_UNAVAIL);
 			break;
 		case ACK:
 			sbp->reject(PROC_UNAVAIL);
 			break;
		default: {
			sbp->reject(PROC_UNAVAIL);
			break;
		}
	}	
}

tamed static void start_rpc_srv(int listen_port) {
	tvars {
		bool ret;
		rpc_server_factory fact;
	}
	twait {
		fact.run(listen_port, mkevent(ret));
	}
	warn << "received a return val in start_rpc_srv of: " << ret << "\n";
	exit(ret);
}

tamed static void 
register_to_manager(int my_port, str h, int port) {
	tvars {
		int fd,r;
		ptr<axprt_stream> x;
		ptr<aclnt> cli; 
		str ip;
		clnt_stat e, e2;
		ostringstream ss;
		rpc_node arg;
		rpc_node_list ret;
		unsigned int i;
	}
	
	manager_hostname = h;
	manager_port = port;
	
	ip = get_ip_address();
	srand ( time(NULL) );
	r = rand();
	ss << ip.cstr() << ":" << my_port << r;
	my_id = get_sha1(ss.str());
	warn << "my id = " << my_id.toString().c_str() << "\n";

	arg.ip = ip;
	arg.id = my_id.get_rpc_id();
	arg.port = my_port;
	
	my_node.set_from_rpc_node(arg);

	twait { get_rpc_cli (h, port, &cli, &rpc_manager_1, mkevent(fd)); }
	if( fd<0 ) {
		fatal << "Connection failed (host:" << h << ",port:" << port << "\n";
	}

	twait {	
		cli->call(REGISTER, &arg, NULL, mkevent(e));
		//cli->call(GET_NODE_LIST, NULL, &ret, mkevent(e2));
	}
	//warn << "donecalling\n";
	if(e) {
		fatal << "RPC failed!\n";
	}
	
	warn << "Connected to manager.\n";
	
	/*known_version = ret.ver;
	for(i=0; i<ret.nodes.size(); i++) {
		Node cur(ret.nodes[i]);
		ring[cur.getId()] = cur;
	}*/

	//delaycb(1, 0, wrap(get_updates_stub));
	
}

void get_updates_stub() {
	//get_updates();
}

tamed static
void main2(int argc, char **argv) {
	int listen_port;
	str manager_hostname;
	int manager_port;
	
	if (argc == 4 && convertint (argv[1], &listen_port)
				  		 && convertint(argv[3], &manager_port)) {
	 	manager_hostname = argv[2];
		start_rpc_srv(listen_port);
		register_to_manager(listen_port, manager_hostname, manager_port);
	} else {
		fatal << "usage: chain_node <listen_port> <manager_hostname> <manager_port>\n"
			  << "               - connects to manager and joins the network\n";
		exit(1);
	}
}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain ();
}
