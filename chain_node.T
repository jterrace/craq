#include <iostream>
#include <string>
#include <map>
#include <set>
#include <deque>
#include <sstream>
#include "sha.h"
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

using namespace CryptoPP;
using namespace std;

const unsigned int CHAIN_SIZE = 4;

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
Storage * storage = new MemStorage();

static void process_poke_node_list_ver(svccb * sbp, CLOSURE);
static void process_query_obj_ver(svccb * sbp, CLOSURE);
static void process_tail_read(svccb * sbp, CLOSURE);
static void process_head_write(svccb * sbp, CLOSURE);
static void process_propagate(svccb * sbp, CLOSURE);
static void propagate(ID_Value id, cbb cb, CLOSURE);
static void get_updates(CLOSURE);

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
	bool is_head;
	bool is_tail;
};
map<ID_Value, key_meta> key_meta_list;

str get_ip_address() {
        vec<in_addr> addrs;
        if (!myipaddrs(&addrs))
        fatal << "Cannot find my IP address.\n";

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
                fatal << "Cannot find my IP address.\n";
        if (touse == NULL) {
                warn << "Using loopback address as my address.\n";
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

tamed void process_poke_node_list_ver(svccb * sbp) {
	unsigned parg = *(sbp->getarg<unsigned>());
	warn << "Got POKE_NODE_LIST_VER Request\n";
	
	if(parg > known_version) {
		get_updates();
	}
		
	sbp->replyref(NULL);
}

tamed void process_query_obj_ver(svccb * sbp) {
	tvars {
		rpc_hash parg;
		query_obj_ver_ret repl;
		ID_Value id;
		map<ID_Value, key_meta>::iterator it;
	}
	
	parg = *(sbp->getarg<rpc_hash>());
	warn << "Got QUERY_OBJ Request\n";

	id.set_from_rpc(parg);
	it = key_meta_list.find(id);
	if(it == key_meta_list.end())
		sbp->replyref(NULL);
	
	repl.hist = (it->second).committed;
	repl.pend = (it->second).max_pending;
	sbp->replyref(repl);
}

tamed void process_tail_read(svccb * sbp) {
	tvars {
		rpc_hash parg;
		const blob * repl;
		ID_Value id;
		map<ID_Value, key_meta>::iterator it;
	}
	
	parg = *(sbp->getarg<rpc_hash>());
	warn << "Got TAIL_READ Request\n";

	id.set_from_rpc(parg);
	it = key_meta_list.find(id);
	if(it == key_meta_list.end() || !(it->second).is_tail )
		sbp->replyref(NULL);
	
	repl = storage->get(id);
	sbp->replyref(*repl);	
}

tamed void process_head_write(svccb * sbp) {
	tvars {
		head_write_arg parg;
		ID_Value id;
		map<ID_Value, key_meta>::iterator it;
		map<ID_Value, Node>::iterator parent_ptr;
		key_meta wrt;
		bool ret_val;
	}
	
	//Reject writes unless we can form a chain
	if(ring.size() < CHAIN_SIZE)
		sbp->replyref(false);
	
	parg = *(sbp->getarg<head_write_arg>());
	warn << "Got HEAD_WRITE Request\n";

	id.set_from_rpc(parg.id);
	it = key_meta_list.find(id);
	//If we're not the head, reject the request
	if(it != key_meta_list.end() || !(it->second).is_head )
		sbp->replyref(false);
		
	parent_ptr = my_node_ptr;
	ring_decr(parent_ptr);
	if(it == key_meta_list.end() && !id.between(parent_ptr->first, my_node.getId())) {
		sbp->replyref(false);
	} else if(it == key_meta_list.end()) {
		wrt.committed = 0;
		wrt.max_pending = 1;
		wrt.is_tail = false;
		wrt.is_head = true;
		wrt.pending_list[1] = parg.data;
		key_meta_list[id] = wrt;
	}
	
	twait { propagate(id, mkevent(ret_val)); }
	
	sbp->replyref(true);	
}

tamed void process_propagate(svccb * sbp) {
	tvars {
		propagate_arg parg;
		ID_Value id;
		map<ID_Value, Node>::iterator it;
		map<ID_Value, Node>::iterator parent_ptr;
		map<ID_Value, key_meta>::iterator kit;
		map<ID_Value, Node>::iterator t;
		key_meta wrt;
		int i;
		bool in_succ;
	}

	parg = *(sbp->getarg<propagate_arg>());
	warn << "Got PROPAGATE Request\n";
	
	id.set_from_rpc(parg.id);

	kit = key_meta_list.find(id);
	//Reject if we already have a higher version
	if(kit != key_meta_list.end() || kit->second.max_pending > parg.ver  )
		sbp->replyref(false);
		
	//Reply true if versions are equal
	if(kit != key_meta_list.end() || kit->second.max_pending == parg.ver  )
		sbp->replyref(true);

	t = ring_succ(id);
	in_succ = false;
	for(i=0; i<RING_SIZE; i++) {
		if(t == my_node_ptr) {
			in_succ = true;
			break;
		}
		ring_inc(t);
	}
	
	if(!in_succ) {
		sbp->replyref(false);
	}
	
	if(kit == key_meta_list.end() && !id.between(parent_ptr->first, my_node.getId())) {
		//Reply false if 
		sbp->replyref(false);
	} else if(kit == key_meta_list.end()) {
		//Update meta key
		wrt = kit->second;
		wrt.max_pending = parg.ver;
		wrt.pending_list[parg.ver] = parg.data;
		key_meta_list[id] = wrt;
	}

}

tamed void propagate(ID_Value id, cbb cb) {
	tvars {
		map<ID_Value, key_meta>::iterator it;
		map<ID_Value, Node>::iterator succ;
		map<int, blob>::iterator dt_it;
		propagate_arg arg;
		ptr<aclnt> cli; 
		clnt_stat e;
		int fd;
		bool ret;
		bool rpc_ret;
	}
	
	rpc_ret = false;
	while(!rpc_ret) {
	
		it = key_meta_list.find(id);
		if(it == key_meta_list.end()) {
			ret = false;
			(*cb)(ret);
			return;
		}
			
		succ = my_node_ptr;
		ring_incr(succ);
		
		dt_it = it->second.pending_list.find(it->second.max_pending);
		if(dt_it == it->second.pending_list.end()) {
			ret = false;
			(*cb)(ret);
			return;
		}
		arg.id = id.get_rpc_id();
		arg.ver = it->second.max_pending;
		arg.data = dt_it->second;
	
		warn << "Propagating ID " << id.toString().c_str() << " to neighbor " << succ->second.getIp().c_str() << "\n";
		twait { get_rpc_cli (succ->second.getIp().c_str(), succ->second.getPort(), &cli, &chain_node_1, mkevent(fd)); }
	
		if( fd<0 ) {
			continue;
		}
		
		twait {	cli->call(PROPAGATE, &arg, &rpc_ret,  mkevent(e)); }
		if(e) {
			continue;
		}
	
	}
	
	ret = true;
	(*cb)(ret);
	return;
	
}

void update_my_ptr() {
	my_node_ptr = ring.find(my_id);
	if(my_node_ptr == ring.end()) {
		fatal << "Couldn't find my own ID in the node list! Killing myself...\n";
	}
}

void rpc_server::dispatch(svccb * sbp) {
	if(!sbp){}
	
	u_int p = sbp->proc();
	switch(p) {
		case TAIL_READ:
			process_tail_read(sbp);
			break;
 		case HEAD_WRITE:
 			process_head_write(sbp);
 			break;
 		case PROPAGATE:
 			process_propagate(sbp);
 			break;
 		case QUERY_OBJ_VER:
 			process_query_obj_ver(sbp);
 			break;
 		case ACK:
 			sbp->reject(PROC_UNAVAIL);
 			break;
 		case POKE_NODE_LIST_VER:
 			process_poke_node_list_ver(sbp);
 			break;
 		case BACK_PROPAGATE:
 			sbp->reject(PROC_UNAVAIL);
 			break;
		default: {
			sbp->reject(PROC_UNAVAIL);
			break;
		}
	}	
}

map<ID_Value, Node>::iterator ring_succ(ID_Value id) {
	map<ID_Value, Node>::iterator it = ring.lower_bound(id);
	if(it == ring.end())
		it = ring.begin();
	return it;
}

void ring_incr(map<ID_Value, Node>::iterator * it) {
	(*it)++;
	if( (*it)==ring.end() ) {
		(*it) = ring.begin();
	}
}

void ring_decr(map<ID_Value, Node>::iterator * it) {
	if( (*it)==ring.begin() ) {
		(*it) = ring.end();
	}
	(*it)--;
}

tamed static void report_bad_node(Node n) {
	tvars {
		int fd, i;
		ptr<axprt_stream> x;
		ptr<aclnt> cli; 
		clnt_stat e;
		bool ret;
		rpc_node arg;
	}
	
	twait { get_rpc_cli (manager_hostname, manager_port, &cli, &rpc_manager_1, mkevent(fd)); }
	
	if( fd<0 ) {
		fatal << "Lost connection to manager! Dying...\n";
		return;
	} else {
		arg = n.get_rpc_node();
		twait {	cli->call(REPORT_BAD, &arg, NULL, mkevent(e)); }
		if(e) {
			fatal << "Problem communicating with manager! Dying...\n";
		}
	}
}

tamed static void poke_neighbor(Node n, cbb cb) {
	tvars {
		int fd, i;
		ptr<axprt_stream> x;
		ptr<aclnt> cli; 
		clnt_stat e;
		bool ret;
	}

	warn << "Poking neighbor " << n.toString().c_str() << "\n";
	twait { get_rpc_cli (n.getIp().c_str(), n.getPort(), &cli, &chain_node_1, mkevent(fd)); }

	if( fd<0 ) {
		ret = false;
		(*cb)(ret);
	} else {
		twait {	cli->call(POKE_NODE_LIST_VER, &known_version, NULL,  mkevent(e)); }
		if(e) {
			ret = false;
			(*cb)(ret);
		} else {
			ret = true;
			(*cb)(ret);
		}
	}
}

tamed static void poke_neighbors() {
	tvars {
		map<ID_Value, Node>::iterator it;
		set<Node> to_poke;
		set<Node>::iterator t;
		deque<Node> final_list;
		u_int i;
		ptr<axprt_stream> x;
		ptr<aclnt> cli; 
		ptr<bool> res;
		rendezvous_t<u_int, ptr<bool> > rv;
		u_int nrecv;
	}
	
	it = my_node_ptr;
	if(ring.size()==1)
		return;
		
	for(i=0; i<CHAIN_SIZE-1; i++)
		ring_decr(&it);
		
	for(i=0; i<2*CHAIN_SIZE-2; i++, ring_incr(&it)) {
		if(it == my_node_ptr) {
			i--;
			continue;
		}
		to_poke.insert(it->second);
	}
	
	final_list.resize(to_poke.size());

	for(t=to_poke.begin(), i=0; t!=to_poke.end(); t++, i++) {
		final_list[i] = *t;
		res = New refcounted<bool> ();
		poke_neighbor(*t, mkevent(rv, i, res, *res));
	}

	nrecv = 0;
	while(nrecv < to_poke.size()) {
		twait(rv, i, res);
		nrecv++;
		if(! (*res)) {
			report_bad_node(final_list[i]);
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
		fatal << "Connection to manager failed (host:" << h << ",port:" << port << "\n";
	}

	twait {	
		cli->call(REGISTER, &arg, NULL, mkevent(e));
		cli->call(GET_NODE_LIST, NULL, &ret, mkevent(e2));
	}
	if(e || e2) {
		fatal << "Registering to the manager and retrieving node list failed.\n";
	}
	
	warn << "Connected to manager.\n";
	
	known_version = ret.ver;
	for(i=0; i<ret.nodes.size(); i++) {
		Node cur(ret.nodes[i]);
		ring[cur.getId()] = cur;
	}
	update_my_ptr();
	poke_neighbors();

	delaycb(1, 0, wrap(get_updates_stub));
	
}

tamed void get_updates() {
	
	tvars {
		int fd;
		ptr<aclnt> cli; 
		rpc_node_list ret;
		clnt_stat e;
		unsigned int i;
	}
	
	twait { get_rpc_cli (manager_hostname, manager_port, &cli, &rpc_manager_1, mkevent(fd)); }
	if( fd<0 ) {
		fatal << "Connection to manager failed (host:" << manager_hostname << ",port:" << manager_port << "\n";
	}
	
	twait {	
		cli->call(GET_NODE_LIST, NULL, &ret, mkevent(e));
	}
	if(e) {
		fatal << "Retrieving node list failed. Dying...\n";
	}

	known_version = ret.ver;
	ring.clear();
	for(i=0; i<ret.nodes.size(); i++) {
		Node cur(ret.nodes[i]);
		ring[cur.getId()] = cur;
	}
	update_my_ptr();
	
}

void get_updates_stub() {
	twait { get_updates(); }
	delaycb(1, 0, wrap(get_updates_stub));
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
