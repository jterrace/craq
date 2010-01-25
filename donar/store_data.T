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
  sd.seq_number = 3;
  sd.fqdn = "nyud.net";

  rec.type = "A";
  rec.content = "140.247.60.126"; // righthand.eecs.harvard.edu
  rec.ttl = 10;
  sd.records.push_back(rec);

  rec.content = "134.121.64.4"; // planetlab1.eecs.wsu.edu
  rec.ttl  = 10;
  rec.type = "A";
  sd.records.push_back(rec);

  rec.content = "213.131.1.101"; // plab-1.sinp.msu.ru
  rec.ttl  = 10;
  rec.type = "A";
  sd.records.push_back(rec);

  rec.content = "129.97.74.12"; // plink.cs.uwaterloo.ca
  rec.ttl = 10;
  rec.type = "A";
  sd.records.push_back(rec);

  rec.content = "193.196.39.10"; // iraplab2.iralab.uni-karlsruhe.de
  rec.ttl = 10;
  rec.type = "A";
  sd.records.push_back(rec);

  rec.content = "202.38.99.68"; // pl1.6test.edu.cn
  rec.ttl = 10;
  rec.type = "A";
  sd.records.push_back(rec);

  sd2.fqdn = "foo.com";
  rec5.content = "1.2.3.4";
  rec5.type = "A";
  rec5.ttl = 1000;
  sd2.records.push_back(rec5);

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
