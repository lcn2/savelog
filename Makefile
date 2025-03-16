#!/usr/bin/env make
#
# savelog - save/compress log files
#
# Copyright (c) 2000,2023,2025 by Landon Curt Noll.  All Rights Reserved.
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
# chongo (Landon Curt Noll) /\oo/\
#
# http://www.isthe.com/chongo/index.html
# https://github.com/lcn2
#
# Share and enjoy!


#############
# utilities #
#############
CHMOD= chmod
CP= cp
DATE= date
ID= id
INSTALL= install
MKDIR= mkdir
RM= rm
SHELL= bash
TAR= tar


######################
# target information #
######################

# V=@:  do not echo debug statements (quiet mode)
# V=@   echo debug statements (debug / verbose mode)
#
V=@:
#V=@

DESTDIR= /usr/local/sbin
LIBDIR= /usr/local/lib
DESTLIB= ${LIBDIR}/savelog

INDX_PROG= mail

TARGETS= savelog ${INDX_PROG}


######################################
# all - default rule - must be first #
######################################

all: ${TARGETS}
	${V} echo DEBUG =-= $@ start =-=
	${V} echo DEBUG =-= $@ end =-=


#################################################
# .PHONY list of rules that do not create files #
#################################################

.PHONY: all configure clean clobber install \
	test


#################
# utility rules #
#################

test: all
	${V} echo DEBUG =-= $@ start =-=
	@echo "make $@: testing savelog"
	@${RM} -rf OLD logfile
	@${DATE} > logfile
	@${MKDIR} -p OLD
	@./savelog logfile
	@if [ ! -f logfile -o -s logfile ]; then \
	    echo "savelog did not seem to work, check it manually" 1>&2; \
	    exit 1; \
	fi
	@${RM} -rf OLD logfile
	@echo "make $@: savelog passed"
	${V} echo DEBUG =-= $@ end =-=


###################################
# standard Makefile utility rules #
###################################

configure:
	${V} echo DEBUG =-= $@ start =-=
	${V} echo DEBUG =-= $@ end =-=

clean:
	${V} echo DEBUG =-= $@ start =-=
	${RM} -rf logfile OLD
	${V} echo DEBUG =-= $@ end =-=

clobber: clean
	${V} echo DEBUG =-= $@ start =-=
	${V} echo DEBUG =-= $@ end =-=

install: all test
	${V} echo DEBUG =-= $@ start =-=
	@if [[ $$(${ID} -u) != 0 ]]; then echo "ERROR: must be root to make $@" 1>&2; exit 2; fi
	${INSTALL} -m 0755 -d ${DESTDIR}
	${INSTALL} -m 0755 savelog ${DESTDIR}
	${INSTALL} -m 0755 -d ${LIBDIR}
	${INSTALL} -m 0755 ${INDX_PROG} ${DESTLIB}
	${V} echo DEBUG =-= $@ end =-=
