#!/bin/make
#
# savelog - save/compress log files

SHELL=/bin/sh
DIRMODE=0555
DESTDIR=/usr/local/etc

all: savelog

savelog: savelog.sh
	-rm -f $@
	cp $@.sh $@
	chmod +x $@

install: all
	install -F ${DESTDIR} -m ${DIRMODE} savelog

clean:

clobber: clean
	-rm -f savelog
