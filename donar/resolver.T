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
#include "mosek.h"
#include <tr1/unordered_map>
#include <tr1/unordered_set>

str sock_path;
str mosek_file;
str mysql_user;
str mysql_pass;
str mysql_host;
str zoo_list;
ofstream logfile;
bool debug;
bool closest_node;

#define LOG_EXPIRY_MINUTES 15
#define LOG_CLEAN_INTERVAL_MINS 15
#define MAX_A_RECORDS 1

using namespace std;
using namespace sql;

const unsigned int MAX_BUFF = 1000;
Connection* quova_conn;
Connection* donar_conn;
Driver *driver;

craq_interface craq;
unsigned int theta;
unsigned int my_ip_addr;
unsigned int update_interval;
unsigned int max_cache_period;
unsigned int geo_rounding;

string last; // PDNS hack

// Store subdomains in a hash-set for quick lookup
tr1::unordered_set<SubdomainInfo, SubdomainHash, SubdomainEqual> 
  subdomain_cache;
typedef tr1::unordered_set<SubdomainInfo, SubdomainHash, SubdomainEqual>::iterator subdomain_cache_it;


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
    bool saw_exception;
  }
  if (debug) {
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
  saw_exception = false;
  try {
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
  } catch (sql::SQLException &e) {
    cout << "ERROR: Mysql Exception!!!\n";
    saw_exception = true;
    lat_d = 0;
    lon_d = 0;
  }
  if (saw_exception) {
   driver = get_driver_instance();
   quova_conn = driver->connect(mysql_host.cstr(), mysql_user.cstr(),
     mysql_pass.cstr());
  }
  // Binning
  lat_d_rounded = lat_d - (lat_d % geo_rounding);
  lon_d_rounded = lon_d - (lon_d % geo_rounding);
 
  ClientRegion out = ClientRegion(lat_d_rounded, lon_d_rounded);

  if (location_cache.size() > 300) {
    location_cache.erase(location_cache.begin()->first);
  }
  
  location_cache.insert(pair<unsigned long, ClientRegion>(addr.s_addr, out));
  
  if (debug) {
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
//    if (by_distance.count(by_distance_it->first) > 1) {
//      
 //   }
 //   else {
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
  subdomain_cache_it sd_it = subdomain_cache.begin();
  size_t cutoff_time = time(NULL) - (60 * LOG_EXPIRY_MINUTES);
  while (sd_it != subdomain_cache.end()) {
    SubdomainInfo* sd = const_cast<SubdomainInfo*>(&*sd_it);
    client_requests_iter it = sd->num_requests.begin();
    int client_total = 0;
    while (it != sd->num_requests.end()) {
      unordered_map<size_t, unsigned int>* map = it->second;
      num_request_iter t_it = map->begin();
      while (t_it != map->end()) {
        if (t_it->first < cutoff_time) {
          map->erase(t_it->first);     
        }
        else {
          client_total += 1;
        }      
        t_it++;
      }
      if (client_total < 5) {
        sd->num_requests.erase(it);
      }
      it++;
    }
    sd_it++;
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
    if (debug) cout << "Updating Value\n";
    unsigned int value = t_it->second;
    existing_map->erase(t);
    existing_map->insert(pair<size_t, unsigned int>(t, value + 1));
  }
}

// Sets the optimization data described by sd_opt in craq
tamed void SubdomainInfo::set_opt_data(struct subdomain_opt sd_opt, 
  callback<void>::ref cb) {
  tvars {
    str subdomain_data;
    string result;
    string opt_key;
  }
  subdomain_data = xdr2str(sd_opt);
  opt_key = this->storage.fqdn.cstr();
  opt_key += "-opt";
  if (debug) cout << "Updating optimization values for " << opt_key;
  twait {craq.set_key(opt_key, subdomain_data.cstr(), subdomain_data.len(),
    mkevent(result));}
  TRIGGER(cb);
}

// Un-marshal RPC double
double get_attr(record_attr* att) {
  double out;
  for (int i = 0; i < sizeof(double); i++) {
    ((char*) &out)[i] = att->data[i];
  }
  return out;
}

// Gets optimization data from CRAQ for this subdomain. If no optimization
// record exists in CRAQ, creates one. 
tamed void SubdomainInfo::get_opt_data(callback<void, subdomain_opt>::ref cb) {
  tvars {
    string opt_key;
    str subdomain_data;
    subdomain_opt sd_opt;
    rec_opt_info new_rec_opt;
    int i, j;
    double proportion, lambda, epsilon;
  }

  opt_key = this->storage.fqdn.cstr();
  opt_key += "-opt";
  twait {craq.get_key(opt_key, mkevent(subdomain_data));}

  if (subdomain_data.len() > 20) {
    str2xdr (sd_opt, subdomain_data);
  }
  if (subdomain_data.len() < 20 || 
       (sd_opt.records.size() != this->storage.records.size()) ||
       (sd_opt.seq_number < this->storage.seq_number)) {
      if (debug) cout << "CRAQ does not have updated optimization info for \n" 
        << this->storage.fqdn.cstr();

      // Add new entries for existing records
      sd_opt.seq_number = this->storage.seq_number;
      sd_opt.fqdn = this->storage.fqdn;
      sd_opt.records.setsize(0);
      for (i=0; i < this->storage.records.size(); i++) {
        new_rec_opt.content = this->storage.records[i].content;
        proportion =  1.0 / this->storage.records.size();
        epsilon = .02;
        for (j=0; j < this->storage.records[i].attrs.size(); j++) {
          if (this->storage.records[i].attrs[j].type == SPLIT_PROPORTION) {
            proportion = get_attr(&this->storage.records[i].attrs[j]);
          }  
          if (this->storage.records[i].attrs[j].type == SPLIT_EPSILON) {
            epsilon = get_attr(&this->storage.records[i].attrs[j]);
          } 
        }
        lambda = 1.0;
        memcpy(&new_rec_opt.proportion, &proportion, 
          sizeof(new_rec_opt.proportion));
        memcpy(&new_rec_opt.epsilon, &epsilon, sizeof(new_rec_opt.epsilon));
        memcpy(&new_rec_opt.lambda, &lambda, sizeof(new_rec_opt.lambda));

        sd_opt.records.push_back(new_rec_opt);
        if (debug) cout << sd_opt.records.size();
        if (debug) cout << this->storage.records.size();
      }
  }
  if (this->storage.records.size() != sd_opt.records.size()) {
    exit(1);
  }

  TRIGGER(cb, sd_opt);
}

// Get the toal traffic this node expects to route to each record
tamed void SubdomainInfo::get_my_totals(int minutes, callback<void, vector<pair<record, double> >, double>::ref cb) {
  tvars {
    client_requests_iter client_it;
    size_t now;
    vector<pair<record, double> > to_add;
    vector<pair<record, double> >::iterator to_add_it;
    num_request_iter time_it;
    unordered_map<size_t, unsigned int>* requests;
    int i, j;
    rules_iter rules_it;
    client_rule_iter c_rule_it;
    vector<record> recs;
    double my_total;
  }
  client_it = this->num_requests.begin();
  now = time(NULL);
  my_total = 0.0;
  // Populate record list with blanks
  for (i=0; i < this->storage.records.size(); i++) {
    to_add.push_back(pair<record, double> (this->storage.records[i], 0.0));
  }

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
              my_total += 1.0 * time_it->second;
            }
            to_add_it++;
          }
        }
        time_it++;
      }
      client_it++;
      continue;
    }
    // We have rules for this cleint...
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
              my_total += c_rule_it->second * time_it->second;
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

  TRIGGER(cb, to_add, my_total);
}

