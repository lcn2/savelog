#!/bin/make
#
# savelog - save/compress log files
#
# @(#) $Revision: 1.9 $
# @(#) $Id: Makefile,v 1.9 2002/02/03 02:22:42 chongo Exp chongo $
# @(#) $Source: /usr/local/src/etc/savelog/RCS/Makefile,v $
#
# Copyright (c) 2000 by Landon Curt Noll.  All Rights Reserved.
#
# Permission to use, copy, modify, and distribute this software and
# its documentation for any purpose and without fee is hereby granted,
# provided that the above copyright, this permission notice and text
# this comment, and the disclaimer below appear in all of the following:
#
#       supporting documentation
#       source copies
#       source works derived from this source
#       binaries derived from this source or from derived source
#
# LANDON CURT NOLL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
# INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
# EVENT SHALL LANDON CURT NOLL BE LIABLE FOR ANY SPECIAL, INDIRECT OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
# USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
# chongo <was here> /\oo/\
#
# Share and enjoy!


SHELL=/bin/sh

DESTDIR=/usr/local/etc
LIBDIR=/usr/local/lib
DESTLIB=${LIBDIR}/savelog
WWWDIR=/web/isthe/chroot/html/chongo/src/savelog
INSTALL= install

INDX_PROG= mail

TARGETS= savelog ${INDX_PROG}

all: ${TARGETS}

savelog: savelog.pl
	-rm -f $@
	@if ! perl -e 'require "syscall.ph"; 1;' 2>/dev/null; then \
	    printf "\nmissing syscall.ph\n\n"; \
	    printf "\ttry: cd /usr/include; h2ph -a -h syscall.h\n\n" 1>&2; \
	    exit 1; \
	fi
	-rm -rf OLD date
	date > date
	mkdir OLD
	./savelog.pl date
	@if [ ! -f date -o -s date ]; then \
	    echo "savelog did not seem to work, check it manually" 1>&2; \
	    exit 1; \
	fi
	-rm -rf OLD date
	cp -f savelog.pl $@
	chmod +x $@

install: all
	${INSTALL} -m 0755 savelog ${DESTDIR}
	-@if [ ! -d "${LIBDIR}" ]; then \
	    echo "mkdir -p ${LIBDIR}"; \
	    mkdir -p ${LIBDIR}; \
	    echo "chmod 0755 ${LIBDIR}"; \
	    chmod 0755 ${LIBDIR}; \
	fi
	-@if [ ! -d "${DESTLIB}" ]; then \
	    echo "mkdir -p ${DESTLIB}"; \
	    mkdir -p ${DESTLIB}; \
	    echo "chmod 0755 ${DESTLIB}"; \
	    chmod 0755 ${DESTLIB}; \
	fi
	${INSTALL} -m 0755 ${INDX_PROG} ${DESTLIB}
	-@if [ -d "${WWWDIR}" ]; then \
	    echo "${INSTALL} -m 0444 savelog ${WWWDIR}"; \
	    ${INSTALL} -m 0444 savelog ${WWWDIR}; \
	    echo "${INSTALL} -m 0444 ${INDX_PROG} ${WWWDIR}"; \
	    ${INSTALL} -m 0444 ${INDX_PROG} ${WWWDIR}; \
	    echo "${INSTALL} -m 0444 Makefile ${WWWDIR}"; \
	    ${INSTALL} -m 0444 Makefile ${WWWDIR}; \
	    (echo "cd ${WWWDIR}/.."; \
	     cd ${WWWDIR}/..; \
	     tgz="savelog/savelog.tgz"; \
	     files="savelog/savelog savelog/Makefile"; \
	     for i in ${INDX_PROG}; do \
	         files="$$files savelog/$$i"; \
	     done; \
	     echo "tar -zcvf $$tgz $$files"; \
	     tar -zcvf $$tgz $$files; \
	     echo "chmod 0444 $$tgz"; \
	     chmod 0444 $$tgz; \
	    ); \
	fi

clean:
	rm -rf date OLD

clobber: clean
	rm -f savelog
