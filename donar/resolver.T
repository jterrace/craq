#include <cstdio>
#include <cstdlib>
#include <cerrno>
#include <cstring>
#include <sstream>
#include <iostream>
#include <fstream>
#include <unistd.h>
#include <sys/types.h> 
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include "tame.h"
#include "tame_io.h"
#include "async.h"
#include "resolver.h"
#include "arpc.h"
#include "donar_rpc.h"
#include "tame_rpcserver.h"
#include "mysql_connection.h"
#include "client/craq_interface.h"
#include "cppconn/driver.h"
#include "cppconn/connection.h"
#include "cppconn/statement.h"
#include "cppconn/prepared_statement.h"
#include "cppconn/resultset.h"
#include "cppconn/metadata.h"
#include "cppconn/resultset_metadata.h"
#include "cppconn/exception.h"
#include "cppconn/warning.h"
#include <tr1/unordered_map>
#include <tr1/unordered_set>

#define SOCK_PATH "echo_socket"
#define MYSQL_USER "root"
#define MYSQL_PASS "35500"
#define MYSQL_HOST "unix:///var/run/mysqld/mysqld.sock"
#define ZOO_LIST "127.0.0.1:2181"
#define DEBUG 1
#define MAX_CACHE_PERIOD 10

using namespace std;
using namespace sql;

const unsigned int MAX_BUFF = 1000;
Connection* quova_conn;
Connection* donar_conn;
craq_interface craq;

string last; // PDNS hack

// Store subdomains in a hash-set for quick lookup
tr1::unordered_set<SubdomainInfo, SubdomainHash, SubdomainEqual> 
  subdomain_cache;
tr1::unordered_set<SubdomainInfo, SubdomainHash, SubdomainEqual>::iterator
  subdomain_cache_it;

ClientRegion::ClientRegion(int lat, int lon) {
  this->lat = lat;
  this->lon = lon;
}

ClientRegion::ClientRegion() {
}

ostream& operator<<(ostream& s, ClientRegion &cr) {
  s << "Client Region: (" << cr.lat << ", " << cr.lon << ")";
  return s;
}

bool ClientRegion::operator==(const ClientRegion &other) {
  return (this->lat == other.lat && this->lon == other.lon);
}

// Arbitrary ordering
bool ClientRegion::operator>(const ClientRegion &other) {
  if (this->lat > other.lat) return true;
  if (this->lat == other.lat) {
    if (this->lon > other.lon) return true;
  }
  return false;
}

bool ClientRegion::operator<(const ClientRegion &other) {
  return (!(*this == other) && !(*this > other));
}

int ClientRegion::get_hash() {
  int out = 0;
  for (int i = 0; i < (2 * sizeof(int)); i++) {
    if (i < sizeof(int)) {
      out = out*31 + ((char*) &lat)[i];
    }
    else {
      out = out*31 + ((char*) &lon)[i - sizeof(int)];
    }
  } 
  return out;
}


// Functions for hash based sets
size_t ClientRegionEqual::operator()(
  const ClientRegion &cr1, const ClientRegion &cr2) const {
  ClientRegion& cr1_b = const_cast<ClientRegion&>(cr1);
  ClientRegion& cr2_b = const_cast<ClientRegion&>(cr2);
  return cr1_b == cr2_b;
} 

size_t ClientRegionHash::operator()(const ClientRegion &cr) const {
  return const_cast<ClientRegion&>(cr).get_hash();
}

size_t SubdomainEqual::operator()(
  const SubdomainInfo &s1, const SubdomainInfo &s2) const {
  return (string(s1.storage.fqdn.cstr()) == string(s2.storage.fqdn.cstr()));
}

size_t SubdomainHash::operator()(const SubdomainInfo &s) const {
  size_t out = 0;
  const char* fqdn = s.storage.fqdn.cstr();
  for (int i = 0; i < strlen(fqdn); i++) {
    out = out * 31 + fqdn[i];
  }
  return out;
}

