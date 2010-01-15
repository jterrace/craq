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
#include "QuadProg++.hh"
/*
#include <glpk.h>
#include "coin/ClpSimplex.hpp"
#include "coin/CoinHelperFunctions.hpp"
#include "coin/CoinTime.hpp"
#include "coin/CoinBuild.hpp"
#include "coin/CoinModel.hpp"
*/
#include <tr1/unordered_map>
#include <tr1/unordered_set>

str sock_path;
str mysql_user;
str mysql_pass;
str mysql_host;
str zoo_list;
#define DEBUG 1
#define MAX_CACHE_PERIOD 10
#define LOG_EXPIRY_MINUTES 15
#define LOG_CLEAN_INTERVAL_MINS 15
#define MAX_A_RECORDS 1

using namespace std;
using namespace sql;
using namespace QuadProgPP;

const unsigned int MAX_BUFF = 1000;
Connection* quova_conn;
Connection* donar_conn;
craq_interface craq;
unsigned int my_ip_addr;

string last; // PDNS hack

// Store subdomains in a hash-set for quick lookup
tr1::unordered_set<SubdomainInfo, SubdomainHash, SubdomainEqual> 
  subdomain_cache;
tr1::unordered_set<SubdomainInfo, SubdomainHash, SubdomainEqual>::iterator
  subdomain_cache_it;

// Cache of IP location lookups so we don't hit quova as often
tr1::unordered_map<unsigned long, ClientRegion> location_cache;
tr1::unordered_map<unsigned long, ClientRegion>:: iterator location_cache_it;

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
  return (cr1.lat == cr2.lat) && (cr1.lon == cr2.lon);
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
    struct in_addr addr;
  }
  if (DEBUG) {
    cout << "Quova lookup requested for " << ip << endl;
    fflush(stdout);
  }
  // In cache?
  inet_aton(ip.c_str(), &addr);
  location_cache_it = location_cache.find(addr.s_addr);
  if (location_cache_it != location_cache.end()) {
    TRIGGER(cb, location_cache_it->second);
    return;
  }
  st = quova_conn->createStatement();
  res = st->executeQuery("SELECT * FROM quova a WHERE a.start_ip_int = (\
    SELECT MAX(start_ip_int) FROM quova b\
    WHERE b.start_ip_int <= INET_ATON('" + ip + "'))\
    AND a.end_ip_int >= INET_ATON('" + ip + "');");

  lat_f = 0;
  lon_f = 0;

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

  if (location_cache.size() > 300) {
    location_cache.erase(location_cache.begin()->first);
  }
  
  location_cache.insert(pair<unsigned long, ClientRegion>(addr.s_addr, out));
  
  if (DEBUG) {
    cout << "Returning client region from quova lookup: " <<  out << endl;
    fflush(stdout);
  }
  TRIGGER(cb, out);
}

// Given a subdomain and a client region, returns the closest n records,
// with the closest one first.
tamed static void closest_n_records(SubdomainInfo* sd, ClientRegion* cr, int
 n, callback<void, vector<record> >::ref cb) {
  tvars {
    record rec;
    multimap<int, record> by_distance;
    multimap<int, record>::iterator by_distance_it;
    int i;
    vector<record> out;
    ClientRegion other;
  }
  for (i = 0; i < sd->storage.records.size(); i++) {
    rec = sd->storage.records[i];
    twait{get_client_region(rec.content.cstr(), mkevent(other));}
    int distance = ((cr->lat - other.lat) * (cr->lat - other.lat)) +
      ((cr->lon - other.lon) * (cr->lon - other.lon));
    by_distance.insert(pair<int, record>(distance, rec));
  }
  by_distance_it = by_distance.begin();
  for (i = 0; (i < by_distance.size()) && (i < n); i++) {
    out.push_back(by_distance_it->second);
    by_distance_it++;
  }
  TRIGGER(cb, out);
}

void print_request_logs(SubdomainInfo* sd) {
  client_requests_iter it = sd->num_requests.begin();
  cout << sd->storage.fqdn << endl;
  while (it != sd->num_requests.end()) { 
    ClientRegion r = it->first;
    cout << r << endl;
    unordered_map<size_t, unsigned int>* map = it->second;
    num_request_iter t_it = map->begin();
    while (t_it != map->end()) {
      cout << t_it->first << ": " << t_it->second << endl;
      ++t_it;
    }
    ++it;
  }
  fflush(stdout);
}