// Take traffic over the last <minutes> minutes, and calculate the
// expected traffic load on each server given the current routing policy.
tamed void SubdomainInfo::update_expected_traffic(int minutes,
    callback<void>::ref cb) {
  tvars {
    size_t now;
    client_requests_iter client_it;
    unordered_map<size_t, unsigned int>* requests;
    vector<pair<record, double> > to_add;
    vector<pair<record, double> >::iterator to_add_it;
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
    vector<record> recs;
    double unused;
  }
  
  twait {this->get_my_totals(minutes, mkevent(to_add, unused));}
  twait{this->get_opt_data(mkevent(sd_opt)); }
  
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
            memcpy(&sd_opt.records[i].entries[j].traffic_vol,
              &to_add_it->second, sizeof(double));
            seen = true;
          }
        }
        if (seen == false) {
          new_entry.server_id = my_ip_addr;
          new_entry.update_time = time(NULL);
          memcpy(&new_entry.traffic_vol, &to_add_it->second, sizeof(double));
          sd_opt.records[i].entries.push_back(new_entry);
        }
        seen = false;
      }
      to_add_it++;
    }
  }

  twait { this->set_opt_data(sd_opt, mkevent()); }

  // Print out totals
  to_add_it = to_add.begin();
  if (debug) {
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

// Given an struct subdomain_opt add up the total traffic to each instance.
// If include_me is true, the instance map includes traffic
// from this node.
tamed void SubdomainInfo::get_traffic_totals(struct subdomain_opt sd_opt,
    bool include_me, cb_totals cb) {
  tvars {
    unordered_map <string, double> out;
    string opt_key;
    str subdomain_data;
    int i;
    int j;
    double temp;
    double other_instance_total;
    double instance_total;
    double subdomain_total;
  }

  subdomain_total = 0.0;

  for (i=0; i < sd_opt.records.size(); i++) {
    other_instance_total = 0;
    instance_total = 0;
    // Sum contribution from all nodes
    for (j=0; j < sd_opt.records[i].entries.size(); j++) {
      memcpy(&temp, &sd_opt.records[i].entries[j].traffic_vol, sizeof(double));
      instance_total += temp;
      if (debug) cout << "Adding: " << temp << "\n";
      if (include_me ||
        (sd_opt.records[i].entries[j].server_id != my_ip_addr)) {
        other_instance_total += temp;
      }
    }
    subdomain_total += instance_total;
    if (debug) {
      cout << "Adding the total for record: " << 
        sd_opt.records[i].content.cstr() << " " << other_instance_total << "\n";
    }

    out.insert(pair <string, double> (
      string(sd_opt.records[i].content.cstr()), other_instance_total));
  }
  if (debug) cout << "Total traffic was " << subdomain_total;
  TRIGGER(cb, out, subdomain_total);
}

static void MSKAPI printstr(void *handle, char str[]) {
  exit(1);
  printf("%s", str);
  fflush(stdout);
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
    subdomain_opt sd_opt;
    int i, j, k, l;
    int distance;
    float distance_norm;
    int problem_size, temp_index;
    vector<double> temp_row;
    vector<pair<record, double> > unused;
    double* solution;
    unordered_map<ClientRegion, vector<pair<record, float> >, 
	ClientRegionHash, ClientRegionEqual > new_rules;
    vector<pair<record, float> > client_rules;
    MSKenv_t env;
    MSKsolstae solsta;
    MSKrescodee r;
    MSKtask_t task;
    MSKrescodee trmcode;
    double temp, S_n, P_other, P_i, lambda, proportion, epsilon, diff;
    double *result;
    double update_prob;
    unordered_map <string, double> totals;
    unordered_map <string, double>::iterator totals_it;
    double total_traffic;
  }

  // Get optimization parameters
  twait { this->get_opt_data(mkevent(sd_opt)); }

  // Get global data
  twait { this->get_traffic_totals(sd_opt, 
   false, mkevent(totals, total_traffic)); }  

  // Find my proportion
  twait{ this->get_my_totals(10, mkevent(unused, temp)); }
  if (debug) cout << "My total: " << temp << " Other total " << total_traffic
    << "\n";
  S_n = temp / (total_traffic + temp);
  if (debug) cout << "Using S_n " << S_n << "\n";

  S_n = 1.0;
  // Get client request data
  props = this->get_client_props(10);
  it = props.begin();
  
  if (debug) cout << "Calculating optimal policy for " << 
    this->storage.fqdn << "\n";
  num_clients = props.size();
  num_servers = this->storage.records.size();
  problem_size = num_clients * num_servers;

  // Make sure we have enough records in opt

  if (debug) {
    cout << sd_opt.records.size();
    cout << this->storage.records.size();

    cout << "Number of clients: " << num_clients;
    cout << " Number of servers: " << num_servers;
  }

  r = MSK_makeenv(&env, NULL, NULL, NULL, NULL);
  r = MSK_initenv(env);
  r = MSK_maketask(env, num_clients, problem_size, &task);
  MSK_linkfiletotaskstream(task,MSK_STREAM_LOG,"debug.txt",0);
  MSK_putintparam(task, MSK_IPAR_INTPNT_NUM_THREADS, 4);
  r = MSK_append(task, MSK_ACC_CON, num_clients);
  r = MSK_append(task, MSK_ACC_VAR, problem_size);
  r = MSK_putmaxnumvar(task, problem_size);
  r = MSK_putmaxnumcon(task, num_clients);
  r = MSK_putmaxnumanz(task, problem_size);
  
  for (i=0; i < num_servers; i++) {
    for (j=0; j < num_clients; j++) {
      for (k=0; k < num_clients; k++) {
        memcpy(&lambda, &sd_opt.records[i].lambda, sizeof(double));
        temp = S_n * S_n * props[j].second * props[k].second * lambda;
        if (j >= k) {
          r = MSK_putqobjij(task, j * num_servers + i, 
                                  k * num_servers + i, temp);
          if (r != MSK_RES_OK) { fatal << "Call returned bad" << r; }
        }
        // row: j * num_servers + i // col: k * num_servers + i
      }
    }
  }

  // Add "sum to 1" constraints
  for (i = 0; i < num_clients; i++) {
    for (j = 0; j < num_servers; j++) {
      temp_index = i;
      temp = 1.0;
      r = MSK_putavec(task, MSK_ACC_VAR, i * num_servers + j, 1, &temp_index,
        &temp );
    }
    r = MSK_putbound(task, MSK_ACC_CON, i, MSK_BK_FX, 1.0, 1.0);
  }


  // Add constraints that all x[] must be positive (may be default)
  for (i = 0; i < problem_size; i++) {
    MSK_putbound(task, MSK_ACC_VAR, i, MSK_BK_RA, 0.0, +MSK_INFINITY);
  }

  // Add linear coefficients
  for (i = 0; i < num_clients; i++) {
 
    for (j = 0; j < num_servers; j++) {
      twait{get_client_region(
        this->storage.records[j].content.cstr(), mkevent(other));}
        cr = props[i].first;
      distance = ((cr.lat - other.lat) * (cr.lat - other.lat)) +
        ((cr.lon - other.lon) * (cr.lon - other.lon));
      distance_norm = (float) distance / (350 * 350);
      // Add dist(c, i) * alpha_c * S_n
      temp = distance_norm * props[i].second * S_n;
      
      totals_it = totals.find(this->storage.records[j].content.cstr());
      if (totals_it == totals.end()) {
        if (debug) cout << "No record data for " << 
         this->storage.records[j].content.cstr();
        exit(1);
      }

      P_other = totals_it->second / total_traffic;
      // Allow some FP errors
      if ((total_traffic > -.1) && (total_traffic < .1)) P_other = 0.0;

      // Add S_n * 2 * alpha_c * (P_other - w) * lambda
      memcpy(&proportion, &sd_opt.records[j].proportion, sizeof(double));
      memcpy(&lambda, &sd_opt.records[j].lambda, sizeof(double));

      if (debug) cout << "Lambda: " << lambda << " P_other: " << P_other
        << " Proportion: " << proportion << endl;
      temp+= S_n * 2  * props[i].second * (P_other - proportion) * lambda;
      MSK_putcj(task, i * num_servers + j, temp);
    }
  }

  r = MSK_putobjsense(task, MSK_OBJECTIVE_SENSE_MINIMIZE);

  r = MSK_optimizetrm(task, &trmcode);

  if (debug) {
    cout << "After optimization";
    if (trmcode == MSK_RES_OK) cout << "OK\n";
    else { cout << trmcode; }
  }

  MSK_solutionsummary (task, MSK_STREAM_ERR);
  MSK_getsolutionstatus (task, MSK_SOL_ITR, NULL, &solsta);
  if (solsta == MSK_SOL_STA_OPTIMAL || solsta == MSK_SOL_STA_NEAR_OPTIMAL) {
    if (debug) cout << "At optimal point\n";
  }
  else {
    cout << "NOT Optimal for :" << sd_opt.fqdn.cstr() << endl;
    fflush(stdout);
    if (debug) printf("%i\n", solsta);
    TRIGGER(cb);
    return;
  }

  result = new double[problem_size];
  MSK_getsolutionslice(task, MSK_SOL_ITR, MSK_SOL_ITEM_XX, 0, problem_size,
    result);
  if (debug) {
    for (i = 0; i < problem_size; i++) {
      cout << result[i];
      cout << endl;
    }
  }
  cout << time(NULL);
  cout << ": Policy update ";
  // Populate routing rules based on the new data
  for (i = 0; i < num_clients; i++) {
    client_rules = vector<pair<record, float> > ();
    cout << "(" << props[i].first.lat << "," << props[i].first.lon << "," << 
      props[i].second << "):";
    for (j = 0; j < num_servers; j++) {
      client_rules.push_back(pair<record, float> 
        (this->storage.records[j], result[i * num_servers + j]));
      cout << this->storage.records[j].content;
      cout << "--" << result[i * num_servers + j] << "---";
    }
    cout << "::";
    new_rules.insert(pair<ClientRegion, vector<pair<record, float> > > (
      props[i].first, client_rules));
  }
  cout << endl;
  fflush(stdout);
  this->rules = new_rules;

  // Store expected traffic given this new policy
  twait {this->update_expected_traffic(10, mkevent());}

  twait { this->get_opt_data(mkevent(sd_opt)); }

  update_prob = 1.0 / craq.number_of_nodes();

  if (((double) rand() / ((double) RAND_MAX + (double) 1)) > update_prob) {
    TRIGGER(cb);
    return;
  }

  // Update optimization paramters

  twait { this->get_traffic_totals(sd_opt, true, 
    mkevent(totals, total_traffic)); }

  // We can't do anything useful if there is no traffic right now
  if (total_traffic < 0.1) {
    TRIGGER(cb);
    return;
  }
  if (debug) cout << "Total traffic: " << total_traffic;

  for (int i = 0; i < num_servers; i++) {
    totals_it = totals.find(this->storage.records[i].content.cstr());
    P_i = totals_it->second / total_traffic;

    memcpy(&proportion, &sd_opt.records[i].proportion, sizeof(double));
    memcpy(&epsilon, &sd_opt.records[i].epsilon, sizeof(double));    
    diff = ((P_i - proportion) * (P_i - proportion)) - (epsilon * epsilon);

    if (debug) {
      cout << "True proportion was " << P_i << " while requested was " <<
        proportion << endl;
      cout << " diff^2: " << (diff * diff) << " exceeded epsilon^2: " << 
        (epsilon * epsilon) << "\n";
    }

    memcpy(&lambda, &sd_opt.records[i].lambda, sizeof(double));      

    if (debug) {
      cout << "Updating lambda_i for instance " << 
        this->storage.records[i].content.cstr() << " old value " <<
        lambda << "\n";
    }
    lambda = lambda + (((double) theta) / (epsilon * epsilon)) * (diff);
    if (lambda < 0.0) continue;
    if (debug) cout << "New value " << lambda << "\n";
	   
    memcpy(&sd_opt.records[i].lambda, &lambda, sizeof(double));
  }

  twait { this->set_opt_data(sd_opt, mkevent()); }

  TRIGGER(cb);
}

