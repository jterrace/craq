#ifndef MEMSTORAGE_H_
#define MEMSTORAGE_H_
#include <string>
#include <map>
#include "Storage.h"
#include "ID_Value.h"
#include "craq_rpc.h"

using namespace std;

class MemStorage : public Storage
{
	private:
		map<ID_Value, blob*> mem_data;
	
	public:
		MemStorage();
		virtual ~MemStorage();
		const blob* get(ID_Value key);
		bool set(ID_Value key, const blob* data);
		bool add(ID_Value key, const blob* data);
		bool replace(ID_Value key, const blob* data);
		bool del(ID_Value key);
};

#endif /*MEMSTORAGE_H_*/
