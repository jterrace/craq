#include <stdio.h>
#include <iostream>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sstream>
#include <iostream>
#include <netdb.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define SOCK_PATH "echo_socket"
#define BUFF_SIZE 10000

using namespace std;

int main(void)
{
    int listen_1, listen_2, listen_3, len;
    int accept_sock, backend_sock;
    //struct sockaddr_un unix_sockaddr;
    struct sockaddr_in backend_sockaddr;
    struct sockaddr_in listen_sockaddr;
    struct sockaddr_in peer_sockaddr;
    socklen_t addr_len;
 
    char line_buf[BUFF_SIZE];

   // Backend sock
   backend_sockaddr.sin_family = AF_INET;
   backend_sockaddr.sin_port = htons(21000);
   struct hostent* local;
   local = gethostbyname("localhost");
   struct in_addr localaddr;
   bcopy(local->h_addr, (char*) &localaddr, sizeof(localaddr));
   backend_sockaddr.sin_addr = localaddr;

   if ((backend_sock = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
        perror("socket");
        exit(1);
    }
    int socklen = sizeof(struct sockaddr_in);
    if (connect(backend_sock, 
      (struct sockaddr *)&backend_sockaddr, socklen) == -1){
      perror("connect");
      exit(1);
    }

   // TCP socket for accepting incoming connections
    if ((listen_1 = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
        perror("socket");
        exit(1);
    }
    listen_sockaddr.sin_family = AF_INET;
    listen_sockaddr.sin_port = htons(21005);
    inet_aton("0.0.0.0", &listen_sockaddr.sin_addr);

    if ((listen_2 = bind(listen_1, 
      (struct sockaddr *)&listen_sockaddr, sizeof(listen_sockaddr))) != 0) {
      perror("bind");
      exit(1);
    }

    if (listen(listen_1, 1) != 0) {
      perror("listen");
      exit(1);
    }
    cout << "Listening for incoming requests...\n"; 

    addr_len = sizeof(peer_sockaddr);
    while((accept_sock = accept(listen_1, (struct sockaddr*) &peer_sockaddr,
      (socklen_t*) &addr_len)) > 0) {
        if (accept_sock == -1) {
          perror("accept");
          printf("errno:%i", errno);
          exit(1);
        }

        if (fork() != 0) {
          continue;
        }

        cout << "Handling commection from: ";
        char peer_addr[40];
        inet_ntop(AF_INET, (const void*) 
          &peer_sockaddr.sin_addr, peer_addr, 40);
        cout << peer_addr;
        cout << "\n";
/*
	// UNIX socket for communication with resolver
	if ((unix_sock = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
	    perror("socket");
	    exit(1);
	}
	unix_sockaddr.sun_family = AF_UNIX;
	strcpy(unix_sockaddr.sun_path, SOCK_PATH);
	len = strlen(unix_sockaddr.sun_path) + sizeof(unix_sockaddr.sun_family);
	if (connect(unix_sock, (struct sockaddr *)&unix_sockaddr, len) == -1) {
	  perror("connect");
	  exit(1);
	}
*/
        // Perform handshake
        char init_buff[BUFF_SIZE];
        strcpy(init_buff, "HELO\t1\r\n");
        if (send(backend_sock, init_buff, strlen(init_buff), 0) == -1) {
          perror("send");
          exit(1);
        }

        if (recv(backend_sock, init_buff, BUFF_SIZE, 0) > 0) {
        } else {
          printf("Server closed connection\n");
          exit(1);
        }

        cout << "Accepted and handshake completed\n";
        fflush(stdout);
        
        while (true) {
          char buff[BUFF_SIZE];
          int length;
          length = recv(accept_sock, buff, BUFF_SIZE, 0);
          if (length < 1) {
            break;
          }       
          buff[length] = '\0';
          buff[length - 1] = '\0'; // TODO: strip function?
          buff[length - 2] = '\0';

          // We get of the form <domain> or [<domain> <remote_ip>]
          stringstream in (stringstream::in | stringstream::out);
          stringstream out (stringstream::in | stringstream::out);
          in << buff;
          string domain, remote_ip;   
          in >> domain;
          in >> remote_ip;

          out << "Q ";
          out << domain;
          out << " IN ANY -1 ";
          if (remote_ip.length() > 0) {out << remote_ip;}
          else {out << "-1";}
          out << "\r\n";
          strncpy(buff, out.str().c_str(), BUFF_SIZE);
          
          fflush(stdout);

  	  if (send(backend_sock, buff, strlen(buff), 0) == -1) {
	      perror("send");
	      exit(1);
  	  }
          int t;
	  if ((t=recv(backend_sock, buff, BUFF_SIZE, 0)) > 0) {
	      buff[t] = '\0';
	      send(accept_sock, buff, strlen(buff), 0);
	  } else {
	    if (t < 0) perror("recv");
	    else printf("Server closed connection\n");
	    exit(1);
	  }
      }
    }

    close(backend_sock);

    return 0;
}

