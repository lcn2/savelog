#!/usr/bin/perl -Tw
#
# savelog - save old log files and prep for web indexing
#
# @(#) $Revision: 1.10 $
# @(#) $Id: savelog.pl,v 1.10 2000/01/27 18:51:17 chongo Exp chongo $
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
#		 [-n] [-1] [-z] [-T] [-l] [-v]
#		 [-i type [-I typedir]] [-a OLD] [-A archive] file ...
#
#	-m mode	   - chmod current files to mode (def: 0644)
#	-M mode	   - chmod archived files to mode (def: 0444)
#	-o owner   - chown files to user (def: do not chown)
#	-g group   - chgrp files to group (def: do not chgrp)
#	-c count   - cycles of the file to keep, 0=>unlimited (def: 7)
#	-n	   - do not do anything, just print cmds (def: do something)
#	-1	   - gzip the new 1st cycle now (def: wait 1 cycle)
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
#	[[ NOTE: If '-1' is given, then this file is immediately gziped
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
#   NOTE: If -n was given, we will not perform any actions, just go thru
#	  the motions and print shell commands that perform the equivalent
#	  of what would happen.
#
# The order of processing of /a/path/file is as follows:
#
#	0) Determine if /a/path/file exists.  Touch it (while setting the
#	   proper mode, uid and gid) if it does not unless -T was given.
#	   Do nothing else if the file missing and was not created.
#
#	   Assertion: At this point the file exists or we have stopped.
#
#	1) Determine if /a/path/file is empty.  Do nothing else if empty
#	   unless -z was given.
#
#	   Assertion: At this point the file is non-empty or -z was given
#		      and the file is empty.
#
#	2) Remove all but the newest count-1 cycles and, if they exist
#	   unless count is 0.  Remove any index file that is not associated
#	   with a (non-removed) file.  If both foo and foo.gz are found,
#	   the foo file will be removed.  Files are removed from under
#	   /a/path/OLD or from under /a/path/OLD/archive if archive exists.
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
#      12) If -1 was given, the gzip /a/path/OLD/file.tstamp-now.  Place the
#	   result under /a/path/OLD or /a/path/OLD/archive if -A was given.
#	   If -1 was not given, then we will ship this step.
#
#	   Assertion: The file /a/path/OLD/file.tstamp-now.gz exists and -1
#		      was given.
#
###

# requirements
#
use strict;
use English;
use vars qw($opt_m $opt_M $opt_o $opt_g $opt_c
	    $opt_n $opt_1 $opt_z $opt_T $opt_l $opt_v
	    $opt_i $opt_I $opt_a $opt_A);
use Getopt::Std;
$ENV{PATH} = "/sbin:/bin:/usr/sbin:/usr/bin";
$ENV{IFS} = " \t\n";
$ENV{SHELL} = "/bin/sh";
delete $ENV{ENV};
use Cwd;
use File::Basename;
use IO::File;
require 'syscall.ph';

# my vars
#
my $usage;		# usage message
my $file_mode;		# set files to this mode
my $archive_mode;	# set archived files to this mode
my $archdir_mode;	# mode for the OLD and archive directories
my $file_uid;		# file owner or undefined
my $file_gid;		# group owner or undefined
my $cycle;		# number of cycles to keep in archive
my $verbose;		# defined if verbose DEBUG mode is on
my $indx_prog;		# indexing program of undefined
my $oldname;		# name of the OLD directory
my $archive_dir;	# where the archive symlink should point
#
my $exit_val;		# how we will exit
my $cwd;		# initial current working directory
#
my $true = 1;		# truth as we know it
my $false = 0;		# genuine falseness

# setup
#
$usage = "usage:\n" .
	 "$0 [-m mode] [-M mode] [-o owner] [-g group] [-c cycle]\n" .
	 "\t[-n] [-1] [-z] [-T] [-l] [-v]\n" .
	 "\t[-i indx_type [-I typedir]] [-a OLD] [-A archive] file ...\n" .
	 "\t\n" .
	 "\t-m mode\t chmod current files to mode (def: 0644)\n" .
	 "\t-M mode\t chmod archived files to mode (def: 0444)\n" .
	 "\t-o owner\t chown files to user (def: do not chown)\n" .
	 "\t-g group\t chgrp files to group (def: do not chgrp)\n" .
	 "\t-c count\t cycles of the file to keep, 0=>unlimited (def: 7)\n" .
	 "\t-n\t gzip the most recent cycle now (def: wait 1 cycle)\n" .
	 "\t-n\t do not do anything, just print cmds (def: do something)\n" .
	 "\t-1\t gzip the new 1st cycle now (def: wait 1 cycle)\n" .
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
    my $filename;	# the current file we are processing
    my $dir;		# preped directory in which $filename resides
    my $file;		# basename of $filename
    my $gz_dir;		# where .gz files are to be placed

