#!/usr/bin/perl -Tw
#
# savelog - save old log files and prep for web indexing
#
# @(#) $Revision: 1.18 $
# @(#) $Id: savelog.pl,v 1.18 2000/01/30 11:15:47 chongo Exp chongo $
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
#	   unless -1 was given.   Files will be placed under /a/path/OLD or
#	   /a/path/OLD/archive if it exists.  If -1 was given, then
#	   no files will be gziped.
#
#	   Assertion: At this point, all files of the form file.tstamp1-tstamp2
#		      have been gziped, or -1 was given and no additional files
#		      were gziped.
#
#	5) If /a/path/OLD/file.tstamp is not hard linked to /a/path/file,
#	   when remove /a/path/OLD/file.tstamp and relink /a/path/file to it.
#	   If /a/path/OLD/file.tstamp does not exist, then link /a/path/file
#	   to /a/path/OLD.file.now where 'now' is the current timestamp.
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
#	   result under /a/path/OLD or /a/path/OLD/archive if it exists.
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
delete $ENV{GZIP};
use Cwd;
use File::Basename;
use File::Copy;
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
my $gzip;		# location of the gzip program
#
my $true = 1;		# truth as we know it
my $false = 0;		# genuine falseness

# directory cache
#
# $dir_cache[$dir_indx{$dir}] is an array of files found directly under $dir
#
my @dir_cache;		# $dir_cache[$dir_indx{$dir}] - array of files
my %dir_indx;		# @dir_cache index for $dir

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
    my $file;		# the current file we are processing
    my $dir;		# preped directory in which $file resides
    my $gz_dir;		# where .gz files are to be placed

    # setup
    #
    $exit_val = 0;	# hope for the best
    select STDOUT;
    $| = 1;
    if (-x "/bin/gzip") {
	$gzip = "/bin/gzip";
    } elsif (-x "/usr/bin/gzip") {
	$gzip = "/usr/bin/gzip";
    } elsif (-x "/usr/local/bin/gzip") {
	$gzip = "/usr/local/bin/gzip";
    } elsif (-x "/usr/gnu/bin/gzip") {
	$gzip = "/usr/gnu/bin/gzip";
    } elsif (-x "/usr/freeware/bin/gzip") {
	$gzip = "/usr/freeware/bin/gzip";
    } else {
	$gzip = "gzip";
    }

    # parse args
    #
    &parse();

# $opt_n = 1;	# XXX - DEBUG

# # XXX - debug
# #
# my (@list, @single, @gz, @plain, @double, @index);
# &scan_dir("foo", "OLD", "OLD/archive", \@list);
# print "scanned list\n", join("\n", @list), "\n";
# &clean_list(\@list);
# print "\ncleaned list:\n", join("\n", @list), "\n";
# &split_list(\@list, \@single, \@gz, \@plain, \@double, \@index);
# print "\nsingle list:\n", join("\n", @single), "\n";
# print "\ngz list:\n", join("\n", @gz), "\n";
# print "\nplain list:\n", join("\n", @plain), "\n";
# print "\ndouble list:\n", join("\n", @double), "\n";
# print "\nindex list:\n", join("\n", @index), "\n";
# print "\ncycles: $cycle, double last: $#double\n";
# if ($cycle > 0 && $#double ge $cycle-1) {
# &rm_cycles(\@list, \@single, \@gz, \@plain, \@double, \@index);
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
    foreach $file (@ARGV) {

	# prepare to process the file
	#
	print "\n" if $verbose;
	if (! &prepfile($file, \$dir, \$gz_dir)) {
	    print STDERR "error while preparing for $file, skipping\n";
	    next;
	}

	# archive the file
	#
	if (! &archive($file, $dir, $gz_dir)) {
	    print STDERR "error while processing $file\n";
	    next;
	}
	print "DEBUG: finished with $file\n" if $verbose;
    }

    # all done
    #
    print "\nDEBUG: exit code: $exit_val\n" if $verbose;
    exit $exit_val;
}

