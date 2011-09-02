CXX=g++
JSON_SPIRIT=$(OOYALA_CODE_ROOT)/vendor/json_spirit
LOG4CXX=$(OOYALA_CODE_ROOT)/vendor/log4cxx/current
CXXFLAGS=-I/usr/include -I$(JSON_SPIRIT)/json_spirit -I$(LOG4CXX)/src/main/include -O3
LDFLAGS=-ljson_spirit -llog4cxx -ltermite -L. -L$(JSON_SPIRIT)/build/json_spirit -L$(LOG4CXX)/src/main/cpp

UNAME := $(shell uname)

ifeq ($(UNAME),Darwin)
MACHINE_CXXFLAGS=-I/opt/local/include
MACHINE_LDFLAGS=-L/opt/local/lib
endif

all: termite.a

example: termite_example.cc json_spirit log4cxx termite.a
	$(CXX) $(CXXFLAGS) $(MACHINE_CXXFLAGS) $(LDFLAGS) $(MACHINE_LDFLAGS) -o termite_example termite_example.cc

termite.a: termite.o
	ar rc libtermite.a termite.o
	ranlib libtermite.a

termite.o: termite.cc termite.h
	$(CXX) $(CXXFLAGS) $(MACHINE_CXXFLAGS) -c termite.cc

json_spirit: $(JSON_SPIRIT)/build/json_spirit/json_spirit.a

$(JSON_SPIRIT)/build/json_spirit/json_spirit.a:
	$(JSON_SPIRIT)/make.sh

log4cxx: $(LOG4CXX)/src/main/cpp/.libs/liblog4cxx.a

$(LOG4CXX)/src/main/cpp/liblog4cxx.la: 
	pushd $(LOG4CXX)
	./configure
	make
	popd

clean:
	rm -f termite.o libtermite.a termite_example.o termite termite_example


