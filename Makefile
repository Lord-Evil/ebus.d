VIBED_LIBS=-L./lib/libvibe-d_utils.so \
           -L./lib/libvibe-d_data.so \
           -L./lib/libvibe-d_core.so \
           -L./lib/libvibe-d_http.so
LIBS=$(VIBED_LIBS) -L./lib/libevent-2.1.so.5 -L./lib/libevent_pthreads-2.1.so.5 -L-s -L--no-as-needed -L./lib/libphobos2.so.0.73 -L-rpath=./lib
D_FLAGS=-fPIC -version=VibeLibeventDriver -version=Have_vibe_d_core -version=Have_libevent -version=Have_openssl -version=Have_vibe_d_data -version=Have_vibe_d_utils -I./include

SOURCES=src/main.d src/imports.d src/BusGroup.d src/butils.d
TARGET=ebus-d


ALL:clean
	dmd -c $(SOURCES) -odtmp $(D_FLAGS)
	dmd tmp/*.o -of${TARGET} $(LIBS)
clean:
	rm tmp/*.o ${TARGET} *.o -f
package-linux:ALL
	mkdir ebus
	cp ebus-d config.json lib -r ebus
	7z a ebus-d.7z ebus
	rm -r ebus