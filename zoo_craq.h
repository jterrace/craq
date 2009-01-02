#ifndef ZOO_CRAQ_H_
#define ZOO_CRAQ_H_

#include <string>
#include <map>
#include <vector>
#include "zookeeper.h"
#include "tame.h"
#include "tame_rpcserver.h"
#include "parseopt.h"
#include "arpc.h"
#include "async.h"
#include "Node.h"

using namespace std;

extern string my_zoo_id;
extern int zoo_node_count;
extern map<string, Node> zoo_nodes;
extern zhandle_t * zh;
extern map<int, timecb_t *> read_timeouts;
extern map<int, timecb_t *> write_timeouts;

extern void czoo_watcher(zhandle_t *zzh, int type, int state, const char *path,
							void* context);
extern void czoo_interest();
extern void czoo__interest_timer();
extern void czoo_fdcb_read_timeout(int fd);
extern void czoo_fdcb_read(int fd);
extern void czoo_fdcb_write_timeout(int fd);
extern void czoo_fdcb_write(int fd);

extern ptr<callback<void, bool> > init_cb;
extern void czoo_init(const char * host, ptr<callback<void, bool> > cb, CLOSURE);

extern map<int, ptr<callback<void, int> > > czoo_create_cbs;
extern void czoo_create( string path, string value, const struct ACL_vector *acl,
							int flags, ptr<callback<void, int> > cb, CLOSURE );
extern void czoo_created(int rc, const char *name, const void *data);

typedef void (*czoo_get_children_watcher)(string, ptr<closure_t>);
extern map<int, ptr<callback<void, vector<string> *> > > czoo_get_children_cbs;
extern map<string, czoo_get_children_watcher> czoo_get_children_watches;
extern void czoo_got_children(int rc, const struct String_vector *strings, const void *data);
extern void czoo_get_children(string path, czoo_get_children_watcher func,
								ptr<callback<void, vector<string> *> > cb, CLOSURE);

extern map<int, ptr<callback<void, string *> > > czoo_get_cbs;
extern void czoo_got(int rc, const char *value, int value_len, const struct Stat *stat, const void *data);
extern void czoo_get(string path, ptr<callback<void, string *> > cb, CLOSURE);

#endif /* ZOO_CRAQ_H_ */
