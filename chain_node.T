#include <iostream>
#include <string>
#include <map>
#include <set>
#include <deque>
#include <sstream>
#include <ctime>
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
#include "zookeeper.h"

#define BUG 1


using namespace CryptoPP;
using namespace std;

const unsigned int CHAIN_SIZE = 3;
bool CRAQ;

class rpc_server : public tame::server_t {
public:
  rpc_server (int fd, int v) : tame::server_t (fd, v) { tcp_nodelay(fd); }
  const rpc_program &get_prog () const { return chain_node_1; }
  void dispatch (svccb *sbp);
};

class rpc_server_factory : public tame::server_factory_t {
public:
  rpc_server_factory () : tame::server_factory_t () {}
  tame::server_t *alloc_server (int fd, int v) { return New rpc_server (fd, v); }
};

void get_updates_stub();
void random_no_op_stub();
Storage * storage = new MemStorage();

struct key_meta {
	unsigned int committed;
	unsigned int max_pending;
	map<int, blob> pending_list;
	map<int, deque<svccb *> > write_reqs;
	bool is_head;
	bool is_tail;
};

typedef map<ID_Value, Node>::iterator ring_iter;
typedef map<ID_Value, key_meta>::iterator key_iter;

static void process_poke_node_list_ver(svccb * sbp, CLOSURE);
static void process_query_obj_ver(svccb * sbp, CLOSURE);
static void process_tail_read(svccb * sbp, CLOSURE);
static void process_tail_read_ex(svccb * sbp, CLOSURE);
static void process_head_write(svccb * sbp, CLOSURE);
static void process_propagate(svccb * sbp, CLOSURE);
static void propagate(ID_Value id, bool send_committed, cbb cb, CLOSURE);
static void process_back_propagate(svccb * sbp, CLOSURE);
static void back_propagate(ID_Value id, bool send_committed, cbb cb, CLOSURE);
static void process_ack(svccb * sbp, CLOSURE);
static void ack(ID_Value id, cbb cb, CLOSURE);
static void get_updates(CLOSURE);
static void report_bad_node(Node n, CLOSURE);

ring_iter ring_succ(ID_Value id);
void ring_incr(ring_iter * it);
void ring_decr(ring_iter * it);

ring_iter ring_succ(ID_Value id);
void ring_incr(ring_iter * it);
void ring_decr(ring_iter * it);

void do_zoo_interest();
void watcher(zhandle_t *zzh, int type, int state, const char *path, void* context);

str manager_hostname;
int manager_port;
unsigned int known_version;

map<ID_Value, Node> ring;
Node my_node;
string my_node_str;
ring_iter my_node_ptr;
ID_Value my_id;
string my_zoo_id;
int zoo_node_count = 0;

map<ID_Value, key_meta> key_meta_list;

bool update_running = false;

zhandle_t * zh;
map<int, timecb_t *> read_timeouts;
map<int, timecb_t *> write_timeouts;

void delay(long ms) {
  timespec ts;
  ts.tv_sec = ms / 1000;
  ts.tv_nsec = (ms % 1000) * 1000000;
  nanosleep(&ts, NULL);
}

str user_ip;
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
                else {
                	touse = addr;
                	str check = inet_ntoa(*touse);
                	if(check == user_ip) {
                		break;
                	}
                }
                addr++;
        }
        if (addr >= addrs.lim () && (loopback == NULL))
                fatal << "Cannot find my IP address.\n";
        str ids = inet_ntoa (*touse);
        if (touse == NULL) {
                warn << "Using loopback address as my address.\n";
                touse = loopback;
        } else {
        	warn << "Using IP address: " << ids << "\n";
        }
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
	if(BUG) warn << "Got POKE_NODE_LIST_VER Request\n";

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
		key_iter it;
	}

	parg = *(sbp->getarg<rpc_hash>());
	if(BUG>=2) warn << "Got QUERY_OBJ Request\n";

	id.set_from_rpc(parg);
	it = key_meta_list.find(id);
	if(it == key_meta_list.end()) {
		sbp->replyref(NULL);
		return;
	}

	repl.hist = (it->second).committed;
	repl.pend = (it->second).max_pending;
	sbp->replyref(repl);
}

tamed void process_tail_read(svccb * sbp) {
	tvars {
		rpc_hash parg;
		const blob * repl;
		ID_Value id;
		key_iter it;
		ring_iter rit;
		int i;
		ptr<aclnt> cli;
		clnt_stat e;
		int fd;
		query_obj_ver_ret ret;
		map<int, blob>::iterator kit;
		blob to_rep;
	}

	parg = *(sbp->getarg<rpc_hash>());
	if(BUG) warn << "Got TAIL_READ Request\n";

	id.set_from_rpc(parg);

	it = key_meta_list.find(id);

	if(CRAQ) {

		//CRAQ tail read

		if(it == key_meta_list.end() ) {
			sbp->replyref(NULL);
			return;
		}

		if(it->second.committed == it->second.max_pending) {
			if(BUG) warn << "Clean READ " << id.toString().c_str() << "\n";
			repl = storage->get(id);
			sbp->replyref(*repl);
			return;
		} else {
			if(BUG) warn << "Dirty READ " << id.toString().c_str() << "\n";

			//Find tail
			rit = ring_succ(id);
			for(i=0; i<CHAIN_SIZE-1; i++)
				ring_incr(&rit);

			twait { get_rpc_cli (rit->second.getIp().c_str(), rit->second.getPort(), &cli, &chain_node_1, mkevent(fd)); }

			if( fd<0 ) {
				report_bad_node(rit->second);
				sbp->replyref(NULL);
				return;
			}

			//Query tail
			twait {	cli->call(QUERY_OBJ_VER, &parg, &ret,  mkevent(e)); }

			if(e) {
				report_bad_node(rit->second);
				sbp->replyref(NULL);
				return;
			} else {
				//Refetch key
				it = key_meta_list.find(id);
				if(it == key_meta_list.end() ) {
					sbp->replyref(NULL);
					return;
				}

				//Got an ACK between call
				if(it->second.committed == it->second.max_pending) {
					if(BUG) warn << "Clean READ " << id.toString().c_str() << "\n";
					repl = storage->get(id);
					sbp->replyref(*repl);
					return;
				}
				//See if we have the version the tail would return
				kit = it->second.pending_list.find(ret.hist);
				if(kit == it->second.pending_list.end()) {
					sbp->replyref(NULL);
					return;
				}
				//Return tail's committed version
				to_rep = kit->second;
				sbp->replyref(to_rep);
				return;
			}
		}
	} else {
		//CR Read
		if(it == key_meta_list.end() || !(it->second).is_tail ) {
			sbp->replyref(NULL);
			return;
		}

		repl = storage->get(id);
		sbp->replyref(*repl);
	}
}

