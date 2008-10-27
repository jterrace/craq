#include <deque>
#include <map>
#include "tame.h"
#include "tame_rpcserver.h"
#include "parseopt.h"
#include "arpc.h"
#include "async.h"
#include "craq_rpc.h"
#include "Node.h"

class rpc_server : public tame::server_t {
public:
  rpc_server (int fd, int v) : tame::server_t (fd, v) {}
  const rpc_program &get_prog () const { return rpc_manager_1; }
  void dispatch (svccb *sbp);
};

class rpc_server_factory : public tame::server_factory_t {
public:
  rpc_server_factory () : tame::server_factory_t () {}
  tame::server_t *alloc_server (int fd, int v) { return New rpc_server (fd, v); }
};

const unsigned VERSION_HIST_CT = 10;

unsigned int version_number = 0;
map<ID_Value, Node> node_list;
rpc_memb_delta memb_hist_cache;
rpc_node_list node_list_cache;

static void update_node_list_cache(CLOSURE);
static void process_register(svccb * sbp, CLOSURE);
static void process_get_node_list_version(svccb * sbp, CLOSURE);
static void process_get_node_list(svccb * sbp, CLOSURE);
static void process_get_node_list_delta(svccb * sbp, CLOSURE);
static void process_report_bad(svccb * sbp, CLOSURE);

void rpc_server::dispatch(svccb * sbp) {
	if(!sbp){}

	u_int p = sbp->proc();
	switch(p) {
		case REGISTER: {
			process_register(sbp);
			break;
		} case GET_NODE_LIST_VERSION: {
			process_get_node_list_version(sbp);
			break;
		} case GET_NODE_LIST: {
			process_get_node_list(sbp);
			break;
		} case GET_NODE_LIST_DELTA: {
			process_get_node_list_delta(sbp);
			break;
		} case REPORT_BAD: {
			process_report_bad(sbp);
			break;
		} default: {
			sbp->reject(PROC_UNAVAIL);
			break;
		}
	}	
}

tamed void update_node_list_cache() {
	node_list_cache.nodes.setsize(node_list.size());
	node_list_cache.ver = version_number;
	int i = 0;
	for(map<ID_Value,Node>::iterator it = node_list.begin(); it != node_list.end(); it++, i++) {
		node_list_cache.nodes[i] = (it->second).get_rpc_node();
	}
}

tamed void process_register(svccb * sbp) {
	rpc_node parg = *(sbp->getarg<rpc_node>());
	warn << "Got REGISTER Request\n";
	
	//Update node list
	Node new_node(parg);
	node_list[new_node.getId()] = new_node;
	version_number++;
	update_node_list_cache();
	
	//Update history
	rpc_memb_change new_memb;
	new_memb.event = EVENT_ADD;
	new_memb.node = parg;
	new_memb.ver = version_number;
	memb_hist_cache.changes.push_back(new_memb);
	if(memb_hist_cache.changes.size() > VERSION_HIST_CT)
		memb_hist_cache.changes.pop_front();
		
	sbp->replyref(NULL);
}

tamed void process_get_node_list_version(svccb * sbp) {
	warn << "Got GET_NODE_LIST_VERSION Request\n";
	sbp->replyref(version_number);
}

tamed void process_get_node_list(svccb * sbp) {
	warn << "Got GET_NODE_LIST Request\n";
	sbp->replyref(node_list_cache);
}

tamed void process_get_node_list_delta(svccb * sbp) {
	tvars {
		u_int i;
	}
	warn << "Got GET_NODE_LIST_DELTA Request\n";
	unsigned cli_ver = *(sbp->getarg<unsigned>());
	if( cli_ver >= version_number || 
		(version_number-cli_ver)>VERSION_HIST_CT ) {
		sbp->replyref(NULL);
	} else {
		rpc_memb_delta to_ret;
		for(i=0; i<(version_number-cli_ver); i++) {
			to_ret.changes.push_back(
				memb_hist_cache.changes[memb_hist_cache.changes.size()-i-1]);
		}
		sbp->replyref(to_ret);
	}
}

tamed void process_report_bad(svccb * sbp) {
	rpc_node parg = *(sbp->getarg<rpc_node>());
	warn << "Got REPORT_BAD Request\n";
	
	//Update node list
	Node new_node(parg);
	map<ID_Value, Node>::iterator to_del = node_list.find(new_node.getId());
	if(to_del != node_list.end()) {
		node_list.erase(to_del);
		version_number++;
		update_node_list_cache();
		
		//Update history
		rpc_memb_change new_memb;
		new_memb.event = EVENT_DEL;
		new_memb.node = parg;
		new_memb.ver = version_number;
		memb_hist_cache.changes.push_back(new_memb);
		if(memb_hist_cache.changes.size() > VERSION_HIST_CT)
			memb_hist_cache.changes.pop_front();
	}

	sbp->replyref(NULL);
}
 
tamed static void start_rpc_srv(int listen_port) {
	tvars {
		bool ret;
		rpc_server_factory fact;
	}
	twait {
		fact.run(listen_port, mkevent(ret));
	}
	warn << "received a return val in start_rpc of: " << ret << "\n";
	exit(ret);
}

tamed static
void main2(int argc, char **argv) {
	int listen_port;
	if (argc == 2 && convertint(argv[1], &listen_port) ) {
		start_rpc_srv(listen_port);
	} else {
		fatal << "       manager <listen_port>\n"
			  << "               - starts the manager\n";
		exit(1);
	}
}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain ();
}
