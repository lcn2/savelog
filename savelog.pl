#!/usr/bin/perl -wT
#
# savelog - save old log files and prep for web indexing
#
# @(#) $Revision: 1.3 $
# @(#) $Id: savelog.pl,v 1.3 2000/01/21 15:30:36 chongo Exp chongo $
# @(#) $Source: /usr/local/src/etc/savelog/RCS/savelog.pl,v $
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
#
###
#
# usage: savelog [-m mode] [-M mode] [-o owner] [-g group] [-c cycle]
#		 [-n] [-z] [-T] [-l] [-v]
#		 [-i type [-I typedir]] [-a OLD] [-A archive] file ...
#
#	-m mode	   - chmod current files to mode (def: 0644)
#	-M mode	   - chmod archived files to mode (def: 0444)
#	-o owner   - chown files to user (def: do not chown)
#	-g group   - chgrp files to group (def: do not chgrp)
#	-c count   - cycles of the file to keep, 0=>unlimited (def: 7)
#	-n	   - gzip the most recent cycle now (def: wait 1 cycle)
#	-z	   - force the processing of empty files (def: don't)
#	-T	   - do not create if missing
#	-l	   - do not gziped any new files (def: gzip after 1st cycle)
#	-v	   - enable verbose / debug mode
#	-i type	   - form index files of a given type (def: don't)
#	-I typedir - type file prog dir (def: /usr/local/lib/savelog)
#	-a OLD	   - OLD directory name (not a path) (def: OLD)
#	-A archive - form archive symlink for gzip files (def: don't)
#	file 	   - log file names
#
# FYI:
#	-t	   - (option is ignored, backward compat with Smail savelog)
#
# The savelog tool can archive, compress (gzip) and index files such as
# mailboxes or log files.  Care is taken to ensure that:
#
#	* If a file exists, then there will be some file by the same name
#	  during the savelog processing (avoids time gaps where the
#	  file is missing).
#
#	* The current file is renamed but it otherwise kept untouched in
#	  the same file system for 1 cycle (in case some process still
#	  has it open for writing).
#
#	* Permission and ownership are preserved as command args request.
#
###
#
# By default, given a file:
#
#	/a/path/file
#
# will be archived into an OLD sub-directory:
#
#	/a/path/OLD
#
#	[[ The ``-a OLDname'' can rename OLD to another so long as 
#	   it is directly under the same directory as the file. ]]
#
# The archived and compressed (gziped) cycle of the file have names such as:
#
#	/a/path/OLD/file.948209998-948296401.gz
#
# where the 1st number, '948209998' is the timestamp when the file
# was first created (started to be use) and the 2nd number '948296401'
# is when the file was moved aside.  Thus the file was active approximately
# between the same 948209998 and 948296401.  This range is approximate
# because on the first cycle, it is possible that some process still
# had the file opened for writing and later flushed its buffers into it.
#
#	[[ NOTE: The timestamps are determined by POSIX P1003.1 ``seconds 
#	   since the the Epoch'' which is effectively the number of 1 second
#	   intervals since 1970-01-01 00:00:00 UTC epoch not counting 
#	   leap seconds. ]]
#
###
#
# In order to deal with the possibility that some process may still have file
# open for writing, the file is renamed but otherwise not touched for a cycle.
# Thus, by default, the most recent cycle of the file is not gziped and
# will be found in a name (without the .gz) such as:
#
#	/a/path/OLD/file.948209998-948296401
#
#	[[ NOTE: If '-n' is given, then this file is immediately gziped
#	   when it is formed instead of waiting a cycle. ]]
#
# Any previously archived files (files of the form name.timestamp-timestamp)
# found in OLD that are not gziped will be gziped during savelog processing
# unless '-l' was given.  The '-l' option prevents the 1st cycle from
# being gziped as well as preventing other archived files from being gziped.
#
###
#
# When a new file is put in place, it is hard linked to a file under the
# OLD directory with a single timestamp in its name.  I.e.,
#
#	ln /a/path/file /a/path/OLD/file.948346647
#
# where '948346647' is the time of when the link was made.  On the next
# cycle, this linked file is renamed to:
#
#	/a/path/OLD/file.948346647-948433048
#
# where '948433048' is the time when the move took place.  Also as a result
# a new empty /a/path/file is hard linked to:
#
#	/a/path/OLD/file.948433048
#
# It is possible that the file is removed and replaced in-between cycles
# resulting in the hard link breaking.  If savelog finds that the file
# is no longer linked to the new timestamp copy, savelog will reform the
# link before processing the file further.
#
###
#
# When '-i type' is given an parallel index file is created when a file
# is archived.  Index files are of the form:
#
#	/a/path/OLD/file.948346647-948433048.indx
#
# An index file consists of lines with two fields:
#
#	byte offset 		name of the index
#
# followed by a single byte offset indicating the length of the file.
#
# For example:
#
#	0	the 1st item
#	1345	the 2nd item
#	2755	the 3rd item
#	4105
#
# In the above example, bytes 1345 to 2774 refer to a block of text
# called 'the 2nd item'.
#
# What constitutes a block of text depends on the 'type' given with the
# flag.  For example, '-i mail' will search for starts of mail messages
# and tag them with the subject line or (no subject).  For example:
#
#	0	A mail message subject line
#	3507	Another subject line
#	6628	(no subject)
#	9345	A mail message subject line
#	10125
#
# By default, savelog uses the program found under /usr/local/lib/savelog
# that as the same name as type.  The '-I typedir' can change the location
# of this type forming script.  For example:
#
#	-i ipchain -I /some/test/dir
#
# Will cause savelog to look for the program:
#
#	/some/test/dir/ipchain
#
# If this file does not exist or is not executable, savelog will not
# process the file.
#
###
#
# One can control the number of cycles that savelog will archive a file
# via the '-c count' option.  By default savelog keeps 7 cycles.
#
# If '-c 1' is given, then only the plaintext cycle file is kept.
# If '-c 2' is given, the plaintext file and 1 gziped file is kept.
# If '-c 3' is given, the plaintext file and 2 gziped files are kept.
#
# When savelog finds that too many cycles exist, it will removed those
# with the oldest starting timestamps until the number of cycles is
# reduced.  For example, if ``-c 3'' is given and the follow files exist:
#
#	/a/path/OLD/file.947482648	(doesn't count, linked to current file)
#	/a/path/OLD/file.947396249-947482648		(cycle 1)
#	/a/path/OLD/file.947309849-947396249.gz		(cycle 2)
#	/a/path/OLD/file.947223450-947309849.gz		(cycle 3)
#	/a/path/OLD/file.947137050-947223450.gz		(cycle 4)
#	/a/path/OLD/file.947050649-947137050.gz		(cycle 5)
#
# Then the files associated with cycle 4 and 5 would be removed.  Also
# the file associated with cycle would be removed if /a/path/file was
# processed (say because it was non-empty).  This 3 cycle files would
# remain afterwards:
#
#	/a/path/OLD/file.947569049	(doesn't count, linked to current file)
#	/a/path/OLD/file.947482648-947569049		(new cycle 1)
#	/a/path/OLD/file.947396249-947482648.gz		(new cycle 2)
#	/a/path/OLD/file.947309849-947396249.gz		(new cycle 3)
#
# The count of 0 means that all cycles are to be kept.  Cycles of < 0
# are reserved for future use.
#
# Index files are removed when their corresponding archive file is removed.
#
###
#
# It is possible to preserve space in the file's filesystem by placing
# gziped files into another directory.  If the OLD directory contains a
# symlink named 'archive':
#
#	/a/path/OLD/archive -> /b/history/directory
#
# then files will be gziped into the path:
#
#	/a/path/OLD/archive/file.948209998-948296401.gz
#
# which, by way of the archive symlink, will be placed into:
#
#	/b/history/directory/file.948209998-948296401.gz
#
# 	[[ NOTE: The '-A archive' file will cause the archive symlink.
#	   to be created (or changed if it existed previously).  Savelog
#	   will create a directory where the archive symlink points
#	   if one does not exist already.  If savelog cannot do this, then
#	   savelog will refuse to run.
#
#	   If one does create the archive symlink, it is recommended that 
#	   any previously gziped and indexed files be moved into the new 
#	   archive directory.  This is because savelog will ignore any
#	   gziped files directly under OLD when the archive symlink exists.
#
#	   Non-gziped files under OLD will remain under OLD and will
#	   continue to be moved under OLD regardless of if 'archive'
#	   exists or not.  However when the non-gziped newest cycle
#	   is gziped, it will be gziped into the archive directory. ]]
#
###
#
# If '-z' is used, then a file will be processed ONLY if it is not empty.
# If the file does not exist, savelog will create it.  The '-T' flag will
# prevent creation of missing files.  Missing files are never processed.
# Therefore:
#
#	args		empty file		missing file
#	----
#	(default)	do not process		create empty but do not process
#	-z		process file		create and then process
#	-T		do not process		do not create or process
#	-z -T		process file		do not create or process
#
###
#
# The following prechecks are performed at the start of savelog:
#
#	-1) Precheck: 	:-)
#
#	     * case no -a and no -A:
#		+ If /a/path/OLD exists, it must be a writable directory
#		  or we will abort.
#		+ If /a/path/OLD does not exist and we cannot create it
#		  as a writable directory, we will abort.
#		+ If /a/path/OLD/archive exists, it must be a writable directory
#		  or a symlink that points to a writable directory or we 
#		  will abort.
#
#	     * case -a FOO and no -A:
#		+ If /a/path/FOO exists, it must be a writable directory
#		  or we will abort.
#		+ If /a/path/FOO does not exist and we cannot create it
#		  as a writable directory, we will abort.
#		+ If /a/path/FOO/archive exists, it must be a writable directory
#		  or a symlink that points to a writable directory or we 
#		  will abort.
#
#	     * case -A /some/path:
#		+ If /a/path/OLD exists, it must be a writable directory
#		  or we will abort.
#		+ If /a/path/OLD does not exist and we cannot create it
#		  as a writable directory, we will abort.
#		+ If /some/path exists, it must be a writable directory
#		  or a symlink that points to a writable directory or we 
#		  will abort.
#		+ If /some/path not exist and we cannot create it
#		  as a writable directory, we will abort.
#		+ If /a/path/OLD/archive exists and is not a symlink,
#		  we will abort.
#		+ If /a/path/OLD/archive is a symlink and we cannot replace
#		  it with a symlink that points the /some/path directory
#		  then we will abort.
#
#	     * case -a FOO and -A /some/path:
#		+ If /a/path/FOO exists, it must be a writable directory
#		  or we will abort.
#		+ If /a/path/FOO does not exist and we cannot create it
#		  as a writable directory, we will abort.
#		+ If /some/path exists, it must be a writable directory
#		  or a symlink that points to a writable directory or we 
#		  will abort.
#		+ If /some/path not exist and we cannot create it
#		  as a writable directory, we will abort.
#		+ If /a/path/FOO/archive exists and is not a symlink,
#		  we will abort.
#		+ If /a/path/FOO/archive is a symlink and we cannot replace
#		  it with a symlink that points the /some/path directory
#		  then we will abort.
#
#	    * case -i indx_type and no -I:
#		+ /usr/local/lib/savelog/indx_type must be an executable
#		  file or we will abort.
#
#	    * case -i indx_type and -I /indx/prog/dir:
#		+ /indx/prog/dir/indx_type must be an executable
#		  file or we will abort.
#
#	   Assertion: The args are reasonable sane.  The proper directories
#		      and if needed, executable files exist.
#
#   NOTE: As this point we will carry on as of -a FOO was not given.
#	  If it was, replace 'OLD' with 'FOO' below.
#
#   NOTE: As this point we will carry on as of -I /some/dir was not given.
#	  If it was, replace /usr/local/lib/savelog with '/some/dir' below.
#
# The order of processing of /a/path/file is as follows:
#
#	0) Determine if /a/path/file exists.  Touch it (while setting the
#	   proper mode, uid and gid) if it does not unless -T was given.
#	   Do nothing else if the file missing and was not created.
#
#	   Assertion: At this point the file exists or we have stopped.
#
#	1) Determine if /a/path is empty.  Do nothing else if empty
#	   unless -z was given.
#
#	   Assertion: At this point the file is non-empty or -z was given
#		      and the file is empty.
#
#	2) Remove all but the newest count-1 cycles and, if they exist
#	   unless count is 0.  Remove any index file that is not associated 
#	   with a (non-removed) file.  Files are removed from under /a/path/OLD
#	   or from under /a/path/OLD/archive if archive exists.
#
#	   Assertion: At this point only count-1 cycles exist, or '-c 0'
#		      was given and no files were removed.
#
#	3) If more than one file of the form: /a/path/OLD/file.tstamp exists,
#	   then all but the newest timestamp are renamed to files of the form:
#	   /a/path/OLD/file.time-time (files with two timestamps with
#	   the same time).  The exception is if one of those files is hardlinked
#	   to /a/path/file.  If that is the case, then that file, not the
#	   file with the newest timestamp, is not renamed.
#
#	   Assertion: At this point, either 1 or 0 files of the form:
#		      /a/path/OLD/file.tstamp exist.
#
#	4) Gzip the all files of the form: /a/path/OLD/file.tstamp1-tstamp2
#	   unless -t was given.   Files will be placed under /a/path/OLD or 
#	   /a/path/OLD/archive if -A was given.  If -t was given, then
#	   no files will be gziped.
#
#	   Assertion: At this point, all files of the form file.tstamp1-tstamp2
#		      have been gziped, or -t was given and no additional files
#		      were gziped.
#
#	5) If /a/path/OLD/file.tstamp is not hard linked to /a/path/file,
#	   when remove /a/path/OLD/file.tstamp and relink /a/path/file to it.
#	   If /a/path/OLD/file.tstamp does not exist, then link /a/path/file
#	   to /a/path/OLD.file.now-tstamp where 'now-tstamp' is the current
#	   timestamp.
#
#	   Assertion: /a/path/OLD/file.tstamp exists and is hard linked
#		      to /a/path/file.
#
#	7) Create /a/path/.file.new with the proper mode, uid and gid.
#
#	   Assertion: /a/path/.file.new exists with the proper mode, uid & gid.
#
#	8) Move /a/path/.file.new to /a/path/file (and thus unlinking the
#	   old /a/path/file inode).
#
#	   Assertion: /a/path/file exists with the proper mode, uid and gid.
#
#	   Assertion: The file /a/path/OLD/file.tstamp (referred to in 
#		      step 6) exists and is not had linked to /a/path/file.
#
#	9) The file /a/path/OLD/file.tstamp (referred to in step 6) is
#	   renamed /a/path/file.tstamp-now where now is the current timestamp.
#
#	   Assertion: The file /a/path/file.tstamp-now exists.
#
#      10) The file /a/path/file is hardlinked to /a/path/OLD/file.now
#	   (now is the timestamp referred to in step 9).
#
#	   Assertion: The file /a/path/OLD/file.now exists and is hard linked
#		      to /a/path/file.
#
#      11) If -i, then /usr/local/lib/savelog /a/path/OLD/file.tstamp-now
#	   is executed to form /a/path/OLD/file.tstamp-now.indx.  If -i was
#	   not given, we will skip this step.
#
#	   Assertion: The file /a/path/OLD/file.tstamp-now exists.
#
#	   Assertion: The file /a/path/OLD/file.tstamp-now.indx exists and
#		      -i was given.
#
#      12) If -n was given, the gzip /a/path/OLD/file.tstamp-now.  Place the
#	   result under /a/path/OLD or /a/path/OLD/archive if -A was given.
#	   If -n was not given, then we will ship this step.
#
#	   Assertion: The file /a/path/OLD/file.tstamp-now.gz exists and -n
#		      was given.
#
###