// Delete old records so we don't fill up too much memory
void clean_request_logs() {
  subdomain_cache_it = subdomain_cache.begin();
  size_t cutoff_time = time(NULL) - (60 * LOG_EXPIRY_MINUTES);
  while (subdomain_cache_it != subdomain_cache.end()) {
    SubdomainInfo* sd = const_cast<SubdomainInfo*>(&*subdomain_cache_it);
    client_requests_iter it = sd->num_requests.begin();
    while (it != sd->num_requests.end()) {
      unordered_map<size_t, unsigned int>* map = it->second;
      num_request_iter t_it = map->begin();
      while (t_it != map->end()) {
        if (t_it->first < cutoff_time) 
          map->erase(t_it->first);           
        t_it++;
      }
      it++;
    }
    subdomain_cache_it++;
  }
  delaycb(LOG_CLEAN_INTERVAL_MINS * 60, 0, wrap(clean_request_logs));
}

// Increments various counters which record request volume and client space.
void log_client_request(ClientRegion* c, SubdomainInfo* sd) {
  // Assure we're storing this client region for this subdomain
  client_requests_iter it = sd->num_requests.find(*c);
  if (it == sd->num_requests.end()) {
    unordered_map<size_t, unsigned int> *new_map = 
      new unordered_map<size_t, unsigned int>;
    sd->num_requests.insert(
      pair<ClientRegion, unordered_map<size_t, unsigned int>* >(*c, new_map));
    it = sd->num_requests.find(*c);
  }
  unordered_map<size_t, unsigned int>* existing_map = it->second;

  size_t t = time(NULL);

  t = t - (t % 60); // Request granularity is per-minute

  // Add this request to the log for this minute
  num_request_iter t_it = existing_map->find(t);
  
  if (t_it == existing_map->end()) {
    existing_map->insert(pair<size_t, unsigned int>(t, 1));
  }
  else {
    cout << "Updating Value\n";
    unsigned int value = t_it->second;
    existing_map->erase(t);
    existing_map->insert(pair<size_t, unsigned int>(t, value + 1));
  }
}