tamed void process_tail_read_ex(svccb * sbp) {
	tvars {
		tail_read_ex_arg parg;
		const blob * repl;
		ID_Value id;
		key_iter it;
		ring_iter rit;
		int i;
		ptr<aclnt> cli;
		clnt_stat e;
		int fd;
		query_obj_ver_ret ret;
		map<int, blob>::iterator kit;
		tail_read_ex_ret to_rep;
	}

	parg = *(sbp->getarg<tail_read_ex_arg>());
	if(BUG>=2) warn << "Got TAIL_READ_EX Request\n";

	id.set_from_rpc(parg.id);

	it = key_meta_list.find(id);

	if(CRAQ) {

		//CRAQ tail read

		if(it == key_meta_list.end() ) {
			sbp->replyref(NULL);
			return;
		}

		if(!parg.dirty && it->second.committed == it->second.max_pending) {
			if(BUG>=2) warn << "Clean READ " << id.toString().c_str() << "\n";
			repl = storage->get(id);
			to_rep.data = *repl;
			to_rep.dirty = false;
			sbp->replyref(to_rep);
			return;
		} else {
			if(BUG>=2) warn << "Dirty READ " << id.toString().c_str() << "\n";

			//Find tail
			rit = ring_succ(id);
			for(i=0; i<CHAIN_SIZE-1; i++)
				ring_incr(&rit);

			twait { get_rpc_cli (rit->second.getIp().c_str(), rit->second.getPort(), &cli, &chain_node_1, mkevent(fd)); }

			if( fd<0 ) {
				report_bad_node(rit->second);
				sbp->replyref(NULL);
				return;
			}

			//Query tail
			twait {	cli->call(QUERY_OBJ_VER, &parg, &ret,  mkevent(e)); }

			if(e) {
				report_bad_node(rit->second);
				sbp->replyref(NULL);
				return;
			} else {
				//Refetch key
				it = key_meta_list.find(id);
				if(it == key_meta_list.end() ) {
					sbp->replyref(NULL);
					return;
				}

				//Got an ACK between call
				if(it->second.committed == it->second.max_pending) {
					if(BUG>=2) warn << "Clean READ " << id.toString().c_str() << "\n";
					repl = storage->get(id);
					to_rep.data = *repl;
					to_rep.dirty = true;
					sbp->replyref(to_rep);
					return;
				}
				//See if we have the version the tail would return
				kit = it->second.pending_list.find(ret.hist);
				if(kit == it->second.pending_list.end()) {
					sbp->replyref(NULL);
					return;
				}
				//Return tail's committed version
				to_rep.data = kit->second;
				to_rep.dirty = true;
				sbp->replyref(to_rep);
				return;
			}
		}
	} else {
		//CR Read
		if(it == key_meta_list.end() || !(it->second).is_tail ) {
			sbp->replyref(NULL);
			return;
		}

		repl = storage->get(id);
		to_rep.data = *repl;
		to_rep.dirty = false;
		sbp->replyref(to_rep);
	}
}

tamed void process_head_write(svccb * sbp) {
	tvars {
		head_write_arg parg;
		ID_Value id;
		key_iter it;
		ring_iter parent_ptr;
		key_meta wrt;
		bool ret_val;
	}

	//Reject writes unless we can form a chain
	if(ring.size() < CHAIN_SIZE) {
		sbp->replyref(false);
		return;
	}

	parg = *(sbp->getarg<head_write_arg>());
	if(BUG) warn << "Got HEAD_WRITE Request\n";

	id.set_from_rpc(parg.id);
	it = key_meta_list.find(id);

	//If we're not the head, reject the request
	if(it != key_meta_list.end() && !(it->second).is_head ) {
		sbp->replyref(false);
		return;
	}

	parent_ptr = my_node_ptr;
	ring_decr(&parent_ptr);

	if(it == key_meta_list.end() && !id.between(parent_ptr->first, my_id)) {
		//Reply false if we don't think we should be the head
		sbp->replyref(false);
		return;
	} else if(it == key_meta_list.end()) {
		//Create new key if this is the first
		wrt.committed = 0;
		wrt.max_pending = 1;
		wrt.is_tail = false;
		wrt.is_head = true;
		wrt.pending_list[1] = parg.data;
		wrt.write_reqs[1].push_back(sbp);
		key_meta_list[id] = wrt;
	} else {
		//Update key if this is not the first
		wrt = it->second;
		wrt.max_pending++;
		wrt.pending_list[wrt.max_pending] = parg.data;
		wrt.write_reqs[wrt.max_pending].push_back(sbp);
		key_meta_list[id] = wrt;
	}

	twait { propagate(id, false, mkevent(ret_val)); }
}

