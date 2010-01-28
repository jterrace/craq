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

void set_attr(record_attr* att, double value) {
  att->data.setsize(sizeof(double));
  for (int i = 0; i < sizeof(double); i++) {
    att->data[i] = ((char*) &value)[i];
  }
}

double get_attr(record_attr* att) {
  double out;
  for (int i = 0; i < sizeof(double); i++) {
    ((char*) &out)[i] = att->data[i];
  }
  return out;
}

tamed static void main2() {
  tvars{
    subdomain sd;
    subdomain sd2;
    subdomain sd_out;
    record rec;
    record rec2;
    record rec3;
    record_attr attr1;
    record_attr attr2;
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
    double test_val;
    double proportion;
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
  sd.seq_number = 8;
  sd.fqdn = "nyud.net";

  attr1.type = SPLIT_PROPORTION;
  attr2.type = SPLIT_EPSILON;
  set_attr(&attr2, .01);

  rec.type = "A";  
  rec.content = "140.247.60.126"; // righthand.eecs.harvard.edu
  rec.ttl = 10;
  set_attr(&attr1, .2);
  memcpy(&test, &attr1.data, sizeof(double));
  cout << "TEST" << get_attr(&attr1);
  rec.attrs.push_back(attr1);
  rec.attrs.push_back(attr2);
  sd.records.push_back(rec);

  rec.content = "134.121.64.4"; // planetlab1.eecs.wsu.edu
  rec.ttl  = 10;
  rec.type = "A";
  set_attr(&attr1, .1);
  rec.attrs.push_back(attr1);
  rec.attrs.push_back(attr2);
  sd.records.push_back(rec);

  rec.content = "140.112.42.158"; //adam.ee.ntu.edu.tw
  rec.ttl  = 10;
  rec.type = "A";
  set_attr(&attr1, .05);
  rec.attrs.push_back(attr1);
  rec.attrs.push_back(attr2);
  sd.records.push_back(rec);

  rec.content = "193.147.162.166"; //ait05.us.es
  rec.ttl  = 10;
  rec.type = "A";
  set_attr(&attr1, .05);
  rec.attrs.push_back(attr1);
  rec.attrs.push_back(attr2);
  sd.records.push_back(rec);

  rec.content = "203.178.133.11"; //planetlab1.dojima.wide.ad.jp
  rec.ttl  = 10;
  rec.type = "A";
  set_attr(&attr1, .05);
  rec.attrs.push_back(attr1);
  rec.attrs.push_back(attr2);
  sd.records.push_back(rec);

  rec.content = "137.165.1.113"; // planetlab3.williams.edu
  rec.ttl = 10;
  rec.type = "A";
  set_attr(&attr1, .05);
  rec.attrs.push_back(attr1);
  rec.attrs.push_back(attr2);
  sd.records.push_back(rec);

  rec.content = "207.197.40.250"; // planetlab1.scsr.nevada.edu
  rec.ttl = 10;
  rec.type = "A";
  set_attr(&attr1, .2);
  rec.attrs.push_back(attr1);
  rec.attrs.push_back(attr2);
  sd.records.push_back(rec);

  rec.content = "202.38.99.68"; // pl1.6test.edu.cn
  rec.ttl = 10;
  rec.type = "A";
  set_attr(&attr1, .1);
  rec.attrs.push_back(attr1);
  rec.attrs.push_back(attr2);
  sd.records.push_back(rec);

  rec.content = "213.131.1.101"; // plab-1.sinp.msu.ru
  rec.ttl = 10;
  rec.type = "A";
  set_attr(&attr1, .1);
  rec.attrs.push_back(attr1);
  rec.attrs.push_back(attr2);
  sd.records.push_back(rec);

  rec.content = "138.251.214.78"; // planetlab4.cs.st-andrews.ac.uk
  rec.ttl = 10;
  rec.type = "A";
  set_attr(&attr1, .1);
  rec.attrs.push_back(attr1);
  rec.attrs.push_back(attr2);
  sd.records.push_back(rec);


  rec.content = "216.165.109.82.ip4.nyucd.net. hostmaster.nyucd.net. 0 1800 3600 7200 3600";
  rec.ttl = 3600;
  rec.type = "SOA";
  //sd.records.push_back(rec);
  

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