// Take traffic over the last <minutes> minutes, and calculate the
// expected traffic load on each server given the current routing policy.
tamed void SubdomainInfo::update_expected_traffic(int minutes,
    callback<void>::ref cb) {
  tvars {
    size_t now;
    client_requests_iter client_it;
    unordered_map<size_t, unsigned int>* requests;
    vector<pair<record, unsigned int>> to_add;
    vector<pair<record, unsigned int>>::iterator to_add_it;
    num_request_iter time_it;
    rules_iter rules_it;
    client_rule_iter c_rule_it;
    vector<pair<record, float>> rules;
    str subdomain_data;
    struct subdomain_opt sd_opt;
    int i, j;
    bool seen;
    string opt_key, result;
    struct traffic_entry new_entry;
    struct rec_opt_info new_rec_opt;
    vector<record> recs;
  }
  client_it = this->num_requests.begin();
  now = time(NULL);

  // Populate record list with blanks
  for (i=0; i < this->storage.records.size(); i++) {
    to_add.push_back(pair<record, unsigned int> (this->storage.records[i], 0));
  }

  // TODO fix N^2 components here

  // Iterate through client regions
  while (client_it != this->num_requests.end()) {
    requests = client_it->second;
    rules_it = this->rules.find(client_it->first);
    if (rules_it == this->rules.end()) {
      // If we don't have any rules, we must be mapping to closest node
      // so store expected traffic as if mapping to closest node
      twait{closest_n_records(this, const_cast<ClientRegion*>( 
        &(client_it->first)), 1, mkevent(recs));}
      if (recs.size() == 0) {
        client_it++;
        continue;
      }
      time_it = requests->begin();
      
      while (time_it != requests->end()) {
        if (time_it->first > (now - (minutes * 60))) {
          to_add_it = to_add.begin();
          while (to_add_it != to_add.end()) {
            if (recs[0].content == to_add_it->first.content ) {
              to_add_it->second += 1.0 * time_it->second;
            }
            to_add_it++;
          }
        }
        time_it++;
      }
      client_it++;
      continue;
    }
    // We have rules for this client...
    time_it = requests->begin();
    while(time_it != requests->end()) {
      // Do we consider this time-period?
      if (time_it->first > (now - (minutes * 60))) {
        // For each record add the expected traffic from this client
        // group.
        to_add_it = to_add.begin();
        while (to_add_it != to_add.end()) {
          c_rule_it = rules_it->second.begin();
          while (c_rule_it != rules_it->second.end()) {
           if (c_rule_it->first.content == to_add_it->first.content ) {
              to_add_it->second += c_rule_it->second * time_it->second;
            }
            c_rule_it++;
          }
          to_add_it++;
        }  
      }
      time_it++;
    }
    client_it++;
  }

  opt_key = this->storage.fqdn.cstr();
  opt_key += "-opt";
  twait {craq.get_key(opt_key, mkevent(subdomain_data));}

  if (subdomain_data.len() < 20) {
      cout << "CRAQ does not have optimization info for \n" << 
        this->storage.fqdn.cstr();
      // Add blank entries for existing records
      sd_opt.fqdn = this->storage.fqdn;
      for (i=0; i < this->storage.records.size(); i++) {
        new_rec_opt.content = this->storage.records[i].content;
        // TODO fill in proportion
        sd_opt.records.push_back(new_rec_opt);
      }
  }
  else {
    str2xdr (sd_opt, subdomain_data);
  }

  to_add_it = to_add.begin();

  // Look at each record in the optimization entry
  for (i=0; i < sd_opt.records.size(); i++) {
    to_add_it = to_add.begin();
    // Now see if we have a traffic value for this record
    while (to_add_it != to_add.end()) {
      if (sd_opt.records[i].content == to_add_it->first.content) {
        // We have something to add, so add it...
        for (j=0; j<sd_opt.records[i].entries.size(); j++) {
          if (sd_opt.records[i].entries[j].server_id == my_ip_addr) {
            sd_opt.records[i].entries[j].update_time = time(NULL);
            sd_opt.records[i].entries[j].traffic_vol = 
              to_add_it->second;
            seen = true;
          }
        }
        if (seen == false) {
          new_entry.server_id = my_ip_addr;
          new_entry.update_time = time(NULL);
          new_entry.traffic_vol = to_add_it->second;
          sd_opt.records[i].entries.push_back(new_entry);
        }
        seen = false;
      }
      to_add_it++;
    }
  }

  subdomain_data = xdr2str(sd_opt);
  cout << "Setting update traffic volume for " << opt_key;
  twait {craq.set_key(opt_key, subdomain_data.cstr(), subdomain_data.len(),
    mkevent(result));}

  // Print out totals
  to_add_it = to_add.begin();
  if (DEBUG) {
    cout << "Totals\n:";
    while (to_add_it != to_add.end()) {
      cout << to_add_it->first.content;
      cout << " ";
      cout << to_add_it->second;
      cout << "\n";
      to_add_it++;
    }
  }
  TRIGGER(cb);
}

// Probe the CRAQ backend to get the wide-area totals of traffic being routed
// to an instance.
tamed void SubdomainInfo::get_traffic_totals(cb_totals cb) {
  tvars {
    unordered_map <string, unsigned int> out;
    string opt_key;
    str subdomain_data;
    struct subdomain_opt sd_opt;
    int i;
    int j;
    unsigned int other_instance_total;
    unsigned int instance_total;
    unsigned int subdomain_total;
  }

  opt_key = this->storage.fqdn.cstr();
  opt_key += "-opt";
  twait {craq.get_key(opt_key, mkevent(subdomain_data));}

  if (subdomain_data.len() < 30) {
    if (DEBUG) {
      cout << "Request to get total traffic failed since data not in CRAQ: ";
      cout << this->storage.fqdn.cstr() << "\n";
    }
    for (i=0; i < this->storage.records.size(); i++) {
      out.insert(pair <string, unsigned int> (
        string(this->storage.records[i].content), 0));
    }
  }

  if (DEBUG) cout << "Got traffic totals for " << this->storage.fqdn.cstr() <<
   "\n";
  str2xdr (sd_opt, subdomain_data);
  for (i=0; i < sd_opt.records.size(); i++) {
    other_instance_total = 0;
    instance_total = 0;
    // Sum contribution from all nodes
    for (j=0; j < sd_opt.records[i].entries.size(); j++) {
      instance_total += sd_opt.records[i].entries[j].traffic_vol;
      if (sd_opt.records[i].entries[j].server_id != my_ip_addr) {
        other_instance_total += sd_opt.records[i].entries[j].traffic_vol;
      }
    }
    subdomain_total += instance_total;
    if (DEBUG) {
      cout << "Adding the total for record: " << 
        sd_opt.records[i].content.cstr() << " " << other_instance_total << "\n";
    }

    out.insert(pair <string, unsigned int> (
      string(sd_opt.records[i].content.cstr()), other_instance_total));
  }
  TRIGGER(cb, out, subdomain_total);
}

