#!/bin/sh
#
# savelog - save a log file
#
# This code was based on a pre-Copylefted version of savelog as distributed
# in Smail.  Savelog was written by Landon Curt Noll (chongo@toad.com) with
# some mods/suggestions by Ronald S. Karr.
#
# Copyright (c) Landon Curt Noll and Ronald S. Karr, 1993.
# Copyright (c) Landon Curt Noll, 1999.
# All rights reserved.
#
# Permission to use, copy, modify, and distribute this software and
# its documentation for any purpose and without fee is hereby granted,
# provided that the above copyright, this permission notice and text
# this comment, and the disclaimer below appear in all of the following:
#
#      supporting documentation
#      source copies
#      source works derived from this source
#      binaries derived from this source or from derived source
#
# LANDON CURT NOLL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
# INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
# EVENT SHALL LANDON CURT NOLL BE LIABLE FOR ANY SPECIAL, INDIRECT OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
# USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
###
#
# usage: savelog [-m mode] [-o owner] [-g group] [-t] [-c cycle] [-l] file...
#
#	-m mode	  - chmod log files to mode
#	-o owner  - chown log files to user
#	-g group  - chgrp log files to group
#	-c cycle  - save cycle versions of the logfile	(default: 7)
#	-t	  - touch file
#	-l	  - don't compress any log files	(default: gzip files)
#	file 	  - log file names
#
# The savelog command saves and optionally compresses old copies of files
# into an 'dir'/OLD sub-directory.  The 'dir' directory is determined from
# the directory of each 'file'.
#
# Older version of 'file' are named:
#
#	OLD/'file'.<number>.gz
#
# where <number> is the version number, 0 being the newest.  By default,
# version numbers > 0 are compressed (unless -l prevents it). The
# version number 0 is never compressed on the off chance that a process
# still has 'file' opened for I/O.
#
# If the 'file' does not exist or if it is zero length, no further processing
# is performed.  However if -t was also given, it will be created.
#
# For files that do exist and have lengths greater than zero, the following
# actions are performed.
#
#	1) Version numered files are cycled.  That is version 6 is moved to
#	   version 7, version is moved to becomes version 6, ... and finally
#	   version 0 is moved to version 1.  Both compressed names and
#	   uncompressed names are cycled, regardless of -t.  Missing version
#	   files are ignored.
#
#	2) The new OLD/file.1 is compressed and is changed subject to
#	   the -m, -o and -g flags.  This step is skipped if the -t flag
#	   was given.
#
#	3) The main file is moved to OLD/file.0.
#
#	4) If the -m, -o, -g or -t flags are given, then file is created
#	   (as an empty file) subject to the given flags.
#
#	5) The new OLD/file.0 is chanegd subject to the -m, -o and -g flags.
#
# Note: If the OLD sub-directory does not exist, it will be created
#	with mode 0755.
#
# Note: For backward compatibility, -u user means the same as -o user.
#
# Note: If no -t, -m, -o  or -g flag is given, then the primary log file is
#	not created.
#
# Note: Since the version numbers start with 0, version number <cycle>
#	is never formed.  The <cycle> count must be at least 2.
#
# Note: The default compression extension is .gz instead of .z.
#
# Note: This utility will refuse to process symlinks in addition
#	to other non-file/special-files.  So the target must be
#	a regular file.
#
# Bugs: If a process is still writing to the file.0 and savelog
#	moved it to file.1 and compresses it, data could be lost.

# common locations
#
PATH="/usr/sbin:/usr/ucb:/usr/bsd:/sbin:/usr/bin:/bin:/usr/etc:/usr/freeware/bin:/usr/gnu/bin:/usr/local/bin"
DOT_Z=".gz"
ECHO="/usr/bin/echo"
CHOWN="/usr/bin/chown"
CHGRP="/usr/bin/chgrp"
CHMOD="/usr/bin/chmod"
MV="/usr/bin/mv"
RM="/usr/bin/rm"
EXPR="/usr/bin/expr"
MKDIR="/usr/bin/mkdir"
GETOPT="/usr/bin/getopt"
if [ -x /usr/sbin/gzip ]; then
    GZIP_BINARY="/usr/sbin/gzip"
elif [ -x /opt/FSFgzip/bin/gzip ]; then
    GZIP_BINARY="/opt/FSFgzip/bin/gzip"
elif [ -x /usr/freeware/bin/gzip ]; then
    GZIP_BINARY="/usr/freeware/bin/gzip"
