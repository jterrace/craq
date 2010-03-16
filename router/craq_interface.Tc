/*
 * craq_interface.T
 * author: Patrick Wendell
 *
 * A get/set interface to CRAQ to be used by Namecast. It doesn't really make
 * sense to write this as a class since only one can exist at a time, but
 * I need to learn tame and  C++... Also, this is basically a copy of 
 * client.T.
 * */

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
#include "../logging/debug.h"
#include "connection_pool.TH"
#include "craq_interface.h"
#define DEBUG 0

using namespace std;
using namespace CryptoPP;

tamed static void craq_interface::watcher_wrapper(string path, void* context) {
  craq_interface* my_iface = static_cast<craq_interface*>( context);
  my_iface->node_list_watcher(path);
}

str get_ip_address() {
  // Gets IP address
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
      break; // Take the first non-loopback we find...
    }
    addr++;
  }
  if (addr >= addrs.lim () && (loopback == NULL))
    fatal << "Cannot find my IP address.\n";

  if (touse == NULL) {
    warn << "Using loopback address as my address.\n";
    touse = loopback;
  } else {
    warn << "Using IP address: " << inet_ntoa (*touse) << "\n";
  }
  str ids = inet_ntoa (*touse);
  return ids;
}

ID_Value get_sha1(string msg) {
        byte buffer[SHA::DIGESTSIZE];
        SHA().CalculateDigest(buffer, (byte *)msg.c_str(), msg.length());
        ID_Value ret(buffer);
        return ret;
}

craq_interface::craq_interface() {
  zoo_connected = false;  
}

craq_interface::~craq_interface() {}


inline ring_iter craq_interface::ring_succ(ID_Value id) {
  // Given an ID, find it's successor node in the ring
  ring_iter it = ring.lower_bound(id);
  if(it == ring.end())
    it = ring.begin();
    return it;
}

inline void craq_interface::ring_incr(ring_iter * it) {
  // Increment position in ring
  (*it)++;
  if( (*it)==ring.end() ) {
    (*it) = ring.begin();
  }
}


tamed void craq_interface::init(string zoo_list, cbbool cb) {
  tvars {
    bool connect_success;
    bool list_success;
  }
  my_ip_addr = string(get_ip_address().cstr());
  twait {connect_to_manager(zoo_list, mkevent(connect_success));}
  twait {populate_node_list(mkevent(list_success));}
  if (!(connect_success & list_success)) {
    cout << "Error connecting to zookeeper\n";
    TRIGGER(cb, false);
  }
  TRIGGER(cb, true);
}

tamed void craq_interface::set_key(string key, const char* data, int data_length, cbstr cb) {
  tvars {
    ID_Value id;
    ring_iter succ;
    ptr<aclnt> cli;
    clnt_stat e;
    ptr<chain_meta> chain_info;
    add_chain_arg add_arg;
    add_chain_ret add_ret;
    head_write_arg wrt_arg;
    blob to_write;
    int fd;
    bool rc; // TODO find out what this means
  }

  id = get_sha1(key);

  // Who'se the head of this key
  succ = ring_succ(id);

  twait { get_rpc_cli (succ->second.getIp().c_str(), succ->second.getPort(),
    &cli, &chain_node_1, mkevent(fd)); }

  if (fd < 0) {
    TRIGGER(cb, "ERROR\n");
    return;
  }

  twait { get_chain_info(id, mkevent(chain_info)); }

  // If this is new, add a chain
  if (chain_info == NULL) {
    add_arg.id = id.get_rpc_id();
    add_arg.chain_size = 2;
    add_arg.data_centers.setsize(1);
    add_arg.data_centers[0] = "namecast";
  
    // Add chain at the head
    twait { cli->call(ADD_CHAIN, &add_arg, &add_ret, mkevent(e)); }

    if (e || add_ret == ADD_CHAIN_FAILURE) {
      TRIGGER(cb, "ERROR\n");
      return;
    }
  }

  // Convert data to blob
  to_write.setsize(data_length);
  for (int i = 0; i < data_length; i++) {
    to_write[i] = data[i];
  }
  if (DEBUG) cout << "Writing " << data_length << " bytes of data.\n";
  wrt_arg.chain = id.get_rpc_id();
  wrt_arg.id = id.get_rpc_id();
  wrt_arg.data = to_write;
 
  twait { cli->call(HEAD_WRITE, &wrt_arg, &rc, mkevent(e)); }
  
  if (e || !rc) {
    TRIGGER(cb, "ERROR\n");
    return;
  }

  TRIGGER(cb, "STORED!\n");
}

