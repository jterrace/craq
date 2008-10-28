#include "MemStorage.h"

MemStorage::MemStorage()
{
}

MemStorage::~MemStorage()
{
}

const blob* MemStorage::get(ID_Value key) {
	map<ID_Value, blob*>::iterator it = mem_data.find(key);
	if(it == mem_data.end()) {
		return NULL;
	} else {
		return it->second;
	}
}

bool MemStorage::set(ID_Value key, const blob* data) {
	del(key);
	mem_data[key] = new blob(*data);
	return true;
}

bool MemStorage::add(ID_Value key, const blob* data) {
	map<ID_Value, blob*>::iterator it = mem_data.find(key);
	if(it == mem_data.end()) {
		mem_data[key] = new blob(*data);
		return true;
	} else {
		return false;
	}
}

bool MemStorage::replace(ID_Value key, const blob* data) {
	map<ID_Value, blob*>::iterator it = mem_data.find(key);
	if(it == mem_data.end()) {
		return false;
	} else {
		delete it->second;
		mem_data[key] = new blob(*data);
		return true;
	}
}


bool MemStorage::del(ID_Value key) {
	map<ID_Value, blob*>::iterator it = mem_data.find(key);
	if(it != mem_data.end()) {
		delete it->second;
		mem_data.erase(key);
	}
	return true;
}
