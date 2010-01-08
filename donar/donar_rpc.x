enum attr_type {
  DONAR_TTL = 1,
  LATITUDE = 2,
  LONGITUDE = 3
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
