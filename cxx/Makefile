CXX=g++
CXXFLAGS=-I/usr/include -I/opt/local/include -O3
LD=ld
LDFLAGS=-L. -L/opt/local/lib -ljson_spirit -llog4cxx -ltermite

all: termite.a

example: termite_example.cc
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o termite_example termite_example.cc

termite.a: termite.o
	ar rc libtermite.a termite.o
	ranlib libtermite.a

termite.o: termite.cc termite.h
	$(CXX) $(CXXFLAGS) -c termite.cc

clean:
	rm -f termite.o libtermite.a termite_example.o termite termite_example


