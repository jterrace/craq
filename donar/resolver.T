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
#include "tame_rpcserver.h"
#include "mysql_connection.h"
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
#define DEBUG 1

using namespace std;
using namespace sql;

typedef enum { READ, WRITE } ev_t;
const unsigned int MAX_BUF = 1000;
Connection* quova_conn;
Connection* donar_conn;

string last; // PDNS hack

tr1::unordered_set<ClientRegion> known_clients;
tr1::unordered_set<SubdomainInfo> subdomain_cache;

ClientRegion::ClientRegion(double lat, double lon) {
  this->lat = lat;
  this->lon = lon;
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
  for (int i = 0; i < (2 * sizeof(double)); i++) {
    if (i < sizeof(double)) {
      out = out*31 + ((char*) &lat)[i];
    }
    else {
      out = out*31 + ((char*) &lon)[i - sizeof(double)];
    }
  } 
  return out;
}

tamed static void process(int fd) {
  tvars {
    strbuf resp;
    strbuf out;
    char buff[MAX_BUF];
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
      
      if (type == "AXFR") {
        out << strbuf("%s", last.c_str());
      }
      else {
        stmt = donar_conn->createStatement();
        query = "SELECT * FROM records WHERE name = '" + qname + "'";
        res = stmt->executeQuery(query);
        while (res->next()) {
          out << strbuf("DATA %s IN %s %i -1 %s\n",
	    res->getString("name").c_str(), res->getString("type").c_str(),
  	    res->getInt("ttl"), res->getString("content").c_str());
          last = string(str(out).cstr());
        }
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

int main (int argc, char *argv[]) {
  // Open log file
  ofstream logfile;
  logfile.open("/var/log/donar", ios::out | ios::app);
  logfile << "Test";

  // Setup mysql connections
  Driver *driver;
  driver = get_driver_instance();
  
  quova_conn = driver->connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS);
  donar_conn = driver->connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS);  

  Statement *quova_stmt = quova_conn->createStatement();
  Statement *donar_stmt = donar_conn->createStatement();
  quova_stmt->execute("USE quova");
  donar_stmt->execute("USE namecast");
  
  listen_loop();
  amain();
}