tamed void process_propagate(svccb * sbp) {
	tvars {
		propagate_arg parg;
		ID_Value id;
		key_iter kit;
		ring_iter t;
		key_meta wrt;
		u_int i;
		bool in_succ;
		bool ret_val;
	}

	parg = *(sbp->getarg<propagate_arg>());
	if(BUG) warn << "Got PROPAGATE Request\n";
	if(BUG) warn << "Received Propagate key of size " << parg.data.size() << "\n";

	id.set_from_rpc(parg.id);

	kit = key_meta_list.find(id);

	//Reply true if we already have a higher or equal version
	if(kit != key_meta_list.end() &&
		((kit->second.max_pending >= parg.ver && parg.committed == false) ||
		 (kit->second.committed >= parg.ver && parg.committed == true))) {
		 	if(BUG) warn << "Already higher\n";
			sbp->replyref(true);
			return;
	}

	wrt.committed = 0;
	wrt.max_pending = 0;
	wrt.is_tail = false;
	wrt.is_head = false;

	t = ring_succ(id);
	in_succ = false;
	for(i=0; i<CHAIN_SIZE; i++) {
		if(t == my_node_ptr) {
			in_succ = true;
			break;
		}
		ring_incr(&t);
	}
	if(i == CHAIN_SIZE-1)
		wrt.is_tail = true;
	if(i == 0)
		wrt.is_head = true;
	//Return false if we don't think we should be storing a replica of this key
	if(!in_succ) {
		sbp->replyref(false);
		return;
	}

	if(kit != key_meta_list.end()) {
		wrt = kit->second;
	}

	//Update meta key
	if(parg.committed == true) {
		storage->set(id, &parg.data);
		wrt.committed = parg.ver;
		if(wrt.max_pending < wrt.committed)
			wrt.max_pending = wrt.committed;
		wrt.pending_list[wrt.max_pending] = parg.data;
	} else {
		wrt.max_pending = parg.ver;
		wrt.pending_list[parg.ver] = parg.data;
	}
	if(wrt.is_tail) {
		wrt.committed = wrt.max_pending;
		storage->set(id, &wrt.pending_list[wrt.max_pending]);
		wrt.pending_list.clear();
	}
	key_meta_list[id] = wrt;

	if(!wrt.is_tail) {
		sbp->replyref(true);
		twait { propagate(id, parg.committed, mkevent(ret_val)); }
	} else {
		sbp->replyref(true);
		twait { ack(id, mkevent(ret_val)); }
	}

}

tamed void process_back_propagate(svccb * sbp) {
	tvars {
		propagate_arg parg;
		ID_Value id;
		key_iter kit;
		ring_iter t;
		key_meta wrt;
		u_int i;
		bool in_succ;
		bool ret_val;
	}

	parg = *(sbp->getarg<propagate_arg>());
	if(BUG) warn << "Got BACK_PROPAGATE Request\n";

	id.set_from_rpc(parg.id);

	kit = key_meta_list.find(id);
	//Reply true if we already have a higher or equal version
	if(kit != key_meta_list.end() &&
		((kit->second.max_pending >= parg.ver && parg.committed == false) ||
		 (kit->second.committed >= parg.ver && parg.committed == true))) {
			sbp->replyref(true);
			return;
	}

	wrt.committed = 0;
	wrt.max_pending = 0;
	wrt.is_tail = false;
	wrt.is_head = false;

	t = ring_succ(id);
	in_succ = false;
	for(i=0; i<CHAIN_SIZE; i++) {
		if(t == my_node_ptr) {
			in_succ = true;
			break;
		}
		ring_incr(&t);
	}
	if(i == CHAIN_SIZE-1)
		wrt.is_tail = true;
	if(i == 0)
		wrt.is_head = true;
	//Return false if we don't think we should be storing a replica of this key
	if(!in_succ) {
		sbp->replyref(false);
		return;
	}

	if(kit != key_meta_list.end()) {
		wrt = kit->second;
	}

	//Update meta key
	if(parg.committed == true) {
		storage->set(id, &parg.data);
		wrt.committed = parg.ver;
		if(wrt.max_pending < wrt.committed)
			wrt.max_pending = wrt.committed;
	} else {
		wrt.max_pending = parg.ver;
		wrt.pending_list[parg.ver] = parg.data;
	}
	key_meta_list[id] = wrt;

	if(!wrt.is_head) {
		twait { back_propagate(id, parg.committed, mkevent(ret_val)); }
	}

}

tamed void process_ack(svccb * sbp) {
	tvars {
		ack_arg parg;
		ID_Value id;
		key_iter kit;
		map<int, blob>::iterator pendit;
		map<int, deque<svccb *> >::iterator it;
		deque<svccb *>::iterator repls;
		bool ret_val;
	}

	parg = *(sbp->getarg<ack_arg>());
	if(BUG) warn << "Got ACK Request\n";

	id.set_from_rpc(parg.id);

	kit = key_meta_list.find(id);

	//If we don't have this key, just reply false
	if(kit == key_meta_list.end()) {
		sbp->replyref(false);
		return;
	}

	//If we have higher or equal version committed, just reply true
	if(kit->second.committed >= parg.ver  ) {
		sbp->replyref(true);
		return;
	}

	//Try and find the acked version so we can commit and error if not found
	pendit = kit->second.pending_list.find(parg.ver);
	if(pendit == kit->second.pending_list.end()) {
		sbp->replyref(false);
		return;
	}

	if(!storage->set(id, &pendit->second)) {
		sbp->replyref(false);
		return;
	}

	//Send replies for head writes that we just acked before erasing
	for(it = kit->second.write_reqs.begin(); it != kit->second.write_reqs.end(); ) {
		for(repls = it->second.begin(); repls != it->second.end(); repls++) {
			if(BUG) warn << "Replying to write request\n";
			(*repls)->replyref(true);
		}
		it->second.clear();
		kit->second.write_reqs.erase(it++);
		if(it->first > parg.ver) break;
	}

	//Update committed version number
	kit->second.committed = parg.ver;
	//Erase all pending versions less than one just committed
	kit->second.pending_list.erase(kit->second.pending_list.begin(), pendit);

	if(BUG) warn << "Updated key " << id.toString().c_str() << " to "
		 << kit->second.committed << "/" << kit->second.max_pending << "\n";

	sbp->replyref(true);
	if(!kit->second.is_head) {
		twait { ack(id, mkevent(ret_val)); }
	}

}

