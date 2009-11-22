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
    subdomain storage; // CRAQ storage struct

    // For each client region, maps a time value to a request volume.
    unordered_map<ClientRegion, unordered_map<size_t, unsigned int>, 
      ClientRegionHash, ClientRegionEqual> num_requests;

    // For each record, for each client region, store the probability
    // of routing to that client region.
    vector<pair<record, unordered_map<ClientRegion*, float> > > rules;
};

typedef unordered_map<ClientRegion, unordered_map<size_t, unsigned int>, 
      ClientRegionHash, ClientRegionEqual>::iterator num_requests_iter;

class SubdomainEqual {
  public:
    size_t operator()(const SubdomainInfo &s1, const SubdomainInfo &s2) const;
};

class SubdomainHash {
  public:
    size_t operator()(const SubdomainInfo &s) const;
};

typedef callback<void, SubdomainInfo*>::ref cb_sub;

//void assure_in_cache(string fqdn, CLOSURE);
