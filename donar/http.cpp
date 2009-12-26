#include <platform.h>
#include <microhttpd.h>
#include <string.h>
#include <time.h>
#include <stdio.h>
#include <iostream>
#include <sstream>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>

#define BUFF_SIZE 2000
#define PORT 8888

using namespace std;
static int s, t;


int
answer_to_connection (void *cls, struct MHD_Connection *connection,
                      const char *url, const char *method,
                      const char *version, const char *upload_data,
                      size_t *upload_data_size, void **con_cls)
{
  unsigned char *buffer = NULL;
  struct MHD_Response *response;
  int ret;
  char line_buf[BUFF_SIZE];

  response =
    MHD_create_response_from_data (
      0, (void *) NULL, MHD_NO, MHD_NO);

  // Get Host: header value
  const char *long_host = MHD_lookup_connection_value(
    connection, MHD_HEADER_KIND, "Host");

  char* host = strtok((char*) long_host, ":");

  // Get remote IP address
  const union MHD_ConnectionInfo* info = MHD_get_connection_info (
    connection, MHD_CONNECTION_INFO_CLIENT_ADDRESS);
  struct sockaddr_in* client = info->client_addr;
  char* client_addr = inet_ntoa(client->sin_addr);

  // Formulate Query according to PDNS Backend Protocol
  string query = "Q ";
  query += host;
  query += " IN A -1 ";
  query += client_addr;

  // Send query to backend
  strncpy(line_buf, query.c_str(), BUFF_SIZE);
  cout << query;

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
  
  stringstream ss (stringstream::in | stringstream::out);
  ss << line_buf;
  string data, qname, qclass, qtype, ttl, id, content;
  cout << line_buf;
  ss >> data;
  ss >> qname;
  ss >> qclass;
  ss >> qtype;
  ss >> ttl;
  ss >> id;
  ss >> content;
  cout << "Content:\n";
  cout << content;
  fflush(stdout);

  string out = "0; url=http://" + content;
  MHD_add_response_header (response, "Refresh", out.c_str());
 
  ret = MHD_queue_response (connection, MHD_HTTP_OK, response);
  MHD_destroy_response (response);
  return ret;
}


int
main ()
{
  int len;
  struct sockaddr_un remote;
  char* helo = "HELO\t1";
  char line_buf[BUFF_SIZE];

  if ((s = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
    perror("socket");
    exit(1);
  }

  remote.sun_family = AF_UNIX;
  strcpy(remote.sun_path, "echo_socket");
  len = strlen(remote.sun_path) + sizeof(remote.sun_family);

  if (connect(s, (struct sockaddr *)&remote, len) == -1) {
        perror("connect");
        exit(1);
  }

  // Send HELO
  if (send(s, helo, strlen(helo), 0) == -1) {
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



  struct MHD_Daemon *daemon;

  daemon = MHD_start_daemon (MHD_USE_SELECT_INTERNALLY, PORT, NULL, NULL,
                             &answer_to_connection, NULL, MHD_OPTION_END);
  if (NULL == daemon) {
    printf("Error starting daemon");
    return 1;
  }

  getchar ();

  MHD_stop_daemon (daemon);

  return 0;
}