tamed void propagate(ID_Value id, bool send_committed, cbb cb) {
	tvars {
		key_iter it;
		ring_iter succ;
		map<int, blob>::iterator dt_it;
		propagate_arg arg;
		ptr<aclnt> cli;
		clnt_stat e;
		int fd;
		bool ret;
		bool rpc_ret;
		u_int backoff;
	}

	backoff = 0;
	rpc_ret = false;
	while(!rpc_ret) {
		it = key_meta_list.find(id);
		if(it == key_meta_list.end()) {
			ret = false;
			(*cb)(ret);
			return;
		}

		if(it->second.is_tail) {
			ret = true;
			(*cb)(ret);
			return;
		}

		succ = my_node_ptr;
		ring_incr(&succ);

		if(send_committed) {
			arg.id = id.get_rpc_id();
			arg.ver = it->second.committed;
			arg.data = *(storage->get(id));
			arg.committed = true;
		} else {
			dt_it = it->second.pending_list.find(it->second.max_pending);
			if(dt_it == it->second.pending_list.end()) {
				ret = false;
				(*cb)(ret);
				return;
			}
			arg.id = id.get_rpc_id();
			arg.ver = it->second.max_pending;
			arg.data = dt_it->second;
			arg.committed = false;
		}

		if(BUG) warn << "Propagating ID " << id.toString().c_str() << " to neighbor " << succ->second.toString().c_str() << "\n";
		twait { get_rpc_cli (succ->second.getIp().c_str(), succ->second.getPort(), &cli, &chain_node_1, mkevent(fd)); }

		if( fd<0 ) {
			report_bad_node(succ->second);
			backoff++;
			twait { delaycb (0, 50 * 1000000 * backoff, mkevent ()); }
			continue;
		}

		if(BUG) warn << "Propagating key of size " << arg.data.size() << "\n";
		twait {	cli->call(PROPAGATE, &arg, &rpc_ret,  mkevent(e)); }
		if(e) {
			report_bad_node(succ->second);
			backoff++;
			twait { delaycb (0, 50 * 1000000 * backoff, mkevent ()); }
			continue;
		} else if(!rpc_ret) {
			backoff++;
			twait { delaycb (0, 50 * 1000000 * backoff, mkevent ()); }
			continue;
		}

	}

	ret = true;
	(*cb)(ret);
	return;

}

tamed void back_propagate(ID_Value id, bool send_committed, cbb cb) {
	tvars {
		key_iter it;
		ring_iter pred;
		map<int, blob>::iterator dt_it;
		propagate_arg arg;
		ptr<aclnt> cli;
		clnt_stat e;
		int fd;
		bool ret;
		bool rpc_ret;
		const blob * st_val;
		u_int backoff;
	}

	backoff = 0;
	rpc_ret = false;
	while(!rpc_ret) {
		it = key_meta_list.find(id);
		if(it == key_meta_list.end()) {
			ret = false;
			(*cb)(ret);
			return;
		}

		if(it->second.is_head) {
			ret = true;
			(*cb)(ret);
			return;
		}

		pred = my_node_ptr;
		ring_decr(&pred);

		if(send_committed) {
			if(it->second.committed <= 0) {
				//There is no committed version, so die
				ret = true;
				(*cb)(ret);
				return;
			}
			arg.id = id.get_rpc_id();
			arg.ver = it->second.committed;
			st_val = storage->get(id);
			if(!st_val) {
				fatal << "Couldn't get value from storage " << id.toString().c_str() << "! Dying...\n";
			}
			arg.data = *st_val;
			arg.committed = true;
		} else {
			dt_it = it->second.pending_list.find(it->second.max_pending);
			if(dt_it == it->second.pending_list.end()) {
				ret = false;
				(*cb)(ret);
				return;
			}
			arg.id = id.get_rpc_id();
			arg.ver = it->second.max_pending;
			arg.data = dt_it->second;
			arg.committed = false;
		}

		if(BUG) warn << "Back Propagating ID " << id.toString().c_str() << " to neighbor " << pred->second.toString().c_str() << "\n";
		twait { get_rpc_cli (pred->second.getIp().c_str(), pred->second.getPort(), &cli, &chain_node_1, mkevent(fd)); }

		if( fd<0 ) {
			report_bad_node(pred->second);
			backoff++;
			twait { delaycb (0, 50 * 1000000 * backoff, mkevent ()); }
			continue;
		}

		twait {	cli->call(BACK_PROPAGATE, &arg, &rpc_ret,  mkevent(e)); }
		if(e || !rpc_ret) {
			report_bad_node(pred->second);
			backoff++;
			twait { delaycb (0, 50 * 1000000 * backoff, mkevent ()); }
			continue;
		}

	}

	ret = true;
	(*cb)(ret);
	return;

}

