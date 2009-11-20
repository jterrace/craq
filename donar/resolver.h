#include <tr1/unordered_map>
#include <tr1/unordered_set>

using namespace std::tr1;

// Storage class for recordkeeping the number of requests
// from a given client region. The region is defined in terms
// of a lat/lon pair. The decision of how to map clients into
// a client region is not handled in this class.
class ClientRegion {
  private:
    double lat;
    double lon;

  public:
    ClientRegion(double lat, double lon);
    bool operator==(const ClientRegion &other);
    bool operator>(const ClientRegion &other);    
    bool operator<(const ClientRegion &other);
    int get_hash();
};

// Local info stored per record
class RecordInfo {
  public:
    // Answer rule table, populated by optimization
    unordered_map<ClientRegion*, float> probs;
};

// Local information stored per subdomain
class SubdomainInfo {
  public:
    int seq_num;
    time_t validated; // How stale

    // Maps a given minute (key is the first second in that min.)
    // to the number of requests received.
    unordered_map<unsigned int, unsigned int> num_requests;

    unordered_set<RecordInfo> records;
};
