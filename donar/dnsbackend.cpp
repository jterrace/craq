#include <stdio.h>
#include <iostream>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>

#define SOCK_PATH "echo_socket"
#define BUFF_SIZE 1000

using namespace std;

int main(void)
{
    int s, t, len;
    struct sockaddr_un remote;
    char line_buf[BUFF_SIZE];

    if ((s = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
	perror("socket");
	exit(1);
    }

    remote.sun_family = AF_UNIX;
    strcpy(remote.sun_path, SOCK_PATH);
    len = strlen(remote.sun_path) + sizeof(remote.sun_family);
    if (connect(s, (struct sockaddr *)&remote, len) == -1) {
	perror("connect");
	exit(1);
    }

    while(true) {
        cin.getline(line_buf, BUFF_SIZE);
	if (send(s, line_buf, strlen(line_buf), 0) == -1) {
	    perror("send");
	    exit(1);
	}

	if ((t=recv(s, line_buf, BUFF_SIZE, 0)) > 0) {
	    line_buf[t] = '\0';
	    printf("%s", line_buf);
	} else {
	    if (t < 0) perror("recv");
	    else printf("Server closed connection\n");
	    exit(1);
	}
    }

    close(s);

    return 0;
}