// Use traffic from other nodes, alongside local client information, to
// calculate optimal routes.
tamed void SubdomainInfo::calculate_optimal_routes(callback<void>::ref cb) {
  tvars {
    vector<pair<ClientRegion, float> > props;
    vector<pair<ClientRegion, float> >::iterator it;
    int num_clients;
    int num_servers;
    ClientRegion other;
    ClientRegion cr;
    vector<float> coeffs;
    int i, j, k, l;
    int distance;
    float distance_norm;
    int problem_size;
    vector<double> temp_row;
    double* solution;
    unordered_map<ClientRegion, vector<pair<record, float> >, 
	ClientRegionHash, ClientRegionEqual > new_rules;
    vector<pair<record, float> > client_rules;
    Vector<double> g0, ce0, ci0, x, eq_vec;
    Matrix<double> G, CE, CI;
    double temp, S_n, P_other;
    unordered_map <string, unsigned int> totals;
    unordered_map <string, unsigned int>::iterator totals_it;
    unsigned int total_traffic;
    Vector<double> quad_row;
  }

  // Get global data
  twait { get_traffic_totals(mkevent(totals, total_traffic)); }  
  
  // Get client proportions
  props = this->get_client_props(10);
  it = props.begin();
  
  cout << "Calculating optimal policy for " << this->storage.fqdn << "\n";
  num_clients = props.size();
  num_servers = this->storage.records.size();
  problem_size = num_clients * num_servers;

  cout << "Number of clients: " << num_clients;
  cout << " Number of servers: " << num_servers;

  // Create coefficient vector of Rci's (R11, R12, R13...)
  G.resize(problem_size, problem_size);
  g0.resize(problem_size);
  x.resize(problem_size);
  ce0.resize(num_clients);
  ci0.resize(problem_size);  
  CE.resize(problem_size, num_clients);
  CI.resize(problem_size, problem_size);

  S_n = 1.0;

  for (i=0; i < num_servers; i++) {
    for (j=0; j < num_clients; j++) {
      quad_row = Vector<double> (problem_size);
      for (l=0; l < problem_size; l++) quad_row[l] = 0.00;
      for (k=0; k < num_clients; k++) {
        temp = props[j].second * props[k].second * 2.0; // temp 1.0 cost
        cout << "Setting to: " << temp << "\n";
        quad_row[k * num_servers + i] = temp;
        // row: j * num_servers + i // col: k * num_servers + i
      }
      G.setRow(j * num_servers + i, quad_row);
    }
  }

  eq_vec.resize(problem_size);

  // Add constraints that all must be positive
  for (i = 0; i < problem_size; i++) {
    quad_row = Vector<double> (problem_size);
    for (l=0; l < problem_size; l++) quad_row[l] = 0.0;
    quad_row[i] = 1.0;
    CI.setRow(i, quad_row);
    ci0[i] = 0.0;
  }

  // Add linear coefficients and constraints
  for (i = 0; i < num_clients; i++) {
    ce0[i] = -1.0;

    eq_vec = Vector<double> (problem_size);
    for (k=0; k<problem_size; k++) eq_vec[k] = 0.0;

    for (j = 0; j < num_servers; j++) {
      twait{get_client_region(
        this->storage.records[j].content.cstr(), mkevent(other));}
        cr = props[i].first;
      distance = ((cr.lat - other.lat) * (cr.lat - other.lat)) +
        ((cr.lon - other.lon) * (cr.lon - other.lon));
      distance_norm = (float) distance / (350 * 350);
      // Add dist(c, i) * alpha_c * S_n
      g0[i * num_servers + j] = distance_norm * props[i].second * S_n;
      
      totals_it = totals.find(this->storage.records[j].content.cstr());

      P_other = (float) totals_it->second / total_traffic;
      if (total_traffic == 0) P_other = 0.0;

      // Add S_n * 2 * alpha_c * (P_other - w) * lambda
      g0[i * num_servers + j] += S_n * 2 * (P_other - .25) * 1.0;

      eq_vec[i * num_servers + j] = 1.0;
    }
    CE.setColumn(i, eq_vec);
  }

  cout << G;
  cout << g0;
  cout << CE;
  cout << CI;
  cout << ce0;
  cout << ci0;

  cout << "Solution cost\n";
  cout << solve_quadprog(G, g0, CE, ce0, CI, ci0, x) << "\n";
  cout << "Solution\n";
  cout << x;

  // Now populate routing rules based on the new data
  for (i = 0; i < num_clients; i++) {
    client_rules = vector<pair<record, float> > ();
    for (j = 0; j < num_servers; j++) {
      client_rules.push_back(pair<record, float> 
        (this->storage.records[j], x[i * num_servers + j]));
    }
    new_rules.insert(pair<ClientRegion, vector<pair<record, float> > > (
      props[i].first, client_rules));
  }
  this->rules = new_rules;

  // Now store expected traffic given this new policy
  twait {this->update_expected_traffic(10, mkevent());}

  TRIGGER(cb);
}
void client_debug(callback<void>::ref cb, CLOSURE);