// Increments various counters which record request volume and client space.
void log_client_request(ClientRegion* c, SubdomainInfo* sd) {
  // Assure we're storing this client region for this subdomain
  num_requests_iter it = sd->num_requests.find(*c);
  if (it == sd->num_requests.end()) {
    unordered_map<size_t, unsigned int> new_map;
    sd->num_requests.insert(
      pair<ClientRegion, unordered_map<size_t, unsigned int> >(*c, new_map));
  }
 
  size_t time = time(NULL);
  time = time - (time % 60); // Request granulairty is per-minute
  if (sd->num_requests
}

tamed static void get_client_region(string ip, cb_cr cb) {
  tvars {
    Statement *st;
    ResultSet *res;
    float lat_f;
    float lon_f;
    int lat_d;
    int lon_d;
    int lat_d_rounded;
    int lon_d_rounded;
  }
  st = quova_conn->createStatement();
  res = st->executeQuery("SELECT * FROM quova a WHERE a.start_ip_int = (\
    SELECT MAX(start_ip_int) FROM quova b\
    WHERE b.start_ip_int <= INET_ATON('" + ip + "'))\
    AND a.end_ip_int >= INET_ATON('" + ip + "');");

  while (res->next()) {
    lat_f = static_cast<float>(res->getInt("latitude"));
    lon_f = static_cast<float>(res->getInt("longitude"));
  }
  lat_d = static_cast<int>(lat_f);
  lon_d = static_cast<int>(lon_f);

  // Binning
  lat_d_rounded = lat_d - (lat_d % 5);
  lon_d_rounded = lon_d - (lon_d % 5);
  
  ClientRegion out = ClientRegion(lat_d_rounded, lon_d_rounded);
  TRIGGER(cb, out);
}

// Gets a subdomain record from cache. May hit CRAQ if cached copy is
// old or non-existent.
tamed static void get_from_cache(string fqdn, cb_sub cb) {
  tvars {
    SubdomainInfo to_find;
    SubdomainInfo to_insert;
    str subdomain_data;
    subdomain sd;
  }
  to_find.storage.fqdn = str(fqdn.c_str());
  subdomain_cache_it = subdomain_cache.find(to_find);
  
  // No data stored for this record
  if (subdomain_cache_it == subdomain_cache.end()) {
    twait {craq.get_key(fqdn, mkevent(subdomain_data));}
    str2xdr(sd, subdomain_data);

    // TODO deal with not found
    to_insert.storage = sd;
    to_insert.validated = time(NULL);
    subdomain_cache.insert(to_insert);
    if (DEBUG) {
      cout << "Inserting record into cache from CRAQ";
      fflush(stdout);
    }
    TRIGGER(cb, 
      const_cast<SubdomainInfo*>(&*(subdomain_cache.find(to_insert))));
    return;
  }

  // If data stored, test if it's expired
  if (time(NULL) > (subdomain_cache_it->validated + MAX_CACHE_PERIOD)) {
    twait {craq.get_key(fqdn, mkevent(subdomain_data));}
    str2xdr(sd, subdomain_data);
    if (sd.seq_number > subdomain_cache_it->storage.seq_number) {
      to_insert.storage = sd;
      to_insert.validated = time(NULL);
      subdomain_cache.insert(to_insert); // This will overwrite (?)
      if (DEBUG) {
        cout << "Sequence number too low, updating record";
        fflush(stdout);
      }
      TRIGGER(cb,
      const_cast<SubdomainInfo*>(&*(subdomain_cache.find(to_insert))));
      return;
    }
    else {
      const_cast<SubdomainInfo*>(&*subdomain_cache_it)->validated = time(NULL);
    } 
    // TODO: deal with case where sequence number not updated but TTL's are
    // different
  }

  if (DEBUG) {
    cout << "Answering for " << fqdn << " from cache.\n";
    fflush(stdout);
  }

  // Otherwise just return the existing subdomain
  TRIGGER(cb,
    const_cast<SubdomainInfo*>(&*(subdomain_cache_it)));
}

tamed static void process(int fd) {
  tvars {
    strbuf resp;
    strbuf out;
    char buff[MAX_BUFF];
    int line_len;
    string type;
    string qname;
    string qclass;
    string qtype;
    int id;
    istringstream input;
    string remote_ip;
    string in;
    string query;
    string test;
    Statement *stmt;
    ResultSet *res;
    bool init;
    str subdomain_data;
    SubdomainInfo* sd;
    record rec;
    string record_data_str;
    ClientRegion cr;
  }
  while (true) {
    twait{ tame::waitread (fd, mkevent()); }
    if ( (resp.tosuio()->input(fd)) < 0 && errno != EAGAIN) {
      break;
    }
    line_len = str(resp).len();
    if (!init) {
      test = string(str(resp).cstr());
      if (test == "HELO\t1") {
        out << "OK	DONAR Backend fired up...\n";
        init = true;
      }
      else {
        out << "FAIL\n";
      }
    }
    else {
      input.str(str(resp).cstr());
      input >> type;
      input >> qname;

      input >> qclass;
      input >> qtype;
      input >> id;
      input >> remote_ip;
      //out << id;
    
      twait {get_client_region(remote_ip, mkevent(cr));}

      if (type == "AXFR") {
        out << strbuf("%s", last.c_str());
      }
      else {
        twait {get_from_cache(qname, mkevent(sd));}
        if (sd == NULL) break;
        log_client_request(&cr, sd);
        for (int i = 0; i < sd->storage.records.size(); i++) {
           rec = sd->storage.records[i];
           out << strbuf("DATA\t%s\tIN\t%s\t%i\t-1\t%s\n",
            sd->storage.fqdn.cstr(), rec.type.cstr(), 
            rec.ttl, rec.content.cstr());
        }
        last = string(str(out).cstr());
      }
      out << "END\n";    
    }
    twait{ tame:: waitwrite (fd, mkevent()); }
    if ( out.tosuio()->output(fd) < 0) {
      close(fd);
      if (DEBUG) cout << "Error writing to socket, closing";
      break;
    }
    out.tosuio()->rembytes(out.tosuio()->linelen());
    resp.tosuio()->rembytes(line_len);
    input.str("");
    input.clear();
  }
  return;
}

tamed static void listen_loop() {
  tvars {
    int s, fd, len;
    rendezvous_t<ev_t> G (__FILE__, __LINE__);
    socklen_t t;
    struct sockaddr_un local, remote;
    char input[1000];
    ev_t which;
  }

  if ((s = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
      perror("socket");
      exit(1);
  }

  local.sun_family = AF_UNIX;
  strcpy(local.sun_path, SOCK_PATH);
  remove(local.sun_path);
  len = strlen(local.sun_path) + sizeof(local.sun_family);
  if (bind(s, (struct sockaddr *)&local, len) == -1) {
      perror("bind");
      exit(1);
  }

  if (listen(s, 5) == -1) {
      perror("listen");
      exit(1);
  }

  while (true) {
      tame::waitread(s, mkevent(G, READ));
      int n;
      if (DEBUG) cout << "Waiting for a connection...\n";
      twait (G, which);

      switch (which) {
        case READ:
          t = sizeof(remote);
          if ((fd = accept(s, reinterpret_cast<sockaddr *>(&remote), &t)) 
             == -1) {
	    perror("accept");
	    exit(1);
          }
          if (DEBUG) cout << "Connected.\n";
          process(fd);
          break;
	default:
          break;
      }
  }
  return;
}

tamed static void main2() {
  tvars {
    ofstream logfile;
    Driver *driver;
    Statement *quova_stmt;
    Statement *donar_stmt;
    bool init_success;
  }
  // Open log file
  logfile.open("/var/log/donar", ios::out | ios::app);
  logfile << "Test";

  // Setup mysql connections
  driver = get_driver_instance();
  
  quova_conn = driver->connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS);
  donar_conn = driver->connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS);  

  quova_stmt = quova_conn->createStatement();
  donar_stmt = donar_conn->createStatement();
  quova_stmt->execute("USE quova");
  donar_stmt->execute("USE namecast");

  // Setup craq connection
  twait {
    craq.init(ZOO_LIST, mkevent(init_success));
  }

  if (init_success) {
    if (DEBUG) cout << "Connection established.\n";
  }
  else {
    if (DEBUG) cout << "Connection establishemnt failed.\n";
    exit(-1);
  }
  
  listen_loop();
}

int main (int argc, char* argv[]) {
  main2();
  amain();
}
