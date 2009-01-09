// -*-c++-*-
/* $Id: ex3.T 3274 2008-05-17 20:10:40Z max $ */

#include "tame.h"
#include "parseopt.h"
#include "ex_prot.h"
#include "arpc.h"
#include "tame_autocb.h"
 
tamed static 
void try_rpc (str h, int port, cbb cv)
{
  tvars {
    bool ret (false);
    int fd, n (5);
    ptr<axprt_stream> x;
    ptr<aclnt> cli;
    vec<int> rv;
    vec<clnt_stat> ev;
    holdvar autocb_t<bool> acb (cv, ret);
    int i;
    ex_struct_t blah;
    clnt_stat e;	
    timeval started;
    timeval cur_time;
    long sec_diff;
    long usec_diff;

  }

  twait { tcpconnect (h, port, mkevent(fd)); }
 
  if (fd < 0) {
    warn ("%s:%d: connection failed: %m\n", h.cstr(), port);
  } else {
    x = axprt_stream::alloc (fd);
    cli = aclnt::alloc (x, ex_prog_1);
 
    gettimeofday(&started, NULL);

    twait { cli->call(EX_STRUCT, NULL, &blah, mkevent(e)); }
    if(e) {
      fatal << "IT FAILED\n";
    }

    gettimeofday(&cur_time, NULL);
    
	warn << cur_time.tv_sec << "\t" << cur_time.tv_usec << "\t";
	sec_diff = cur_time.tv_sec - started.tv_sec;
	if(sec_diff == 0) {
		usec_diff = cur_time.tv_usec - started.tv_usec;
	} else {
		usec_diff = (1000000 - started.tv_usec) + cur_time.tv_usec;
		sec_diff--;
		sec_diff += (usec_diff / 1000000);
		usec_diff = usec_diff % 1000000;
	}
	warn << sec_diff << "\t" << usec_diff << "\n";


    /*ev.setsize (n);
    rv.setsize (n);
 
    twait {
      for (i = 0; i < n; i++) {
	RPC::ex_prog_1::ex_random (cli, &rv[i], mkevent(ev[i]));
      }
    }
    ret = true;
    // check for n-fold success as usual
    for (int i = 0 ; i < n; i++) {
      if (ev[i]) {
        warn << "A failure: " << ev[i] << "\n";
        ret = false;
      } else {
         warn << "Result " << i << ": " << rv[i] << "\n";
      }
      }*/
  }
}
 
static void finish (bool rc)
{
  exit (rc ? 0 : -1);
}
 
int main (int argc, char *argv[])
{
  int port;
  if (argc != 3 || !convertint (argv[2], &port))
    fatal << "usage: ex3 <hostname> <port>\n";
  
  try_rpc (argv[1], port, wrap (finish));
  amain ();
}
