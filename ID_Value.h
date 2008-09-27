#ifndef ID_VALUE_H_
#define ID_VALUE_H_

#include <string>
#include "craq_rpc.h"

using namespace std;
typedef unsigned char byte;

class ID_Value
{
private:
	bool null;
	byte id[20];
	rpc_hash test;
public:
	ID_Value();
	ID_Value(byte newid[20]);
	ID_Value(rpc_hash newid);
	virtual ~ID_Value();
	string toString() const;
	bool isNull();
	void setNull();
	void randomize();
	rpc_hash get_rpc_id();
	void set_from_rpc(rpc_hash newid);
	bool between(ID_Value x, ID_Value y) const;
	bool operator == (const ID_Value &other) const;
	bool operator != (const ID_Value &other) const;
	bool operator <  (const ID_Value &other) const;
	bool operator >  (const ID_Value &other) const;
	bool operator <= (const ID_Value &other) const;
	bool operator >= (const ID_Value &other) const;
};

#endif
