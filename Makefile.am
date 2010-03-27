SFS_DIR=./sfslite-1.2.7
SFS_BIN=./sfs_install
SFS_LIB_DIR=$(SFS_BIN)/lib/sfslite
SFS_INCLUDE_DIR=$(SFS_BIN)/include/sfslite

TAME=$(SFS_LIB_DIR)/tame
RPCC=$(SFS_LIB_DIR)/rpcc

CRYPTO_PP_DIR = ./cryptopp560

ZOOKEEPER_DIR = ./zookeeper-3.1.1
ZOOKEEPER_BIN = ./zookeeper_install

LOG4CPP_DIR = ./log4cpp-1.0
LOG4CPP_BIN = ./log4cpp_install

LIBCONFIG_DIR = ./libconfig-1.4.2
LIBCONFIG_BIN = ./libconfig_install

GMP_DIR = ./gmp-4.3.1

CC=g++


AM_LDFLAGS =-g -O2 -Wall -Werror -Wno-unused -Wno-sign-compare \
            -L$(LOG4CPP_BIN)/lib -L$(LIBCONFIG_BIN)/lib \
            -L$(CRYPTO_PP_DIR) -L$(ZOOKEEPER_BIN)/lib
AM_CPPFLAGS= $(AM_LDFLAGS) -x c++

INCLUDES = -I$(SFS_INCLUDE_DIR) \
			-I$(ZOOKEEPER_BIN)/include/c-client-src \
			-I$(CRYPTO_PP_DIR) \
			-I$(LOG4CPP_BIN)/include \
			-I$(LOG4CPP_DIR)/include/log4cpp \
			-I$(LIBCONFIG_BIN)/include \
			-I./

LDADD= $(SFS_LIB_DIR)/libtame.a \
		$(SFS_LIB_DIR)/libsfscrypt.a \
		$(SFS_LIB_DIR)/libarpc.a \
		$(SFS_LIB_DIR)/libasync.a \
		-lresolv \
		-lcryptopp \
		-ldl \
		-lzookeeper_st \
		-lpthread \
		-llog4cpp \
		-lconfig++
	
OBJS= craq_rpc.c \
      ID_Value.c \
      Node.c \
      MemStorage.c \
      DiskStorage.c \
      HttpStorage.c \
      connection_pool.c \
      zoo_craq.c

EXTRA_DIST = $(CRYPTO_PP_DIR) $(SFS_DIR) $(ZOOKEEPER_DIR) $(GMP_DIR) ./tclap ./install_libraries \
             craq_rpc.x
             