tamed void client_debug(callback<void>::ref cb) {
  tvars {
    SubdomainInfo* sd;
  }
  TRIGGER(cb);
  while (true) {
    subdomain_cache_it = subdomain_cache.begin();
    cout << "Running optimization\n\n";
    while (subdomain_cache_it != subdomain_cache.end()) {
      sd = const_cast<SubdomainInfo*>(&*subdomain_cache_it);
      cout <<  sd->storage.fqdn.cstr();
      cout << "\n";
      // Calculate optimal routes based on external traffic
      twait{ sd->calculate_optimal_routes(mkevent()); }
      //twait {sd->update_expected_traffic(10, mkevent());}
      subdomain_cache_it++;
    }
    twait { delaycb(10, 0, mkevent()); }
  }
}


vector<pair<ClientRegion, float> > 
  SubdomainInfo::get_client_props(int minutes) {
  vector<pair<ClientRegion, unsigned int> > totals;
  vector<pair<ClientRegion, float> > out;
  unsigned int total_volume = 0;

  size_t now = time(NULL);
  client_requests_iter client_it;
  client_it = this->num_requests.begin();

  while (client_it != this->num_requests.end()) {
    unordered_map<size_t, unsigned int>* requests = client_it->second;
    num_request_iter time_it;
    time_it = requests->begin();
    unsigned int client_total = 0;
    while(time_it != requests->end()) {
      if (time_it->first > (now - (minutes * 60))) {
        client_total += time_it->second;
        total_volume += time_it->second;
      }
      time_it++;
    }
  
    totals.push_back(pair<ClientRegion, unsigned int> 
      (client_it->first, client_total));
    client_it++;
  }

  // Now all client traffic has been recorded, so go back and normalize
  vector<pair<ClientRegion, unsigned int> >::iterator totals_it =
    totals.begin();
  while (totals_it != totals.end()) {
    cout << "Adding region (" << totals_it->first.lat << ", ";
    cout << totals_it->first.lon << ") ";
    cout << "Total traffic for this region " << totals_it->second << "\n";
    out.push_back(pair<ClientRegion, float> 
      (totals_it->first, (float) totals_it->second / total_volume));
    totals_it++;
  }

  return out;
}