elif [ -x /usr/local/bin/gzip ]; then
    GZIP_BINARY="/usr/local/bin/gzip"
elif [ -x /usr/bin/gzip ]; then
    GZIP_BINARY="/usr/bin/gzip"
elif [ -x /sbin/gzip ]; then
    GZIP_BINARY="/sbin/gzip"
elif [ -x /bin/gzip ]; then
    GZIP_BINARY="/bin/gzip"
else
    GZIP_BINARY="/usr/gnu/bin/gzip"
fi
# NOTE: gzip uses $GZIP as the default set of args
GZIP="--best --force"
if [ -x /usr/bin/test ]; then
    TEST="/usr/bin/test"
else
    TEST="/bin/test"
fi
export PATH GZIP DOT_Z ECHO CHOWN CHGRP CHMOD MV RM EXPR MKDIR
export GETOPT GZIP_BINARY TEST

# paranoid firewall
#
if [ ! -x "$ECHO" ]; then
    echo "$prog: cannot find echo executable: $ECHO" 1>&2
    exit 1
fi
if [ ! -x "$GZIP_BINARY" ]; then
    $ECHO "$prog: cannot find gzip executable: $GZIP_BINARY" 1>&2
    exit 2
fi
if [ ! -x "$CHOWN" ]; then
    $ECHO "$prog: cannot find chown executable: $CHOWN" 1>&2
    exit 3
fi
if [ ! -x "$CHGRP" ]; then
    $ECHO "$prog: cannot find chgrp executable: $CHGRP" 1>&2
    exit 4
fi
if [ ! -x "$MV" ]; then
    $ECHO "$prog: cannot find mv executable: $MV" 1>&2
    exit 5
fi
if [ ! -x "$RM" ]; then
    $ECHO "$prog: cannot find rm executable: $RM" 1>&2
    exit 6
fi
if [ ! -x "$EXPR" ]; then
    $ECHO "$prog: cannot find expr executable: $EXPR" 1>&2
    exit 7
fi
if [ ! -x "$MKDIR" ]; then
    $ECHO "$prog: cannot find mkdir executable: $MKDIR" 1>&2
    exit 8
fi
if [ ! -x "$GETOPT" ]; then
    $ECHO "$prog: cannot find getopt executable: $GETOPT" 1>&2
    exit 9
fi
if [ ! -x "$TEST" ]; then
    $ECHO "$prog: cannot find test executable: $TEST" 1>&2
    exit 10
fi

# parse args
#
exitcode=0	# no problems to far
prog="$0"
mode=
user=
group=
touch=
count=7
compress=1
set -- `$GETOPT m:o:u:g:c:lt $*`
if [ $# -eq 1 -o $? -ne 0 ]; then
    $ECHO "usage: $prog [-m mode][-o owner][-g group][-t][-c cycle][-l] file ..." 1>&2
    exit 11
fi
for i in $*; do
    case "$i" in
    -m) mode="$2"; shift 2;;
    -o) user="$2"; shift 2;;
    -u) user="$2"; shift 2;;
    -g) group="$2"; shift 2;;
    -c) count="$2"; shift 2;;
    -t) touch="1"; shift;;
    -l) compress=""; shift;;
    --) shift; break;;
    esac
done
if [ "$count" -lt 2 ]; then
    $ECHO "$prog: count must be at least 2" 1>&2
    exit 12
fi

