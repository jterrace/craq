/* Basic type definitions
 * =============================== */
typedef string rpc_string<255>;
typedef opaque rpc_hash<20>;
typedef opaque blob<>;
/* ====================== */

/* Manager RPC types and functions
 * =============================== */
enum event_type {
	EVENT_ADD = 0,
	EVENT_DEL = 1
};

struct rpc_node {
	rpc_string ip;
	unsigned port;
	rpc_hash id;
};

struct rpc_node_list {
	unsigned ver;
	rpc_node nodes<>;
};

struct rpc_memb_change {
	event_type event;
	rpc_hash id;
	unsigned ver;
};

struct rpc_memb_delta {
	rpc_memb_change changes<>;
};

program RPC_MANAGER {
	version	RPC_MANAGER_VERSION {
		void REGISTER(rpc_node) = 0;
		rpc_node_list GET_NODE_LIST(void) = 1;
		unsigned GET_NODE_LIST_VERSION(void) = 2;
		rpc_memb_delta GET_NODE_LIST_DELTA(unsigned) = 3;
		void REPORT_BAD(rpc_node) = 4;
	} = 1;
} = 31313;
/* ====================== */

/* Chain Node RPC types and functions
 * =============================== */
 
 struct head_write_arg {
 	rpc_hash id;
 	blob data;
 };
 
 struct propagate_arg {
 	rpc_hash id;
 	unsigned ver;
 	blob data;
 };
 
 struct ack_arg {
 	rpc_hash id;
 	unsigned ver;
 };
 
 struct query_obj_ver_ret {
 	int hist;
 	int pend;
 };
 
 program CHAIN_NODE {
 	version CHAIN_NODE_VERSION {
 		//External functions
 		blob TAIL_READ(rpc_hash) = 0;
 		bool HEAD_WRITE(head_write_arg) = 1;
 		
 		//Internal functions
 		bool PROPAGATE(propagate_arg) = 2;
 		query_obj_ver_ret QUERY_OBJ_VER(rpc_hash) = 3;
 		void ACK(ack_arg) = 4;
 		void POKE_NODE_LIST_VER(unsigned) = 5; 
 		void BACK_PROPAGATE(propagate_arg) = 6;
 	} = 1;
 } = 21212;
/* ====================== */