void client_debug(callback<void>::ref cb, CLOSURE);
tamed void client_debug(callback<void>::ref cb) {
  tvars {
    SubdomainInfo* sd;
    unsigned int next_update_interval;
    subdomain_cache_it sd_it;
  }
  TRIGGER(cb);
  next_update_interval = (rand() % update_interval) + 1;
  while (true) {
    if (debug) 
      cout << "Delaying optimization " << next_update_interval << " seconds\n";
    twait { delaycb(next_update_interval, 0, mkevent()); }
    sd_it = subdomain_cache.begin();
    if (debug) cout << "Running optimization\n\n";
    while (sd_it != subdomain_cache.end()) {
      sd = const_cast<SubdomainInfo*>(&*sd_it);
      if (debug) cout <<  sd->storage.fqdn.cstr();
      // Calculate optimal routes based on external traffic
      if (!closest_node) {
        twait{ sd->calculate_optimal_routes(mkevent()); }
      }
      sd_it++;
    }
    next_update_interval = (update_interval - next_update_interval) + 
                           (rand() % update_interval + 1);
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
    if (debug) {
      cout << "Adding region (" << totals_it->first.lat << ", ";
      cout << totals_it->first.lon << ") ";
      cout << "Total traffic for this region " << totals_it->second << "\n";
    }
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
    subdomain_cache_it sd_it;
  }
  to_find.storage.fqdn = str(fqdn.c_str());
  if (debug) {
    cout << "Cache request for " << fqdn << endl;
    fflush(stdout);
  }
  sd_it = subdomain_cache.find(to_find);
  
  // No data stored for this record
  if (sd_it == subdomain_cache.end()) {
    
    if (debug) cout << "Getting key";
    fflush(stdout);
    twait {craq.get_key(fqdn, mkevent(subdomain_data));}
    if (subdomain_data.len() < 20) {
      if (debug) cout << "CRAQ did not have data for this record\n";
      TRIGGER(cb, NULL);
      return;
    }

    if (debug) {
      cout << "Got value of size " << subdomain_data.len();
      cout << subdomain_data;
      fflush(stdout);
    }
    str2xdr(sd, subdomain_data);

    if (sd.fqdn.len() == 0) {
      TRIGGER(cb, NULL);
      return;
    }

    to_insert.storage = sd;
    to_insert.validated = time(NULL);
    subdomain_cache.insert(to_insert);
    if (debug) {
      cout << "Inserting record into cache from CRAQ";
      fflush(stdout);
    }
    TRIGGER(cb, 
      const_cast<SubdomainInfo*>(&*(subdomain_cache.find(to_insert))));
    return;
  }

  // If data stored, test if it's expired
  if (time(NULL) > (sd_it->validated + max_cache_period)) {
    twait {craq.get_key(fqdn, mkevent(subdomain_data));}
    str2xdr(sd, subdomain_data);
    if (sd.seq_number > sd_it->storage.seq_number) {
      to_insert.storage = sd;
      to_insert.validated = time(NULL);
      // Save request data from old entry
      to_insert.num_requests = sd_it->num_requests;
      subdomain_cache.erase(sd_it);
      subdomain_cache.insert(to_insert);
      if (debug) {
        cout << "Sequence number too low, updating record";
        cout << "New data length: " << subdomain_data.len();
        fflush(stdout);
      }

      TRIGGER(cb,
      const_cast<SubdomainInfo*>(&*(subdomain_cache.find(to_insert))));
      return;
    }
    else {
      const_cast<SubdomainInfo*>(&*sd_it)->validated = time(NULL);
    } 
    // TODO: deal with case where sequence number not updated but TTL's are
    // different
  }

  if (debug) {
    cout << "Answering for " << fqdn << " from cache.\n";
    fflush(stdout);
  }

  // Otherwise just return the existing subdomain
  TRIGGER(cb,
    const_cast<SubdomainInfo*>(&*(sd_it)));
}

