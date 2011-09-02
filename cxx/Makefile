CXX=g++
LOG4CXX=$(OOYALA_CODE_ROOT)/vendor/log4cxx/current
CXXFLAGS=-I/usr/include -I$(LOG4CXX)/src/main/include -O3
LDFLAGS=-llog4cxx -ltermite -L. -L$(LOG4CXX)/src/main/cpp

UNAME := $(shell uname)

ifeq ($(UNAME),Darwin)
MACHINE_CXXFLAGS=-I/opt/local/include
MACHINE_LDFLAGS=-L/opt/local/lib
endif

all: termite.a

example: termite_example.cc log4cxx termite.a
	$(CXX) $(CXXFLAGS) $(MACHINE_CXXFLAGS) $(LDFLAGS) $(MACHINE_LDFLAGS) -o termite_example termite_example.cc

termite.a: termite.o
	ar rc libtermite.a termite.o
	ranlib libtermite.a

termite.o: termite.cc termite.h
	$(CXX) $(CXXFLAGS) $(MACHINE_CXXFLAGS) -c termite.cc

log4cxx: $(LOG4CXX)/src/main/cpp/.libs/liblog4cxx.a

$(LOG4CXX)/src/main/cpp/liblog4cxx.la: 
	pushd $(LOG4CXX)
	./configure
	make
	popd

clean:
	rm -f termite.o libtermite.a termite_example.o termite termite_example


