VIBED_LIBS=-L./lib/libvibe-d_utils.so \
           -L./lib/libvibe-d_data.so \
           -L./lib/libvibe-d_core.so \
           -L./lib/libvibe-d_http.so
LIBS=$(VIBED_LIBS) -L./lib/libevent-2.1.so.5 -L./lib/libevent_pthreads-2.1.so.5 -L./lib/libphobos2.so.0.73 -L-rpath=./lib
D_FLAGS=-fPIC -version=VibeLibeventDriver -version=Have_vibe_d_core -version=Have_libevent -version=Have_openssl -version=Have_vibe_d_data -version=Have_vibe_d_utils -I./include -de -Jbuildinfo
LDFLAGS=-L-s -L--no-as-needed
SOURCES=src/main.d src/imports.d src/Bus.d src/butils.d
TARGET=ebus-d


ALL:release
	./ebus-d
release:clean version
	dmd -c $(SOURCES) -odtmp $(D_FLAGS)
	dmd tmp/*.o -of${TARGET} $(LIBS) $(LDFLAGS)
dub-release:clean version
	dub build --build=release
	strip -s ebus-d
debug:
	dmd -c $(SOURCES) -odtmp $(D_FLAGS)
	dmd tmp/*.o -of${TARGET} $(LIBS)
profile-cov:clean version
#https://dlang.org/code_coverage.html
	dmd -c $(SOURCES) -odtmp $(D_FLAGS) -cov
	dmd tmp/*.o -of${TARGET} $(LIBS)
profile-gc:clean version
	dmd -c $(SOURCES) -odtmp $(D_FLAGS) -profile=gc
	dmd tmp/*.o -of${TARGET} $(LIBS)
profile-trace:clean version
#http://www.digitalmars.com/ctg/trace.html
	dmd -c $(SOURCES) -odtmp $(D_FLAGS) -profile
	dmd tmp/*.o -of${TARGET} $(LIBS)
	./ebus-d && ./util/d-profile-viewer
clean:
	rm tmp/*.o ${TARGET} *.o trace.* *.log *.lst -f *.7z
version:
	mkdir -p buildinfo/
	cat .git/`cat .git/HEAD |grep -oP "refs/heads/(.+)"` >buildinfo/version.txt
package-linux:clean dub-release
	mkdir -p ebus
	cp ebus-d config.json -r ebus
	7z a ebus-d.7z ebus
	rm -r ebus
