#!/bin/make
#
# savelog - save/compress log files
#
# @(#) $Revision: 1.4 $
# @(#) $Id: Makefile,v 1.4 2000/02/05 09:24:28 chongo Exp chongo $
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
WEBDIR=/web/isthe/chroot/html/chongo/src/savelog
INSTALL= install

INDX_PROG= mail

TARGETS= savelog ${INDX_PROG}

all: ${TARGETS}

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
	-@if [ -d "${WEBDIR}" ]; then \
	    echo "${INSTALL} -m 0444 savelog ${DESTDIR}"; \
	    ${INSTALL} -m 0444 savelog ${DESTDIR}; \
	    echo "${INSTALL} -m 0444 ${INDX_PROG} ${DESTLIB}"; \
	    ${INSTALL} -m 0444 ${INDX_PROG} ${DESTLIB}; \
	    echo "${INSTALL} -m 0444 Makefile ${DESTDIR}"; \
	    ${INSTALL} -m 0444 Makefile ${DESTDIR}; \
	fi

clean:

clobber: clean
