// Stores aggregate traffic for each record from each instance
struct traffic_entry {
  unsigned int server_id;
  unsigned int update_time;
  uint64_t traffic_vol;
};

struct rec_opt_info {
  string content<>;
  uint64_t proportion;
  uint64_t epsilon;
  uint64_t cap;
  uint64_t lambda; // in optimization
  traffic_entry entries<>;
};

// Stores optimization info for subdomain, key in craq is [fqdn-opt]
struct subdomain_opt {
  string fqdn<>;
  hyper seq_number;
  unsigned int current_server_id;
  bool in_progress;
  rec_opt_info records<>;
};

enum attr_type {
  DONAR_TTL = 1,
  LATITUDE = 2,
  LONGITUDE = 3,
  SPLIT_PROPORTION = 4,
  SPLIT_EPSILON = 5,
  BANDWIDTH_CAP = 6
};

struct record_attr {
  attr_type type;
  opaque data<>;
};

struct record {
  string type<>;
  string content<>;
  int ttl;
  record_attr attrs<>;
};

struct subdomain {
  string fqdn<>;
  hyper seq_number;
  record records<>;
  opaque account_hash[20];
};

struct account {
  opaque key_hash[20]; 
  hyper seq_num;
  string suffix<>;
  hyper last_update;
  int soa_ttl;
  string contact_email<>;
  subdomain subdomains<>;
};