tamed static void process(int fd) {
  tvars {
    strbuf resp;
    strbuf out;
    char buff[MAX_BUFF];
    int line_len;
    string type;
    string qname;
    string coralname;
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
      cout << time(NULL) << ": ";
      cout << str(resp).cstr() << " ";
      input.str(str(resp).cstr());
      input >> type;
      input >> qname;
      // Coral Hack :)
      if (qname.find("nyud.net")!=string::npos) {
        coralname = string(qname);
        qname = "nyud.net";
      }

      input >> qclass;
      input >> qtype;
      input >> id;
      input >> remote_ip;
      //out << id;
    
      twait {get_client_region(remote_ip, mkevent(cr));}
      cout << cr.lat << "," << cr.lon << endl;
      if (type == "AXFR") {
        out << strbuf("%s", last.c_str());
      }
      else if (qname == "IN" || qname == "ANY" || qname == "SOA" || qname == "CNAME") {
        out << strbuf("%s", last.c_str());
      } 
      else {
        twait {get_from_cache(qname, mkevent(sd));}
        if (sd != NULL) {
          if (coralname.size() > 0) qname = coralname;
	  log_client_request(&cr, sd);
	  if (debug) print_request_logs(sd);

	  // Get A Records according to optimal policy
	  if (qtype == "A" || qtype == "ANY") {
	    twait {get_a_records(sd, &cr, mkevent(recs));}
	    vector<record>::iterator it = recs.begin();
	    while (it != recs.end()) {
	       out << strbuf("DATA\t%s\tIN\t%s\t%i\t-1\t%s\n",
	      qname.c_str(), it->type.cstr(),
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
		qname.c_str(), rec.type.cstr(), 
		rec.ttl, rec.content.cstr());
	     }
	  }
	  last = string(str(out).cstr());
        }
      }
      cout << time(NULL) << ": ";
      cout << str(out).cstr();
      out << "END\n";    
    }
    twait{ tame:: waitwrite (fd, mkevent()); }
    if ( out.tosuio()->output(fd) < 0) {
      close(fd);
      if (debug) cout << "Error writing to socket, closing";
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
      if (debug) cout << "Waiting for a connection...\n";
      twait (G, which);

      switch (which) {
        case READ:
          t = sizeof(remote);
          if ((fd = accept(s, reinterpret_cast<sockaddr *>(&remote), &t)) 
             == -1) {
	    perror("accept");
	    exit(1);
          }
          if (debug) cout << "Connected.\n";
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
    strbuf mosek_buf;
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
  ct.add("MosekKeyFile", &mosek_file);
  ct.insert(New conftab_bool ("ShowDebug", &debug, true));
  ct.insert(New conftab_bool ("ClosestNode", &closest_node, false));
  ct.insert(New conftab_int<unsigned int>
      ("MaxCacheSeconds", &max_cache_period, 0, 300, 10));
  ct.insert(New conftab_int<unsigned int>
      ("Theta", &theta, 1, 100000, 1));

  ct.insert(New conftab_int<unsigned int>
      ("UpdateInterval", &update_interval, 0, 10000, 500));
 ct.insert(New conftab_int<unsigned int>
      ("GeoRounding", &geo_rounding, 0, 100, 10));

  line = 0;
  while (pa.getline(&av, &line)) {
    if (!ct.match(av, str("donar.conf"), line, &errors)) {
      warn << config << ":" << line << ": unknown directive\n";
    }
  }
  // Open log file
  logfile.open("/var/log/donar", ios::out | ios::app);
  logfile << "DONAR LOG\n";

/* NOT WORKING RIGHT NOW
  // Set mosek env variable
  mosek_buf << "MOSEKLM_LICENSE_FILE=";
  mosek_buf << mosek_file;
  putenv((char*) str(mosek_buf).cstr());
*/

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
  logfile << "Using IP Address: " << craq.my_ip_addr.c_str();
  inet_aton(craq.my_ip_addr.c_str(), &addr);
  my_ip_addr = (unsigned int) addr.s_addr;

  if (init_success) {
    if (debug) cout << "Connection established.\n";
  }
  else {
    if (debug) cout << "Connection establishemnt failed.\n";
    exit(-1);
  }
 
  listen_loop();
}

int main (int argc, char* argv[]) {
  signal(SIGPIPE, SIG_IGN);
  main2(argc, argv);
  amain();
}
