#include "tame.h"
#include "tame_io.h"
#include "arpc.h"
#include "async.h"
#include "tame_aio.h"

using namespace std;
using namespace tame;

const unsigned int MAX_BUF = 2000;

tamed static void main2(int argc, char **argv) {
	tvars {
		int fd;
		strbuf data;
		int rc;
		strbuf resp;
		int line_len;
		char buff[MAX_BUF];
	}
	twait { tcpconnect ("adam.cs.princeton.edu", 80, mkevent(fd)); }
	if (fd >= 0) {
		warn << "Connection succeeded!\n";
	} else {
		fatal << "Connection failed!\n";
	}

	data.cat("GET / HTTP/1.1\nHost:adam.cs.princeton.edu\n\n");
	while(data.tosuio()->resid()) {
		twait { tame::waitwrite(fd, mkevent()); }
		if(data.tosuio()->output(fd) < 0) {
			fatal << "error writing to socket\n";
		}
	}

	while(true) {
		twait { tame::waitread (fd, mkevent()); }
		if( (rc = resp.tosuio()->input(fd)) < 0 && errno != EAGAIN) {
			fatal << "error reading from socket\n";
		}
		line_len = resp.tosuio()->linelen();
		while(line_len > 0) {
			if(line_len < MAX_BUF) {
				resp.tosuio()->copyout(buff, line_len);
				buff[line_len] = '\0';
				warn << buff;
			} else {
				fatal << "exceeded buffer\n";
			}
			resp.tosuio()->rembytes(line_len);
			line_len = resp.tosuio()->linelen();
		}
	}
}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain();
}
