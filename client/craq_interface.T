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
#include "connection_pool.TH"
#include "craq_interface.h"

using namespace std;

craq_interface::craq_interface() {}

craq_interface::~craq_interface() {}

tamed void craq_interface::init(string zoo_list) {
  tvars {int success;}
  twait {connect_to_manager(zoo_list, mkevent());}
  twait {populate_node_list(mkevent(success));}
  warn << "Result " << success;
}

void craq_interface::set_key(string key, string val, cbstr) {}

void craq_interface::get_key(string key, cbstr) {}

tamed void craq_interface::connect_to_manager(string zoo_list, cbv cb) {
  tvars {
    bool success;
    zoo_connected;
  }
  twait {
    czoo_init(zoo_list.c_str(), mkevent(success), ZOO_LOG_LEVEL_ERROR);
  }
  if (!success) {
    fatal << "Could not initialize ZooKeeper. Dying.\n";
    zoo_connected = false;
    return;
  }

  warn << "Connected to ZooKeeper";
  zoo_connected = true;
}

tamed void craq_interface::populate_node_list(cbi cb) {
  if (!zoo_connected) {
    (*cb) (-1);
  }

  (*cb) (0);
}

tamed static void main2() {
  craq_interface iface;
  iface.init("192.168.1.1:394");
}

int main() {
  main2();
  amain();
}

