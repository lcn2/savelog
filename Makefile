#!/usr/bin/env make
#
# savelog - save/compress log files
#
# Copyright (c) 2000,2023 by Landon Curt Noll.  All Rights Reserved.
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


SHELL= bash

DESTDIR= /usr/local/sbin
LIBDIR= /usr/local/lib
DESTLIB= ${LIBDIR}/savelog
WWWDIR= /web/chongo/isthe.com/chongo/src/savelog
INSTALL= install
RM= rm
DATE= date
MKDIR= mkdir
CP= cp
CHMOD= chmod
TAR= tar

INDX_PROG= mail

TARGETS= savelog ${INDX_PROG}

all: ${TARGETS}

savelog: savelog.pl
	${RM} -f $@
	${RM} -rf OLD date
	${DATE} > date
	${MKDIR} -p OLD
	./savelog.pl date
	@if [ ! -f date -o -s date ]; then \
	    echo "savelog did not seem to work, check it manually" 1>&2; \
	    exit 1; \
	fi
	${RM} -rf OLD date
	${CP} -f savelog.pl $@
	${CHMOD} +x $@

install: all
	${INSTALL} -m 0755 savelog ${DESTDIR}
	-@if [ ! -d "${LIBDIR}" ]; then \
	    echo "${MKDIR} -p ${LIBDIR}"; \
	    ${MKDIR} -p ${LIBDIR}; \
	    echo "${CHMOD} 0755 ${LIBDIR}"; \
	    ${CHMOD} 0755 ${LIBDIR}; \
	fi
	-@if [ ! -d "${DESTLIB}" ]; then \
	    echo "${MKDIR} -p ${DESTLIB}"; \
	    ${MKDIR} -p ${DESTLIB}; \
	    echo "${CHMOD} 0755 ${DESTLIB}"; \
	    ${CHMOD} 0755 ${DESTLIB}; \
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
	     echo "${TAR} -zcvf $$tgz $$files"; \
	     ${TAR} -zcvf $$tgz $$files; \
	     echo "${CHMOD} 0444 $$tgz"; \
	     ${CHMOD} 0444 $$tgz; \
	    ); \
	fi

clean:
	${RM} -rf date OLD

clobber: clean
	${RM} -f savelog
