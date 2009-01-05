#include "ID_Value.h"

ID_Value::ID_Value() {
	setNull();
}

ID_Value::ID_Value(byte newid[20]) {
	for(int i=0; i<20; i++)
		id[i] = newid[i];
	null = false;
}

ID_Value::ID_Value(rpc_hash newid) {
	//const char * strnew = newid.cstr();
	//warn << strnew[0];
	//id[0] = strnew[0];
	for(int i=0; i<20; i++)
		id[i] = (char)newid[i];
	null = false;
}

ID_Value::~ID_Value() {
}

void ID_Value::randomize() {
	srand(time(NULL));
	for(int i=0; i<20; i++)
		id[i] = rand() % 256;
	null = false;
}

bool ID_Value::isNull() {
	return null;
}

void ID_Value::setNull() {
	for(int i=0; i<20; i++)
		id[i] = 0;
	null = true;
}

int ID_Value::hex_to_int(char x) {
	if(x >= '0' && x <= '9') {
		return x-'0';
	} else if(x >= 'a' && x <= 'f') {
		return x-'a' + 10;
	} else {
		assert(false);
	}
}

void ID_Value::fromString(const string s) {
	string ret;
	assert(s.length() == 40);
	for(int i=0; i<20; i++) {
		int high = hex_to_int(s[i*2]);
		int low = hex_to_int(s[i*2+1]);
		id[i] = (high << 4) | (low);
	}
}

string ID_Value::toString() const {
	static const char hexval[16] = {'0', '1', '2', '3', '4', '5', '6', '7',
									'8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
	string ret;
	for(int i=0; i<20; i++) {
		ret += hexval[((id[i] >> 4) & 0xF)];
		ret += hexval[(id[i]) & 0x0F];
	}
	return ret;
}

rpc_hash ID_Value::get_rpc_id() {
	//this function is fucked up
	//mstr m(20);
	vec<char> m;
	m.setsize(20);
	//warn << "test1\n";
	rpc_hash ret;
	//warn << "test2\n";
	for(int i=0; i<20; i++) {
		//warn << "test3 " << (int)id[i] << "\n";
		m[i] = (char)id[i];
	}
	//warn << "test4\n";
	rpc_vec<char, 20> dude;
	dude = m;
	//warn << "test0\n";
	ret = dude;
	//warn << "test5\n";
	//warn << "before check\n";
	//warn << "After check\n";
	return ret;
}

void ID_Value::set_from_rpc(rpc_hash newid) {
	for(int i=0; i<20; i++)
		id[i] = (char)newid[i];
	null = false;
}

bool ID_Value::between(ID_Value x, ID_Value y) const {
	//Three cases because the circle could have wrapped around
	// 1. x < this <= y
	// 2. this <= y < x (wraps)
	// 3. y < x < this (wraps)
	return ((*this > x && *this <= y) || (*this <= y && x > y) || (y < x && x < *this));
}

bool ID_Value::betweenIncl(ID_Value x, ID_Value y) const {
	//Three cases because the circle could have wrapped around
	// 1. x <= this <= y
	// 2. this <= y <= x (wraps)
	// 3. y <= x <= this (wraps)
	return ((*this >= x && *this <= y) || (*this <= y && x >= y) || (y <= x && x <= *this));
}

bool ID_Value::operator == (const ID_Value &other) const {
	for(int i=0; i<20; i++)
		if(other.id[i] != this->id[i])
			return false;
	return true;
}

bool ID_Value::operator <  (const ID_Value &other) const {
	for(int i=0; i<20; i++)	{
		if(this->id[i] < other.id[i]) return true;
		if(this->id[i] > other.id[i]) return false;
	}
	return false;
}

bool ID_Value::operator >  (const ID_Value &other) const {
	for(int i=0; i<20; i++)	{
		if(this->id[i] > other.id[i]) return true;
		if(this->id[i] < other.id[i]) return false;
	}
	return false;
}

bool ID_Value::operator <= (const ID_Value &other) const { return !(*this >  other); }
bool ID_Value::operator >= (const ID_Value &other) const { return !(*this <  other); }
bool ID_Value::operator != (const ID_Value &other) const { return !(*this == other); }
