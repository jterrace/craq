#include "connection_pool.H"

deque<conn_info> conn_pool;

tamed void
get_rpc_cli( const char * host, unsigned int port, ptr<aclnt> * call_ret, const rpc_program * prog, evi_t ev ) {
	tvars {
		int fd;
		string hostname;
		deque<conn_info>::iterator it;
		conn_info to_ins;
		clnt_stat e;
	}
	
	hostname = host;
	for(it=conn_pool.begin(); it!=conn_pool.end(); it++) {
		if( it->hostname == hostname && it->port == port && (prog == it->prog) && (it->fd >= 0) ) {
			(*call_ret) = it->cli;
			ev->trigger(0);
			return;
		}
	}
	twait { tcpconnect (host, port, mkevent(fd)); }
	if(fd < 0) {
		ev->trigger(fd);
		return;
	}
	to_ins.x = axprt_stream::alloc(fd);
	to_ins.cli = aclnt::alloc(to_ins.x, *prog);
	to_ins.hostname = host;
	to_ins.port = port;
	to_ins.fd = fd;
	to_ins.prog = prog;
	conn_pool.push_back(to_ins);
	(*call_ret) = to_ins.cli;
	ev->trigger(0);
}
