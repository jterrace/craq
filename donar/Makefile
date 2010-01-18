TAME=/usr/local/lib/sfslite/tame
RPCC=/usr/local/lib/sfslite/rpcc
LFLAGS= -g $(STATIC) -O2 -Wall -Wno-unused -Wno-sign-compare
CFLAGS=$(LFLAGS) -x c++
CC=g++
STATIC=
ifeq (Darwin,${ARCH})
        STATIC=
        CC=g++-4.2
        CRYPTO_PP=pp
else
        CRYPTO_PP=++
endif

QUADPROG=/home/patrick/Documents/QUAD/quadprog/src

INCLUDE= -I/usr/local/include/sfslite \
			-I/usr/local/include \
			-I/usr/local/lib \
                        -I/usr/local/include/c-client-src \
                        -I/usr/include/crypto$(CRYPTO_PP) \
                        -I$(QUADPROG) \
                        -I./ \
			-I../ \

SFS_LIB_DIR=/usr/local/lib/sfslite
COIN_LIB_DIR=/home/patrick/Documents/COIN/coin-Clp/lib

CRAQ_OBJS=../craq_rpc.o \
                ../ID_Value.o \
                ../Node.o \
                ../MemStorage.o \
                ../connection_pool.o \
                ../zoo_craq.o \
		../client/craq_interface.o \

LIBS= $(SFS_LIB_DIR)/libtame.a \
                $(SFS_LIB_DIR)/libsfscrypt.a \
                $(SFS_LIB_DIR)/libarpc.a \
                $(SFS_LIB_DIR)/libasync.a \
                -lmosek \
                -lmoseknoomp \
                -liomp5 \
                -lresolv \
                -lmicrohttpd \
                -lcrypto$(CRYPTO_PP) \
                -ldl \
		-lzookeeper_st \
                -lpthread \
                -lmysqlcppconn-static \
                -lmysqlclient \
                -lpthread \
                -lz \

all: dnsbackend resolver donar_rpc store_data

dnsbackend: dnsbackend.cpp
	$(CC) $(INCLUDE) dnsbackend.cpp -o dnsbackend

test_console: test_console.cpp
	$(CC) $(INCLUDE) $(LFLAGS) test_console.cpp -o test_console $(LIBS)

http: http.cpp
	$(CC) $(INCLUDE) http.cpp -o http $(LIBS)

donar_rpc: donar_rpc.x
	$(RPCC) -h -o donar_rpc.h donar_rpc.x
	$(RPCC) -c -o donar_rpc.c donar_rpc.x
	$(CC) $(INCLUDE) $(CFLAGS) -c donar_rpc.c

store_data: store_data.T $(CRAQ_OBJS)
	$(TAME) -o store_data.TC store_data.T
	$(CC) $(INCLUDE) $(CFLAGS) -c store_data.TC
	$(CC) $(LFLAGS) -o store_data store_data.o $(CRAQ_OBJS) $(LIBS)

resolver: resolver.T resolver.h $(CRAQ_OBJS)
	$(TAME) -o resolver.TC resolver.T
	$(CC) $(INCLUDE) $(CFLAGS) -c resolver.TC resolver.h
	$(CC) $(LFLAGS) -o resolver resolver.o $(CRAQ_OBJS) $(LIBS)