# requirements
#
use strict;
use vars qw($opt_m $opt_M $opt_o $opt_g $opt_c $opt_n
	    $opt_n $opt_z $opt_T $opt_l $opt_v
	    $opt_i $opt_I $opt_a $opt_A);
use Getopt::Std;

# my vars
#
my $usage;		# usage message
my $file_mode;		# set files to this mode
my $archive_mode;	# set archived files to this mode
my $file_uid;		# file owner or undefined
my $file_gid;		# group owner or undefined
my $cycle;		# number of cycles to keep in archive
my $verbose;		# defined if verbose DEBUG mode is on
my $indx_prog;		# indexing program of undefined
my $old_name;		# name of the OLD directory
my $archive_dir;	# where the archive symlink should point
#
my $exit_val;		# how we will exit

# setup
#
$usage = "usage:\n" .
	 "$0 [-m mode] [-M mode] [-o owner] [-g group] [-c cycle]\n" .
	 "\t[-n] [-z] [-T] [-l] [-v]\n" .
	 "\t[-i indx_type [-I typedir]] [-a OLD] [-A archive] file ...\n" .
	 "\t\n" .
	 "\t-m mode\t chmod current files to mode (def: 0644)\n" .
	 "\t-M mode\t chmod archived files to mode (def: 0444)\n" .
	 "\t-o owner\t chown files to user (def: do not chown)\n" .
	 "\t-g group\t chgrp files to group (def: do not chgrp)\n" .
	 "\t-c count\t cycles of the file to keep, 0=>unlimited (def: 7)\n" .
	 "\t-n\t gzip the most recent cycle now (def: wait 1 cycle)\n" .
	 "\t-z\t force the processing of empty files (def: don't)\n" .
	 "\t-T\t do not create if missing\n" .
	 "\t-l\t do not gziped any new files (def: gzip after 1st cycle)\n" .
	 "\t-i indx_type\t form index files of a given type (def: don't)\n" .
	 "\t-I typedir\t type file prog dir (def: /usr/local/lib/savelog)\n" .
	 "\t-a OLD\t OLD directory name (not a path) (def: OLD)\n" .
	 "\t-A archive\t form archive symlink for gzip files (def: don't)\n" .
	 "\tfile ...\tlog file names\n";

