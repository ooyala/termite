CXX=g++
LOG4CXX=$(OOYALA_CODE_ROOT)/vendor/log4cxx/current

UNAME := $(shell uname)

ifeq ($(UNAME),Darwin)
CXXFLAGS=-I/usr/include -I$(LOG4CXX)/src/main/include -I/opt/local/include -O3
LDFLAGS=-llog4cxx -ltermite -L. -L$(LOG4CXX)/src/main/cpp -L/opt/local/lib
else
CXXFLAGS=-I/usr/include -I$(LOG4CXX)/src/main/include -O3
LDFLAGS=-llog4cxx -ltermite -lboost_thread -L. -L$(LOG4CXX)/src/main/cpp -L/opt/local/lib
endif

all: libtermite.a

test: termite_test
	./termite_test

termite_test: termite_test.cc
	$(CXX) $(CXXFLAGS) -o termite_test termite_test.cc $(LDFLAGS) -lgtest

example: termite_example

termite_example: termite_example.cc log4cxx libtermite.a
	$(CXX) $(CXXFLAGS) -o termite_example termite_example.cc $(LDFLAGS)

libtermite.a: termite.o
	ar rc libtermite.a termite.o
	ranlib libtermite.a

termite.o: termite.cc termite.h
	$(CXX) $(CXXFLAGS) -c termite.cc

log4cxx: $(LOG4CXX)/src/main/cpp/.libs/liblog4cxx.a

$(LOG4CXX)/src/main/cpp/liblog4cxx.la: 
	pushd $(LOG4CXX)
	./configure
	make
	popd

clean:
	rm -f termite.o libtermite.a termite_example.o termite termite_example termite_test termite_test.log termite_example.log

