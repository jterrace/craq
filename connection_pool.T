#include "connection_pool.H"

const u_int NUM_POOLS = 50;
u_int glob_pool = 0;
deque<conn_info> conn_pool[NUM_POOLS];

tamed void
get_rpc_cli( const char * host, unsigned int port,
				ptr<aclnt> * call_ret, const rpc_program * prog,
				evi_t ev ) {
	tvars {
		int fd;
		string hostname;
		deque<conn_info>::iterator it;
		conn_info to_ins;
		u_int cur_pool;
	}

	glob_pool++;
	if(glob_pool >= NUM_POOLS)
		glob_pool = 0;

	cur_pool = glob_pool;

	hostname = host;
	for(it=conn_pool[cur_pool].begin(); it!=conn_pool[cur_pool].end(); ) {
		if( (it->hostname == hostname) && (it->port == port) && (prog == it->prog) ) {
			if( it->fd >= 0 ) {
				(*call_ret) = it->cli;
				ev->trigger(0);
				return;
			} else {
				//try and wait and see if the other function call will get it
				twait { delaycb (0, 10, mkevent ()); }
				it = conn_pool[cur_pool].begin();
			}
		} else {
			it++;
		}
	}

	//Set initial host info so others dont also try and connect at the same time
	to_ins.hostname = host;
	to_ins.port = port;
	to_ins.prog = prog;
	to_ins.fd = -1;
	conn_pool[cur_pool].push_back(to_ins);

	//try and connect
	twait { tcpconnect (host, port, mkevent(fd)); }

	//erase the old one with the -1 file descriptor
	for(it=conn_pool[cur_pool].begin(); it!=conn_pool[cur_pool].end(); it++) {
		if( (it->hostname == hostname) && (it->port == port) && (prog == it->prog) && (it->fd == -1) ) {
			conn_pool[cur_pool].erase(it);
			break;
		}
	}

	//return if file descriptor is bad
	if(fd < 0) {
		ev->trigger(fd);
		return;
	}

	//insert real one
	to_ins.x = axprt_stream::alloc(fd);
	to_ins.cli = aclnt::alloc(to_ins.x, *prog);
	to_ins.fd = fd;
	conn_pool[cur_pool].push_back(to_ins);

	//return good value
	(*call_ret) = to_ins.cli;
	ev->trigger(0);
}

void
invalidate_rpc_host( const char * host,
				unsigned int port) {

	deque<conn_info>::iterator it;
	string hostname;
	u_int i;

	hostname = host;

	for(i=0; i<NUM_POOLS; i++) {
		for(it=conn_pool[i].begin(); it!=conn_pool[i].end(); ) {
			if( it->hostname == hostname && it->port == port ) {
				conn_pool[i].erase(it);
				it = conn_pool[i].begin();
			} else {
				it++;
			}
		}
	}

}
