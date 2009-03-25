#include <string>
#include "tame.h"
#include "tame_rpcserver.h"
#include "parseopt.h"
#include "tame_io.h"
#include "arpc.h"
#include "async.h"
#include "../craq_rpc.h"
#include "../Node.h"
#include "../ID_Value.h"
#include <tclap/CmdLine.h>

using namespace std;

typedef enum { READ, WRITE } ev_t;
const unsigned int MAX_BUF = 2000;

tamed static void process(int fd)
{

	tvars {
		strbuf resp;
		int rc;
		int line_len;
		string line;
		char buff[MAX_BUF];
	}

	buff[2] = '\0';

	while(true) {
		twait { tame::waitread (fd, mkevent()); }
		if( (rc = resp.tosuio()->input(fd)) < 0 && errno != EAGAIN) {
			warn << "failed\n";
		}
		if (rc == 0) {
			warn << "done\n";
			break;
		}

		line_len = resp.tosuio()->linelen();
		if(line_len > 0) {
			if(line_len < MAX_BUF) {
				warn << "len " << line_len << "\n";
				resp.tosuio()->copyout(&buff, line_len);
				warn << buff[0] << "\n";
				//line = buff;
				//warn << line.c_str() << "\n";
			}
			resp.tosuio()->rembytes(line_len);
		}
	}

	resp.tosuio()->output(1);

}

static int listen_on(int port)
{
	int fd = inetsocket(SOCK_STREAM, port);
	if (fd >= 0) {
		close_on_exec(fd);
		listen(fd, 20);
	} else {
		return -1;
	}
	return fd;
}

tamed static void listen_loop(int lport) {

	tvars {
		int lsock, rc, nfd;
		rendezvous_t<ev_t> G (__FILE__, __LINE__);
	    ev_t which;
	    sockaddr_in sin;
	    socklen_t sinlen (sizeof (sin));
	}

	lsock = listen_on(lport);
	if(lsock <= 0) {
		fatal << "Listen failed on port '" << lport << "'. Dying.\n";
	}

	while (true) {
		tame::waitread (lsock, mkevent (G, READ));

		twait (G, which);

		switch (which) {
			case READ:
				bzero (&sin, sinlen);
				if ((nfd = accept (lsock, reinterpret_cast<sockaddr *> (&sin), &sinlen)) >= 0) {
					warn << "Accepting connection from '" << inet_ntoa(sin.sin_addr) << "'.\n";
					process(nfd);
				} else {
					warn << "Accept failed.\n";
				}
				break;
			default:
				fatal << "Got unknown message. Dying.\n";
		}
	}

}

tamed static void main2(int argc, char **argv) {
	tvars {
		int listen_port;
		str manager_hostname;
		str type;
		int manager_port;
		str user_ip;
	}

	try
	{
		TCLAP::CmdLine cmd("client starts a CRAQ client which listens for commands on a socket and translates them to CRAQ RPC format", ' ', "0.2");
		TCLAP::ValueArg<string> managerHost("o", "manager_host", "Manager hostname", true, "", "string", cmd);
		TCLAP::ValueArg<int> managerPort("r", "manager_port", "Manager port number", true, 0, "int", cmd);
		TCLAP::ValueArg<int> listenPort("p", "listen_port", "Port to listen for connections", true, 0, "int", cmd);
		TCLAP::ValueArg<string> ipAddress("i", "ip_address", "IP Address to listen for connections", false, "", "string", cmd);
		cmd.parse(argc, argv);

		manager_hostname = managerHost.getValue().c_str();
		manager_port = managerPort.getValue();
		listen_port = listenPort.getValue();
		user_ip = ipAddress.getValue().c_str();

		listen_loop(listen_port);

		//start_rpc_srv(listen_port);
		//register_to_manager(listen_port, manager_hostname, manager_port);
	}
	catch (TCLAP::ArgException &e)  // catch any exceptions
	{
		fatal << "Error: " << e.error().c_str() << " for arg " << e.argId().c_str() << "\n";
	}
}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain();
}
