#!/bin/make
#
# savelog - save/compress log files
#
# @(#) $Revision$
# @(#) $Id$
# @(#) $Source$
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
INSTALL= install

INDX_PROG= mail

TARGETS= savelog ${INDX_PROG}

all: ${TARGETS}

install: all
	${INSTALL} -m 0755 savelog ${DESTDIR}
	-@if [ ! -d "${LIBDIR}" ]; then \
	    echo "	mkdir -p ${LIBDIR}"; \
	    mkdir -p ${LIBDIR}; \
	    echo "	chmod 0755 ${LIBDIR}"; \
	    chmod 0755 ${LIBDIR}; \
	fi
	-@if [ ! -d "${DESTLIB}" ]; then \
	    echo "	mkdir -p ${DESTLIB}"; \
	    mkdir -p ${DESTLIB}; \
	    echo "	chmod 0755 ${DESTLIB}"; \
	    chmod 0755 ${DESTLIB}; \
	fi
	${INSTALL} -m 0755 ${INDX_PROB} ${DESTDIR}

clean:

clobber: clean
