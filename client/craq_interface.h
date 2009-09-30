using namespace std;

typedef callback<void, string>::ref cbstr;
typedef enum { READ, WRITE } ev_t;
typedef map<ID_Value, Node>::iterator ring_iter;

#define MAX_BUF = 2000

class craq_interface {
  public:
    craq_interface();
    ~craq_interface();
    void init(string zoo_list, CLOSURE);

    void set_key(string key, string val, cbstr);
    void get_key(string key, cbstr);

  private:
    void connect_to_manager(string node_list, cbv cb, CLOSURE);
    void populate_node_list(cbi cb, CLOSURE);

    bool zoo_connected;
    bool ring_init;
    map<ID_Value, Node> ring;
    string datacenter;
    struct chain_meta {
      unsigned int chain_size;
      vector<string> data_ceters;
    };
    map<ID_Value, chain_meta> chain_meta_list;
};
