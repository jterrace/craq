#include <tr1/unordered_map>
#include <tr1/unordered_set>
#include <iostream>
#include "tame.h"
#include <string>
#include <utility>
#include "donar_rpc.h"
#include <vector>

using namespace std::tr1;
using std::vector;
using std::pair;

// Storage class for recordkeeping the number of requests
// from a given client region. The region is defined in terms
// of a lat/lon pair. The decision of how to map clients into
// a client region is not handled in this class.
class ClientRegion {
  public:
    int lat, lon;
    ClientRegion();
    ClientRegion(int lat, int lon);
    bool operator==(const ClientRegion &other);
    bool operator>(const ClientRegion &other);    
    bool operator<(const ClientRegion &other);
    int get_hash();
};

class ClientRegionEqual {
  public:
    size_t operator()(const ClientRegion &cr1, const ClientRegion &cr2) const;
};

class ClientRegionHash {
  public:
    size_t operator()(const ClientRegion &cr) const;
};

typedef callback<void, ClientRegion>::ref cb_cr;

// Local information stored per subdomain
class SubdomainInfo {
  public:
    time_t validated; // How stale
    bool rules_populated; // Do we have rules yet from optimization
    subdomain storage; // CRAQ storage struct

    // For each client region, maps a time value to a request volume.
    unordered_map<ClientRegion, unordered_map<size_t, unsigned int>*, 
      ClientRegionHash, ClientRegionEqual> num_requests;

    // Returns the request proportions from each client in last
    // N minutes.
    vector<pair<ClientRegion, float> > get_client_props(int minutes);

    // Populate my routing rules
    void calculate_optimal_routes(callback<void>::ref cb, CLOSURE);

    // For each record, for each client region, store the probability
    // of routing to that client region.
    unordered_map<ClientRegion, vector<pair<record, float> >, ClientRegionHash,
      ClientRegionEqual > rules;

    void set_opt_data(struct subdomain_opt sd_opt, 
      callback<void>::ref cb, CLOSURE);

    void get_opt_data(callback<void, subdomain_opt>::ref cb, CLOSURE);

    void update_expected_traffic(int, callback<void>::ref cb, CLOSURE);

    void get_traffic_totals(struct subdomain_opt sd_opt, bool include_me,
      callback<void, unordered_map<std::string, unsigned int >, unsigned int >::ref cb, CLOSURE);
};

typedef unordered_map<ClientRegion, unordered_map<size_t, unsigned int>*, 
      ClientRegionHash, ClientRegionEqual>::iterator client_requests_iter;

typedef unordered_map<size_t, unsigned int>::iterator num_request_iter;

typedef callback<void, unordered_map<std::string, unsigned int>, unsigned int>::ref cb_totals;

typedef unordered_map<ClientRegion, vector<pair<record, float> >, ClientRegionHash, ClientRegionEqual >::iterator rules_iter;


typedef vector<pair<record, float> >::iterator client_rule_iter;

class SubdomainEqual {
  public:
    size_t operator()(const SubdomainInfo &s1, const SubdomainInfo &s2) const;
};

class SubdomainHash {
  public:
    size_t operator()(const SubdomainInfo &s) const;
};

typedef callback<void, SubdomainInfo*>::ref cb_sub;