// Return a subset of the A records for SubdomainInfo as determined
// by optimal mapping policy. If policy not yet in place, default
// policy is to return nereast three records.
tamed static void get_a_records(SubdomainInfo* sd, ClientRegion* cr,
  callback<void, vector<record> >::ref cb) {
  tvars{
    ClientRegion other;
    vector<record> out; 
    vector<pair<record, float> > rules;
    rules_iter r_it;
    bool rules_present;
    unordered_map<ClientRegion, float, ClientRegionHash, ClientRegionEqual> 
      this_rec;
    vector<pair<record, float> >::iterator record_it;
    double cumulative;
    double random;
  }
  rules_present = false;
  r_it = sd->rules.find(*cr);

  if (r_it != sd->rules.end()) {
    rules_present = true;
    record_it = r_it->second.begin();
    cumulative = 0.0;
    random = (double) rand() / ((double) RAND_MAX + (double) 1);
    while (record_it != r_it->second.end()) {
      cumulative += record_it->second;
      if (cumulative > random) {
        out.push_back(record_it->first);
        TRIGGER(cb, out);
        return;
      }
      record_it++;
    }
    // Shouldn't ever get here
  }
  
  // If we don't have rules yet, just use proximity
  twait { closest_n_records(sd, cr, MAX_A_RECORDS, mkevent(out)); }
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
  if (DEBUG) {
    cout << "Cache request for " << fqdn << endl;
    fflush(stdout);
  }
  subdomain_cache_it = subdomain_cache.find(to_find);
  
  // No data stored for this record
  if (subdomain_cache_it == subdomain_cache.end()) {
    cout << "Getting key";
    fflush(stdout);
    twait {craq.get_key(fqdn, mkevent(subdomain_data));}
    if (subdomain_data.len() < 20) {
      cout << "CRAQ did not have data for this record\n";
      TRIGGER(cb, NULL);
      return;
    }

    cout << "Got value of size " << subdomain_data.len();
    cout << subdomain_data;
    fflush(stdout);
    str2xdr(sd, subdomain_data);

    to_insert.storage = sd;
    to_insert.rules_populated = false;
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
      to_insert.rules_populated = false;
      to_insert.validated = time(NULL);
      subdomain_cache.erase(subdomain_cache_it);
      subdomain_cache.insert(to_insert);
      if (DEBUG) {
        cout << "Sequence number too low, updating record";
        cout << "New data length: " << subdomain_data.len();
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
    vector<record> recs;
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
        if (sd != NULL) {
	  log_client_request(&cr, sd);
	  print_request_logs(sd);

	  // Get A Records according to optimal policy
	  if (qtype == "A" || qtype == "ANY") {
	    twait {get_a_records(sd, &cr, mkevent(recs));}
	    vector<record>::iterator it = recs.begin();
	    while (it != recs.end()) {
	       out << strbuf("DATA\t%s\tIN\t%s\t%i\t-1\t%s\n",
	      sd->storage.fqdn.cstr(), it->type.cstr(),
	      it->ttl, it->content.cstr()); 
	      ++it;
	    }
	  }
	  // Add other records
	  for (int i = 0; i < sd->storage.records.size(); i++) {
	     rec = sd->storage.records[i];
	     if ((rec.type != "A") && 
	       (qtype == "ANY" || qtype == rec.type.cstr())) {
	       out << strbuf("DATA\t%s\tIN\t%s\t%i\t-1\t%s\n",
		sd->storage.fqdn.cstr(), rec.type.cstr(), 
		rec.ttl, rec.content.cstr());
	     }
	  }
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

/*
// Return a set of request-routing rules given:
// clients: An list of clients with correspoding proportions
// records: A list of records
  vector<pair<record, unordered_map<ClientRegion, float,
  ClientRegionHash, ClientRegionEqual> > > get_rules(
  vector<pair<ClientRegion, float> > clients, vector<record> records) {

}
*/

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
  strcpy(local.sun_path, sock_path);
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

tamed static void main2(int argc, char** argv) {
  tvars {
    ofstream logfile;
    Driver *driver;
    Statement *quova_stmt;
    bool init_success;
    int log_clean_interval;
    conftab ct;
    int ch;
    str config;
    vec<str> av;
    int line;
    bool errors;
    parseargs pa("donar.conf", -1);
    struct in_addr addr;
  }
  /*
  while ((ch = getopt(argc, argv, "C")) != -1) {
    switch(ch) {
      case 'C':
        config = optarg;
        break;
    }
  }
  */
  // Config options
  ct.add("MySqlUser", &mysql_user);
  ct.add("MySqlPass", &mysql_pass);
  ct.add("MySqlHost", &mysql_host);
  ct.add("ZooList", &zoo_list);
  ct.add("SockPath", &sock_path);

  line = 0;
  while (pa.getline(&av, &line)) {
    if (!ct.match(av, str("donar.conf"), line, &errors)) {
      warn << config << ":" << line << ": unknown directive\n";
    }
  }
  // Open log file
  logfile.open("/var/log/donar", ios::out | ios::app);
  logfile << "Test";

  // Setup mysql connections
  driver = get_driver_instance();
  
  quova_conn = driver->connect(mysql_host.cstr(), mysql_user.cstr(), 
    mysql_pass.cstr());
  donar_conn = driver->connect(mysql_host.cstr(), mysql_user.cstr(), 
    mysql_pass.cstr());  

  quova_stmt = quova_conn->createStatement();
  quova_stmt->execute("USE quova");

  // Periodically clean old data
  delaycb(LOG_CLEAN_INTERVAL_MINS * 60, 0, wrap(clean_request_logs));

  // Temporary debug
  twait { client_debug(mkevent()); }

  // Setup craq connection
  twait {
    craq.init(string(zoo_list.cstr()), mkevent(init_success));
  }

  inet_aton(craq.my_ip_addr.c_str(), &addr);
  my_ip_addr = (unsigned int) addr.s_addr;

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
  main2(argc, argv);
  amain();
}