dist-hook:
# remove .c and .h files that are automatically added
	find $(distdir)/*.[ch] -exec rm {} \; || echo
	find $(distdir)/router/*.[ch] -exec rm {} \; || echo
	find $(distdir)/test/*.[ch] -exec rm {} \; || echo
	find $(distdir)/logging/*.[ch] -exec rm {} \; || echo
#add .Tc and .Th files that are not caught automatically
	cp -p $(srcdir)/*.T* $(distdir)
	cp -p $(srcdir)/router/*.T* $(distdir)/router
	cp -p $(srcdir)/test/*.T* $(distdir)/test
#TODO remove line below to reflect how debugging is currently done
	cp -pR $(srcdir)/logging $(distdir)
#clean up library installations
	cd $(distdir)/$(CRYPTO_PP_DIR) && make clean || echo
	cd $(distdir)/$(SFS_DIR) && make clean || echo
	cd $(distdir)/$(ZOOKEEPER_DIR) && make clean || echo
	cd $(distdir)/$(GMP_DIR) && make clean || echo

#this script references the following directories directly and must be changed
#if they are renamed on account of an upgraded version or anything else:
#  cryptopp560
#  gmp-4.3.1
#  sfslite-1.2.7
#  zookeeper-3.1.1
#  log4cpp-1.0
lib_install:
	./install_libraries

craq_rpc.h: craq_rpc.x
	$(RPCC) -h -o craq_rpc.h craq_rpc.x
	
craq_rpc.c: craq_rpc.x
	$(RPCC) -c -o craq_rpc.c craq_rpc.x
	
craq_rpc.o: craq_rpc.x craq_rpc.c craq_rpc.h
	$(CC) $(INCLUDES) $(AM_CPPFLAGS) -c craq_rpc.c
	
connection_pool.o: connection_pool.h connection_pool.c craq_rpc.o
	$(CC) $(INCLUDES) $(AM_CPPFLAGS) -c connection_pool.c
ID_Value.o: ID_Value.h ID_Value.c craq_rpc.o
	$(CC) $(INCLUDES) $(AM_CPPFLAGS) -c ID_Value.c
Node.o: Node.h Node.c ID_Value.o craq_rpc.o
	$(CC) $(INCLUDES) $(AM_CPPFLAGS) -c Node.c
MemStorage.o: MemStorage.h MemStorage.c Storage.h
	$(CC) $(INCLUDES) $(AM_CPPFLAGS) -c MemStorage.c
DiskStorage.o: DiskStorage.h DiskStorage.c Storage.h
	$(CC) $(INCLUDES) $(AM_CPPFLAGS) -c DiskStorage.c
HttpStorage.o: HttpStorage.h HttpStorage.c Storage.h
	$(CC) $(INCLUDES) $(AM_CPPFLAGS) -c HttpStorage.c
zoo_craq.o: zoo_craq.h zoo_craq.c
	$(CC) $(INCLUDES) $(AM_CPPFLAGS) -c zoo_craq.c

.Tc.c:
	$(TAME) -o ./$(@D)/$(*F).c $<
.Th.h:
	$(TAME) -o ./$(@D)/$(*F).h $<
.c.o:
	$(CC) $(INCLUDES) $(AM_CPPFLAGS) -o ./$(@D)/$(*F).o -c $<
	
clean-local:
	rm -f *.c *.h \
          test/*.c test/*.h \
          router/*.c router/*.h \
          logging/*.c
	
BUILT_SOURCES = lib_install \
				craq_rpc.o \
				router/router.c \
                router/craq_interface.c \
                router/craq_interface.h \
                chain_node.c \
                connection_pool.c \
                connection_pool.h \
                craq_rpc.c \
                craq_rpc.h \
                ID_Value.c \
                ID_Value.h \
                MemStorage.c \
                MemStorage.h \
                DiskStorage.c \
                DiskStorage.h \
                HttpStorage.c \
                HttpStorage.h \
                logging.h \
                Node.c \
                Node.h \
                Storage.h \
                zoo_craq.c \
                zoo_craq.h \
                connection_pool.o \
                ID_Value.o \
                Node.o \
                MemStorage.o \
                DiskStorage.o \
                HttpStorage.o \
                zoo_craq.o

bin_PROGRAMS = chain_node \
               test/single_write_read \
               test/multi_read_write \
               test/writer \
               test/reader \
               test/single_reader \
               test/read_write \
               test/get_chain_info \
               test/transaction_tester \
               test/bulk_loader \
               router/router

chain_node_SOURCES = chain_node.Tc $(OBJS)
test_single_write_read_SOURCES = test/single_write_read.Tc $(OBJS)
test_multi_read_write_SOURCES = test/multi_read_write.Tc $(OBJS)
test_writer_SOURCES = test/writer.Tc $(OBJS)
test_reader_SOURCES = test/reader.Tc $(OBJS)
test_single_reader_SOURCES = test/single_reader.Tc $(OBJS)
test_read_write_SOURCES = test/read_write.Tc $(OBJS)
test_get_chain_info_SOURCES = test/get_chain_info.Tc $(OBJS)
test_transaction_tester_SOURCES = test/transaction_tester.Tc $(OBJS)
test_bulk_loader_SOURCES = test/bulk_loader.Tc $(OBJS)
router_router_SOURCES = router/router.Tc $(OBJS)
