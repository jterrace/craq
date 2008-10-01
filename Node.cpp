#include "Node.h"

Node::Node() {}

Node::~Node() {}

Node::Node(rpc_node newnode) {
	set_from_rpc_node(newnode);
}
Node::Node(string newip, unsigned int newport, ID_Value newid) :
	ip(newip), port(newport), id(newid) {}

rpc_node Node::get_rpc_node() {
	rpc_node ret;
	ret.ip = ip.c_str();
	ret.id = id.get_rpc_id();
	ret.port = port;
	return ret;
}

void Node::set_from_rpc_node(rpc_node newnode) {
	ip = newnode.ip;
	ID_Value newid(newnode.id);
	id = newid;
	port = newnode.port;
}

const string Node::toString() const {
	ostringstream ss;
	ss << "(" << ip
	   << ":" << port
	   << " - " << id.toString()
	   << ")";
	return ss.str();
}

string Node::getIp() { return ip; }
unsigned int Node::getPort() { return port; }
ID_Value Node::getId() const { return id; }

void Node::setIp(string newip) { ip = newip; }
void Node::setPort(unsigned int newport) { port = newport; }
void Node::setId(ID_Value newid) { id = newid; }

bool Node::operator == (const Node &other) const { return (other.getId() == this->getId()); }
bool Node::operator != (const Node &other) const { return !(*this == other); }
bool Node::operator < (const Node &other) const { return (other.getId() < this->getId()); }
bool Node::operator > (const Node &other) const { return (other.getId() > this->getId()); }