int craq_interface::number_of_nodes() {
  return ring.size();
}

tamed void craq_interface::get_key(string key, cbs cb) {
  tvars {
    ID_Value id;
    ptr<chain_meta> chain_info;
    ptr<aclnt> cli;
    strbuf out_buf;
    str out;
    ring_iter succ;
    clnt_stat e;
    int rnd;
    int fd;
    tail_read_ex_arg arg; // arguments to tail read
    tail_read_ex_ret ret; // return value from tail read
  }

  id = get_sha1(key);

  twait{ get_chain_info(id, mkevent(chain_info)); }
  if (DEBUG) {
    cout << "Got chain info for key: ";
    cout << key.c_str();
    cout << "\n";
    fflush(stdout);
  }
 
  if (chain_info == NULL) {
    TRIGGER(cb, str(("NOT FOUND: " + key + "\n").c_str()));
    return;
  }

  // Get start of chain
  succ = ring_succ(id);

  // Go to random point on chain
  rnd = rand() % chain_info->chain_size;
  for ( ; rnd > 0; rnd--) {
    ring_incr(&succ);
  } 

  twait { get_rpc_cli (succ->second.getIp().c_str(), succ->second.getPort(),
    &cli, &chain_node_1, mkevent(fd)); }
  if (DEBUG) {
    cout << "Got RPC client for node with IP: " << succ->second.getIp().c_str();
    fflush(stdout);
  }

  if (fd < 0) {
    TRIGGER(cb, str("ERROR"));
    return;
  }
  
  arg.id = id.get_rpc_id();
  arg.chain = id.get_rpc_id();
  arg.dirty = false;

  twait { cli->call(TAIL_READ_EX, &arg, &ret, mkevent(e)); }
  if (e) {
    TRIGGER(cb, str("ERROR"));
    return;
  }
  if (DEBUG) {
    cout << "Got object of size " << ret.data.size();
    fflush(stdout);
  }
  TRIGGER(cb, str((char*)&(ret.data[0]), ret.data.size()));
}

tamed void craq_interface::connect_to_manager(string zoo_list, cbbool cb) {
  tvars {
    bool success;
  }

  twait {
    czoo_init(zoo_list.c_str(), mkevent(success), ZOO_LOG_LEVEL_ERROR);
  }

  if (!success) {
    cout << "Could not initialize ZooKeeper.\n";
  }

  TRIGGER(cb, success);
}

tamed void craq_interface::populate_node_list(cbbool cb) {
  tvars {
    vector<string> * node_list;
    vector<string *> node_vals;
    vector<ID_Value> ring_keys;
    vector<Node> ring_vals;
    string node_name;
    string search_str;
    Node new_node;
  }
  twait {
    czoo_get_children_2("/nodes/namecast", &watcher_wrapper, this,
      mkevent(node_list));
  }
  if (node_list == NULL) {
    cout << "Erorr retreiving initial node list\n";
    TRIGGER(cb, false);
  }
  else {
    cerr << "Did retreive node list of size ";
    cerr << (*node_list).size() << "\n";
  }
  node_vals.resize((*node_list).size());

  // Get data for each node
  twait {
    for (int i=0; i < (*node_list).size(); i++) {
      node_name = (*node_list)[i];
      search_str = "/nodes/namecast/" + node_name;
      czoo_get(search_str, mkevent(node_vals[i]));
    }
  }

  // Assure value for each node
  for (int i=0; i < node_vals.size(); i++) {
    if (node_vals[i] == NULL) {
      cout << "Error retreiving value for node " << 
        (*node_list)[i].c_str() << "\n";
      TRIGGER(cb, false);
    }
    else {
      // Create a Node and add it to the ring
      new_node.set_from_string(*node_vals[i]);
      ring[new_node.getId()] = new_node;
      zoo_nodes[(*node_list)[i]] = new_node;
      cout << "Got node " << new_node.toString() << "\n";
      delete node_vals[i];
    }
  }
  delete node_list;
  ring_init = true;
  TRIGGER(cb, true);
}