# cycle thru filenames
while [ $# -gt 0 ]; do

    # get the filename
    filename="$1"
    shift

    # catch files that are not regular files
    #
    if [ -d "$filename" -o -b "$filename" -o \
	 -c "$filename" -o -p "$filename" ]; then
	$ECHO "$prog: $filename is not a regular file" 1>&2
	exitcode=13
	continue
    fi
    #
    # Testing for symbolic links is a problem ...
    #
    # Some /bin/sh's do not have [ -L foo ]
    # Some require [ -h foo ]
    # Some claim that /bin/test -L will go away someday
    #      but still have it
    #
    # For all of these conclicting claims, /bin/test -h seems
    # to be the most available.
    #
    if $TEST -h "$filename" 2>/dev/null; then
	$ECHO "$prog: $filename is symlink" 1>&2
	exitcode=14
	continue
    fi

    # if an missing or empty file, create/touch it and move on
    #
    if [ ! -s "$filename" ]; then
	# touch it if -t was given
	if [ ! -z "$touch" ]; then
	    (:> "$filename") 2>/dev/null
	    if [ ! -f "$filename" ]; then
		$ECHO "$prog: could not touch $filename" 1>&2
		exitcode=15
		continue
	    fi
	fi
	# force mode, group and/or mode as directed by -o, -g and/or -m
	if [ -f "$filename" ]; then
	    if [ ! -z "$user" ]; then
		$CHOWN "$user" "$filename"
	    fi
	    if [ ! -z "$group" ]; then
		$CHGRP "$group" "$filename"
	    fi
	    if [ ! -z "$mode" ]; then
		$CHMOD "$mode" "$filename"
	    fi
	fi
	continue
    fi

    # be sure that the savedir exists and is writable
    savedir=`$EXPR "$filename" : '\(.*\)/'`
    if [ -z "$savedir" ]; then
	savedir=./OLD
    else
	savedir="$savedir/OLD"
    fi
    if [ ! -s "$savedir" ]; then
	$MKDIR -p "$savedir"
	if [ $? -ne 0 ]; then
	    $ECHO "$prog: could not mkdir $savedir" 1>&2
	    exitcode=16
	    continue
	fi
	$CHMOD 0755 "$savedir"
    fi
    if [ ! -d "$savedir" ]; then
	$ECHO "$prog: $savedir is not a directory" 1>&2
	exitcode=17
	continue
    fi
    if [ ! -w "$savedir" ]; then
	$ECHO "$prog: directory $savedir is not writable" 1>&2
	exitcode=18
	continue
    fi

    # deterine our uncompressed file names
    newname=`$EXPR "$filename" : '.*/\(.*\)'`
    if [ -z "$newname" ]; then
	newname="$savedir/$filename"
    else
	newname="$savedir/$newname"
    fi

    # cycle the old compressed log files
    cycle=`$EXPR "$count" - 1`
    $RM -f "$newname.$cycle" "$newname.$cycle$DOT_Z"
    while [ "$cycle" -gt 1 ]; do
	# --cycle
	oldcycle="$cycle"
	cycle=`$EXPR "$cycle" - 1`
	# cycle log
	if [ -f "$newname.$cycle$DOT_Z" ]; then
	    $MV -f "$newname.$cycle$DOT_Z" "$newname.$oldcycle$DOT_Z"
	fi
	if [ -f "$newname.$cycle" ]; then
	    # file was not compressed for some reason move it anyway
	    $MV -f "$newname.$cycle" "$newname.$oldcycle"
	fi
    done

    # compress the old uncompressed log if needed
    if [ -f "$newname.0" ]; then
	if [ -z "$compress" ]; then
	    newfile="$newname.1"
	    $MV -f "$newname.0" "$newfile"
	else
	    newfile="$newname.1$DOT_Z"
	    $RM -f "$newfile"
	    # NOTE: gzip uses $GZIP as the default set of args
	    $GZIP_BINARY -c "$newname.0" > "$newfile"
	    $RM -f "$newname.0"
	fi
	if [ ! -z "$user" ]; then
	    $CHOWN "$user" "$newfile"
	fi
	if [ ! -z "$group" ]; then
	    $CHGRP "$group" "$newfile"
	fi
	if [ ! -z "$mode" ]; then
	    $CHMOD "$mode" "$newfile"
	fi
    fi

    # move the file into the file.0 holding place
    $MV -f "$filename" "$newname.0"

    # replace file if needed
    if [ ! -z "$touch" -o ! -z "$user" -o ! -z "$group" -o ! -z "$mode" ]; then
	(:> "$filename") 2>/dev/null
	if [ ! -f "$filename" ]; then
	    $ECHO "$prog: could not touch $filename" 1>&2
	    exitcode=19
	    continue
	fi
    fi
    if [ ! -z "$user" ]; then
	$CHOWN "$user" "$filename"
    fi
    if [ ! -z "$group" ]; then
	$CHGRP "$group" "$filename"
    fi
    if [ ! -z "$mode" ]; then
	$CHMOD "$mode" "$filename"
    fi

    # fix the permissions on the holding place file.0 file
    if [ ! -z "$user" ]; then
	$CHOWN "$user" "$newname.0"
    fi
    if [ ! -z "$group" ]; then
	$CHGRP "$group" "$newname.0"
    fi
    if [ ! -z "$mode" ]; then
	$CHMOD "$mode" "$newname.0"
    fi
done
exit "$exitcode"