tamed void ack(ID_Value id, cbb cb) {
	tvars {
		key_iter it;
		ring_iter pred;
		ack_arg arg;
		ptr<aclnt> cli;
		clnt_stat e;
		int fd;
		bool ret;
		bool rpc_ret;
		u_int backoff;
	}

	backoff = 0;
	rpc_ret = false;
	while(!rpc_ret) {
		//TODO: DELETE THIS!
		if(backoff > 10) {
			exit(1);
		}
		it = key_meta_list.find(id);
		if(it == key_meta_list.end()) {
			ret = false;
			(*cb)(ret);
			return;
		}

		pred = my_node_ptr;
		ring_decr(&pred);

		arg.id = id.get_rpc_id();
		arg.ver = it->second.committed;

		if(BUG) warn << "ACKing ID " << id.toString().c_str() << " to neighbor " << pred->second.toString().c_str() << "\n";
		twait { get_rpc_cli (pred->second.getIp().c_str(), pred->second.getPort(), &cli, &chain_node_1, mkevent(fd)); }

		if( fd<0 ) {
			report_bad_node(pred->second);
			backoff++;
			twait { delaycb (0, 50 * 1000000 * backoff, mkevent ()); }
			continue;
		}

		twait {	cli->call(ACK, &arg, &rpc_ret,  mkevent(e)); }
		if(e) {
			report_bad_node(pred->second);
			backoff++;
			twait { delaycb (0, 50 * 1000000 * backoff, mkevent ()); }
			continue;
		} else if(!rpc_ret) {
			continue;
			backoff++;
			twait { delaycb (0, 50 * 1000000 * backoff, mkevent ()); }
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
		case TAIL_READ_EX:
			process_tail_read_ex(sbp);
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
 			process_ack(sbp);
 			break;
 		case POKE_NODE_LIST_VER:
 			process_poke_node_list_ver(sbp);
 			break;
 		case BACK_PROPAGATE:
 			process_back_propagate(sbp);
 			break;
 		case NO_OP:
 			sbp->replyref(true);
 			break;
		default: {
			sbp->reject(PROC_UNAVAIL);
			break;
		}
	}
}

ring_iter ring_succ(ID_Value id) {
	ring_iter it = ring.lower_bound(id);
	if(it == ring.end())
		it = ring.begin();
	return it;
}

void ring_incr(ring_iter * it) {
	(*it)++;
	if( (*it)==ring.end() ) {
		(*it) = ring.begin();
	}
}

void ring_decr(ring_iter * it) {
	if( (*it)==ring.begin() ) {
		(*it) = ring.end();
	}
	(*it)--;
}

tamed void report_bad_node(Node n) {
	tvars {
		int fd;
		ptr<aclnt> cli;
		clnt_stat e;
		rpc_node arg;
	}

	if(BUG) warn << "Reporting bad node " << n.toString().c_str() << "\n";
	invalidate_rpc_host(n.getIp().c_str(), n.getPort());

	twait { get_rpc_cli (manager_hostname, manager_port, &cli, &rpc_manager_1, mkevent(fd)); }

	if( fd<0 ) {
		fatal << "Lost connection to manager! Dying...\n";
	} else {
		arg = n.get_rpc_node();
		twait {	cli->call(REPORT_BAD, &arg, NULL, mkevent(e)); }
		if(e) {
			fatal << "Problem communicating with manager! Dying...\n";
		}
	}

	twait { get_updates(); }

}

tamed static void poke_neighbor(Node n, cbb cb) {
	tvars {
		int fd;
		ptr<aclnt> cli;
		clnt_stat e;
		bool ret;
	}

	if(BUG) warn << "Poking neighbor " << n.toString().c_str() << "\n";
	twait { get_rpc_cli (n.getIp().c_str(), n.getPort(), &cli, &chain_node_1, mkevent(fd)); }

	if( fd<0 ) {
		report_bad_node(n);
		ret = false;
		(*cb)(ret);
	} else {
		twait {	cli->call(POKE_NODE_LIST_VER, &known_version, NULL,  mkevent(e)); }
		if(e) {
			report_bad_node(n);
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
		ring_iter it;
		set<Node> to_poke;
		set<Node>::iterator t;
		deque<Node> final_list;
		u_int i;
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
	warn << "Exiting after RPC stopped. Return value was: " << ret << "\n";
	exit(ret);
}

tamed static void node_added(Node node_changed) {
	tvars {
		ring_iter succ;
		ring_iter pred;
		ring_iter cs_head;
		ring_iter cs_head_pred;
		key_iter k;
		key_iter temp;
		bool ret;
		u_int i;
	}

	if(BUG) warn << "Node added: " << node_changed.toString().c_str() << "\n";

	succ = my_node_ptr;
	ring_incr(&succ);
	pred = my_node_ptr;
	ring_decr(&pred);

	ring[node_changed.getId()] = node_changed;
	update_my_ptr();

	if(BUG) warn << "Checking if node " << node_changed.getId().toString().c_str()
		 << " is between me " << my_id.toString().c_str()
		 << " and my succ " << succ->first.toString().c_str() << "\n";

	//Check if successor and propagate all keys
	if(node_changed.getId().between(my_id, succ->first)) {
		twait {
			for(k = key_meta_list.begin(); k != key_meta_list.end(); k++) {
				propagate(k->first, false, mkevent(ret));
				propagate(k->first, true, mkevent(ret));
			}
		}
		return;
	}

	cs_head = my_node_ptr;
	for(i=0; i<(CHAIN_SIZE-1); i++) {
		ring_decr(&cs_head);
	}
	cs_head_pred = cs_head;
	ring_decr(&cs_head_pred);

	if(BUG) warn << "Checking if node " << node_changed.getId().toString().c_str()
		 << " is between pred " << pred->first.toString().c_str()
		 << " and me " << my_id.toString().c_str() << "\n";

	//Check if predecessor and back propagate all keys that i'm not the head for
	//   For keys that now belong to new guy, mark not head
	//	 For keys I was tail for and new guy is now tail, mark
	//	 For keys that I should become the tail, become it
	if(node_changed.getId().between(pred->first, my_id)) {
		twait {
			//Fire off back propagates for all keys that im not still head for
			for(k = key_meta_list.begin(); k != key_meta_list.end(); ) {
				//Only look at keys for which we are not STILL the head
				if(!k->first.between(node_changed.getId(), my_id)) {
					//We were the head, but now the new guy is
					if(k->second.is_head) {
						if(BUG) warn << "No longer head for " << k->first.toString().c_str() << "\n";
						k->second.is_head = false;
					}

					back_propagate(k->first, false, mkevent(ret));
					back_propagate(k->first, true, mkevent(ret));

					if(k->second.is_tail) {
						//We are no longer tail so remove
						if(BUG) warn << "Removing key " << k->first.toString().c_str() << "\n";
						key_meta_list.erase(k++);
					} else {
						//Check if we need to become the tail
						if(k->first.between(cs_head_pred->first, cs_head->first)) {
							if(BUG) warn << "Becoming tail for " << k->first.toString().c_str() << "\n";
							k->second.is_tail = true;
						}
						k++;
					}

				} else {
					k++;
				}
			}
		}
		return;
	}

	if(BUG) warn << "Checking if node " << node_changed.getId().toString().c_str()
		 << " is between first " << cs_head->first.toString().c_str()
		 << " and me " << my_id.toString().c_str() << "\n";

	//Check if in chain-size predecessor list and remove tail keys
	//    Since our predecessor is now the tail
	//	Also, we might have to become the new tail
	//    so any keys between predpred and pred i should be the tail for
	if(node_changed.getId().betweenIncl(cs_head->first, my_id)) {
		for(k = key_meta_list.begin(); k != key_meta_list.end(); ) {
			if(k->second.is_tail) {
				if(BUG) warn << "Removing key " << k->first.toString().c_str() << "\n";
				key_meta_list.erase(k++);
			} else {
				if(k->first.between(cs_head_pred->first, cs_head->first)) {
					if(BUG) warn << "Becoming tail for " << k->first.toString().c_str() << "\n";
					k->second.is_tail = true;
				}
				k++;
			}
		}
	}

}

tamed static void node_deleted(Node node_changed) {

	tvars {
		ring_iter succ;
		ring_iter pred;
		ring_iter cs_head;
		ring_iter cs_head_pred;
		ring_iter it;
		key_iter k;
		key_iter temp;
		bool ret;
		u_int i;
	}

	if(BUG) warn << "Node deleted: " << node_changed.toString().c_str() << "\n";

	it = ring.find(node_changed.getId());
	if(it == ring.end()) {
		fatal << "Deleting node that we didn't know about! Should never happen... dying!\n";
	}
	invalidate_rpc_host(it->second.getIp().c_str(), it->second.getPort());
	ring.erase(it);
	update_my_ptr();

	succ = my_node_ptr;
	ring_incr(&succ);
	pred = my_node_ptr;
	ring_decr(&pred);

	if(BUG) warn << "Checking if node " << node_changed.getId().toString().c_str()
		 << " is between me " << my_id.toString().c_str()
		 << " and my succ " << succ->first.toString().c_str() << "\n";

	//Check if successor and propagate all keys
	if(node_changed.getId().between(my_id, succ->first)) {
		twait {
			for(k = key_meta_list.begin(); k != key_meta_list.end(); k++) {
				propagate(k->first, false, mkevent(ret));
				propagate(k->first, true, mkevent(ret));
			}
		}
		return;
	}

	cs_head = my_node_ptr;
	for(i=0; i<(CHAIN_SIZE-1); i++) {
		ring_decr(&cs_head);
	}
	cs_head_pred = cs_head;
	ring_decr(&cs_head_pred);

	if(BUG) warn << "Checking if node " << node_changed.getId().toString().c_str()
		 << " is between pred " << pred->first.toString().c_str()
		 << " and me " << my_id.toString().c_str() << "\n";

	//Check if predecessor and back propagate all keys that i'm not the head for
	//	 For keys that I should become the head, become it
	//	 If I am tail, unmark tail and propagate
	//	 Can't search for keys that I should be the tail because I don't know about them
	//           and I will get a propagate from the dead dude's predecessor anyway
	if(node_changed.getId().between(pred->first, my_id)) {
		twait {
			for(k = key_meta_list.begin(); k != key_meta_list.end(); k++) {
				//First, find keys that I should be the head for
				if(k->first.between(pred->first, my_id)) {
					if(k->second.is_head == false) {
						if(BUG) warn << "Becoming head for " << k->first.toString().c_str() << "\n";
						k->second.is_head = true;
					}
				//For all other keys, we should back propagate
				} else {
					if(k->second.is_tail) {
						if(BUG) warn << "No longer tail for " << k->first.toString().c_str() << "\n";
						k->second.is_tail = false;
						propagate(k->first, false, mkevent(ret));
						propagate(k->first, true, mkevent(ret));
					}
					back_propagate(k->first, false, mkevent(ret));
					back_propagate(k->first, true, mkevent(ret));
				}
			}
		}
		return;
	}

	if(BUG) warn << "Checking if node " << node_changed.getId().toString().c_str()
		 << " is between first " << cs_head->first.toString().c_str()
		 << " and me " << my_id.toString().c_str() << "\n";

	//Check if in chain-size predecessor list and unmark tail and propagate
	if(node_changed.getId().betweenIncl(cs_head->first, my_id)) {
		twait {
			for(k = key_meta_list.begin(); k != key_meta_list.end(); k++) {
				if(k->second.is_tail) {
					if(BUG) warn << "No longer tail for " << k->first.toString().c_str() << "\n";
					k->second.is_tail = false;
					propagate(k->first, false, mkevent(ret));
					propagate(k->first, true, mkevent(ret));
				}
			}
		}
	}

}

tamed void get_updates() {

	tvars {
		int fd;
		ptr<aclnt> cli;
		clnt_stat e;
		u_int newest_ver;
		rpc_memb_delta delt;
		ID_Value id_changed;
		Node node_changed;
	}

	if(update_running) return;
	update_running = true;

	twait { get_rpc_cli (manager_hostname, manager_port, &cli, &rpc_manager_1, mkevent(fd)); }
	if( fd<0 ) {
		fatal << "Connection to manager failed (host:" << manager_hostname << ",port:" << manager_port << "\n";
	}

	twait {	cli->call(GET_NODE_LIST_VERSION, NULL, &newest_ver, mkevent(e)); }
	if(e) {
		fatal << "Retrieving the node list from the manager failed.\n";
	}

	if(newest_ver <= known_version) {
		update_running = false;
		return;
	}

	twait { cli->call(GET_NODE_LIST_DELTA, &known_version, &delt, mkevent(e)); }
	if(e) {
		fatal << "Retrieving the delta of the node list from the manager failed.\n";
	}

	if(delt.changes.size() == 0) {
		//TODO: Do diff with full version
		fatal << "Too lazy to implement this right now! Dying! (yay research)\n";
	} else {
		for(int i=0; i<delt.changes.size(); i++) {
			if(delt.changes[i].ver > newest_ver)
				newest_ver = delt.changes[i].ver;
			node_changed.set_from_rpc_node(delt.changes[i].node);
			if(delt.changes[i].event == EVENT_ADD) {
				node_added(node_changed);
			} else {
				node_deleted(node_changed);
			}
		}
	}

	known_version = newest_ver;
	if(BUG) warn << "Updated to newest node list version: " << known_version << "\n";
	update_running = false;

}

void get_updates_stub() {
	twait { get_updates(); }
	delaycb(1, 0, wrap(get_updates_stub));
}

tamed static void random_no_op {
	tvars {
		u_int r, i;
		ring_iter k;
		int fd;
		ptr<aclnt> cli;
		clnt_stat e;
		bool ret;
	}

	srand ( time(NULL) );

	while(1) {

		r = rand() % ring.size();
		for(k = ring.begin(), i=0; k != ring.end(), i<r; k++, i++);
		if(k == ring.end()) {
			fatal << "Somehow got to the end of the list when randomly running a NOOP. Shouldn't happen. Dying!\n";
		}

		if(BUG>=2) warn << "Calling a random NOOP on " << k->second.toString().c_str() << "\n";

		twait { get_rpc_cli (k->second.getIp().c_str(), k->second.getPort(), &cli, &chain_node_1, mkevent(fd)); }

		if( fd<0 ) {
			report_bad_node(k->second);
		} else {
			twait {	cli->call(NO_OP, NULL, &ret,  mkevent(e)); }
			if(e || !ret) {
				report_bad_node(k->second);
			}
		}

		twait { delaycb (0, 250 * 1000000, mkevent()); }

	}

}

void random_no_op_stub() {
	random_no_op();
}

void fdcb_read_timeout(int fd) {
	warn << "read timeout " << fd << "\n";
	map<int, timecb_t *>::iterator it = read_timeouts.find(fd);
	if( it != read_timeouts.end() ) {
		read_timeouts.erase(it);
	}
	//fdcb(fd, selread, 0);
	int events = 0;
	//events |= ZOOKEEPER_READ;
	zookeeper_process(zh, events);
	do_zoo_interest();
}

void fdcb_read(int fd) {
	warn << "got read for fd: " << fd << "\n";
	map<int, timecb_t *>::iterator it = read_timeouts.find(fd);
	if( it != read_timeouts.end() ) {
		timecb_remove(it->second);
		read_timeouts.erase(it);
	}
	int events = 0;
	events |= ZOOKEEPER_READ;
	zookeeper_process(zh, events);
	do_zoo_interest();
}

void fdcb_write_timeout(int fd) {
	warn << "write timeout " << fd << "\n";
	map<int, timecb_t *>::iterator it = write_timeouts.find(fd);
	if( it != write_timeouts.end() ) {
		write_timeouts.erase(it);
	}
	//fdcb(fd, selwrite, 0);
	int events = 0;
	//events |= ZOOKEEPER_WRITE;
	zookeeper_process(zh, events);
	do_zoo_interest();
}

void fdcb_write(int fd) {
	warn << "got write for fd: " << fd << "\n";
	map<int, timecb_t *>::iterator it = write_timeouts.find(fd);
	if( it != write_timeouts.end() ) {
		timecb_remove(it->second);
		write_timeouts.erase(it);
	}
	int events = 0;
	events |= ZOOKEEPER_WRITE;
	zookeeper_process(zh, events);
	do_zoo_interest();
}

void updated_node_list(int rc, const struct String_vector *strings, const void *data) {
    if(rc!=ZOK || !strings || strings->count < 1) {
    	fatal << "Received bad children list.\n";
    }

    if(zoo_node_count != 0) {
    	//TODO: Fix this
    	fatal << "Updated node list while doing initial list. Not implemented.\n";
    }


}

void initial_node_value(int rc, const char *value, int value_len, const struct Stat *stat, const void *data) {
	if(rc != ZOK) {
		fatal << "Received bad node info" << rc << ".\n";
	}
	string val(value, value_len);
	Node new_node;
	new_node.set_from_string(val);
	ring[new_node.getId()] = new_node;
	if( ring.size() == zoo_node_count ) {
		warn << "Node List Initialization finished.\n";
		zoo_node_count = 0;
		update_my_ptr();
	}
}

void initial_node_list(int rc, const struct String_vector *strings, const void *data) {
    if(rc!=ZOK || !strings || strings->count < 1) {
    	fatal << "Received bad children list.\n";
    }

	zoo_node_count = strings->count;
	for (int i=0; i < strings->count; i++) {
		warn << strings->data[i] << "\n";
		string this_one = "/nodes/";
		this_one += strings->data[i];
        int r = zoo_aget(zh, this_one.c_str(), 0, &initial_node_value, 0);
        if (r) {
            fatal << "Received error " << r << " when querying initial node information.\n";
        }
	}
}

void created_my_node(int rc, const char *name, const void *data) {
    if ( !(rc==ZOK) ) {
        fatal << "Creating my ZooKeeper node failed! (" << rc << ")\n";
    }
    warn << "Received ZooKeeper ID: " << name << "\n";
    my_zoo_id = name;
    int r = zoo_aget_children(zh, "/nodes", 1, &initial_node_list, 0);
    if(r) {
    	fatal << "Received error " << r << " when getting initial node list.\n";
    }
}

void created_root(int rc, const char *name, const void *data) {
    if ( !(rc==ZOK || rc==ZNODEEXISTS) ) {
        fatal << "Creating/verifying root ZooKeeper node failed! (" << rc << ")\n";
    }
    int r = zoo_acreate(zh, "/nodes/", my_node_str.c_str(), my_node_str.length(),
    		&ZOO_OPEN_ACL_UNSAFE, ZOO_EPHEMERAL | ZOO_SEQUENCE,
    		&created_my_node, 0);
    if(r) {
    	fatal << "Received error " << r << " when creating my node.\n";
    }
}

void watcher(zhandle_t *zzh, int type, int state, const char *path,void* context) {
    if (type == ZOO_SESSION_EVENT) {
        if (state == ZOO_CONNECTED_STATE) {
        	warn << "Connected to ZooKeeper.\n";
            int rc = zoo_acreate(zh, "/nodes", "", 0,
            		&ZOO_OPEN_ACL_UNSAFE, 0,
            		&created_root, 0);
            if(rc) {
            	fatal << "Received error " << rc << " when creating root node.\n";
            }
        } else if (state == ZOO_AUTH_FAILED_STATE) {
            fatal << "ZooKeeper Authentication failed.\n";
        } else if (state == ZOO_EXPIRED_SESSION_STATE) {
            fatal << "ZooKeeper session expired.\n";
        } else if (state == ZOO_CONNECTING_STATE ) {
        	warn << "Connecting to ZooKeeper...\n";
        } else if (state == ZOO_ASSOCIATING_STATE) {
			warn << "Associating ZooKeeper connection...\n";
        }
    } else if( type == ZOO_CREATED_EVENT ) {

    } else if( type == ZOO_DELETED_EVENT ) {

    } else if( type == ZOO_CHANGED_EVENT ) {

    } else if( type == ZOO_CHILD_EVENT ) {
    	warn << "Got child event on " << path << "\n";
        int r = zoo_aget_children(zh, "/nodes", 1, &updated_node_list, 0);
        if(r) {
        	fatal << "Received error " << r << " when getting updated node list.\n";
        }
    } else if( type == ZOO_NOTWATCHING_EVENT ) {

    }
}

void do_zoo_interest() {
	int fd;
	int interest;
	timeval tv;
	int ret = zookeeper_interest(zh, &fd, &interest, &tv);
	if(ret != ZOK) {
		fatal << "Bad return from interest!\n";
	}
	if (fd != -1) {
		if (interest & ZOOKEEPER_READ) {
			//warn << "interest read fd: " << fd << "\n";
			timecb_t * timeout = delaycb(tv.tv_sec, tv.tv_usec * 1000, wrap(fdcb_read_timeout, fd));
			map<int, timecb_t *>::iterator it = read_timeouts.find(fd);
			if( it != read_timeouts.end() ) {
				timecb_remove(it->second);
				read_timeouts.erase(it);
			}
			read_timeouts[fd] = timeout;
			fdcb(fd, selread, wrap(fdcb_read, fd));
		} else {
			//warn << "disabling read fd: " << fd << "\n";
			map<int, timecb_t *>::iterator it = read_timeouts.find(fd);
			if( it != read_timeouts.end() ) {
				timecb_remove(it->second);
				read_timeouts.erase(it);
			}
			fdcb(fd, selread, 0);
		}

		if (interest & ZOOKEEPER_WRITE) {
			//warn << "interest write fd: " << fd << "\n";
			timecb_t * timeout = delaycb(tv.tv_sec, tv.tv_usec * 1000, wrap(fdcb_write_timeout, fd));
			map<int, timecb_t *>::iterator it = write_timeouts.find(fd);
			if( it != write_timeouts.end() ) {
				timecb_remove(it->second);
				write_timeouts.erase(it);
			}
			write_timeouts[fd] = timeout;
			fdcb(fd, selwrite, wrap(fdcb_write, fd));
		} else {
			//warn << "disabling write fd: " << fd << "\n";
			map<int, timecb_t *>::iterator it = write_timeouts.find(fd);
			if( it != write_timeouts.end() ) {
				timecb_remove(it->second);
				write_timeouts.erase(it);
			}
			fdcb(fd, selwrite, 0);
		}
	} else {
		fatal << "got 0 fd\n";
		fd = 0;
	}
}

void zoo_interest_timer() {
	do_zoo_interest();
	delaycb(0, 1000 * 1000, wrap(zoo_interest_timer));
}

tamed static void
register_to_manager(int my_port, str h, int port) {
	tvars {
		int fd,r;
		ptr<aclnt> cli;
		str ip;
		clnt_stat e, e2;
		ostringstream ss;
		unsigned int i;
		string my_ip;
	}

	manager_hostname = h;
	manager_port = port;

	ip = get_ip_address();
	srand ( time(NULL) );
	r = rand();
	ss << ip.cstr() << ":" << my_port << r;
	my_id = get_sha1(ss.str());
	warn << "my id = " << my_id.toString().c_str() << "\n";

	my_ip = ip;
	my_node.setIp(my_ip);
	my_node.setId(my_id);
	my_node.setPort(my_port);

	ss.str("");
	ss << my_ip << " " << my_port << " " << my_id.toString();
	my_node_str = ss.str();

	zoo_set_debug_level(ZOO_LOG_LEVEL_DEBUG);
	ss.str("");
	ss << manager_hostname << ":" << manager_port;
	zh = zookeeper_init(ss.str().c_str(), watcher, 10000, 0, 0, 0);
	if(!zh) {
		fatal << "ZooKeeper initialization failed\n";
	}
	zoo_interest_timer();

/*	for(i=0; i<ret.nodes.size(); i++) {
		Node cur(ret.nodes[i]);
		ring[cur.getId()] = cur;
	}
	update_my_ptr();*/

}

tamed static
void main2(int argc, char **argv) {
	int listen_port;
	str manager_hostname;
	str type;
	int manager_port;

	if(argc > 4) type = argv[1];
	if(type == "CRAQ") {
		CRAQ = true;
	} else {
		CRAQ = false;
	}

	if (argc == 5 && convertint (argv[2], &listen_port)
				  		 && convertint(argv[4], &manager_port) &&
				  		 (type=="CR" || type=="CRAQ") ) {
		user_ip = "";
	 	manager_hostname = argv[3];
		start_rpc_srv(listen_port);
		register_to_manager(listen_port, manager_hostname, manager_port);
	} else if(argc == 6 && convertint (argv[2], &listen_port)
				  		 && convertint(argv[4], &manager_port) &&
				  		 (type=="CR" || type=="CRAQ")) {
		user_ip = argv[5];
	 	manager_hostname = argv[3];
		start_rpc_srv(listen_port);
		register_to_manager(listen_port, manager_hostname, manager_port);
	} else {
		fatal << "usage: chain_node <type> <listen_port> <manager_hostname>\n"
			  << "<manager_port> [<ip_address>]\n"
			  << "  - connects to manager and joins the network. <type> can\n"
			  << "    be CR or CRAQ. Optionally set <ip_address> if multiple\n"
			  << "    interfaces.\n";
		exit(1);
	}
}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain ();
}