# main
#
MAIN:
{
    # my vars
    #
    my $file;		# the current file we are processing

    # parse args
    #
    $exit_val = 0;	# hope for the best
    &parse();

    # process each file
    #
    foreach $file (@ARGV) {
	
	# pre-check file
	#
	print "\n" if $verbose;
	if (! -f $file) {
	    &warning(20, "cannot read: $file, skipping");
	    next;
	}

	# process the file
	#
	&savelog($file);
    }

    # all done
    #
    print "\nDEBUG: exit code: $exit_val\n" if $verbose;
    exit $exit_val;
}


# error - report an error and exit
#
# usage:
#	&error(exitcode, "error format" [,arg ...])
#
sub error($$$)
{
    # parse args
    #
    my ($code, $fmt, $args) = @_;
    $fmt = "<<no error message given>>" unless defined $fmt;
    $code = 1 unless defined $code;

    # issue message
    #
    print STDERR "$0: ERROR: ";
    if (defined $args) {
    	printf STDERR $fmt, $args;
    } else {
    	print STDERR $fmt;
    }
    print STDERR "\n";

    # exit
    #
    print "DEBUG: exit code was: $exit_val\n" if $verbose;
    $exit_val = $code;
    print "DEBUG: exit code: $exit_val\n" if $verbose;
    exit $exit_val;
}


