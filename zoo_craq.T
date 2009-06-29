#include "zoo_craq.TH"

ptr<callback<void, bool> > init_cb;
string my_zoo_id;
int zoo_node_count = 0;
bool zoo_connected = false;
map<string, Node> zoo_nodes;
zhandle_t * zh;
map<int, timecb_t *> read_timeouts;
map<int, timecb_t *> write_timeouts;

map<int, ptr<callback<void, int> > > czoo_create_cbs;
map<int, ptr<callback<void, vector<string> *> > > czoo_get_children_cbs;
map<string, czoo_get_children_watcher> czoo_get_children_watches;
map<int, ptr<callback<void, string *> > > czoo_get_cbs;

void czoo_watcher(zhandle_t *zzh, int type, int state, const char *path, void* context) {
    if (type == ZOO_SESSION_EVENT) {
        if (state == ZOO_CONNECTED_STATE) {
        	//warn << "Connected to ZooKeeper.\n";
        	TRIGGER( init_cb, true );
        } else if (state == ZOO_AUTH_FAILED_STATE) {
            fatal << "ZooKeeper Authentication failed.\n";
        } else if (state == ZOO_EXPIRED_SESSION_STATE) {
            fatal << "ZooKeeper session expired.\n";
        } else if (state == ZOO_CONNECTING_STATE ) {
            warn << "Connecting to ZooKeeper...\n";
        } else if (state == ZOO_ASSOCIATING_STATE) {
			warn << "Associating ZooKeeper connection...\n";
        }
    } else if( type == ZOO_CREATED_EVENT ) {

    } else if( type == ZOO_DELETED_EVENT ) {

    } else if( type == ZOO_CHANGED_EVENT ) {

    } else if( type == ZOO_CHILD_EVENT ) {
    	string the_path = path;
    	map<string, czoo_get_children_watcher>::iterator it = czoo_get_children_watches.find(the_path);
    	if(it != czoo_get_children_watches.end()) {
    		(it->second)(the_path, NULL);
    	}
    } else if( type == ZOO_NOTWATCHING_EVENT ) {

    }
}

void czoo_fdcb_read_timeout(int fd) {
	//warn << "read timeout " << fd << "\n";
	map<int, timecb_t *>::iterator it = read_timeouts.find(fd);
	if( it != read_timeouts.end() ) {
		read_timeouts.erase(it);
	}
	//fdcb(fd, selread, 0);
	int events = 0;
	//events |= ZOOKEEPER_READ;
	zookeeper_process(zh, events);
	czoo_interest();
}

void czoo_fdcb_read(int fd) {
	//warn << "got read for fd: " << fd << "\n";
	map<int, timecb_t *>::iterator it = read_timeouts.find(fd);
	if( it != read_timeouts.end() ) {
		timecb_remove(it->second);
		read_timeouts.erase(it);
	}
	int events = 0;
	events |= ZOOKEEPER_READ;
	zookeeper_process(zh, events);
	czoo_interest();
}

void czoo_fdcb_write_timeout(int fd) {
	//warn << "write timeout " << fd << "\n";
	map<int, timecb_t *>::iterator it = write_timeouts.find(fd);
	if( it != write_timeouts.end() ) {
		write_timeouts.erase(it);
	}
	//fdcb(fd, selwrite, 0);
	int events = 0;
	//events |= ZOOKEEPER_WRITE;
	zookeeper_process(zh, events);
	czoo_interest();
}

void czoo_fdcb_write(int fd) {
	//warn << "got write for fd: " << fd << "\n";
	map<int, timecb_t *>::iterator it = write_timeouts.find(fd);
	if( it != write_timeouts.end() ) {
		timecb_remove(it->second);
		write_timeouts.erase(it);
	}
	int events = 0;
	events |= ZOOKEEPER_WRITE;
	zookeeper_process(zh, events);
	czoo_interest();
}

void czoo_interest() {
	int fd;
	int interest;
	timeval tv;
	int ret = zookeeper_interest(zh, &fd, &interest, &tv);
	if(ret != ZOK) {
                if (ret == ZCONNECTIONLOSS)
                  fatal << "Lost connection to zookeeper";
		fatal << "Bad return from interest!\n";
	}
	if (fd != -1) {
		if (interest & ZOOKEEPER_READ) {
			//warn << "interest read fd: " << fd << "\n";
			timecb_t * timeout = delaycb(tv.tv_sec, tv.tv_usec * 1000, wrap(czoo_fdcb_read_timeout, fd));
			map<int, timecb_t *>::iterator it = read_timeouts.find(fd);
			if( it != read_timeouts.end() ) {
				timecb_remove(it->second);
				read_timeouts.erase(it);
			}
			read_timeouts[fd] = timeout;
			fdcb(fd, selread, wrap(czoo_fdcb_read, fd));
		} else {
			//warn << "disabling read fd: " << fd << "\n";
			map<int, timecb_t *>::iterator it = read_timeouts.find(fd);
			if( it != read_timeouts.end() ) {
				timecb_remove(it->second);
				read_timeouts.erase(it);
			}
			fdcb(fd, selread, 0);
		}

		if (interest & ZOOKEEPER_WRITE) {
			//warn << "interest write fd: " << fd << "\n";
			timecb_t * timeout = delaycb(tv.tv_sec, tv.tv_usec * 1000, wrap(czoo_fdcb_write_timeout, fd));
			map<int, timecb_t *>::iterator it = write_timeouts.find(fd);
			if( it != write_timeouts.end() ) {
				timecb_remove(it->second);
				write_timeouts.erase(it);
			}
			write_timeouts[fd] = timeout;
			fdcb(fd, selwrite, wrap(czoo_fdcb_write, fd));
		} else {
			//warn << "disabling write fd: " << fd << "\n";
			map<int, timecb_t *>::iterator it = write_timeouts.find(fd);
			if( it != write_timeouts.end() ) {
				timecb_remove(it->second);
				write_timeouts.erase(it);
			}
			fdcb(fd, selwrite, 0);
		}
	} else {
		fatal << "got 0 fd\n";
		fd = 0;
	}
}