tamed void craq_interface::node_list_watcher(string path) {
  tvars{
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
    init_interrupted = true;
    warn << "Updated node list while doing initial list. \
      Re-building initial list.\n";
      return;
    }
    cout << "Running watcher function\n";
    fflush(stdout);
    twait { czoo_get_children_2("/nodes/namecast", &watcher_wrapper, this, 
      mkevent(ret_node_list)); }
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
            cout << "Deleting";
            cout << old_it->first.c_str();

           if (old_it->first.find(my_ip_addr) >= 0) {
             cout << "Chain node on this host died";
             fflush(stdout);
           }
           zoo_nodes.erase(old_it++);
        }
        else if( old_it->first == *new_it ) {
          old_it++;
          new_it++;
      } else if( old_it->first < *new_it ) {
         cout << "Deleting";
         cout << old_it->first.c_str();
         if (old_it->first.find(my_ip_addr) >= 0) {
           cout << "Chain node on this host died";
           fflush(stdout);
         }
         zoo_nodes.erase(old_it++);

       } else if( old_it->first > *new_it ) {
          to_add.insert(*new_it);
          new_it++;
         }
      }

        add_ids.resize(to_add.size());
        add_rets.resize(to_add.size());
        for( i=0, it = to_add.begin(); it != to_add.end(); i++, it++ ) {
                search = "/nodes/namecast/" + (*it);
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
        }

}

tamed void craq_interface::get_chain_info(ID_Value chain_id, 
  ptr<callback<void, ptr<chain_meta>>> cb) {
  tvars {
    ptr<chain_meta> ret;
    map<ID_Value, chain_meta>::iterator it;
    string* val;
    istringstream iss;
    string dc;
  }

  // check if chain meta-data cache
  it = chain_meta_list.find(chain_id);
  if (it != chain_meta_list.end()) {
    ret = New refcounted<chain_meta>;
    *ret = it->second;
    TRIGGER(cb, ret); 
    return;
  }

  // if not in cache, get data from zookeeper
  twait {
    czoo_get("/keys/" + chain_id.toString(), mkevent(val));
  }

  if (val == NULL) {
    if (DEBUG) {
      cout << "Could not find key ";
      cout << chain_id.toString().c_str();
      cout << "\n";
      fflush(stdout);
    }
    ret = NULL;
    TRIGGER(cb, ret);
    return;
  }
  // create chain_meta struct and return
  ret = New refcounted<chain_meta>;
  iss.str(*val);
  delete val;
  if (!(iss >> ret->chain_size)) {
    if (DEBUG) cout << "Got bad value back from zookeeper chain node!\n";
    TRIGGER(cb, ret);
    return;
  }
  if (iss.eof()) {
    if (DEBUG) {
      cout << "Got no data centers for chain: ";
      cout << chain_id.toString().c_str();
    }
  }
  while (!iss.eof()) {
    iss >> dc;
    ret->data_centers.push_back(dc);
  }

  chain_meta_list[chain_id] = *ret;
  TRIGGER(cb, ret);
}
/*
tamed static void main2() {
  tvars{
    craq_interface iface;
    string zoo_list;
    bool init_success;
    string set_result;
    string result; 
  }
  zoo_list = "127.0.0.1:2181";
  cout << "Interface created, attempting to connect\n"; 
 
  twait {
    iface.init(zoo_list, mkevent(init_success));
  }

  if (init_success) {
    cout << "Connection established.\n";
  }
  else {
    cout << "Connection establishemnt failed.\n";
  }

  twait {iface.set_key(string("patrick"), "foo", 3, mkevent(set_result));}
  twait {iface.get_key(string("patrick"), mkevent(result));}

  cout << "Result: " << result << "\n.";
  exit(0);
}

int main() {
  //main2();
  amain();
}
*/