# warning - report an problem and continue
#
# usage:
#	&warning(exitcode, "error format" [,arg ...])
#
# NOTE: Unlike
#
sub warning($$$)
{
    # parse args
    #
    my ($code, $fmt, $args) = @_;
    $fmt = "<<no warning message given>>" unless defined $fmt;
    $code = 1 unless defined $code;

    # issue message
    #
    print STDERR "$0: Warn: ";
    if (defined $args) {
    	printf STDERR $fmt, $args;
    } else {
    	print STDERR $fmt;
    }
    print STDERR "\n";

    # set the exit code but do not exit
    #
    print "DEBUG: exit code was: $exit_val\n" if $verbose;
    $exit_val = $code;
    print "DEBUG: exit code is now: $exit_val\n" if $verbose;
}


# parse - parse the command line args
#
# usage:
#	&parse()
#
# NOTE: This function cannot check or process the OLD archive dir name nor the
#	archive symlink because they are relative to the directories of each
#	of the file args.  That checking must occur later.
#
sub parse()
{

    # my local vars
    #
    my $indx_type;		# type of indexing to perform or undefined
    my $indx_dir;		# directory containing indexing progs

    # defaults
    #
    $verbose = undef;
    $file_mode = 0644;
    $archive_mode = 0444;
    $file_uid = undef;
    $file_gid = undef;
    $cycle = 7;
    $verbose = undef;
    $indx_type = undef;
    $indx_dir = "/usr/local/lib/savelog";
    $indx_prog = undef;
    $old_name = "OLD";
    $archive_dir = undef;

    # parse args
    #
    if (!getopts('m:M:o:g:c:nzTlvi:I:a:A:') || !defined($ARGV[0])) {
    	die $usage;
	exit 1;
    }

    # -v
    #
    $verbose = $opt_v if defined $opt_v;
    print "DEBUG: verbose mode: set\n" if $verbose;

    # -m mode
    #
    $file_mode = oct($opt_m) if defined $opt_m;
    if ($file_mode != 0644 && $verbose) {
	printf "DEBUG: using non-default file mode: 0%o\n", $file_mode;
    }

    # -M mode
    #
    $archive_mode = oct($opt_M) if defined $opt_M;
    if ($archive_mode != 0444 && $verbose) {
	printf "DEBUG: using non-default archive mode: 0%o\n", $archive_mode;
    }

    # -o owner
    #
    if (defined($opt_o)) {
	$file_uid = getpwnam($opt_o) if defined $opt_o;
	if (!defined($file_uid)) {
	    &error(2, "no such user: $opt_o");
	}
	print "DEBUG: set file uid: $file_uid\n" if $verbose;
    }

    # -g group
    #
    if (defined($opt_g)) {
	$file_gid = getgrnam($opt_g) if defined $opt_g;
	if (!defined($file_gid)) {
	    &error(3, "no such group: $opt_g");
	}
	print "DEBUG: set file uid: $file_gid\n" if $verbose;
    }

    # -c cycle
    #
    $cycle = $opt_c if defined $opt_c;
    if ($cycle < 0) {
	&error(4, "cycles to keep: $cycle must be >= 0");
    }

    # -i indx_type
    #
    if (defined $opt_i) {
	$indx_type = $opt_i;
	if ($indx_type =~ m:[/~*?[]:) {
	    &error(5, "index type may not contain /, ~, *, ?, or [");
	}
	if ($indx_type eq "." || $indx_type eq "..") {
	    &error(6, "index type type may not be . or ..");
	}
	print "DEBUG: index type: $indx_type\n" if $verbose;
    }

    # -I typedir
    #
    if (defined $opt_I) {
	if (!defined $opt_i) {
	    &error(7, "use of -I typedir requires -i indx_type");
	}
	if (! -d $opt_I) {
	    &error(8, "no such index type directory: $opt_I");
	}
	$indx_dir = $opt_I;
	print "DEBUG: index prog dir: $indx_dir\n" if $verbose;
    }
    if (defined($indx_type)) {
    	if (! -x "$indx_dir/$indx_type") {
	    &error(9, "index type prog: $indx_type not found in: $indx_dir");
	}
	$indx_prog = "$indx_dir/$indx_type";
	print "DEBUG: indexing prog: $indx_prog\n" if $verbose;
    }

    # -a OLDname
    #
    $old_name = $opt_a if defined $opt_a;
    if ($old_name =~ m:[/~*?[]:) {
	&error(10, "OLD dir name may not contain /, ~, *, ?, or [");
    }
    if ($old_name eq "." || $old_name eq "..") {
	&error(11, "OLD dir name may not be . or ..");
    }
    if ($old_name ne "OLD" && $verbose) {
	print "DEBUG: using non-default OLD name: $old_name\n" if $verbose;
    }

    # -A archive_dir
    #
    if (defined $opt_A) {
	if (! -d $opt_A) {
	    &error(12, "archive directory not found: $opt_A");
	}
	$archive_dir = $opt_A;
	print "DEBUG: archive directory: $archive_dir\n" if $verbose;
    }

    # must have at least one arg
    #
    die $usage unless defined $ARGV[0];
    print "DEBUG: end of argument parse\n" if $verbose;
}


# savelog - archive a file
#
sub savelog($)
{
    # parse args
    #
    my $file = $_[0];	# file name to save

    # archvie setup
    #
    print "DEBUG: starting to process: $file\n" if $verbose;
}