# err_msg - report an error and exit
#
# usage:
#	&err_msg(exitcode, "error format" [,arg ...])
#
sub err_msg($$@)
{
    # parse args
    #
    my ($code, $fmt, @args) = @_;
    $fmt = "<<no error message given>>" unless defined $fmt;
    $code = 2 unless defined $code;

    # issue message
    #
    print STDERR "$0: ERROR($code): ";
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


# warn_msg - report an problem and continue
#
# usage:
#	&warn_msg(exitcode, "warning format" [,arg ...])
#
# NOTE: Unlike
#
sub warn_msg($$@)
{
    # parse args
    #
    my ($code, $fmt, @args) = @_;
    $fmt = "<<no warning message given>>" unless defined $fmt;
    $code = 3 unless defined $code;

    # issue message
    #
    print STDERR "$0: Warn($code): ";
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
		&err_msg(4, "parse: bad user: $opt_o");
	    }
	    print "DEBUG: set file uid: $file_uid\n" if $verbose;
        } else {
	    &err_msg(5, "parse: only the superuser can use -o");
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
		&err_msg(6, "parse: bad group: $opt_g");
	    }
	    print "DEBUG: set file gid: $file_gid\n" if $verbose;
        } else {
	    &err_msg(7, "parse: only the superuser can use -g");
	}
    }

    # -c cycle
    #
    $cycle = $opt_c if defined $opt_c;
    if ($cycle < 0) {
	&err_msg(8, "parse: cycles to keep: $cycle must be >= 0");
    }

    # -i indx_type
    #
    if (defined $opt_i) {
	$indx_type = $opt_i;
	if ($indx_type =~ m:[/~*?[]:) {
	    &err_msg(9, "parse: index type may not contain /, ~, *, ?, or [");
	}
	if ($indx_type eq "." || $indx_type eq "..") {
	    &err_msg(10, "parse: index type type may not be . or ..");
	}
	print "DEBUG: index type: $indx_type\n" if $verbose;
    }

    # -I typedir
    #
    if (defined $opt_I) {
	if (!defined $opt_i) {
	    &err_msg(11, "parse: use of -I typedir requires -i indx_type");
	}
	if (! -d $opt_I) {
	    &err_msg(12, "parse: no such index type directory: $opt_I");
	}
	$indx_dir = $opt_I;
	print "DEBUG: index prog dir: $indx_dir\n" if $verbose;
    }
    if (defined($indx_type)) {
    	if (! -x "$indx_dir/$indx_type") {
	    &err_msg(13,
	    	"parse: index type prog: $indx_type not found in: $indx_dir");
	}
	$indx_prog = "$indx_dir/$indx_type";
	print "DEBUG: indexing prog: $indx_prog\n" if $verbose;
    }

    # -a OLDname
    #
    $oldname = $opt_a if defined $opt_a;
    if ($oldname =~ m:[/~*?[]:) {
	&err_msg(14, "parse: OLD dir name may not contain /, ~, *, ?, or [");
    }
    if ($oldname eq "." || $oldname eq "..") {
	&err_msg(15, "parse: OLD dir name may not be . or ..");
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
#	&prepfile($file, \$dir_p, \$gz_dir_p)
#
#	$file	path of preped file to archive
#	\$dir_p		ref to preped directory of $file
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
    my ($file, $dir_p, $gz_dir_p) = @_;	# parse args
    my $dir;			# dirname of $file (dir where file exists)
    my $gz_dir;			# directory where .gz files are kept
    my $mode;			# stated mode of a file or directory
    my ($dev1, $dev2, $inum1, $inum2);	# dev/inum of two inodes

    # untaint the file
    #
    if ($file =~ m#^([-\@\w./+:%][-\@\w./+:%~]*)$#) {
    	$file = $1;
    } else {
	&warn_msg(16, "file has dangerious chars: $file");
	return $false;
    }
    print "DEBUG: starting to process: $file\n" if $verbose;
    print "\n# starting to process: $file\n" if defined $opt_n;

    # determine the file's directory
    #
    $dir = dirname($file);
    print "DEBUG: $file dir is: $dir\n" if $verbose;

    # make sure that the OLD directory exists
    #
    if (! -d "$dir/$oldname") {
	if (! mkdir("$dir/$oldname", $archdir_mode)) {
	    &warn_msg(17, "cannot mkdir: $dir/$oldname");
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
	    &err_msg(18,
	    	"prepfile: archive dir has dangerious chars: $archive_dir");
	}

	# The archive directory must exist
	#
	if (! -d $archive_dir) {
	    &err_msg(19,
	    	"prepfile: archive dir: $archive_dir is not a directory");

	# If we have an OLD/archive is a symlink, make it point to archive_dir
	#
	} elsif (-l "$dir/$oldname/archive") {

	    # determine if OLD/archive points to archive_dir
	    #
	    ($dev1, $inum1, undef) = stat("$dir/$oldname/archive");
	    ($dev2, $inum2, undef) = stat($archive_dir);
	    if (!defined($dev2) || !defined($inum2)) {
	    	&err_msg(20, "prepfile: cannot stat archive dir: $archive_dir");
	    }
	    if (!defined($dev1) || !defined($inum1) ||
	    	$dev1 != $dev2 || $inum1 != $inum2) {

		# OLD/archive points to a different place (or nowhere), so
		# we must remove it and form it as a symlink to archive_dir
		#
		if (!unlink("$dir/$oldname/archive") ||
		    !symlink($archive_dir, "$dir/$oldname/archive")) {
		    &warn_msg(21,
			"cannot symlink $dir/$oldname/archive to $archive_dir");
		    return $false;
		}
		printf("DEBUG: symlink %s to %s\n",
		       "$dir/$oldname/archive", $archive_dir) if $verbose;
	    }

	} elsif (-d "$dir/$oldname/archive") {

	    # determine if OLD/archive points to archive_dir
	    #
	    ($dev1, $inum1, undef) = stat("$dir/$oldname/archive");
	    ($dev2, $inum2, undef) = stat($archive_dir);
	    if (!defined($dev2) || !defined($inum2)) {
	    	&err_msg(22, "prepfile: can't stat archive dir: $archive_dir");
	    }
	    if (!defined($dev1) || !defined($inum1) ||
	    	$dev1 != $dev2 || $inum1 != $inum2) {
	    	&warn_msg(23,
		    "$dir/$oldname/archive is a dir and is not $archive_dir");
	    	return $false;
	    }

	# No OLD/archive exists, so make is a symlink to archive_dir
	#
	} else {

	    # make OLD/archive a symlink to the archive_dir
	    #
	    if (!symlink($archive_dir, "$dir/$oldname/archive")) {
		&warn_msg(24,
		    "cannot symlink $dir/$oldname/archive to $archive_dir");
		return $false;
	    }
	    printf("DEBUG: symlinked %s to %s\n",
		   "$dir/$oldname/archive", $archive_dir) if $verbose;
	}
	$gz_dir = "$dir/$oldname/archive";

    # If we were not asked to use an archive subdir of OLD but one
    # exists anyway, be sure it has the right mode and is writable
    #
    } elsif (-d "$dir/$oldname/archive") {

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
    (undef, undef, $mode, undef) = stat("$dir/$oldname");
    $mode &= 07777;
    if ($mode != $archdir_mode) {
	if (chmod($archdir_mode, "$dir/$oldname")) {
	    printf("DEBUG: chmoded %s from 0%03o to 0%03o\n",
	    	   "$dir/$oldname", $mode, $archdir_mode) if $verbose;
	} else {
	    &warn_msg(25, "unable to chmod 0%03o OLD directory: %s",
			 $archdir_mode, "$dir/$oldname");
	    return $false;
	}
    }
    if (! -w "$dir/$oldname") {
	&warn_msg(26, "OLD directory: $dir/$oldname is not writable");
    	return $false;
    }
    #
    if ($gz_dir ne "$dir/$oldname") {
	(undef, undef, $mode, undef) = stat($gz_dir);
	$mode &= 07777;
	if ($mode != $archdir_mode) {
	    if (chmod($archdir_mode, $gz_dir)) {
		printf("DEBUG: chmoded %s from 0%03o to 0%03o\n",
		       $gz_dir, $mode, $archdir_mode) if $verbose;
	    } else {
		&warn_msg(27,
		    "unable to chmod 0%03o archive directory: %s",
		    $archdir_mode, $gz_dir);
		return $false;
	    }
	}
	if (! -w $gz_dir) {
	    &warn_msg(28, "archive directory: $gz_dir is not writable");
	    return $false;
	}
    }

    # return dir, file, gz_dir and success
    #
    $$dir_p = $dir;
    $$gz_dir_p = $gz_dir;
    return $true;
}


# safe_file_create - safely create a file with the proper perm, uid and gid
#
# usage:
#	&safe_file_create($file, $uid, $gid, $mode)
#
#	$file	- form $file (may form $file.new first)
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
    my ($file, $uid, $gid, $mode, $rename) = @_;	# get args
    my $uid_arg;	# $file_uid or -1
    my $gid_arg;	# $file_gid or -1
    my $newname;	# $file.new
    my $fd;		# file descriptor number of an open file

    # create directly if allowed and we do not need to chown or chgrp
    #
    if (!$rename && !defined $file_uid && !defined $file_gid) {

	# create the file in place
	#
	if (! sysopen FILE, $file, O_CREAT|O_RDONLY|O_EXCL, $mode) {
	    print "DEBUG: could not create $file\n" if $verbose;
	    return $false;
	}
	close FILE;
	printf("DEBUG: safely created %s with mode 0%03o\n", $file, $mode)
	    if $verbose;
	return $true;

    # create indirectly and move if allowed and we do not need to chown or chgrp
    #
    } elsif ($rename && !defined $file_uid && !defined $file_gid) {

	# create the file on the side
	#
	$newname = "$file.new";
	if (! sysopen FILE, $newname, O_CREAT|O_RDONLY|O_EXCL, $mode) {
	    print "DEBUG: couldn't create $newname\n" if $verbose;
	    return $false;
	}
	printf("DEBUG: safely made %s, mode 0%03o\n", $newname, $mode)
	    if $verbose;

	# move the file in place
	#
	if (! rename $newname, $file) {
	    print "DEBUG: couldn't mv $newname $file\n" if $verbose;
	    return $false;
	}
	print "DEBUG: moved $newname to $file\n" if $verbose;
	close FILE;
	return $true;
    }

    # create the file on the side
    #
    $newname = "$file.new";
    if ($newname =~ m#^([-\@\w./+:%][-\@\w./+:%~]*)$#) {
	$newname = $1;
    } else {
	print "DEBUG: file.new has chars: $newname" if $verbose;
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
    if (! rename $newname, $file) {
	print "DEBUG: cannot mv $newname $file\n" if $verbose;
	return $false;
    }
    print "DEBUG: mv $newname $file\n" if $verbose;
    close FILE;
    return $true;
}


# loaddir - load a list with the files of files found in a directory
#
# usage:
#	&loaddir($dir, \@list)
#
#	$dir	directory to scan for files
#	\@list	list of files of files found in $dir
#
# returns:
#	0 ==> scan was unsuccessful
#	1 ==> scan was successful or ignored
#
# NOTE: This routine will not rescan a directory once it has been read once.
#
sub loaddir($\@)
{
    my ($dir, $list) = @_;	# get args
    my $file;		# file found in $dir
    my $i;

    # verify that the list arg is an array reference
    #
    if (!defined($list) || ref($list) ne 'ARRAY') {
	&err_msg(29, "loaddir: 2nd argument is not an array reference");
    }

    # if we found it in the cache, return the cached files
    #
    if (defined $dir_indx{$dir}) {
	$#$list = -1;
	for ($i=0; defined $dir_cache[$dir_indx{$dir}][$i]; ++$i) {
	    push(@$list, $dir_cache[$dir_indx{$dir}][$i]);
	}
	return $true;
    }

    # prep for scanning dir
    #
    if (! opendir DIR, $dir) {
	&warn_msg(30, "unable to open dir: $dir");
	return $false;
    }

    # scan dir for files
    #
    $#$list = -1;
    while ($file = readdir DIR) {
	push(@$list, "$dir/$file") if -f "$dir/$file";
    }

    # cache the list of files
    #
    $dir_indx{$dir} = @dir_cache;
    $dir_cache[@dir_cache] = [ @$list ];

    # cleanup, all done
    #
    closedir DIR;
    return $true;
}


# scan_dir - scan the OLD and possibly archive dir for archived files
#
# usage:
#	&scan_dir($file, $base, $olddir, $archdir, \@filelist)
#
#	$file		archived file to scan for in $olddir or $archdir
#	$base		basename of $file
#	$olddir		OLD directory name to scan in
#	$archdir	if defined, name of OLD/archive to scan for
#	\@filelist	list of files found
#
# We will look for files of the form:
#
#	file\.\d{9,10}
#	file\.\d{9,10}\-\d{9,10}
#	file\.\d{9,10}\-\d{9,10}\.gz
#	file\.\d{9,10}\-\d{9,10}\.indx
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
sub scan_dir($$$$\@)
{
    my ($file, $base, $olddir, $archdir, $list) = @_;	# get args
    my @filelist;					# files found under $dir
    my $i;

    # verify that the list arg is an array reference
    #
    if (!defined($list) || ref($list) ne 'ARRAY') {
	&err_msg(31, "scan_dir: 4th argument is not an array reference");
    }

    # scan OLD/ for files of the form base\.\d{9,10}
    #
    print "DEBUG: scanning $olddir for $base tstamp files\n" if $verbose;
    if (! &loaddir($olddir, \@filelist)) {
	&warn_msg(32, "unable to open OLD dir: $olddir");
	return $false;
    }
    @$list = sort grep m#/$base\.\d{9,10}$#, @filelist;

    # scan OLD/archive if it exists
    #
    if (defined $archdir && -d $archdir) {

	# scan the OLD/archive/
	#
	print "DEBUG: scanning $archdir for $base files\n" if $verbose;
	if (! &loaddir($archdir, \@filelist)) {
	    &warn_msg(33, "cannot open OLD/archive dir: $archdir");
	    return $false;
	}
	push(@$list, sort grep m#/$base\.\d{9,10}\-\d{9,10}$|/$base\.\d{9,10}\-\d{9,10}\.gz$|/$base\.\d{9,10}\-\d{9,10}\.indx$#, @filelist);

    # otherwise scan OLD for base\.\d{9,10}\-\d{9,10} and .gz and .indx files
    #
    } else {

	# scan the OLD/ again
	#
	print "DEBUG: scanning $olddir for $base files\n" if $verbose;
	if (! &loaddir($olddir, \@filelist)) {
	    &warn_msg(34, "can't open OLD/archive dir: $olddir");
	    return $false;
	}
	push(@$list, sort grep m#/$base\.\d{9,10}\-\d{9,10}$|/$base\.\d{9,10}\-\d{9,10}\.gz$|/$base\.\d{9,10}\-\d{9,10}\.indx$#, @filelist);
    }
}


# rm - remove a file (or not if -n)
#
# usage:
#	&rm($file[, $reason]);
#
#	$file		the file to remove
#	$reason		the reason to remove, if defined
#
sub rm($$)
{
    my ($file, $reason) = @_;	# get args

    # case: -n was given, only print action\
    #
    if (defined $opt_n) {

	# just print what we would have done
	#
	print "rm -f $file\t# $reason\n";

    # case: attempt to remove the file
    #
    } else {

	# untaint $file
	#
	if ($file =~ m#^([-\@\w./+:%][-\@\w./+:%~]*)$#) {
	    $file = $1;
	} else {
	    &warn_msg(35, "unsafe file to remove: $file");
	    return;
	}

	# unlink
	#
	if (unlink $file) {
	    print "DEBUG: rm $file\n" if $verbose;

	} else {
	    &warn_msg(36, "cannot remove $file\n");
	}
    }
}


# clean_list - remove duplicate foo and foo.gz files and stale .indx files
#
#	&clean_list(\@list)
#
#	@list		list of archived files of $file to be cleaned
#
sub clean_list(\@)
{
    my $list = $_[0];	# get args
    my $prev;		# previous item on list
    my $cur;		# current item on list
    my $i;

    # verify that the list arg is an array reference
    #
    if (!defined($list) || ref($list) ne 'ARRAY') {
	&err_msg(37, "clean_list: 2nd argument is not an array reference");
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
	    &err_msg(38, "clean_list: found duplicate list item: $cur");
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


# split_list - split a list of files into single, double, gz and index files
#
# given:
#	&split_list(\@list, \@single, \@gz, \@plain, \@double, \@index)
#
#	@list		a list of archived files (from scan_dir, for example)
#	@single		files of the form name\.\d{9,10}
#	@gz		files of the form name\.\d{9,10}\-\d{9,10}\.gz
#	@plain		files of the form name\.\d{9,10}\-\d{9,10}
#	@double		both @gz and @plain files
#	@index		files of the form name\.\d{9,10}\-\d{9,10}\.inedx
#
sub split_list(\@\@\@\@\@\@)
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
	&err_msg(39, "split_list: arg(s) are not an array reference");
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

	# record file\.\d{9,10} files
	#
	if ($i =~ /\.\d{9,10}$/) {
	    push(@$single, $i);

	# record file\.\d{9,10}\-\d{9,10}\.gz files (also as double files)
	#
	} elsif ($i =~ /\.\d{9,10}\-\d{9,10}\.gz$/) {
	    push(@$gz, $i);
	    push(@$double, $i);

	# record file\.\d{9,10}\-\d{9,10} files (also as double files)
	#
	} elsif ($i =~ /\.\d{9,10}\-\d{9,10}$/) {
	    push(@$plain, $i);
	    push(@$double, $i);

	# record file\.\d{9,10}\-\d{9,10}\.indx files
	#
	} elsif ($i =~ /\.\d{9,10}\-\d{9,10}\.indx$/) {
	    push(@$index, $i);

	# we should not get here
	#
	} else {
	    &err_msg(40, "split_list: found bogus member of file list: $i");
	}
    }
}


# rm_cycles - split a list of files into single, double, gz and index files
#
# given:
#	&rm_cycles(\@single, \@gz, \@plain, \@double, \@index)
#
#	@single		files of the form name\.\d{9,10}
#	@gz		files of the form name\.\d{9,10}\-\d{9,10}\.gz
#	@plain		files of the form name\.\d{9,10}\-\d{9,10}
#	@double		both @gz and @plain files
#	@index		files of the form name\.\d{9,10}\-\d{9,10}\.inedx
#
# This function will all but the last $cycle-1 files found in \@double.
# We remove all but the last (most recent) $cycle-1 files instead of
# $cycle files because later on we will archive the current file and
# form a new cycle.
#
# NOTE: The reason why the other arrays are passed in is so that \@list,
#	\@gz and \@plain will have removed files removed from them as well.
#
sub rm_cycles(\@\@\@\@\@)
{
    my ($single, $gz, $plain, $double, $index) = @_;	# get args
    my $i;

    # verify that we were given references to arrays
    #
    if (!defined $single || !defined $gz ||
        !defined $plain || !defined $double || !defined $index ||
	ref($single) ne 'ARRAY' ||
	ref($gz) ne 'ARRAY' || ref($plain) ne 'ARRAY' ||
	ref($double) ne 'ARRAY' || ref($index) ne 'ARRAY') {
	&err_msg(41, "split_list: arg(s) are not an array reference");
    }

    # Remove all but the oldest $cycle-1 files found in @$double
    #
    return unless $#$double ge $cycle-1;
    for ($i=0; $i <= $#$double-$cycle+1; ++$i) {
	&rm($$double[$i], "keeping newest $cycle-1 cycles");
    }
    splice @$double, 0, $i;

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


# clean_tstamp - prune away too many file.tstamp files
#
# usage:
#	&clean_tstamp($file, \@single);
#
#	$file	path of the file being archived
#	@single		files of the form name\.\d{9,10}
#
# This function will perform actions as given in step 3 when more than
# one file of the form file.tstamp exists.  We will look to see if one
# of these files are hardlinked to the file being archived.  If yes, then
# all other file.tstamp files will be removed.  If no, then all but the
# newest file.tstamp file will be removed.
#
sub clean_tstamp($\@)
{
    my ($file, $list) = @_;		# get args
    my $f_dev;				# dev number of $file
    my $f_inum;				# inode number of $file
    my $f_links;			# link count for $file
    my $t_dev;				# dev number of a file.tstamp file
    my $t_inum;				# inode number of a file.tstamp file
    my $t_links;			# link count for a file.tstamp file
    my $keepname;			# file.tstamp file to keep
    my $i;

    # verify that the list arg is an array reference
    #
    if (!defined($list) || ref($list) ne 'ARRAY') {
	&err_msg(42, "clean_tstamp: 2nd argument is not an array reference");
    }

    # stat the file being archived
    #
    ($f_dev, $f_inum, undef, $f_links, undef) = stat($file);
    if (!defined $f_dev || !defined $f_inum || !defined $f_links) {
	&err_msg(43, "clean_tstamp: failed to stat $file");
    }

    # If the file is linked to another file, look to see if any
    # of the file.tstamps are that file
    #
    if ($f_links > 1) {

	# look for a file.tstamp file linked to file
	for $i ( reverse @$list ) {
	    ($t_dev, $t_inum, undef, $t_links, undef) = stat($i);
	    if (defined $t_links && $f_links == $t_links &&
	        defined $t_dev && $f_dev == $t_dev &&
	        defined $t_inum && $f_inum == $t_inum) {
		# found a linked file.tstamp file
		print "DEBUG: $file is linked to $i\n" if $verbose;
		$keepname = $i;
		last;
	    }
	}

	# pick the newest $tstamp file of not linked file.tstamp file was found
	#
	if (! defined $keepname) {
	    $keepname = $$list[$#$list];
	}

    # The file is not linked to any file, keep the newest file.tstamp file
    #
    } else {
	$keepname = $$list[$#$list];
    }

    # Remove all but the one file.tstamp file are are keeping
    #
    print "DEBUG: remove all tstamp files except: $keepname\n" if $verbose;
    for $i ( @$list ) {

	# keep the keeper file
	#
	next if $i eq $keepname;

	# remove tstamp file with an explination
	#
	if ($f_links > 1) {
	    &rm($i, "removing extra unlinked tstamp file");
    	} else {
	    &rm($i, "removing older tstamp file");
	}
    }

    # Clean out the single list
    #
    $#$list = 0;
    $$list[0] = $keepname;
}


# gzip - gzip a file into the appropriate directory
#
# usage:
#	&gzip($file, $inplace, $dir)
#
#	$file		file to gzip
#	$inplace	if true, gzip $file inplace in its current directory
#	$dir		if $inplace is false, gzip $file into this directory
#
# returns:
#	0 ==> gzip was unsuccessful or was disabled (by -n or -1)
#	1 ==> gzip was successful
#
# We gzip by running the gzip command in a child process.
#
sub gzip($$$)
{
    my ($file, $inplace, $dir) = @_;	# get args
    my $pid;				# gzip process id
    my $base;				# basename of file

    # -1 blocks all gziping
    #
    if (defined $opt_1) {
	print "DEBUG: gzip of $file skipped due to use of -1\n" if $verbose;
	return $false;
    }

    # gzip file in place
    #
    $base = basename($file);
    if ($inplace) {

	# do nothing if -n
	#
	if (defined $opt_n) {
	    print "$gzip --best -f -q $file\n";
	    return $false;
	}

	# fork/exec gzip of the file
	#
	if (system("$gzip", "--best", "-f", "-q", "$file") != 0) {
	    &warn_msg(44, "$gzip --best -f -q $file failed: $!");
	    return $false;
	}
	print "DEBUG: $gzip --best -f -q $file\n" if $verbose;

    # gzip the file into $dir
    #
    } else {

	# do nothing if -n
	#
	if (defined $opt_n) {
	    print "/bin/mv -f $file $dir/$base &&\n";
	    print "$gzip --best -f -q $dir/$base\n";
	    return $false;
	}

	# move file to the new directory
	#
	if (copy("$file", "$dir/$base") != 1) {
	    &warn_msg(45, "failed to cp $file $dir/$base: $!\n");
	    return $false;
	}
	print "DEBUG: cp $file $dir/$base\n" if $verbose;
	&rm("$file", "already moved file to $dir");
	print "DEBUG: rm -f $file\n" if $verbose;

	# gzip the file in dir
	#
	if (system("$gzip", "--best", "-f", "-q", "$dir/$base") != 0) {
	    &warn_msg(46, "$gzip --best -f -q $dir/$base failed: $!");
	    return $false;
	}
	print "DEBUG: $gzip --best -f -q $dir/$base\n" if $verbose;
    }
    return $true;
}


# hardlink - ensure that a file is hardlinked to another
#
# usage:
#	&hardlink($from, $to)
#
#	$from		hardlink this file
#	$to		ensure that $to is a hardlink to $from
#
# returns:
#	0 ==> archive was unsuccessful
#	1 ==> archive was successful or ignored
#
sub hardlink($$)
{
    my ($from, $to) = @_;	# get args
    my ($f_dev, $f_inum, $f_links);	# $from stat information
    my ($t_dev, $t_inum, $t_links);	# $to stat information

    # the from file must exist
    #
    ($f_dev, $f_inum, undef, $f_links) = stat($from);
    if (! -f $from ||
        !defined $f_dev || !defined $f_inum || !defined $f_links) {
	&warn_msg(47, "hardlink: cannot stat or no such file: $from");
	return $false;
    }

    # If the $to file does exist, see if it is a hardlink to $from.
    # We can ignore this if $from does not have enough links.
    #
print "DEBUG: from stat: $f_dev, $f_inum, $f_links\n";
    if ($f_links > 1 && -f $to) {
        ($t_dev, $t_inum, undef, $t_links) = stat($to);
print "DEBUG: to stat: $t_dev, $t_inum, $t_links\n";
	if (defined $t_dev && $f_dev == $t_dev &&
	    defined $t_inum && $f_inum == $t_inum &&
	    defined $t_links && $f_links == $t_links) {
	    print "DEBUG: $from already hardlinked onto $to\n" if $verbose;
	    return $true;
	}
    }

    # force $to to be a hardlink of $from
    #
    if (! defined $opt_n) {

	# untaint the name of $from and $to
	#
	if ($from =~ m#^([-\@\w./+:%][-\@\w./+:%~]*)$#) {
	    $from = $1;
	} else {
	    &warn_msg(48, "hardlink `from' file has dangerious chars: $from");
	    return $false;
	}
	if ($to =~ m#^([-\@\w./+:%][-\@\w./+:%~]*)$#) {
	    $to = $1;
	} else {
	    &warn_msg(49, "hardlink `to' file has dangerious chars: $to");
	    return $false;
	}

	# hardlink $from onto $to
	#
	unlink $to if -f $to;
	print "DEBUG: removed $to prior to hard linking\n" if $verbose;
	if (link($from, $to) <= 0) {
	    &warn_msg(50, "failed to hardlink $from onto $to");
	    return $false;
	}
	print "DEBUG: hardlinked $from onto $to\n" if $verbose;

    } else {
	print "ln -f $from $to\n";
    }
    return $true;
}


# archive - archive a file
#
# usage:
#	&archive($file, $dir, $gz_dir)
#
#	$file		path of preped file to archive
#	$dir		preped directory of $file
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
    my ($file, $dir, $gz_dir) = @_;	# get args
    my @list;		# list of archived files
    my @single;		# files of the form file\.\d{9,10}
    my @gz;		# files of the form file\.\d{9,10}\-\d{9,10}\.gz
    my @plain;		# files of the form file\.\d{9,10}\-\d{9,10}
    my @double;		# @gz and @plain files
    my @indx;		# files of the form file\.\d{9,10}\-\d{9,10}\.indx
    my $base;		# basename of file
    my $now;		# seconds since the epoch of now
    my $i;

    # prep work
    #
    $base = basename($file);
    $now = time();

    # step 0 - Determine if /a/path/file exists
    #
    if (! -f $file) {

	# -T prevents us from touching missing files
	#
	if (defined $opt_T) {

	    print "DEBUG: $file missing and -T was given\n" if $verbose;
	    print "DEBUG: nothing to do for $file\n" if $verbose;
	    return $true;

	# create file
	#
	} else {

	    # create the file
	    #
	    if (! &safe_file_create($file, $file_uid, $file_gid,
	    			    $file_mode, $false)) {
	    	&warn_msg(100, "could not exclusively create $file");
		return $false;
	    }
	}

	# verfiy that the file still exists
	#
	if (! -f $file) {
	    &warn_msg(101, "created $file and now it is missing");
	    return $false;
	}
    }

    # step 1 - Determine if /a/path/file is empty
    #
    if (-z $file && ! defined $opt_z) {

	print "DEBUG: $file is empty and -z was not given\n" if $verbose;
	print "DEBUG: nothing to do for $file\n" if $verbose;
	return $true;
    }

    # step 2 - Remove all but the newest cycle-1 files if not blocked
    #
    &scan_dir($file, $base, "$dir/$oldname", "$dir/$oldname/archive", \@list);
    &clean_list(\@list);
    &split_list(\@list, \@single, \@gz, \@plain, \@double, \@indx);
    if ($cycle > 0 && $#double ge $cycle-1) {
	&rm_cycles(\@single, \@gz, \@plain, \@double, \@indx);
    }

    # step 3 - deal with too many file.timestamp files
    #
    if (scalar(@single) > 1) {
	&clean_tstamp($file, \@single);
    }

    # step 4 - gzip all file.tstamp1-tstamp2 files
    #
    if (scalar(@plain) > 0) {
	
	# gzip each plain file
	#
	for ($i = 0; $i <= $#plain; ++$i) {

	    # gzip file in place
	    #
	    if (&gzip($plain[$i], $true, undef)) {
	    	# move file from @plain to @gz
		push(@gz, "$plain[$i].gz");
		splice(@plain, $i, 1);
		--$i;
	    }
	}

	# fix up @gz and @double
	#
	@gz = sort @gz;
	@double = @gz;
	push(@double, @plain);
	@double = sort @double;
    }

    # step 5 - force file to be hardlinked to file.tstamp
    #
    if (scalar(@single) < 1) {
	print "DEBUG: no file.tstamp file, forming for $base\n" if $verbose;
	if (! &hardlink($file, "$dir/$oldname/$base.$now")) {
	    &warn_msg(102, "failed to hardlink $file onto %s",
	    	      "$dir/$oldname/$base.$now");
	    return $false;
	}
	push(@single, "$dir/$oldname/$base.$now");
    } else {
	if (! &hardlink($file, $single[0])) {
	    &warn_msg(103, "failed to hardlink $file onto $single[0]");
	    return $false;
	}
    }

    # XXX - misc debug stuff
    #
    print "\nDEBUG: all list:\nDEBUG: ", join("\nDEBUG: " , @list), "\n";
    print "\nDEBUG: single list:\nDEBUG: ", join("\nDEBUG: ", @single), "\n";
    print "\nDEBUG: gz list:\nDEBUG: ", join("\nDEBUG: ", @gz), "\n";
    print "\nDEBUG: plain list:\nDEBUG: ", join("\nDEBUG: ", @plain), "\n";
    print "\nDEBUG: double list:\nDEBUG: ", join("\nDEBUG: ", @double), "\n";
    print "\nDEBUG: index list:\nDEBUG: ", join("\nDEBUG: ", @indx), "\n";

    # all done
    #
    return $true;
}
