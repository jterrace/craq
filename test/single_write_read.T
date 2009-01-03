#include <map>
#include <vector>
#include "sha.h"
#include "tame.h"
#include "tame_rpcserver.h"
#include "parseopt.h"
#include "arpc.h"
#include "async.h"
#include "../craq_rpc.h"
#include "../Node.h"
#include "../ID_Value.h"
#include <tclap/CmdLine.h>
#include "../zoo_craq.h"

using namespace CryptoPP;
using namespace std;

vector<string> data_centers;
string key_name;
int key_size;
int chain_size;

void assert_msg(bool val, const char * msg) {
	warn << msg;
	if(!val) {
		fatal << " FAIL!\n";
	}
	warn << " SUCCESS!\n";
}

ID_Value get_sha1(string msg)
{
	byte buffer[SHA::DIGESTSIZE];
	SHA().CalculateDigest(buffer, (byte *)msg.c_str(), msg.length());
	ID_Value ret(buffer);
 	return ret;
}

tamed static void
connect_to_manager(str h, int port) {
	tvars {
		int fd;
		ptr<axprt_stream> x;
		ptr<aclnt> cli;
		clnt_stat e;
		u_int ver, i, j;
		Node me, ret;
		rpc_node me_rpc;
		rpc_node_list cur_list;
		rpc_memb_delta delt;
		ID_Value id;
		string msg;
		map<ID_Value, Node> ring;
		map<ID_Value, Node>::iterator it;
		head_write_arg wrt_arg;
		rpc_hash rd_arg;
		bool wrt_ret;
		blob rd_ret;
		bool eqs;
		bool rc;
		vector<string> * node_list;
		int zoo_node_count;
		string find;
		string search;
		string * found;
		add_chain_arg arg;
		add_chain_ret add_ret;
		ostringstream ss;
	}

	srand ( time(NULL) );

	ss << h << ":" << port;
	twait { czoo_init( ss.str().c_str(), mkevent(rc)); }
	assert_msg(rc, "Connecting to manager...");

	twait { czoo_get_children("/nodes/" + data_centers[0], NULL, mkevent(node_list)); }
	assert_msg(node_list != NULL, "Retrieving initial node list...");

	zoo_node_count = (*node_list).size();
	i = rand() % zoo_node_count;
	find = (*node_list)[i];
	search = "/nodes/" + data_centers[0] + "/" + find;
	twait { czoo_get(search, mkevent(found)); }
	assert_msg(found != NULL, "Retrieving node information...");

	ret.set_from_string(*found);
	delete found;
	delete node_list;

	twait { tcpconnect (ret.getIp().c_str(), ret.getPort(), mkevent(fd)); }
	assert_msg(fd>=0, "Connecting to a random node...");

	x = axprt_stream::alloc(fd);
	cli = aclnt::alloc(x, chain_node_1);

	arg.id = get_sha1(key_name).get_rpc_id();
	arg.chain_size = chain_size;
	arg.data_centers.setsize(data_centers.size());
	for(i=0; i<data_centers.size(); i++) {
		arg.data_centers[i] = data_centers[i].c_str();
	}

	twait { cli->call(ADD_CHAIN, &arg, &add_ret, mkevent(e)); }
	assert_msg(!e && (add_ret != ADD_CHAIN_FAILURE), "Adding Chain...");
	if(add_ret == ADD_CHAIN_EXISTS) {
		warn << "Warning: chain already exists!\n";
	}


	/*msg = "Hello Cruel World!!";
	srand(time(NULL));
	for(i=0; i<10; i++) {
		msg += (char)(rand() % 26 + 65);
	}
	id = get_sha1(msg);
	warn << "Message: " << msg.c_str() << "\n";
	warn << "Id: " << id.toString().c_str() << "\n";

	it = ring.lower_bound(id);
	if(it == ring.end())
		it = ring.begin();

	twait { tcpconnect (it->second.getIp().c_str(), it->second.getPort(), mkevent(fd)); }
	assert_msg(fd>=0, "Connecting to head node...");

	x = axprt_stream::alloc(fd);
	cli = aclnt::alloc(x, chain_node_1);

	wrt_arg.id = id.get_rpc_id();
	wrt_arg.data = msg.c_str();
	twait { cli->call(HEAD_WRITE, &wrt_arg, &wrt_ret, mkevent(e)); }
	assert_msg(!e && wrt_ret, "Writing value...");

	for(j=0; j<CHAIN_SIZE; j++) {

		twait { tcpconnect (it->second.getIp().c_str(), it->second.getPort(), mkevent(fd)); }
		assert_msg(fd>=0, "Connecting to read node...");

		x = axprt_stream::alloc(fd);
		cli = aclnt::alloc(x, chain_node_1);

		rd_arg = id.get_rpc_id();
		twait { cli->call(TAIL_READ, &rd_arg, &rd_ret, mkevent(e)); }
		assert_msg(!e && rd_ret.size()==msg.size(), "Reading value...");
		eqs = true;
		for(i=0; i<rd_ret.size(); i++) {
			if( (char)rd_ret[i] != msg[i] ) {
				eqs = false;
			}
		}
		assert_msg(eqs, "Checking read value equals write value...");

		it++;
		if( it==ring.end() )
			it = ring.begin();

	}*/

	warn << "All tests passed!\n";
	exit(0);

}

tamed static
void main2(int argc, char **argv) {
	tvars {
		string manager_hostname;
		int manager_port;
	}

	try
	{
		TCLAP::CmdLine cmd("single_write_read creates a chain, writes a key, and then reads it", ' ', "0.1");
		TCLAP::ValueArg<string> managerHost("o", "manager_host", "Manager hostname", true, "", "string", cmd);
		TCLAP::ValueArg<int> managerPort("r", "manager_port", "Manager port number", true, 0, "int", cmd);
		TCLAP::MultiArg<string> dataCenters("d", "data_centers", "Data centers to spread the key to", true, "string", cmd );
		TCLAP::ValueArg<string> keyName("k", "key_name", "Identifier for key (will be converted with SHA256)", true, "", "string", cmd);
		TCLAP::ValueArg<int> keySize("s", "key_size", "Size of key data to generate", true, 0, "string", cmd);
		TCLAP::ValueArg<int> chainSize("c", "chain_size", "Size of the chains within data centers", true, 0, "int", cmd);
		cmd.parse(argc, argv);

		manager_hostname = managerHost.getValue();
		manager_port = managerPort.getValue();
		data_centers = dataCenters.getValue();
		key_name = keyName.getValue();
		key_size = keySize.getValue();
		chain_size = chainSize.getValue();

		connect_to_manager(manager_hostname.c_str(), manager_port);
	}
	catch (TCLAP::ArgException &e)  // catch any exceptions
	{
		fatal << "error: " << e.error().c_str() << " for arg " << e.argId().c_str() << "\n";
	}

}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain ();
}