$opt_n = 1;	# XXX - DEBUG


    # setup
    #
    $exit_val = 0;	# hope for the best
    $cwd = cwd();

    # parse args
    #
    &parse();

# XXX - debug
#
# my (@list, @single, @gz, @plain, @double, @index);
# &scandir("foo", "OLD", "OLD/archive", \@list);
# print "scanned list\n", join("\n", @list), "\n";
# &cleanlist(\@list);
# print "\ncleaned list:\n", join("\n", @list), "\n";
# &splitlist(\@list, \@single, \@gz, \@plain, \@double, \@index);
# print "\nsingle list:\n", join("\n", @single), "\n";
# print "\ngz list:\n", join("\n", @gz), "\n";
# print "\nplain list:\n", join("\n", @plain), "\n";
# print "\ndouble list:\n", join("\n", @double), "\n";
# print "\nindex list:\n", join("\n", @index), "\n";
# print "\ncycles: $cycle, double last: $#double\n";
# if ($cycle > 0 && $#double ge $cycle-1) {
# &rmcycles(\@list, \@single, \@gz, \@plain, \@double, \@index);
# print "\nall list:\n", join("\n", @list), "\n";
# print "\nsingle list:\n", join("\n", @single), "\n";
# print "\ngz list:\n", join("\n", @gz), "\n";
# print "\nplain list:\n", join("\n", @plain), "\n";
# print "\ndouble list:\n", join("\n", @double), "\n";
# print "\nindex list:\n", join("\n", @index), "\n";
# }
# exit(0);

    # process each file
    #
    foreach $filename (@ARGV) {

	# prepare to process the file
	#
	print "\n" if $verbose;
	if (! &prepfile($filename, \$dir, \$file, \$gz_dir)) {
	    print STDERR "error while preparing for $filename, skipping\n";
	    next;
	}

	# archive the file
	#
	if (! &archive($filename, $dir, $file, $gz_dir)) {
	    print STDERR "error while processing $filename\n";
	    next;
	}
	print "DEBUG: finished with $filename\n" if $verbose;
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
sub error($$@)
{
    # parse args
    #
    my ($code, $fmt, @args) = @_;
    $fmt = "<<no error message given>>" unless defined $fmt;
    $code = 2 unless defined $code;

    # issue message
    #
    print STDERR "$0: ERROR: ";
    if (defined @args) {
    	printf STDERR $fmt, @args;
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
#	&warning(exitcode, "warning format" [,arg ...])
#
# NOTE: Unlike
#
sub warning($$@)
{
    # parse args
    #
    my ($code, $fmt, @args) = @_;
    $fmt = "<<no warning message given>>" unless defined $fmt;
    $code = 3 unless defined $code;

    # issue message
    #
    print STDERR "$0: Warn: ";
    if (defined @args) {
    	printf STDERR $fmt, @args;
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
    $oldname = "OLD";
    $archive_dir = undef;

    # parse args
    #
    if (!getopts('m:M:o:g:c:n1zTlvi:I:a:A:') || !defined($ARGV[0])) {
    	die $usage;
	exit 1;
    }

    # -v
    #
    $verbose = $opt_v if defined $opt_v;
    print "DEBUG: verbose mode: set\n" if $verbose;
    print "DEBUG: current directory: $cwd\n" if $verbose;

    # -m mode
    #
    $file_mode = oct($opt_m) if defined $opt_m;
    if ($file_mode != 0644 && $verbose) {
	printf "DEBUG: using non-default file mode: 0%03o\n", $file_mode;
    }

    # -M mode
    #
    $archive_mode = $opt_M if defined $opt_M;
    # turn on exec bits in $archdir_mode as well as any write bits
    # found in $archive_mode.
    if ($archive_mode != 0444) {
	printf "DEBUG: non-default archive mode: 0%03o\n", $archive_mode
	   if $verbose;
    	$archdir_mode = 0700;
	if (($archive_mode & 0060) != 0) {
	    $archdir_mode |= (($archive_mode & 0060) | 0010);
	}
	if (($archive_mode & 0006) != 0) {
	    $archdir_mode |= (($archive_mode & 0006) | 0001);
	}
	printf "DEBUG: non-default archive dir mode: 0%03o\n", $archdir_mode;
    } else {
    	$archdir_mode = 0755;
    }

    # -o owner
    #
    if (defined($opt_o)) {
	if ($EFFECTIVE_USER_ID == 0) {
	    if ($opt_o =~ m#^([\w.][\w.-]*)$#) {
		$opt_o = $1;
		$file_uid = getpwnam($opt_o);
	    }
	    if (!defined $file_uid) {
		&error(4, "parse: bad user: $opt_o");
	    }
	    print "DEBUG: set file uid: $file_uid\n" if $verbose;
        } else {
	    &error(5, "parse: only the superuser can use -o");
	}
    }

    # -g group
    #
    if (defined($opt_g)) {
	if ($EFFECTIVE_USER_ID == 0) {
	    if ($opt_g =~ m#^([\w.][\w.-]*)$#) {
		$opt_g = $1;
		$file_gid = getgrnam($opt_g);
	    }
	    if (!defined $file_gid) {
		&error(6, "parse: bad group: $opt_g");
	    }
	    print "DEBUG: set file gid: $file_gid\n" if $verbose;
        } else {
	    &error(7, "parse: only the superuser can use -g");
	}
    }

    # -c cycle
    #
    $cycle = $opt_c if defined $opt_c;
    if ($cycle < 0) {
	&error(8, "parse: cycles to keep: $cycle must be >= 0");
    }

    # -i indx_type
    #
    if (defined $opt_i) {
	$indx_type = $opt_i;
	if ($indx_type =~ m:[/~*?[]:) {
	    &error(9, "parse: index type may not contain /, ~, *, ?, or [");
	}
	if ($indx_type eq "." || $indx_type eq "..") {
	    &error(10, "parse: index type type may not be . or ..");
	}
	print "DEBUG: index type: $indx_type\n" if $verbose;
    }

    # -I typedir
    #
    if (defined $opt_I) {
	if (!defined $opt_i) {
	    &error(11, "parse: use of -I typedir requires -i indx_type");
	}
	if (! -d $opt_I) {
	    &error(12, "parse: no such index type directory: $opt_I");
	}
	$indx_dir = $opt_I;
	print "DEBUG: index prog dir: $indx_dir\n" if $verbose;
    }
    if (defined($indx_type)) {
    	if (! -x "$indx_dir/$indx_type") {
	    &error(13,
	    	"parse: index type prog: $indx_type not found in: $indx_dir");
	}
	$indx_prog = "$indx_dir/$indx_type";
	print "DEBUG: indexing prog: $indx_prog\n" if $verbose;
    }

    # -a OLDname
    #
    $oldname = $opt_a if defined $opt_a;
    if ($oldname =~ m:[/~*?[]:) {
	&error(14, "parse: OLD dir name may not contain /, ~, *, ?, or [");
    }
    if ($oldname eq "." || $oldname eq "..") {
	&error(15, "parse: OLD dir name may not be . or ..");
    }
    if ($oldname ne "OLD" && $verbose) {
	print "DEBUG: using non-default OLD name: $oldname\n" if $verbose;
    }

    # -A archive_dir
    #
    if (defined $opt_A) {
	$archive_dir = $opt_A;
	print "DEBUG: archive directory: $archive_dir\n" if $verbose;
    }

    # must have at least one arg
    #
    die $usage unless defined $ARGV[0];
    print "DEBUG: end of argument parse\n" if $verbose;
}


# prepfile - prepaire archive a file
#
# usage:
#	&prepfile($filename, \$dir_p, \$file_p, \$gz_dir_p)
#
#	$filename	path of preped filename to archive
#	\$dir_p		ref to preped directory of $filename
#	\$file_p	ref to basename of $filename
#	\$gz_dir_p	ref to where .gz files are to be placed
#
# returns:
#	0 ==> prep was unsuccessful
#	1 ==> prep was successful
#
sub prepfile($\$\$\$)
{
    # my vars
    #
    my ($filename, $dir_p, $file_p, $gz_dir_p) = @_;	# parse args
    my $dir;			# dirname of $filename (dir where file exists)
    my $file;			# basename of $filename (file within $dir)
    my $gz_dir;			# directory where .gz files are kept
    my $mode;			# stated mode of a file or directory
    my ($dev1, $dev2, $inum1, $inum2);	# dev/inum of two inodes

    # untaint the filename
    #
    if ($filename =~ m#^([-\@\w./+:%][-\@\w./+:%~]*)$#) {
    	$filename = $1;
    } else {
	&warning(16, "filename has dangerious chars: $filename");
	return $false;
    }
    print "DEBUG: starting to process: $filename\n" if $verbose;
    print "\n# starting to process: $filename\n" if defined $opt_n;

    # determine, untaint and cd to the file's directory
    #
    $dir = dirname($filename);
    if ($dir !~ m:^/:) {
    	if ($dir eq ".") {
	    $dir = $cwd;
	} else {
	    $dir = "$cwd/$dir";
	}
    }
    if ($dir =~ m#^([-\@\w./+:%][-\@\w./+:%~]*)$#) {
    	$dir = $1;
    } else {
	&warning(17, "file directory has dangerious chars: $dir");
	return $false;
    }
    if (! chdir($dir)) {
    	&warning(18, "cannot cd to $dir");
	return $false;
    }
    print "cd $dir\n" if defined $opt_n;
    print "DEBUG: working directory: $dir\n" if $verbose;

    # make sure that the OLD directory exists
    #
    if (! -d $oldname) {
	if (! mkdir($oldname, $archdir_mode)) {
	    &warning(19, "cannot mkdir: $dir/$oldname");
	    return $false;
	} else {
	    print "DEBUG: created $dir/$oldname\n" if $verbose;
	}
    }

    # If we were asked to use an archive subdir of OLD, be sure that it exists,
    # is in the right location, has the right mode and is writable
    #
    if (defined($archive_dir)) {

        # untaint archive_dir
	#
	if ($archive_dir =~ m#^([-\@\w./+:%][-\@\w./+:%~]*)$#) {
	    $archive_dir = $1;
	} else {
	    &error(20,
	    	"prepfile: archive dir has dangerious chars: $archive_dir");
	}

	# The archive directory must exist
	#
	if (! -d $archive_dir) {
	    &error(21,
	    	"prepfile: archive dir: $archive_dir is not a directory");

	# If we have an OLD/archive is a symlink, make it point to archive_dir
	#
	} elsif (-l "$oldname/archive") {

	    # determine if OLD/archive points to archive_dir
	    #
	    ($dev1, $inum1, undef) = stat("$oldname/archive");
	    ($dev2, $inum2, undef) = stat($archive_dir);
	    if (!defined($dev2) || !defined($inum2)) {
	    	&error(22, "prepfile: cannot stat archive dir: $archive_dir");
	    }
	    if (!defined($dev1) || !defined($inum1) ||
	    	$dev1 != $dev2 || $inum1 != $inum2) {

		# OLD/archive points to a different place (or nowhere), so
		# we must remove it and form it as a symlink to archive_dir
		#
		if (!unlink("$oldname/archive") ||
		    !symlink($archive_dir, "$oldname/archive")) {
		    &warning(23,
			     "cannot symlink $oldname/archive to $archive_dir");
		    return $false;
		}
		printf("DEBUG: symlink %s to %s\n",
		       "$oldname/archive", $archive_dir) if $verbose;
	    }

	} elsif (-d "$oldname/archive") {

	    # determine if OLD/archive points to archive_dir
	    #
	    ($dev1, $inum1, undef) = stat("$oldname/archive");
	    ($dev2, $inum2, undef) = stat($archive_dir);
	    if (!defined($dev2) || !defined($inum2)) {
	    	&error(24, "prepfile: can't stat archive dir: $archive_dir");
	    }
	    if (!defined($dev1) || !defined($inum1) ||
	    	$dev1 != $dev2 || $inum1 != $inum2) {
	    	&warning(25,
		    "$oldname/archive is a directory and is not $archive_dir");
	    	return $false;
	    }

	# No OLD/archive exists, so make is a symlink to archive_dir
	#
	} else {

	    # make OLD/archive a symlink to the archive_dir
	    #
	    if (!symlink($archive_dir, "$oldname/archive")) {
		&warning(26, "cannot symlink $oldname/archive to $archive_dir");
		return $false;
	    }
	    printf("DEBUG: symlinked %s to %s\n",
		   "$oldname/archive", $archive_dir) if $verbose;
	}
	$gz_dir = "$dir/$oldname/archive";

    # If we were not asked to use an archive subdir of OLD but one
    # exists anyway, be sure it has the right mode and is writable
    #
    } elsif (-d "$oldname/archive") {

	# archive is a directory, so OLD/archive is the .gz directory
	#
	$gz_dir = "$dir/$oldname/archive";

    } else {

	# no archive directory, so OLD is the .gz directory
	#
	$gz_dir = "$dir/$oldname";
    }
    print "DEBUG: .gz directory: $gz_dir\n" if $verbose;

    # be sure that OLD, and if needed OLD/archive has the right modes
    #
    (undef, undef, $mode, undef) = stat($oldname);
    $mode &= 07777;
    if ($mode != $archdir_mode) {
	if (chmod($archdir_mode, $oldname)) {
	    printf("DEBUG: chmoded %s from 0%03o to 0%03o\n",
	    	   "$dir/$oldname", $mode, $archdir_mode) if $verbose;
	} else {
	    &warning(27, "unable to chmod 0%03o OLD directory: %s",
			 $archdir_mode, "$dir/$oldname");
	    return $false;
	}
    }
    if (! -w $oldname) {
	&warning(28, "OLD directory: $dir/$oldname is not writable");
    	return $false;
    }
    #
    if ($gz_dir ne $oldname) {
	(undef, undef, $mode, undef) = stat($gz_dir);
	$mode &= 07777;
	if ($mode != $archdir_mode) {
	    if (chmod($archdir_mode, $gz_dir)) {
		printf("DEBUG: chmoded %s from 0%03o to 0%03o\n",
		       $gz_dir, $mode, $archdir_mode) if $verbose;
	    } else {
		&warning(29,
		    "unable to chmod 0%03o archive directory: %s",
		    $archdir_mode, $gz_dir);
		return $false;
	    }
	}
	if (! -w $gz_dir) {
	    &warning(30, "archive directory: $gz_dir is not writable");
	    return $false;
	}
    }

    # ensure that the base filename exists
    #
    $file = basename($filename);
    print "DEBUG: filename: $file\n" if $verbose;

    # return dir, file, gz_dir and success
    #
    $$dir_p = $dir;
    $$file_p = $file;
    $$gz_dir_p = $gz_dir;
    return $true;
}


# safe_file_create - safely create a file with the proper perm, uid and gid
#
# usage:
#	&safe_file_create($filename, $uid, $gid, $mode)
#
#	$filename	- form $filename (may form $filename.new first)
#	$uid		- force owner to be $uid (or -1 to not chown)
#	$gid		- force group to be $gid (or -1 to not chgrp)
#	$mode		- permissions / ownership
#	$rename		- 1 ==> force a rename, 0 ==> ok to create directly
#
# returns:
#	0 ==> safe create was unsuccessful
#	1 ==> safe create was successful
#
sub safe_file_create($$$$$)
{
    my ($filename, $uid, $gid, $mode, $rename) = @_;	# get args
    my $uid_arg;	# $file_uid or -1
    my $gid_arg;	# $file_gid or -1
    my $newname;	# $filename.new
    my $fd;		# file descriptor number of an open file

    # create directly if allowed and we do not need to chown or chgrp
    #
    if (!$rename && !defined $file_uid && !defined $file_gid) {

	# create the file in place
	#
	if (! sysopen FILE, $filename, O_CREAT|O_RDONLY|O_EXCL, $mode) {
	    print "DEBUG: could not create $filename\n" if $verbose;
	    return $false;
	}
	close FILE;
	printf("DEBUG: safely created %s with mode 0%03o\n", $filename, $mode)
	    if $verbose;
	return $true;

    # create indirectly and move if allowed and we do not need to chown or chgrp
    #
    } elsif ($rename && !defined $file_uid && !defined $file_gid) {

	# create the file on the side
	#
	$newname = "$filename.new";
	if (! sysopen FILE, $newname, O_CREAT|O_RDONLY|O_EXCL, $mode) {
	    print "DEBUG: couldn't create $newname\n" if $verbose;
	    return $false;
	}
	printf("DEBUG: safely made %s, mode 0%03o\n", $newname, $mode)
	    if $verbose;

	# move the file in place
	#
	if (! rename $newname, $filename) {
	    print "DEBUG: couldn't mv $newname $filename\n" if $verbose;
	    return $false;
	}
	print "DEBUG: moved $newname to $filename\n" if $verbose;
	close FILE;
	return $true;
    }

    # create the file on the side
    #
    $newname = "$filename.new";
    if ($newname =~ m#^([-\@\w./+:%][-\@\w./+:%~]*)$#) {
	$newname = $1;
    } else {
	print "DEBUG: filename.new has chars: $newname" if $verbose;
	return $false;
    }
    if (! sysopen FILE, $newname, O_CREAT|O_RDONLY|O_EXCL, $mode) {
	print "DEBUG: cannot create $newname\n" if $verbose;
	return $false;
    }
    printf("DEBUG: safely formed %s with mode 0%03o\n", $newname, $mode)
	if $verbose;

    # determine fchown args
    #
    if (defined $file_uid) {
	$uid_arg = $file_uid;
    } else {
	$uid_arg = -1;
    }
    if (defined $file_gid) {
	$gid_arg = $file_gid;
    } else {
	$gid_arg = -1;
    }
    $fd = fileno FILE;

    # fchown the file
    #
    if (syscall(&SYS_fchown, $fd, $uid_arg, $gid_arg) != 0) {
	print "DEBUG: bad fchown $uid_arg.$gid_arg $newname\n" if $verbose;
	close FILE;
	return $false;
    }
    print "DEBUG: fchown $uid_arg.$gid_arg $newname\n" if $verbose;

    # move the file in place
    #
    if (! rename $newname, $filename) {
	print "DEBUG: cannot mv $newname $filename\n" if $verbose;
	return $false;
    }
    print "DEBUG: mv $newname $filename\n" if $verbose;
    close FILE;
    return $true;
}


# scandir - scan the OLD and possibly archive dir for archived filenames
#
# usage:
#	&scandir($filename, $olddir, $archdir, \@filelist)
#
#	$filename	archived filename to scan for in $olddir or $archdir
#	$olddir		OLD directory name to scan in
#	$archdir	if defined, name of OLD/archive to scan for
#	\@filelist	list of files found
#
# We will look for filenames of the form:
#
#	filename\.\d{10}
#	filename\.\d{10}\-\d{10}
#	filename\.\d{10}\-\d{10}\.gz
#	filename\.\d{10}\-\d{10}\.indx
#
# directly under:
#
#	OLD
#	OLD/archive	(if archive exists)
#
# returns:
#	0 ==> scan was unsuccessful
#	1 ==> scan was successful or ignored
#
# NOTE: We will return the list sorted by timestamp
#
sub scandir($$$\@)
{
    my ($filename, $olddir, $archdir, $list) = @_;	# get args
    my @found;		# list of matching files found
    my $i;

    # verify that the list arg is an array reference
    #
    if (!defined($list) || ref($list) ne 'ARRAY') {
	&error(31, "scandir: 4th argument is not an array reference");
    }

    # clear the list
    #
    $#$list = -1;

    # scan OLD/ for files of the form filename\.\d{10}
    #
    if (! opendir DIR, $olddir) {
	&warning(32, "unable to open OLD dir: $olddir");
	return $false;
    }
    @found = grep /^$filename\.\d{10}$/, readdir DIR;
    closedir DIR;

    # append each found file as OLD/name in sorted order
    #
    foreach $i (sort @found) {
	push(@$list, "$olddir/$i");
    }

    # scan OLD/archive if it exists
    #
    if (defined $archdir) {

	# scan the OLD/archive/
	#
	if (! opendir DIR, $archdir) {
	    &warning(33, "cannot open OLD/archive dir: $archdir");
	    return $false;
	}
	@found = grep /^$filename\.\d{10}\-\d{10}$|^$filename\.\d{10}\-\d{10}\.gz$|^$filename\.\d{10}\-\d{10}\.indx$/, readdir DIR;
	closedir DIR;

	# append each found file as OLD/archive/name in sorted order
	#
	foreach $i (sort @found) {
	    push(@$list, "$archdir/$i");
	}

    # otherwise scan OLD for filename\.\d{10}\-\d{10} and .gz and .indx files
    #
    } else {

	# scan the OLD/ again
	#
	if (! opendir DIR, $olddir) {
	    &warning(34, "can't open OLD/archive dir: $olddir");
	    return $false;
	}
	@found = grep /^$filename\.\d{10}\-\d{10}$|^$filename\.\d{10}\-\d{10}\.gz$|^$filename\.\d{10}\-\d{10}\.indx$/, readdir DIR;
	closedir DIR;

	# append each found file as OLD/name in sorted order
	#
	foreach $i (sort @found) {
	    push(@$list, "$olddir/$i");
	}
    }
}


# rm - remove a file (or not if -n)
#
# usage:
#	&rm($filename[, $reason]);
#
#	$filename	the file to remove
#	$reason		the reason to remove, if defined
#
sub rm($$)
{
    my ($filename, $reason) = @_;	# get args

    # case: -n was given, only print action\
    #
    if (defined $opt_n) {
	
	# just print what we would have done
	#
	print "rm -f $filename\t# $reason\n";

    # case: attempt to remove the file
    #
    } else {

	# untaint $filename
	#
	if ($filename =~ m#^/# || $filename =~ m#^\.\.\/# ||
	    $filename =~ m#^/\.\./"#) {
	    &warning(35, "unsafe filename to remove: $filename");
	    return;
	}
	if ($filename =~ m#^([-\@\w./+:%][-\@\w./+:%~]*)$#) {
	    $filename = $1;
	}

	# unlink
	#
	if (unlink $filename) {
	    print "DEBUG: rm $filename\n" if $verbose;

	} else {
	    &warning(36, "cannot remove $filename\n");
	}
    }
}


# cleanlist - remove duplicate foo and foo.gz files and stale .indx files
#
#	&cleanlist(\@list)
#
#	@list		list of archived files of $filename to be cleaned
#
sub cleanlist(\@)
{
    my $list = $_[0];	# get args
    my $prev;		# previous item on list
    my $cur;		# current item on list
    my $i;

    # verify that the list arg is an array reference
    #
    if (!defined($list) || ref($list) ne 'ARRAY') {
	&error(37, "cleanlist: 2nd argument is not an array reference");
    }

    # do nothing if the list has 1 or 0 files in it
    #
    if ($#$list <= 0) {
	return;
    }

    # scan thru the list looking for dups, .gz dups and stale .indx files
    #
    # NOTE: There is magic is how $prev and $cur are set.  We must be careful
    #	    because splicing the array can change what is previous.
    #
    for ($prev = $$list[0], $cur = $$list[$i=1];
         $i <= $#$list; 
	 $prev = $$list[$i++], $cur = $$list[$i]) {

	# firewall - catch dup and bogus sorting
	#
	if ($prev eq $cur) {
	    &error(38, "cleanlist: found duplicate list item: $cur");
	}

	# catch foo and foo.gz and remove foo
	#
	if ("$prev.gz" eq $cur) {
	    &rm($prev, "also found $cur");
	    splice @$list, $i-1, 1;
	}

	# remove lone .indx files
	#
	if ($cur =~ /\.indx$/) {
	    my $base;		# base of .indx name

	    # catch lone .indx files
	    #
	    ($base = $cur) =~ s/\.indx$//;
	    if ("$base" ne $prev && "$base.gz" ne $prev) {
		&rm($cur, "lone .indx file");
		splice @$list, $i, 1;
	    }
	}
    }
}


# splitlist - split a list of files into single, double, gz and index files
#
# given:
#	&splitlist(\@list, \@single, \@gz, \@plain, \@double, \@index)
#
#	@list		a list of archived files (from scandir, for example)
#	@single		files of the form name\.\d{10}
#	@gz		files of the form name\.\d{10}\-\d{10}\.gz
#	@plain		files of the form name\.\d{10}\-\d{10}
#	@double		both @gz and @plain files
#	@index		files of the form name\.\d{10}\-\d{10}\.inedx
#
sub splitlist(\@\@\@\@\@\@)
{
    my ($list, $single, $gz, $plain, $double, $index) = @_;	# get args
    my $i;

    # verify that we were given references to arrays
    #
    if (!defined $list || !defined $single || !defined $gz ||
        !defined $plain || !defined $double || !defined $index ||
	ref($list) ne 'ARRAY' || ref($single) ne 'ARRAY' ||
	ref($gz) ne 'ARRAY' || ref($plain) ne 'ARRAY' ||
	ref($double) ne 'ARRAY' || ref($index) ne 'ARRAY') {
	&error(39, "splitlist: arg(s) are not an array reference");
    }

    # truncate lists
    #
    $#$single = -1;
    $#$gz = -1;
    $#$plain = -1;
    $#$double = -1;
    $#$index = -1;

    # look at each element and classify it
    #
    foreach $i (@$list) {

	# record filename\.\d{10} files
	#
	if ($i =~ /\.\d{10}$/) {
	    push(@$single, $i);

	# record filename\.\d{10}\-\d{10}\.gz files (also as double files)
	#
	} elsif ($i =~ /\.\d{10}\-\d{10}\.gz$/) {
	    push(@$gz, $i);
	    push(@$double, $i);

	# record filename\.\d{10}\-\d{10} files (also as double files)
	#
	} elsif ($i =~ /\.\d{10}\-\d{10}$/) {
	    push(@$plain, $i);
	    push(@$double, $i);

	# record filename\.\d{10}\-\d{10}\.indx files
	#
	} elsif ($i =~ /\.\d{10}\-\d{10}\.indx$/) {
	    push(@$index, $i);

	# we should not get here
	#
	} else {
	    &error(40, "splitlist: found bogus member of file list: $i");
	}
    }
}


# rmcycles - split a list of files into single, double, gz and index files
#
# given:
#	&rmcycles(\@list, \@single, \@gz, \@plain, \@double, \@index)
#
#	@list		a list of archived files (from scandir, for example)
#	@single		files of the form name\.\d{10}
#	@gz		files of the form name\.\d{10}\-\d{10}\.gz
#	@plain		files of the form name\.\d{10}\-\d{10}
#	@double		both @gz and @plain files
#	@index		files of the form name\.\d{10}\-\d{10}\.inedx
#
# This function will all but the last $cycle-1 files found in \@double.
# We remove all but the last (most recent) $cycle-1 files instead of
# $cycle files because later on we will archive the current file and
# form a new cycle.
#
# NOTE: The reason why the other arrays are passed in is so that \@list,
#	\@gz and \@plain will have removed files removed from them as well.
#
sub rmcycles(\@\@\@\@\@\@)
{
    my ($list, $single, $gz, $plain, $double, $index) = @_;	# get args
    my $i;

    # Remove all but the oldest $cycle-1 files found in @$double
    #
    return unless $#$double ge $cycle-1;
    for ($i=0; $i <= $#$double-$cycle+1; ++$i) {
	&rm($$double[$i], "keeping newest $cycle-1 cycles");
    }
    splice @$double, 0, $i;

    # rebuild @$list
    #
    $#$list = -1;
    push(@$list, @$single);
    push(@$list, @$double);

    # rebuild @$gz and @$plain
    #
    $#$gz = -1;
    $#$plain = -1;
    for ($i=0; $i <= $#$double; ++$i) {
	if ($$double[$i] =~ /\.gz$/) {
	    push @$gz, $$double[$i];
	} else {
	    push @$plain, $$double[$i];
	}
    }
    return;
}


# archive - archive a file
#
# usage:
#	&archive($filename, $dir, $file, $gz_dir)
#
#	$filename	path of preped filename to archive
#	$dir		preped directory of $filename
#	$file		basename of $filename
#	$gz_dir		where .gz files are to be placed
#
# returns:
#	0 ==> archive was unsuccessful
#	1 ==> archive was successful or ignored
#
# NOTE: It is assumed that our currently directory has been set to $dir.
#
sub archive($$$$)
{
    my ($filename, $dir, $file, $gz_dir) = @_;	# get args
    my @list;		# list of archived files
    my @single;		# files of the form filename\.\d{10}
    my @gz;		# files of the form filename\.\d{10}\-\d{10}\.gz
    my @plain;		# files of the form filename\.\d{10}\-\d{10}
    my @double;		# @gz and @plain files
    my @indx;		# files of the form filename\.\d{10}\-\d{10}\.indx

    # step 0 - Determine if /a/path/file exists
    #
    if (! -f $file) {

	# -T prevents us from touching missing files
	#
	if (defined $opt_T) {

	    print "DEBUG: $filename missing and -T was given\n" if $verbose;
	    print "DEBUG: nothing to do for $filename\n" if $verbose;
	    return $true;

	# create file
	#
	} else {

	    # create the file
	    #
	    if (! &safe_file_create($file, $file_uid, $file_gid,
	    			    $file_mode, $false)) {
	    	&warning(41, "could not exclusively create $filename");
		return $false;
	    }
	}

	# verfiy that the file still exists
	#
	if (! -f $file) {
	    &warning(42, "created $filename and now it is missing");
	    return $false;
	}
    }

    # step 1 - Determine if /a/path/file is empty
    #
    if (-z $file && ! defined $opt_z) {

	print "DEBUG: $filename is empty and -z was not given\n" if $verbose;
	print "DEBUG: nothing to do for $filename\n" if $verbose;
	return $true;
    }

    # step 2 - Remove all but the newest cycle-1 files if not blocked
    #
    &scandir($file, $oldname, "$oldname/archive", \@list);
    &cleanlist(\@list);
    &splitlist(\@list, \@single, \@gz, \@plain, \@double, \@indx);
    if ($cycle > 0 && $#double ge $cycle-1) {
	&rmcycles(\@list, \@single, \@gz, \@plain, \@double, \@indx);
    }

    # all done
    #
    return $true;
}
