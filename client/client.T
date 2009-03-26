#include <string>
#include <algorithm>
#include <set>
#include <ctime>
#include "sha.h"
#include "tame.h"
#include "tame_rpcserver.h"
#include "parseopt.h"
#include "tame_io.h"
#include "arpc.h"
#include "async.h"
#include "../craq_rpc.h"
#include "../Node.h"
#include "../ID_Value.h"
#include <tclap/CmdLine.h>
#include "../zoo_craq.h"
#include "connection_pool.H"

using namespace CryptoPP;
using namespace std;

typedef enum { READ, WRITE } ev_t;
typedef callback<void, string>::ref cbstr;
const unsigned int MAX_BUF = 2000;
bool ring_init = false;
typedef map<ID_Value, Node>::iterator ring_iter;
map<ID_Value, Node> ring;
string datacenter;
struct chain_meta {
	unsigned int chain_size;
	vector<string> data_centers;
};
map<ID_Value, chain_meta> chain_meta_list;

ID_Value get_sha1(string msg)
{
	byte buffer[SHA::DIGESTSIZE];
	SHA().CalculateDigest(buffer, (byte *)msg.c_str(), msg.length());
	ID_Value ret(buffer);
 	return ret;
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

string toLower(string str) {
	transform(str.begin(), str.end(), str.begin(), ::tolower);
	return str;
}

string toUpper(string str) {
	transform(str.begin(), str.end(), str.begin(), ::toupper);
	return str;
}

vector<string> tokenize(const string & str, const string & delimiters = " ") {
	vector<string> tokens;

	// Skip delimiters at beginning.
	string::size_type lastPos = str.find_first_not_of(delimiters, 0);
	// Find first "non-delimiter".
	string::size_type pos = str.find_first_of(delimiters, lastPos);

	while (string::npos != pos || string::npos != lastPos) {
		// Found a token, add it to the vector.
		tokens.push_back(str.substr(lastPos, pos - lastPos));
		// Skip delimiters.  Note the "not_of"
		lastPos = str.find_first_not_of(delimiters, pos);
		// Find next "non-delimiter"
		pos = str.find_first_of(delimiters, lastPos);
	}

	return tokens;
}


void trim(string & str, const string & delimiters = " \t\r\n") {
	size_t startpos = str.find_first_not_of(delimiters);
	size_t endpos = str.find_last_not_of(delimiters);

	if(( string::npos == startpos ) || ( string::npos == endpos)) {
		str = "";
	} else {
		str = str.substr(startpos, endpos-startpos+1);
	}
}

tamed static void get_chain_info(ID_Value chain_id, ptr<callback<void, ptr<chain_meta> > > cb) {
	tvars {
		ptr<chain_meta> ret;
		string * val;
		istringstream iss;
		string dc;
		map<ID_Value, chain_meta>::iterator it;
	}

	it = chain_meta_list.find(chain_id);
	if(it != chain_meta_list.end()) {
		ret = New refcounted<chain_meta>;
		*ret = it->second;
		TRIGGER(cb, ret);
		return;
	}

	twait{ czoo_get("/keys/" + chain_id.toString(), mkevent(val)); }
	if(val == NULL) {
		ret = NULL;
		TRIGGER(cb, ret);
		return;
	}

	ret = New refcounted<chain_meta>;
	iss.str(*val);
	delete val;
	if(!(iss >> ret->chain_size)) {
		fatal << "Got bad value back from zookeeper chain node!\n";
	}
	while(!iss.eof()) {
		iss >> dc;
		ret->data_centers.push_back(dc);
	}
	if(ret->data_centers.size() < 1) {
		fatal << "Got no data centers back from zookeeper chain node!\n";
	}

	chain_meta_list[chain_id] = *ret;
	TRIGGER(cb, ret);

}

tamed static void set_key(string key, blob data, cbstr cb) {

	tvars {
		ID_Value id;
		ring_iter succ;
		ptr<chain_meta> chain_info;
		ptr<aclnt> cli;
		ostringstream out;
		clnt_stat e;
		int fd;
		add_chain_arg add_arg;
		add_chain_ret add_ret;
		head_write_arg wrt_arg;
		bool rc;
	}

	id = get_sha1(key);
	succ = ring_succ(id);

	twait { get_rpc_cli (succ->second.getIp().c_str(),succ->second.getPort(), &cli, &chain_node_1, mkevent(fd)); }
	if(fd < 0) {
		TRIGGER(cb, "ERROR\r\n");
		return;
	}

	twait{ get_chain_info(id, mkevent(chain_info)); }
	if(chain_info == NULL) {
		add_arg.id = id.get_rpc_id();
		add_arg.chain_size = 3;
		add_arg.data_centers.setsize(1);
		add_arg.data_centers[0] = datacenter.c_str();

		twait { cli->call(ADD_CHAIN, &add_arg, &add_ret, mkevent(e)); }
		if(e || add_ret == ADD_CHAIN_FAILURE) {
			TRIGGER(cb, "ERROR\r\n");
			return;
		}
	}

	wrt_arg.chain = id.get_rpc_id();
	wrt_arg.id = id.get_rpc_id();
	wrt_arg.data = data;
	twait {	cli->call(HEAD_WRITE, &wrt_arg, &rc,  mkevent(e)); }
	if(e || !rc) {
		TRIGGER(cb, "ERROR\r\n");
		return;
	}

	TRIGGER(cb, "STORED\r\n");
}

tamed static void get_key(string key, cbstr cb) {

	tvars {
		ID_Value id;
		ring_iter succ;
		ptr<chain_meta> chain_info;
		ptr<aclnt> cli;
		tail_read_ex_arg arg;
		tail_read_ex_ret ret;
		ostringstream out;
		clnt_stat e;
		int fd;
		int rnd;
		int i;
	}

	id = get_sha1(key);

	twait{ get_chain_info(id, mkevent(chain_info)); }
	if(chain_info == NULL) {
		TRIGGER(cb, "NOT_FOUND\r\n");
		return;
	}

	succ = ring_succ(id);
	rnd = rand() % chain_info->chain_size;
	for( ; rnd>0; rnd--) {
		ring_incr(&succ);
	}

	twait { get_rpc_cli (succ->second.getIp().c_str(),succ->second.getPort(), &cli, &chain_node_1, mkevent(fd)); }
	if(fd < 0) {
		TRIGGER(cb, "ERROR\r\n");
		return;
	}
	arg.id = id.get_rpc_id();
	arg.chain = id.get_rpc_id();
	arg.dirty = false;
	twait {	cli->call(TAIL_READ_EX, &arg, &ret,  mkevent(e)); }
	if(e) {
		TRIGGER(cb, "ERROR\r\n");
		return;
	}

	out << "VALUE " << ret.data.size() << "\r\n";
	for(int i=0; i<ret.data.size(); i++) {
		out << ret.data[i];
	}
	out << "\r\n";
	TRIGGER(cb, out.str());
}

tamed static void send_str(int fd, const char * str, cbb cb) {
	tvars {
		strbuf data;
	}
	data.cat(str);
	while(data.tosuio()->resid()) {
		twait { tame::waitwrite(fd, mkevent()); }
		if(data.tosuio()->output(fd) < 0) {
			TRIGGER(cb, false);
			return;
		}
	}
	TRIGGER(cb, true);
}

tamed static void process(int fd)
{

	tvars {
		strbuf resp;
		int rc;
		int line_len;
		int byte_len;
		string line, reply;
		char * temp_buf;
		char buff[MAX_BUF];
		vector<string> tokens;
		bool ret;
		blob data;
		int i;
	}

	while(true) {
		twait { tame::waitread (fd, mkevent()); }
		if( (rc = resp.tosuio()->input(fd)) < 0 && errno != EAGAIN) {
			break;
		}

		line_len = resp.tosuio()->linelen();
		while(line_len > 0) {
			if(line_len < MAX_BUF) {
				resp.tosuio()->copyout(buff, line_len);
				buff[line_len] = '\0';
				line = buff;
				trim(line);
				tokens = tokenize(line);
				if(tokens.size() == 3 && toLower(tokens[0])=="set") {
					if(!convertint(tokens[2].c_str(), &byte_len) || byte_len < 0) {
						twait { send_str(fd, "ERROR\r\n", mkevent(ret)); }
						if(!ret) {
							break;
						}
					} else {
						resp.tosuio()->rembytes(line_len);
						line_len = 0;
						while(resp.tosuio()->resid() < byte_len + 2) {
							twait { tame::waitread (fd, mkevent()); }
							if( (rc = resp.tosuio()->input(fd)) < 0 && errno != EAGAIN) {
								break;
							}
						}
						temp_buf = new char[byte_len+2];
						resp.tosuio()->copyout(temp_buf, byte_len+2);
						if(temp_buf[byte_len] != '\r' || temp_buf[byte_len+1] != '\n') {
							twait { send_str(fd, "ERROR\r\n", mkevent(ret)); }
							if(!ret) {
								break;
							}
						} else {
							data.setsize(byte_len);
							for(i=0; i<byte_len; i++) {
								data[i] = temp_buf[i];
							}
							delete [] temp_buf;
							resp.tosuio()->rembytes(byte_len+2);
							twait { set_key(tokens[1], data, mkevent(reply)); }
							twait { send_str(fd, reply.c_str(), mkevent(ret)); }
							if(!ret) {
								break;
							}
						}
					}
				} else if(tokens.size() == 2 && toLower(tokens[0])=="get") {
					twait { get_key(tokens[1], mkevent(reply)); }
					twait { send_str(fd, reply.c_str(), mkevent(ret)); }
					if(!ret) {
						break;
					}
				} else {
					twait { send_str(fd, "ERROR\r\n", mkevent(ret)); }
					if(!ret) {
						break;
					}
				}
			} else {
				twait { send_str(fd, "ERROR\r\n", mkevent(ret)); }
				if(!ret) {
					break;
				}
			}
			resp.tosuio()->rembytes(line_len);
			line_len = resp.tosuio()->linelen();
		}

		if (rc == 0) {
			break;
		}

	}

	close(fd);

}

static int listen_on(int port)
{
	int fd = inetsocket(SOCK_STREAM, port);
	if (fd >= 0) {
		close_on_exec(fd);
		listen(fd, 20);
	} else {
		return -1;
	}
	return fd;
}

tamed static void listen_loop(int lport) {

	tvars {
		int lsock, rc, nfd;
		rendezvous_t<ev_t> G (__FILE__, __LINE__);
		ev_t which;
		sockaddr_in sin;
		socklen_t sinlen (sizeof (sin));
	}

	lsock = listen_on(lport);
	if(lsock <= 0) {
		fatal << "Listen failed on port '" << lport << "'. Dying.\n";
	}

	while (true) {
		tame::waitread (lsock, mkevent (G, READ));

		warn << "Waiting for connections...\n";
		twait (G, which);

		switch (which) {
			case READ:
				bzero (&sin, sinlen);
				if ((nfd = accept (lsock, reinterpret_cast<sockaddr *> (&sin), &sinlen)) >= 0) {
					warn << "Accepting connection from '" << inet_ntoa(sin.sin_addr) << "'.\n";
					process(nfd);
				} else {
					warn << "Accept failed.\n";
				}
				break;
			default:
				fatal << "Got unknown message. Dying.\n";
		}
	}

}

tamed static void node_added(Node node_changed) {
	ring[node_changed.getId()] = node_changed;
}

tamed static void node_deleted(Node node_changed) {
	tvars {
		ring_iter it;
	}
	it = ring.find(node_changed.getId());
	if(it == ring.end()) {
		fatal << "Deleting node that we didn't know about! Should never happen... dying!\n";
	}
	invalidate_rpc_host(it->second.getIp().c_str(), it->second.getPort());
	ring.erase(it);
}

tamed static void node_list_watcher(string path) {

	tvars {
		vector<string> * ret_node_list;
		set<string> new_list;
		int i, j;
		map<string, Node>::iterator old_it;
		set<string>::iterator new_it;
		set<string> to_add;
		set<string>::iterator it;
		vector<string *> add_rets;
		vector<string> add_ids;
		rendezvous_t<int> rv;
		string search;
		string * new_val;
		Node new_node;
	}

	if(!ring_init) {
    	//TODO: Fix this
    	fatal << "Updated node list while doing initial list. Not implemented.\n";
	}

	twait { czoo_get_children("/nodes/" + datacenter, &node_list_watcher, mkevent(ret_node_list)); }
	if(ret_node_list == NULL) {
		fatal << "Error retrieving updated node list!\n";
	}
	for(i=0; i<ret_node_list->size(); i++) {
		new_list.insert( (*ret_node_list)[i] );
	}
	delete ret_node_list;

	old_it = zoo_nodes.begin();
	new_it = new_list.begin();

	while(old_it != zoo_nodes.end() || new_it != new_list.end()) {
		if(old_it == zoo_nodes.end()) {
			to_add.insert(*new_it);
			new_it++;
		} else if( new_it == new_list.end() ) {
			node_deleted(old_it->second);
			zoo_nodes.erase(old_it++);
		}
		else if( old_it->first == *new_it ) {
			old_it++;
			new_it++;
		} else if( old_it->first < *new_it ) {
			node_deleted(old_it->second);
			zoo_nodes.erase(old_it++);
		} else if( old_it->first > *new_it ) {
			to_add.insert(*new_it);
			new_it++;
		}
	}

	add_ids.resize(to_add.size());
	add_rets.resize(to_add.size());
	for( i=0, it = to_add.begin(); it != to_add.end(); i++, it++ ) {
		search = "/nodes/" + datacenter + "/" + (*it);
		add_ids[i] = *it;
		czoo_get(search, mkevent(rv, i, add_rets[i]));
	}
	for(i=0; i<add_rets.size(); i++) {
		twait(rv, j);
		if(add_rets[j] == NULL) {
			fatal << "Failed to retrieve information about a node!\n";
		}
		new_node.set_from_string(*add_rets[j]);
		delete add_rets[j];
		zoo_nodes[add_ids[j]] = new_node;
		node_added(new_node);
	}

}

tamed static void connect_to_manager(str h, int port, cbv cb) {
	tvars {
		ostringstream ss;
		bool rc;
		vector<string> * node_list;
		vector<string *> node_vals;
		int i;
		string find;
		string search;
		Node new_node;
	}

	ss << h << ":" << port;
	twait { czoo_init( ss.str().c_str(), mkevent(rc), ZOO_LOG_LEVEL_ERROR); }
	if(!rc) {
		fatal << "Couldn't initialize ZooKeeper. Dying.\n";
	}

	twait { czoo_get_children("/nodes/" + datacenter, &node_list_watcher, mkevent(node_list)); }
	if(node_list == NULL) {
		fatal << "Error retrieving initial node list!\n";
	}

	zoo_node_count = (*node_list).size();
	node_vals.resize((*node_list).size());
	twait {
		for(i=0; i<(*node_list).size(); i++) {
			find = (*node_list)[i];
			search = "/nodes/" + datacenter + "/" + find;
			czoo_get(search, mkevent(node_vals[i]));
		}
	}

	for(i=0; i<node_vals.size(); i++) {
		if(node_vals[i] == NULL) {
			fatal << "Error occurred retrieving initial node value!\n";
		}
		new_node.set_from_string(*node_vals[i]);
		ring[new_node.getId()] = new_node;
		zoo_nodes[(*node_list)[i]] = new_node;
		//warn << (*node_list)[i].c_str() << " - " << new_node.toString().c_str() << "\n";
		delete node_vals[i];
	}

	delete node_list;
	ring_init = true;

	TRIGGER(cb);
}

tamed static void main2(int argc, char **argv) {
	tvars {
		int listen_port;
		str manager_hostname;
		str type;
		int manager_port;
		str user_ip;
		str data_center;
	}

	try
	{
		TCLAP::CmdLine cmd("client starts a CRAQ client which listens for commands on a socket and translates them to CRAQ RPC format", ' ', "0.2");
		TCLAP::ValueArg<string> managerHost("o", "manager_host", "Manager hostname", true, "", "string", cmd);
		TCLAP::ValueArg<int> managerPort("r", "manager_port", "Manager port number", true, 0, "int", cmd);
		TCLAP::ValueArg<int> listenPort("p", "listen_port", "Port to listen for connections", true, 0, "int", cmd);
		TCLAP::ValueArg<string> ipAddress("i", "ip_address", "IP Address to listen for connections", false, "", "string", cmd);
		TCLAP::ValueArg<string> dataCenter("d", "data_center", "Datacenter name", true, "", "string", cmd);
		cmd.parse(argc, argv);

		manager_hostname = managerHost.getValue().c_str();
		manager_port = managerPort.getValue();
		listen_port = listenPort.getValue();
		user_ip = ipAddress.getValue().c_str();
		data_center = dataCenter.getValue().c_str();
	}
	catch (TCLAP::ArgException &e)  // catch any exceptions
	{
		fatal << "Error: " << e.error().c_str() << " for arg " << e.argId().c_str() << "\n";
	}

	datacenter = data_center.cstr();
	warn << "Initializing...";
	twait { connect_to_manager(manager_hostname, manager_port, mkevent()); }
	warn << " Done.\n";

	listen_loop(listen_port);

}

int main (int argc, char *argv[]) {
	srand(time(NULL));
	main2(argc, argv);
	amain();
}
