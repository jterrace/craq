#include "tame.h"
#include "tame_io.h"
#include "arpc.h"
#include "async.h"
#include "tame_aio.h"

using namespace std;
using namespace tame;

tamed static void main2(int argc, char **argv) {
	tvars {
		aiod * a;
		int rc;
		ptr<aiofh> fh;
		ptr<aiobuf> buf, b2;
		off_t pos;
		ssize_t blocksz, bufsz, writtensz;
		str s("Hello World\n");
		const char * cur(s.cstr());
		const char * end(s.cstr() + s.len());
	}

	//amount of bytes to write to file at once
	blocksz = 0x4000;

	//create a file class
	a = New aiod (5, 0x20000, 0x10000);

	//create the directory if it doesn't exist
	twait { a->mkdir("/tmp/dir", 0777, mkevent(rc)); }
	if(rc == EEXIST) {
		warn << "Directory exists.\n";
	} else if(rc != 0) {
		fatal << "Error when creating directory - " << rc << " - " << strerror(rc) << "\n";
	}

	//try to open the file for writing (and create if doesn't exist)
	twait { a->open("/tmp/dir/x", O_WRONLY | O_CREAT, 0777, mkevent (fh, rc)); }
	if(rc != 0) {
		fatal << "could not open file for writing - " << rc << " - " << strerror(rc) << "\n";
	}

	//allocate a buffer of size bufsize
	if (!(buf = a->bufalloc (blocksz))) {
		fatal << "error allocating buffer\n";
	}

	pos = 0;
	while( cur < end ) {
		//calculate size we're writing
		bufsz = min<ssize_t>(blocksz, end-cur);

		//copy from the string to the buffer
		memcpy(buf->base(), cur, bufsz);

		//write it to the file
		twait { fh->swrite(pos, buf, 0, bufsz, mkevent(b2, writtensz, rc)); }
		if(rc != 0) {
			fatal << "Error while writing to file - " << rc << " - " << strerror(rc) << "\n";
		} else if(writtensz != bufsz) {
			warn << "Tried to write " << bufsz << " but only wrote " << writtensz << "\n";
		}

		//increment by amount written
		pos += writtensz;
		cur += writtensz;
	}

	//close the file
	twait { fh->close(mkevent(rc)); }
	fh = NULL;

	exit(0);
}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain();
}
