#include <iostream>
#include "donar_rpc.h"
#include "client/craq_interface.h"
#include <string>
#include <map>
#include <vector>
#include "zookeeper.h"
#include "tame.h"
#include "tame_rpcserver.h"
#include "parseopt.h"
#include "arpc.h"
#include "async.h"
#include "../ID_Value.h"
#include "../Node.h"


using namespace std;

tamed static void main2() {
  tvars{
    subdomain sd;
    subdomain sd_out;
    record rec;
    record rec2;
    craq_interface iface;
    string zoo_list;
    bool init_success;
    string result;
    str insert;
    string test_key;
    str get_data;
    str test;
  }
  
  zoo_list = "127.0.0.1:2181";

  twait {
    iface.init(zoo_list, mkevent(init_success));
  } 

  if (init_success) {
    warn << "Connection established.\n";
  }
  else {
    warn << "Connection establishemnt failed.\n";
  }
  sd.seq_number = 1;
  sd.fqdn = "foo.bar.com";
  rec.type = "A";
  rec.content = "192.168.1.1";
  rec.ttl = 1000;
  rec2.type = "A";
  rec2.content = "63.205.254.10";
  rec2.ttl  = 3600;
 
  sd.records.push_back(rec);
  sd.records.push_back(rec2);

  test = xdr2str (sd, false);
  test_key = sd.fqdn;

  cout << "Encoded: " << test.len() << " bytes."  << "\n";
  twait {
    iface.set_key(test_key, test.cstr(), test.len(), mkevent(result)); 
 }

  twait {
    iface.get_key(test_key, mkevent(get_data));
  }

  cout << "Out length: " << get_data.len() << "\n";
  str2xdr (sd_out, get_data);  

  cout << "Out data: " << sd_out.fqdn << "\n";
}

int main() {
  main2();
  amain();
}
