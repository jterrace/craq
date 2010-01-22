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
    subdomain sd2;
    subdomain sd_out;
    record rec;
    record rec2;
    record rec3;
    record rec4;
    record rec5;
    craq_interface iface;
    string zoo_list;
    bool init_success;
    string result;
    str insert;
    string test_key;
    str get_data;
    str test;
    str foo;
  }
  
  zoo_list = "ernie.cs.princeton.edu:9876";

  twait {
    iface.init(zoo_list, mkevent(init_success));
  } 

  if (init_success) {
    warn << "Connection established.\n";
  }
  else {
    warn << "Connection establishemnt failed.\n";
  }
  sd.seq_number = 2;
  sd.fqdn = "patrick.com";
  rec.type = "A";
  rec.content = "128.31.1.13";
  rec.ttl = 10;
  rec2.type = "A";
  rec2.content = "137.165.1.113";
  rec2.ttl  = 10;
  rec3.type = "A";
  rec3.content = "193.196.39.10"; 
  rec3.ttl = 10;
  rec4.type = "A";
  rec4.content = "202.38.99.68";
  rec4.ttl = 10;

  sd2.fqdn = "foo.com";
  rec5.content = "1.2.3.4";
  rec5.type = "A";
  rec5.ttl = 1000;
  sd2.records.push_back(rec5);

  sd.records.push_back(rec);
  sd.records.push_back(rec2);
  sd.records.push_back(rec3);
  sd.records.push_back(rec4);

  foo = xdr2str (sd2, false);
  twait {
    iface.set_key("foo.com", foo.cstr(), foo.len(), mkevent(result));
  }


  test = xdr2str (sd, false);
  test_key = sd.fqdn;

  cout << "Encoded: " << test.len() << " bytes."  << "\n";
  twait {
    iface.set_key(test_key, test.cstr(), test.len(), mkevent(result)); 
   }

  twait {
    iface.set_key(test_key + "-opt", "", 0, mkevent(result));
  }
  twait {
    iface.get_key("foo.com", mkevent(get_data));
  }

  cout << "Out length: " << get_data.len() << "\n";
  str2xdr (sd_out, get_data);  

  cout << "Out data: " << sd_out.fqdn << "\n";
}

int main() {
  main2();
  amain();
}