void czoo_interest_timer() {
	czoo_interest();
	delaycb(0, 1000 * 1000, wrap(czoo_interest_timer));
}

tamed void
czoo_init(const char * host, ptr<callback<void, bool> > cb, ZooLogLevel log_level) {
	init_cb = cb;
	zoo_set_debug_level(log_level);
	zh = zookeeper_init(host, &czoo_watcher, 1000, 0, 0, 0);
	if(!zh) {
		TRIGGER( cb, false );
	}
        zoo_connected = true;
	czoo_interest_timer();
}

void czoo_created(int rc, const char *name, const void *data) {
	int * where = (int *)data;
	/*bool status = true;
    if ( !(rc==ZOK || rc==ZNODEEXISTS) ) {
        status = false;
    }*/
	//warn << "rc " << rc << "\n";
	//warn << "created " << (name==NULL ? "NULL" : name) << "\n";
    map<int, ptr<callback<void, int> > >::iterator it = czoo_create_cbs.find(*where);
    if(it != czoo_create_cbs.end()) {
    	TRIGGER( it->second, rc);
    	czoo_create_cbs.erase(it);
    }
    delete where;
}


tamed void
czoo_create( string path, string value, const struct ACL_vector *acl, int flags, ptr<callback<void, int> > cb ) {
    int * where = new int;
	if(czoo_create_cbs.size()==0) {
    	*where = 0;
    } else {
    	map<int, ptr<callback<void, int> > >::iterator it = czoo_create_cbs.end();
    	it--;
    	*where = it->first + 1;
    }
	czoo_create_cbs[*where] = cb;
	//warn << "path " << path.c_str() << "\n";
	//warn << "value " << value.c_str() << "\n";
	//warn << "len " << value.length() << "\n";
	//warn << "acl " << acl << "\n";
	//warn << "flags " << flags << "\n";

    int rc = zoo_acreate(zh, path.c_str(), value.c_str(), value.length(),
    		acl, flags, &czoo_created, where);
    if(rc) {
    	czoo_create_cbs.erase(*where);
    	TRIGGER( cb, rc );
    	delete where;
    }
}

void czoo_got_children(int rc, const struct String_vector *strings, const void *data) {
	int * where = (int *)data;
	map<int, ptr<callback<void, vector<string> *> > >::iterator it = czoo_get_children_cbs.find(*where);
	if(it != czoo_get_children_cbs.end()) {
		if (rc!=ZOK || !strings) {
			TRIGGER( it->second, NULL);
		} else {
			vector<string> * to_ret = new vector<string>(strings->count);
			for (int i=0; i < strings->count; i++) {
				(*to_ret)[i] = strings->data[i];
			}
			TRIGGER( it->second, to_ret);
		}
		czoo_get_children_cbs.erase(it);
	}
    delete where;
}

tamed void czoo_get_children(string path, czoo_get_children_watcher func,
								ptr<callback<void, vector<string> *> > cb) {
	int watch = 0;
	if(func != NULL) {
		watch = 1;
		czoo_get_children_watches[path] = func;
	}

    int * where = new int;
	if(czoo_get_children_cbs.size()==0) {
    	*where = 0;
    } else {
    	map<int, ptr<callback<void, vector<string> *> > >::iterator it = czoo_get_children_cbs.end();
    	it--;
    	*where = it->first + 1;
    }
	czoo_get_children_cbs[*where] = cb;

    int rc = zoo_aget_children(zh, path.c_str(), watch, &czoo_got_children, where);
    if(rc) {
    	czoo_get_children_cbs.erase(*where);
    	TRIGGER( cb, NULL );
    	delete where;
    }
}

void czoo_got(int rc, const char *value, int value_len, const struct Stat *stat, const void *data) {
	int * where = (int *)data;
	map<int, ptr<callback<void, string * > > >::iterator it = czoo_get_cbs.find(*where);
	if(it != czoo_get_cbs.end()) {
		if (rc!=ZOK) {
			TRIGGER( it->second, NULL);
		} else {
			string * to_ret = new string(value, value_len);
			TRIGGER( it->second, to_ret);
		}
		czoo_get_cbs.erase(it);
	}
    delete where;
}

tamed void czoo_get(string path, ptr<callback<void, string *> > cb) {

    int * where = new int;
	if(czoo_get_cbs.size()==0) {
    	*where = 0;
    } else {
    	map<int, ptr<callback<void, string *> > >::iterator it = czoo_get_cbs.end();
    	it--;
    	*where = it->first + 1;
    }
	czoo_get_cbs[*where] = cb;

    int rc = zoo_aget(zh, path.c_str(), 0, &czoo_got, where);
    if (rc) {
    	czoo_get_cbs.erase(*where);
    	TRIGGER( cb, NULL );
    	delete where;
    }
}

