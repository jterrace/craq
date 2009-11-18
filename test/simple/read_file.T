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
		struct stat *sb;
		ptr<aiobuf> buf, b2;
		bool eof;
		off_t pos, sz;
		ssize_t rsz;
		ssize_t blocksz;
		strbuf b;
	}

	//amount of bytes to read from file at once
	blocksz = 0x4000;

	//create a file class
	a = New aiod (5, 0x20000, 0x10000);

	//open the file for reading
	twait { a->open("/tmp/x", O_RDONLY, 0, mkevent (fh, rc)); }
	if(rc != 0) {
		fatal << "could not open file\n";
	}

	//call stat to get the length
	twait { fh->fstat(mkevent (sb, rc)); }
	if(rc != 0) {
		fatal << "could not fstat\n";
	}
	sz = sb->st_size;
	warn << "size is: " << sz << "\n";

	//allocate a buffer of size bufsize
	if (!(buf = a->bufalloc (blocksz))) {
		fatal << "error allocating buffer\n";
	}

	eof = false;
	pos = 0;
	while(!eof) {
		//read into the buffer bufsize bytes
		twait { fh->read(pos, buf, mkevent(b2, rsz, rc)); }
		if (rc != 0) {
			fatal << "Read error on file\n";
		}
		if (rsz < 0) {
			fatal << "Got unexpected failed read\n";
		}
		if (rsz < blocksz) {
			eof = true;
		}

		//copy bytes read into result string
		b.tosuio ()->copy(b2->base (), rsz);

		pos += rsz;
		if(pos >= sz) eof = true;
	}

	if (b.tosuio()->resid() != size_t(sz)) {
		fatal << "While reading file, I "
		<< "exepcted " << sz << " bytes; got "
		<< b.tosuio()->resid() << " bytes instead\n";
	}

	//close the file
	twait { fh->close(mkevent(rc)); }
	fh = NULL;

	//print out the file
	warn << b;

	exit(0);
}

int main (int argc, char *argv[]) {
	main2(argc, argv);
	amain();
}
