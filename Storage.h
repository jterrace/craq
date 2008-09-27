#ifndef STORAGE_H_
#define STORAGE_H_
#include <string>
#include "craq_rpc.h"
#include "ID_Value.h"

using namespace std;

class Storage
{
	public:
		virtual blob* get(ID_Value key) const = 0;
		virtual bool set(ID_Value key, const blob* data) = 0;
		virtual bool add(ID_Value key, const blob* data) = 0;
		virtual bool replace(ID_Value key, const blob* data) = 0;
		virtual bool del(ID_Value key) = 0;
		
};

#endif /*STORAGE_H_*/
