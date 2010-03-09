#ifndef NODE_H_
#define NODE_H_

#include <sstream>
#include <string>
#include "craq_rpc.h"
#include "ID_Value.h"

using namespace std;

class Node
{
private:
	string ip;
	unsigned int port;
	ID_Value id;

public:
	Node();
	Node(rpc_node newnode);
	Node(string newip, unsigned int newport, ID_Value newid);
	virtual ~Node();

	rpc_node get_rpc_node();
	void set_from_rpc_node(rpc_node newnode);
	void set_from_string(string s);

	const string toString() const;

	string getIp();
	unsigned int getPort();
	ID_Value getId() const;

	void setIp(string newip);
	void setPort(unsigned int newport);
	void setId(ID_Value newid);

	bool operator == (const Node &other) const;
	bool operator != (const Node &other) const;
	bool operator < (const Node &other) const;
	bool operator > (const Node &other) const;

};

#endif /*NODE_H_*/
