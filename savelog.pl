#!/usr/bin/perl -w
#!/usr/bin/perl -Tw
#
# savelog - save old log files and prep for web indexing
#
# @(#) $Revision: 3.2 $
# @(#) $Id: savelog.pl,v 3.2 2002/10/02 05:29:31 chongo Exp chongo $
# @(#) $Source: /usr/local/src/etc/savelog/RCS/savelog.pl,v $
#
# Copyright (c) 2000-2002 by Landon Curt Noll.  All Rights Reserved.
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
#		 [-h] [-n] [-1] [-z] [-T] [-L] [-v]
#		 [-i type [-I typedir]] [-a OLD] [-A archive] file ...
#
#	-m mode	   - chmod current files to mode (def: 0644)
#	-M mode	   - chmod archived files to mode (def: 0444)
#	-o owner   - chown files to user (def: do not chown)
#	-g group   - chgrp files to group (def: do not chgrp)
#	-c count   - cycles of the file to keep, 0=>unlimited (def: 14)
#	-h	   - display a usage message and exit
#	-n	   - do not do anything, just print cmds (def: do something)
#	-1	   - gzip the new 1st cycle now (def: wait 1 cycle)
#	-z	   - force the processing of empty files (def: don't)
#	-T	   - do not create if missing
#	-L	   - do not gzip any new files (def: gzip after 1st cycle)
#	-v	   - enable verbose / debug mode
#	-i type	   - form index files of a given type (def: don't)
#	-I typedir - type file prog dir (def: /usr/local/lib/savelog)
#	-a OLD	   - OLD directory name (not a path) (def: OLD)
#	-A archive - sub-directory under OLD to place files beyond cycle 1
#
# 	savelog [... same flags as above ...] -R dir ...
#
#	-R	   - args are dirs under which most files are archived
#
# FYI:
#	-t	   - (option is ignored, backward compat with Smail savelog)
#
#	NOTE: No Smail code was used in the writing of this source.
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
# unless '-L' was given.  The '-L' option prevents the 1st cycle from
# being gziped as well as preventing other archived files from being gziped.
#
###
#
# When '-i type' is given an parallel index file is created when a file
# is archived.  Index files are of the form:
#
#	/a/path/OLD/file.948346647-948433048.indx
#
# An index file consists lines with 3 fields separated by a single tab:
#
#	offset_start <tab> offset_len <tab> element name <newline>
#
#	offset_start	octet file offset for start of element
#	offset_len	length of element in octets
#	element name	name of this element
#
# For example:
#
#	0	1345	the 1st item
#	1345	1410	the 2nd item
#	2755	1350	the 3rd item
#
# The element name follows the 2nd tab.  It may contain tabs and spaces.
# The element name is terminated by a newline.  An element name may be
# empty; i.e., a newline may immediately follow the 2nd tab.
#
# There may be gaps between elements.  It is not required that the
# entire file consist of element.  For example, a /var/log/messages
# file may only have elements for important blocks of lines.
#
# The index file is sorted by offset_start and then offset_len and
# then by element name.
#
# The offset_len may be 0.  The offset_len must be >= 0.  The offset_start
# must be >= 0.
#
# Elements may overlap other elements.  If an element runs off the
# end of the file, the extra area is assumed to be NUL byte filled.
#
# What constitutes a block of text depends on the 'type' given with the
# flag.  For example, '-i mail' will search for starts of mail messages
# and tag them with the subject line or (no subject).  For example:
#
#	0	3507	A mail message subject line
#	3507	3121	Another subject line
#	6628	2717	(no subject)
#	9345	930	A mail message subject line
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
# If this program does not exist or is not executable, savelog will not
# process the file.
#
###
#
# One can control the number of cycles that savelog will archive a file
# via the '-c count' option.  By default savelog keeps 14 cycles.
#
# If '-c 1' is given, then only the plaintext cycle file is kept.
# If '-c 2' is given, the plaintext file and 1 gziped file is kept.
# If '-c 3' is given, the plaintext file and 2 gziped files are kept.
#
# When savelog finds that too many cycles exist, it will removed those
# with the oldest starting timestamps until the number of cycles is
# reduced.  For example, if ``-c 3'' is given and the follow files exist:
#
#	/a/path/OLD/file.947396249-947482648		(cycle 1)
#	/a/path/OLD/file.947309849-947396249.gz		(cycle 2)
#	/a/path/OLD/file.947223450-947309849.gz		(cycle 3)
#	/a/path/OLD/file.947137058-947050649.gz		(cycle 4)
#	/a/path/OLD/file.947050649-947137050.gz		(cycle 5)
#
# Then the files associated with cycle 4 and 5 would be removed.  Also
# the file associated with cycle would be removed if /a/path/file was
# processed (say because it was non-empty).  This 3 cycle files would
# remain afterwards:
#
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
# On the use of '-A archive':
#
# It is possible to preserve space in the file's filesystem by placing
# gziped files into another directory.  If the OLD directory contains a
# symlink named 'archive':
#
#	/a/path/OLD/archive -> /b/history/directory
#
# and '-A archive' is given, then files will be gziped into the path:
#
#	/a/path/OLD/archive/file.948209998-948296401.gz
#
# which, by way of the archive symlink, will be placed into:
#
#	/b/history/directory/file.948209998-948296401.gz
#
# NOTE: The cycle 1 file will never be placed under OLD/archive.  Only
#	files beyold cycle 1 will be placed under OLD/archive when
#	-A archive is given.
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
# If -R is used, then the arguments are assumed to directories under
# which files will be found.  A tree walk is performed and appropriate
# files are processed.
#
# The following files are NOT archived when -R is given:
#
#	* non-files (dirs, symlinks, sockets, named pipes, special files, ...)
#	* basename of files starting with .
#	* files ending in .gz, .indx or .new
#	* files that match m#\.\d{9,10}$|\.\d{9,10}\-\d{9,10}$#
#
# During the tree walk, the following directories will NOT be walked and
# hence all files under them will be ignored:
#
#	* directories that start with .
#	* directories with the name CVS, RCS or SCCS
#	* directories with the name OLD or archive
#	* if -a was given, directories with the same OLD directory name
#	* directories that are not writable or readable
#	* directories that are not searchable (have no x bits)
#
# If a filename is along with with -R, that filename is processed as
# a regular file without filename restrictions
#
# NOTE: By use of the phrase 'During the tree walk' we refer to files
#	found under the given dir command line argument, not the dir
#	argument itself.  For example, of one gives the a command
#	line argument of OLD, files under OLD will be processed
#	however files under OLD/OLD will not.
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
#
#	     * case -a FOO and no -A:
#		+ If /a/path/FOO exists, it must be a writable directory
#		  or we will abort.
#		+ If /a/path/FOO does not exist and we cannot create it
#		  as a writable directory, we will abort.
#
#	     * case no -a and -A archive:
#		+ If /a/path/OLD exists, it must be a writable directory
#		  or we will abort.
#		+ If /a/path/OLD does not exist and we cannot create it
#		  as a writable directory, we will abort.
#		+ If /a/path/OLD/name exists, it must be a writable directory
#		  or we will abort.
#		+ If /a/path/OLD/name not exist and we cannot create it
#		  as a writable directory, we will abort.
#
#	     * case -a FOO and -A archive:
#		+ If /a/path/FOO exists, it must be a writable directory
#		  or we will abort.
#		+ If /a/path/FOO does not exist and we cannot create it
#		  as a writable directory, we will abort.
#		+ If /a/path/FOO/name exists, it must be a writable directory
#		  or we will abort.
#		+ If /a/path/FOO/name not exist and we cannot create it
#		  as a writable directory, we will abort.
#
#	     * case -i indx_type and no -I:
#		+ /usr/local/lib/savelog/indx_type must be an executable
#		  file or we will abort.
#
#	     * case -i indx_type and -I /indx/prog/dir:
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
#   NOTE: If -R was given, we will assume that the args are directories
#	  and walk the trees under them and perform the equivalent below
#	  as if -R dir ... was replaced with the appropriate files
#	  found under the directories.  See above for information on -R.
#
# The order of processing of /a/path/file is as follows:
#
#	0) Determine if /a/path/file exists.  Touch it (while setting the
#	   proper mode, uid and gid) if it does not unless -T was given.
#	   Do nothing else if the file missing and was not created.
#
#	   Assertion: At this point the file exists or we have stopped.
#
#	1) Remove all but the newest count-1 cycles and, if they exist
#	   unless count is 0.  Remove any index file that is not associated
#	   with a (non-removed) file.  If both foo and foo.gz are found,
#	   the foo file will be removed.  Files are removed from under
#	   /a/path/OLD or from under /a/path/OLD/archive if archive exists.
#
#	   Assertion: At this point only count-1 cycles exist, or '-c 0'
#		      was given and no files were removed.
#
#	2) If -L was NOT given, then gzip all files of the form
#	   /a/path/OLD/file.tstamp1-tstamp2.  The gziped files will be
#	   placed under /a/path/OLD/archive if '-A archive' was given,
#	   or under /a/path/OLD if it was not.
#
#	   If -L was NOT given and if '-A archive' was given then also gzip
#	   any files of the form /a/path/OLD/archive/file.tstamp1-tstamp2
#	   into the /a/path/OLD/archive directory if it exists.
#
#	   If -L was given and '-A archive' was given then any files of the
#	   form /a/path/OLD/file.tstamp1-tstamp2 are moved to
#	   /a/path/OLD/archive/file.tstamp1-tstamp2.
#
#	   If -L was given and '-A archive' was NOT given, then no files
#	   are touched in this step.
#
#	   Assertion: At this point, all files of the form file.tstamp1-tstamp2
#		      have been gziped, or -L was given and no additional files
#		      were gziped.
#
#	   NOTE: Even if '-A archive' was given on the previous run, a file
#		 of the form /a/path/OLD/file.tstamp1-tstamp2 was previously
#		 formed.  For this run, either /a/path/OLD/file.tstamp1-tstamp2
#		 will be gzipped under /a/path/OLD/archive (without -L
#		 or moved under /a/path/OLD/archive (with -L).
#
#	3) Determine if /a/path/file is empty.  Do nothing else if empty
#	   unless -z was given.
#
#	   Assertion: At this point the file is non-empty or -z was given
#		      and the file is empty.
#
#	4) Hard link /a/path/file to /a/path/OLD/file.tstamp_last-now.
#	   Here, 'tstamp_last' is the most recent tstamp2 value from
#	   files of the form /a/path/OLD/file.tstamp1-tstamp2 found
#	   in step 3).  If no such files were found in step 3), then
#	   'tstamp_last' will be set to 'now'.
#
#	   Assertion: /a/path/OLD/file.tstamp_last-now is a hard link
#		      to the file /a/path/file.
#
#	   NOTE: The hard link to /a/path/OLD/file.tstamp_last-now is
#		 done even if '-A archive' was given.  See NOTE in step 3).
#
#	5) Create /a/path/.file.new with the proper mode, uid and gid.
#
#	   Assertion: /a/path/.file.new exists with the proper mode, uid & gid.
#
#	6) Move /a/path/.file.new to /a/path/file (and thus unlinking the
#	   old /a/path/file inode).
#
#	   Assertion: /a/path/file exists with the proper mode, uid and gid.
#
#	   Assertion: The file /a/path/OLD/file.tstamp_last-now (referred
#		      to in step 4) exists and is not had linked to
#		      /a/path/file.
#
#       7) If -i, then /usr/local/lib/savelog /a/path/OLD/file.tstamp_last-now
#	   is executed to form /a/path/OLD/file.tstamp_last-now.indx.  If -i
#	   was not given, we will skip this step.
#
#	   Assertion: The file /a/path/OLD/file.tstamp_last-now exists.
#
#	   Assertion: The file /a/path/OLD/file.tstamp_last-now.indx exists and
#		      -i was given.
#
#       8) If -1 was given, the gzip /a/path/OLD/file.tstamp-now.  Place the
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
	    $opt_h $opt_n $opt_1 $opt_z $opt_T $opt_L $opt_v
	    $opt_i $opt_I $opt_a $opt_A $opt_R);
use Getopt::Std;
$ENV{PATH} = "/sbin:/bin:/usr/sbin:/usr/bin";
$ENV{IFS} = " \t\n";
$ENV{SHELL} = "/bin/sh";
delete $ENV{BASH_ENV};
delete $ENV{ENV};
delete $ENV{GZIP};
use Cwd;
use File::Basename;
use File::Copy;
use IO::File;
use File::Find;
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
my $archive_name;	# files beyond cycle 1 under OLD/archive_name
#
my $exit_val;		# how we will exit
my $gzip_prog;		# location of the gzip program
#
my $true = 1;		# truth as we know it :-)
my $false = 0;		# genuine falseness :-)
#
my %dir_cache;		# $dir_cache{$dir} - \@list of archived files in $dir
my @walk_files;		# list if files found by walk_dir()

# setup
#
$usage = "usage:\n" .
	 "$0 [-m mode] [-M mode] [-o owner] [-g group] [-c cycle]\n" .
	 "\t[-h] [-n] [-1] [-z] [-T] [-L] [-v]\n" .
	 "\t[-i indx_type [-I typedir]] [-a OLD] [-A archive] file ...\n" .
	 "\t\n" .
	 "\t-m mode\t chmod current files to mode (def: 0644)\n" .
	 "\t-M mode\t chmod archived files to mode (def: 0444)\n" .
	 "\t-o owner chown files to user (def: do not chown)\n" .
	 "\t-g group chgrp files to group (def: do not chgrp)\n" .
	 "\t-c count cycles of the file to keep, 0=>unlimited (def: 14)\n" .
	 "\t-h\t display this message and exit\n" .
	 "\t-n\t do not do anything, just print cmds (def: do something)\n" .
	 "\t-1\t gzip the new 1st cycle now (def: wait 1 cycle)\n" .
	 "\t-z\t force the processing of empty files (def: don't)\n" .
	 "\t-T\t do not create if missing\n" .
	 "\t-L\t do not gziped any new files (def: gzip after 1st cycle)\n" .
	 "\t-v\t\t verbose output\n" .
	 "\t-i indx_type\t form index files of a given type (def: don't)\n" .
	 "\t-I typedir\t type file prog dir (def: /usr/local/lib/savelog)\n" .
	 "\t-a OLD\t\t OLD directory name (not a path) (def: OLD)\n" .
	 "\t-A archive\t files beyond cycle 1 under OLD/archive (def: OLD)\n" .
	 "\t\n" .
	 "$0 [... same flags as above ...] -R dir ...\n" .
	 "\t\n" .
	 "\t-R\t args are directories under which most files are archived\n";

# function prototypes
#
sub err_msg($$@);
sub warn_msg($$@);
sub walk_dir($);
sub process_file($);
sub parse();
sub untaint($);
sub prep_file($);
sub safe_file_create($$$$$$$);
sub tstamp_cmp();
sub load_dir($);
sub scan_dir($$$$);
sub rm($$);
sub last_tstamp(@);
sub clean_list(@);
sub split_list(@);
sub rm_cycles(@@);
sub gzip_or_move($$$$);
sub hard_link($$);
sub archive($$$);

# main
#
MAIN:
{
    # setup
    #
    $exit_val = 0;	# hope for the best
    select STDOUT;
    $| = 1;
    if (-x "/bin/gzip") {
	$gzip_prog = "/bin/gzip";
    } elsif (-x "/usr/bin/gzip") {
	$gzip_prog = "/usr/bin/gzip";
    } elsif (-x "/usr/local/bin/gzip") {
	$gzip_prog = "/usr/local/bin/gzip";
    } elsif (-x "/usr/gnu/bin/gzip") {
	$gzip_prog = "/usr/gnu/bin/gzip";
    } elsif (-x "/usr/freeware/bin/gzip") {
	$gzip_prog = "/usr/freeware/bin/gzip";
    } else {
	$gzip_prog = "gzip";
    }
    umask 0;

    # parse args
    #
    parse();
    @ARGV = map { untaint($_) } @ARGV;

    # perform tree walking if -R
    #
    # We place the list of files to process on the command line
    # so that we process files from the current directory instead
    # of from chdir-ed directory (as the result of the find()).
    #
    if (defined $opt_R) {
	find(\&walk_dir, @ARGV);
	@ARGV = sort @walk_files;
    }

    # process each file
    #
    foreach my $file (@ARGV) {
	process_file($file);
    }

    # all done
    #
    print "\nDEBUG: exit code: $exit_val\n" if $verbose;
    exit $exit_val;
}

# err_msg - report an error and exit
#
# usage:
#	err_msg(exitcode, "error format" [,arg ...])
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
    if (@args) {
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
#	warn_msg(exitcode, "warning format" [,arg ...])
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
    if (@args) {
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


# walk_dir - file tree walker
#
# usage:
#	find(\walk_dir, @DIR_LIST);
#
#	$dir	directory to proecss
#
# This function pushes the file names onto the array @walk_files.
#
# NOTE: This function will blindly attempt to start to walk down any directory.
#	While the tree walking will exclude dirs under the -R rules (see above)
#	it is willing to start walk down any directory regardless of name.
#
sub walk_dir($)
{
    my $name = $_;	# the name found by find()

    # taint pruning and untainting
    #
    if ($File::Find::name =~ m#^([\w./,][-\@\w./+:%,~]*)$#) {
    	$File::Find::name = $1;
    } else {
	# disable further tree walking on a tainted name
	#
	print "DEBUG: walk_dir: pruning tainted path: $File::Find::name\n"
	 	if $verbose;
	$File::Find::prune = $true;
    	return;
    }

    # prune out dirs with the name CVS, RCS or SCCS
    #		     with the name OLD or archive
    #		     start with .
    #		     if -a was given, dir with the same OLD directory name
    #		     that are not writable, readable or searchable
    #
    if (-d $name &&
        ($name eq "CVS" || $name eq "RCS" || $name eq "SCCS" ||
    	 $name eq $oldname || $name =~ /^\../ ||
	 ! -r $name || ! -w $name || ! -x $name)) {

	# disable further tree walking
	#
	print "DEBUG: walk_dir: pruning dir: $File::Find::name\n"
		if $verbose;
	$File::Find::prune = $true;
	return;
    }

    # ignore symlinks
    #
    if (-l $name) {
	print "DEBUG: walk_dir: ignoring symlink: $File::Find::name\n"
		if $verbose;
	return;
    }

    # pass thru directories
    #
    if (-d $name) {
	print "DEBUG: walk_dir: passing dir: $File::Find::name\n"
		if $verbose;
	return;
    }

    # ignore other non-files
    #
    if (! -f $name) {
	print "DEBUG: walk_dir: ignoring non-file: $File::Find::name\n"
		if $verbose;
	return;
    }

    # ignore files ending in .gz, .indx or .new
    #		   starting with .
    #	     	   that match m#\.\d{9,10}\-\d{9,10}$#
    #
    if ($name =~ /\.gz$|\.indx$|\.new$|^\.|\.\d{9,10}\-\d{9,10}$/) {
	print "DEBUG: walk_dir: ignoring file: $File::Find::name\n"
		if $verbose;
	return;
    }

    # save the full path of this file for processing
    #
    print "DEBUG: will process $File::Find::name\n" if $verbose;
    push(@walk_files, $File::Find::name);
    return;
}


# process_file - archive a file
#
# usage:
#	process_file($file);
#
#	$file	filename to process
#
# NOTE: This function will blindly attempt to process any file, even those
#	files that are not to be processed under -R tree walking.
#
sub process_file($)
{
    my $file = $_[0];		# filename to process
    my $status;			# subroutine return status
    my $dir;			# prep directory in which $file resides
    my $gz_dir;			# where .gz files are to be placed

    # prepare to process the file
    #
    if ($verbose && defined $opt_n) {
	print "\nDEBUG: starting with: $file\n" if $verbose;
	print "# starting with: $file\n\n" if defined $opt_n;
    } else {
	print "\nDEBUG: starting with: $file\n\n" if $verbose;
	print "\n# starting with: $file\n\n" if defined $opt_n;
    }
    ($status, $dir, $gz_dir) = prep_file($file);
    if (! defined $status || ! defined $dir || ! defined $gz_dir) {
	print STDERR "error while preparing for $file, skipping\n";
	return;
    }

    # archive the file
    #
    if (! archive($file, $dir, $gz_dir)) {
	print STDERR "error while processing $file\n";
	return;
    }
    if ($verbose && defined $opt_n) {
	print "DEBUG: finished with: $file\n" if $verbose;
	print "# finished with: $file\n" if defined $opt_n;
    } else {
	print "\nDEBUG: finished with: $file\n" if $verbose;
	print "\n# finished with: $file\n" if defined $opt_n;
    }

    return;
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
    $cycle = 14;
    $verbose = undef;
    $indx_type = undef;
    $indx_dir = "/usr/local/lib/savelog";
    $indx_prog = undef;
    $oldname = "OLD";
    $archive_name = undef;

    # parse args
    #
    if (!getopts('m:M:o:g:c:hn1zTLvi:I:a:A:R') || !defined($ARGV[0])) {
    	die $usage;
	exit 1;
    }

    # process -h and exit
    #
    if (defined $opt_h) {
	print "$usage";
	exit 0;
    }

    # -v
    #
    $verbose = $opt_v if defined $opt_v;
    print "DEBUG: verbose mode: set\n" if $verbose;

    # -m mode
    #
    $file_mode = oct($opt_m) if defined $opt_m;
    if ($file_mode != 0644 && $verbose) {
	printf "DEBUG: using non-default file mode: 0%03o\n", $file_mode
		if $verbose;
    }

    # -M mode
    #
    # turn on exec bits in $archdir_mode as well as any write bits
    # found in $archive_mode.
    #
    $archive_mode = oct($opt_M) if defined $opt_M;
    if ($archive_mode != 0444) {
	printf("DEBUG: non-default archive mode: 0%03o\n", $archive_mode)
		if $verbose;
    	$archdir_mode = 0700;
	if (($archive_mode & 0060) != 0) {
	    $archdir_mode |= (($archive_mode & 0060) | 0010);
	}
	if (($archive_mode & 0006) != 0) {
	    $archdir_mode |= (($archive_mode & 0006) | 0001);
	}
	printf "DEBUG: non-default archive dir mode: 0%03o\n", $archdir_mode
		if $verbose;
    } else {
    	$archdir_mode = 02755;
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
		err_msg(4, "parse: bad user: $opt_o");
	    }
	    print "DEBUG: set file uid: $file_uid\n" if $verbose;
        } else {
	    err_msg(5, "parse: only the superuser can use -o");
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
		err_msg(6, "parse: bad group: $opt_g");
	    }
	    print "DEBUG: set file gid: $file_gid\n" if $verbose;
        } else {
	    err_msg(7, "parse: only the superuser can use -g");
	}
    }

    # -c cycle
    #
    $cycle = $opt_c if defined $opt_c;
    if ($cycle < 0) {
	err_msg(8, "parse: cycles to keep: $cycle must be >= 0");
    }

    # -i indx_type
    #
    if (defined $opt_i) {
	$indx_type = $opt_i;
	if ($indx_type =~ m:[/~*?[]:) {
	    err_msg(9, "parse: index type may not contain /, ~, *, ?, or [");
	}
	if ($indx_type eq "." || $indx_type eq "..") {
	    err_msg(10, "parse: index type type may not be . or ..");
	}
	print "DEBUG: index type: $indx_type\n" if $verbose;
    }

    # -I typedir
    #
    if (defined $opt_I) {
	if (!defined $opt_i) {
	    err_msg(11, "parse: use of -I typedir requires -i indx_type");
	}
	if (! -d $opt_I) {
	    err_msg(12, "parse: no such index type directory: $opt_I");
	}
	$indx_dir = $opt_I;
	print "DEBUG: index prog dir: $indx_dir\n" if $verbose;
    }
    if (defined($indx_type)) {
    	if (! -x "$indx_dir/$indx_type") {
	    err_msg(13,
	    	"parse: index type prog: $indx_type not found in: $indx_dir");
	}
	$indx_prog = "$indx_dir/$indx_type";
	print "DEBUG: indexing prog: $indx_prog\n" if $verbose;
    }

    # -a OLDname
    #
    $oldname = $opt_a if defined $opt_a;
    if ($oldname =~ m:[/~*?[]:) {
	err_msg(14, "parse: OLD dir name may not contain /, ~, *, ?, or [");
    }
    if ($oldname eq "." || $oldname eq "..") {
	err_msg(15, "parse: OLD dir name may not be . or ..");
    }
    if ($oldname ne "OLD" && $verbose) {
	print "DEBUG: using non-default OLD name: $oldname\n" if $verbose;
    }

    # -A archive_name
    #
    if (defined $opt_A) {
	if (defined $opt_A =~ m:/:) {
	    $archive_name = $opt_A;
	    print "DEBUG: archive name: $archive_name\n" if $verbose;
	} elsif ($opt_A eq "." || $opt_A eq "..") {
	    err_msg(16, "-A name cannot be . or ..");
	} else {
	    err_msg(17, "-A name cannot contain /'s");
	}
    }

    # must have at least one arg
    #
    die $usage unless defined $ARGV[0];
    print "DEBUG: end of argument parse\n" if $verbose;
}


# untaint - untaint a filename
#
# usage:
#	untaint($file)
#
# returns:
#	untainted $file or calls err_msg()
#
# This function helps ensure that the filenames used to not have bad or
# dangerous chars in them.  It is designed to pass -T taint-perl inspection.
#
sub untaint($)
{
    my $file = $_[0];		# get arg

    if ($file =~ m#^([\w./,][-\@\w./+:%,~]*)$#) {
    	$file = $1;
    } else {
	err_msg(16, "file has dangerous chars: $file");
    }
    return $file;
}


# prep_file - prepare archive a file
#
# usage:
#	($status, $dir, $gz_dir) = prep_file($file);
#
#	$file			path of prep file to archive
#
# returns:
#    status:
#	0 ==> prep was unsuccessful
#	1 ==> prep was successful or -n
#    $dir		ref to prep directory of $file
#    $gz_dir		ref to where .gz files are to be placed
#
sub prep_file($)
{
    # my vars
    #
    my ($file) = @_;		# parse args
    my $dir;			# dirname of $file (dir where file exists)
    my $gz_dir;			# directory where .gz files are kept
    my $mode;			# stated mode of a file or directory
    my $archive_dir;		# full path of OLD/archive directory
    my ($dev1, $dev2, $inum1, $inum2);	# dev/inum of two inodes

    # determine the file's directory
    #
    $dir = dirname($file);
    print "DEBUG: prep $file  dir is: $dir\n" if $verbose;

    # untaint the file
    #
    $file = untaint($file);

    # make sure that the OLD directory exists
    #
    if (! -d "$dir/$oldname") {
	if (defined $opt_n) {
	    print "mkdir $dir/$oldname\n";
	} elsif (mkdir("$dir/$oldname", $archdir_mode)) {
	    print "DEBUG: created $dir/$oldname\n" if $verbose;
	} else {
	    err_msg(17, "cannot mkdir: $dir/$oldname: $!");
	}
    }

    # If we were asked to use an archive subdir of OLD, be sure that it exists,
    # is in the right location, has the right mode and is writable
    #
    if (defined($archive_name)) {

        # untaint archive_dir
	#
	$archive_dir = "$dir/$oldname/" . untaint($archive_name);

	# create archive directory if it does not exist
	#
	if (! -d $archive_dir) {
	    if (defined $opt_n) {
		print "mkdir $archive_dir\n";
	    } elsif (mkdir("$archive_dir", $archdir_mode)) {
		print "DEBUG: created $archive_dir\n" if $verbose;
	    } else {
		err_msg(17, "cannot mkdir: $archive_dir: $!");
	    }
	}
	$gz_dir = $archive_dir;

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
	if (chmod($archdir_mode, "$dir/$oldname") == 1) {
	    printf("DEBUG: chmoded %s from 0%03o to 0%03o\n",
	    	   "$dir/$oldname", $mode, $archdir_mode) if $verbose;
	} else {
	    warn_msg(24, "unable to chmod 0%03o OLD directory: %s",
			 $archdir_mode, "$dir/$oldname");
	    return ($false, undef, undef);
	}
    }
    if (! -w "$dir/$oldname") {
	warn_msg(25, "OLD directory: $dir/$oldname is not writable");
    	return ($false, undef, undef);
    }
    #
    if ($gz_dir ne "$dir/$oldname") {
	(undef, undef, $mode, undef) = stat($gz_dir);
	$mode &= 07777;
	if ($mode != $archdir_mode) {
	    if (chmod($archdir_mode, $gz_dir) == 1) {
		printf("DEBUG: chmoded %s from 0%03o to 0%03o\n",
		       $gz_dir, $mode, $archdir_mode) if $verbose;
	    } else {
		warn_msg(26, "unable to chmod 0%03o archive directory: %s",
		    $archdir_mode, $gz_dir);
		return ($false, undef, undef);
	    }
	}
	if (! -w $gz_dir) {
	    warn_msg(27, "archive directory: $gz_dir is not writable");
	    return ($false, undef, undef);
	}
    }

    # return dir, file, and gz_dir
    #
    return ($true, $dir, $gz_dir);
}


# safe_file_create - safely create a file with the proper perm, uid and gid
#
# usage:
#	safe_file_create($file, $uid, $gid, $mode, $rename, $dir, $base);
#
#	$file		form $file (may form $file.new first)
#	$uid		force owner to be $uid (or -1 to not chown)
#	$gid		force group to be $gid (or -1 to not chgrp)
#	$mode		permissions / ownership
#	$rename		TRUE ==> force a rename, FALSE ==> OK to create directly
#	$dir		if $rename is TRUE, the $dir in which $file resides
#	$base		if $rename is TRUE, basename of $file
#
# returns:
#	0 ==> safe create was unsuccessful
#	1 ==> safe create was successful
#
# NOTE: This subroutine does not check $opt_n.
#
sub safe_file_create($$$$$$$)
{
    my ($file, $uid, $gid, $mode, $rename, $dir, $base) = @_;	# get args
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

	# form a safe new name
	#
	$dir = dirname($file) if !defined $dir;
	$base = basename($file) if !defined $base;
	$newname = untaint("$dir/.$base.new");

	# untaint old name
	#
	$file = untaint($file);

	# create the file on the side
	#
	if (! sysopen FILE, $newname, O_CREAT|O_RDONLY|O_EXCL, $mode) {
	    print "DEBUG: couldn't create $newname\n" if $verbose;
	    return $false;
	}
	printf("DEBUG: safely made %s, mode 0%03o\n", $newname, $mode)
		if $verbose;

	# move the file in place
	#
	if (! rename $newname, $file) {
	    warn_msg(28, "couldn't mv $newname $file");
	    return $false;
	}
	print "DEBUG: moved $newname to $file\n" if $verbose;
	close FILE;
	return $true;
    }

    # form a safe new name
    #
    $dir = dirname($file) if !defined $dir;
    $base = basename($file) if !defined $base;
    $newname = "$dir/.$base.new";
    $newname = untaint("$dir/.$base.new");

    # untaint old name
    #
    $file = untaint($file);

    # create the file on the side
    #
    if (! sysopen FILE, $newname, O_CREAT|O_RDONLY|O_EXCL, $mode) {
	warn_msg(29, "cannot create $newname");
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
	warn_msg(30, "bad fchown $uid_arg.$gid_arg $newname");
	close FILE;
	return $false;
    }
    print "DEBUG: fchown $uid_arg.$gid_arg $newname\n" if $verbose;

    # move the file in place
    #
    if (! rename $newname, $file) {
	warn_msg(31, "cannot mv $newname $file");
	return $false;
    }
    print "DEBUG: mv $newname $file\n" if $verbose;
    close FILE;
    return $true;
}


# tstamp_cmp - sort function to sort files by timestamp
#
# usage:
#	@array = sort tstamp_cmp @array;
#
# returns:
#	-1 ==> $a < $b
#	 0 ==> $a == $b
#	 1 ==> $a > $b
#
# Files are sorted in timestamp order.  The 1st timestamp (or the only
# timestamp of the file only has one) is the primary order.  The 2nd
# timestamp, if it exists, is the secondary order.
#
# A file with one timestamp is sorted before a file with two timestamps
# where the 1st stamp is the same.
#
# A files timestamp(s) are sorted after a files without any timestamps.
# Files without timestamps are sorted in cmp (string) order.  Files with
# equivalent timestamps are sorted in cmp (string) order.
#
sub tstamp_cmp()
{
    my $a_base;		# basename of $a
    my $a_t1 = -1;	# first timestamp for $a or -1
    my $a_t2 = -1;	# second timestamp for $a or -1
    my $b_base;		# basename of $b
    my $b_t1 = -1;	# first timestamp for $b or -1
    my $b_t2 = -1;	# second timestamp for $b or -1

    # determine the timestamps of $a
    #
    ($a_base, undef, undef) = fileparse($a, '\.[a-zA-Z]+');
    if ($a_base =~ m#\.(\d+)\-(\d+)$#) {
	$a_t1 = $1;
	$a_t2 = $2;
    } elsif ($a_base =~ m#\.(\d+)$#) {
	$a_t1 = $1;
    }

    # determine the timestamps of $b
    #
    ($b_base, undef, undef) = fileparse($b, '\.[a-zA-Z]+');
    if ($b_base =~ m#\.(\d+)\-(\d+)$#) {
	$b_t1 = $1;
	$b_t2 = $2;
    } elsif ($b_base =~ m#\.(\d+)$#) {
	$b_t1 = $1;
    }

    # compare timestamps
    #
    if ($a_t1 < $b_t1) {
	return -1;
    } elsif ($a_t1 > $b_t1) {
	return 1;
    } elsif ($a_t2 < $b_t2) {
	return -1;
    } elsif ($a_t2 > $b_t2) {
	return 1;
    }
    return $a cmp $b;
}


# load_dir - load a list with the files of files found in a directory
#
# usage:
#	($status, $list) = load_dir($dir)
#
#	$dir	directory to scan for files
#
# returns:
#    $status:
#	0 ==> scan was unsuccessful
#	1 ==> scan was successful or ignored
#    @{$list}
#	list of files of files found in $dir
#
# NOTE: This routine will not rescan a directory once it has been read once.
#
sub load_dir($)
{
    my ($dir) = @_;	# get args
    my @list;		# list if files found in $dir
    my $file;		# file found in $dir
    my $i;

    # if we have not cached files in $dir, cache them now
    #
    if (!defined $dir_cache{$dir}) {

	# prep for scanning dir
	#
	if (! opendir DIR, $dir) {
	    warn_msg(32, "unable to open dir: $dir");
	    return ($false, undef);
	}

	# scan dir for files
	#
	$#list = -1;
	while ($file = readdir DIR) {
	    push(@list, "$dir/$file") if -f "$dir/$file";
	}
	closedir DIR;

	# cache the list of files
	#
	$dir_cache{$dir} = \@list;
    }

    # return our cache
    #
    return ($true, $dir_cache{$dir});
}


# scan_dir - scan the OLD and possibly archive dir for archived files
#
# usage:
#	($status, $list) = scan_dir($file, $base, $olddir, $archdir)
#
#	$file		archived file to scan for in $olddir or $archdir
#	$base		basename of $file
#	$olddir		OLD directory name to scan in
#	$archdir	name of OLD/archive to scan for or just $olddir
#
# We will look for files of the form:
#
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
#    $status:
#	0 ==> scan was unsuccessful
#	1 ==> scan was successful or ignored
#    @{$list}
#	list of files found
#
# NOTE: We will return the list sorted by timestamp.
#
# NOTE: The moves, copies, and gzips that are performed by archive() are
#	specific to a particular file.
#
sub scan_dir($$$$)
{
    my ($file, $base, $olddir, $archdir) = @_;	# get args
    my $filelist;		# @{$array} of files found in a directory
    my @list;			# list of files to return
    my $status;			# subroutine return status

    # scan OLD/ for files of the form base\.\d{9,10}\-\d{9,10}
    #
    print "DEBUG: scanning $olddir for $base files\n" if $verbose;
    ($status, $filelist) = load_dir($olddir);
    if (! $status) {
	warn_msg(33, "unable to open OLD dir: $olddir");
	return ($false, undef);
    }
    @list = grep m#/$base\.\d{9,10}\-\d{9,10}$|/$base\.\d{9,10}\-\d{9,10}\.gz$|/$base\.\d{9,10}\-\d{9,10}\.indx$#, @{$filelist};

    # scan OLD/archive if it exists and is not OLD
    #
    if (defined $archdir && $archdir ne $olddir && -d $archdir) {

	# scan the OLD/archive
	#
	print "DEBUG: also scanning $archdir for $base files\n" if $verbose;
	($status, $filelist) = load_dir($archdir);
	if (! $status) {
	    warn_msg(34, "cannot open OLD/archive dir: $archdir");
	    return ($false, undef);
	}
	push(@list, grep m#/$base\.\d{9,10}\-\d{9,10}$|/$base\.\d{9,10}\-\d{9,10}\.gz$|/$base\.\d{9,10}\-\d{9,10}\.indx$#, @{$filelist});
    }

    # return information
    #
    @list = sort tstamp_cmp @list;
    return ($true, \@list);
}


# rm - remove a file (or not if -n)
#
# usage:
#	rm($file[, $reason]);
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
	print "# removal reason: $reason\nrm -f $file\n";

    # case: attempt to remove the file
    #
    } else {

	# untaint $file
	#
	$file = untaint($file);

	# unlink
	#
	if (unlink $file) {
	    print "DEBUG: removal reason: $reason\n" if $verbose;
	    print "DEBUG: rm -f $file\n" if $verbose;

	} else {
	    warn_msg(36, "cannot remove $file\n");
	}
    }
}


# clean_list - remove duplicate foo and foo.gz files and stale .indx files
#
#	clean_list(\@list)
#
#	@list		list of archived files of $file to be cleaned
#
sub clean_list(@)
{
    my $list = $_[0];	# get args
    my $prev;		# previous item on list
    my $cur;		# current item on list
    my $i;

    # verify that the list arg is an array reference
    #
    if (!defined($list) || ref($list) ne 'ARRAY') {
	err_msg(37, "clean_list: 2nd argument is not an array reference");
    }

    # do nothing if the list has 1 or 0 files in it
    #
    if ($#$list <= 0) {
	return;
    }

    # deal with the case where a .indx file is the first on the list
    #
    if ($$list[0] =~ /\.indx$/) {
	rm($$list[0], "first lone .indx file");
	splice @$list, 0, 1;
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
	    err_msg(38, "clean_list: found duplicate list item: $cur");
	}

	# catch foo and foo.gz and remove foo
	#
	if ("$prev.gz" eq $cur) {
	    rm($prev, "also found $cur");
	    splice @$list, $i-1, 1;
	    --$i;
	}

	# remove lone .indx files
	#
	if ($cur =~ /\.indx$/) {
	    my $baseindx;	# filename without the .indx

	    # catch lone .indx files
	    #
	    ($baseindx = $cur) =~ s/\.indx$//;
	    if ($baseindx ne $prev && "$baseindx.gz" ne $prev) {
		rm($cur, "lone .indx file");
		splice @$list, $i, 1;
		--$i;
	    }
	}
    }
}


# last_tstamp - determine the most recent tstamp in a list of filenames
#
# given:
#	$last_time = last_tstamp(\@list);
#
# returns:
#	Most recent tstamp2 from a list of file.tstamp1-tstamp2* files
#	or return undef or list is empty or undefined
#
sub last_tstamp(@)
{
    my ($list) = @_;	# get args
    my $last = undef;	# most recent tstamp found in $list
    my $tstamp1;	# tstamp1 from file.tstamp1-tstamp2* filename
    my $i;

    # verify that we were given references to arrays
    #
    if (!defined $list || ref($list) ne 'ARRAY') {
	err_msg(39, "last_tstamp: arg is not an array reference");
    }

    # look for the most recent tstamp
    #
    foreach $i (@$list) {

	# filename must be well formed
	#
	if ($i =~ /\.\d{9,10}\-(\d{9,10})\.gz$/ ||
	    $i =~ /\.\d{9,10}\-(\d{9,10})$/) {
	    $tstamp1 = $1;
	    if ((defined $last && $last < $tstamp1) || !defined $last) {
	    	$last = $tstamp1;
	    }
	}
    }

    # return most recent tstamp or undef
    #
    return $last;
}


# split_list - split a list of files into single, double, gz and index files
#
# given:
#	($status, $gz, $plain, $double, $index) = split_list(\@list);
#
#	@list		a list of archived files (from scan_dir, for example)
#
# returns:
#    $status:
#	0 ==> scan was unsuccessful
#	1 ==> scan was successful or ignored
#    @{$gz}		files of the form name\.\d{9,10}\-\d{9,10}\.gz
#    @{$plain}		files of the form name\.\d{9,10}\-\d{9,10}
#    @{$double}		both @gz and @plain files
#    @{$index}		files of the form name\.\d{9,10}\-\d{9,10}\.indx
#
sub split_list(@)
{
    my ($list) = @_;	# get args
    my $status;		# subroutine return status
    my @gz;		# files of the form name\.\d{9,10}\-\d{9,10}\.gz
    my @plain;		# files of the form name\.\d{9,10}\-\d{9,10}
    my @double;		# both @gz and @plain files
    my @index;		# files of the form name\.\d{9,10}\-\d{9,10}\.indx
    my $i;

    # verify that we were given references to arrays
    #
    if (!defined $list || ref($list) ne 'ARRAY') {
	err_msg(40, "split_list: arg is not an array reference");
    }

    # truncate lists
    #
    $#gz = -1;
    $#plain = -1;
    $#double = -1;
    $#index = -1;

    # look at each element and classify it
    #
    foreach $i (@$list) {

	# record file\.\d{9,10}\-\d{9,10}\.gz files (also as double files)
	#
	if ($i =~ /\.\d{9,10}\-\d{9,10}\.gz$/) {
	    push(@gz, $i);
	    push(@double, $i);

	# record file\.\d{9,10}\-\d{9,10} files (also as double files)
	#
	} elsif ($i =~ /\.\d{9,10}\-\d{9,10}$/) {
	    push(@plain, $i);
	    push(@double, $i);

	# record file\.\d{9,10}\-\d{9,10}\.indx files
	#
	} elsif ($i =~ /\.\d{9,10}\-\d{9,10}\.indx$/) {
	    push(@index, $i);

	# we should not get here
	#
	} else {
	    err_msg(41, "split_list: found bogus member of file list: $i");
	}
    }

    # return the results
    #
    return ($true, \@gz, \@plain, \@double, \@index);
}


# rm_cycles - split a list of files into gz and index files
#
# given:
#	rm_cycles(\@plain, \@double)
#
#	@plain		files of the form name\.\d{9,10}\-\d{9,10}
#	@double		both @gz and @plain files
#
# This function will all but the last $cycle-1 files found in \@double.
# We remove all but the last (most recent) $cycle-1 files instead of
# $cycle files because later on we will archive the current file and
# form a new cycle.
#
sub rm_cycles(@@)
{
    my ($plain, $double) = @_;		# get args
    my $indx;				# potential .indx file to remove
    my $i;

    # verify that we were given references to arrays
    #
    if (!defined $plain || ref($plain) ne 'ARRAY' ||
        !defined $double || ref($double) ne 'ARRAY') {
	err_msg(42, "rm_cycles: args are not an array references");
    }

    # Remove all but the oldest $cycle-1 files found in @$double
    #
    return unless scalar(@$double) >= $cycle;
    for ($i=0; $i <= $#$double-$cycle+1; ++$i) {

	# remove archived file
	#
	rm($$double[$i], "keeping newest $cycle-1 cycles");

	# remove an associated index file if it exists
	#
	($indx = "$$double[$i].indx") =~ s/\.gz\.indx$/.indx/;
	rm($indx, "archive file was just removed") if -f $indx;
    }
    splice @$double, 0, $i;

    # rebuild @$plain
    $#$plain = -1;
    for ($i=0; $i <= $#$double; ++$i) {
	if ($$double[$i] !~ /\.gz$/) {
	    push(@$plain, $$double[$i]);
	}
    }

    return;
}


# gzip_or_move - gzip or move a file into the appropriate directory
#
# usage:
#	gzip_or_move($file, $inplace, $dir, $target)
#
#	$file		file to gzip
#	$need_gzip	TRUE ==> gzip file, FALSE ==> move file
#	$inplace	TRUE ==> gzip $file inplace in its current directory
#	$target		$inplace ==> FALSE, move/gzip into $target directory
#
# returns:
#	0 ==> gzip/move was unsuccessful
#	1 ==> gzip/move was successful or was disabled by -n
#
# We gzip by running the gzip command in a child process.
#
# NOTE: When $need_gzip == FALSE and $inplace == TRUE then this function is
#	does nothing.
#
# NOTE: Warns but does not return 0 if the chmod fails.  By the time
#	the chmod is done, the file has either been gziped or it
#	have been moved.
#
# NOTE: No chmod is done if $need_gzip == FALSE and $inplace == TRUE.
#
sub gzip_or_move($$$$)
{
    my ($file, $need_gzip, $inplace, $target) = @_;	# get args
    my $base;				# basename of file

    # firewall
    #
    if (! defined $file || ! defined $need_gzip ||
        ! defined $inplace || ! defined $target) {
	error(20, "gzip_or_move: undef args");
    }

    # Do nothing if we are 'moving in place'
    #
    if (! $need_gzip && $inplace) {
	if (defined $opt_n) {
	    print "# $file will not be gziped or moved\n" if $verbose;
	} else {
	    print "DEBUG: $file is not gziped or moved\n" if $verbose;
	}
	return $true;
    }

    # prep
    #
    $file = untaint($file);
    $target = untaint($target);
    $base = basename($file);

    # gzip file in place
    #
    if ($need_gzip && $inplace) {

	# do nothing if -n
	#
	if (defined $opt_n) {
	    print "$gzip_prog --best -f -q $file\n";
	    printf("chmod 0%03o $file.gz\n", $archive_mode);
	    return $true;
	}

	# fork/exec gzip of the file
	#
	if (system("$gzip_prog", "--best", "-f", "-q", "$file") != 0) {
	    warn_msg(43, "$gzip_prog --best -f -q $file failed: $!");
	    return $false;
	}
	print "DEBUG: $gzip_prog --best -f -q $file\n" if $verbose;

	# chmod the archived file
	#
	if (chmod($archive_mode, "$file.gz") != 1) {
	    warn_msg(44, "chmod 0%03o $file.gz failed", $archive_mode);
	}
	printf("DEBUG: chmod 0%03o $file.gz\n", $archive_mode) if $verbose;

    # gzip the file into $target
    #
    } elsif ($need_gzip && ! $inplace) {

	# do nothing if -n
	#
	if (defined $opt_n) {
	    print "/bin/mv -f $file $target/$base &&\n";
	    print "$gzip_prog --best -f -q $target/$base\n";
	    printf("chmod 0%03o $target/$base.gz\n", $archive_mode);
	    return $true;
	}

	# move file to the new directory
	#
	if (move($file, "$target/$base") != 1) {
	    warn_msg(45, "failed to mv $file $target/$base: $!\n");
	    return $false;
	}
	print "DEBUG: mv -f $file $target/$base\n" if $verbose;

	# gzip the file in dir
	#
	if (system("$gzip_prog", "--best", "-f", "-q", "$target/$base") != 0) {
	    warn_msg(46, "$gzip_prog --best -f -q $target/$base failed: $!");
	    return $false;
	}
	print "DEBUG: $gzip_prog --best -f -q $target/$base\n" if $verbose;

	# chmod the archived file
	#
	if (chmod($archive_mode, "$target/$base.gz") != 1) {
	    warn_msg(47, "chmod 0%03o $target/$base.gz failed",$archive_mode);
	}
	printf("DEBUG: chmod 0%03o $target/$base.gz\n", $archive_mode)
	    if $verbose;

    # move the file into $target
    #
    } elsif (! $need_gzip && ! $inplace) {

	# do nothing if -n
	#
	if (defined $opt_n) {
	    print "/bin/mv -f $file $target/$base &&\n";
	    printf("chmod 0%03o $target/$base.gz\n", $archive_mode);
	    return $true;
	}

	# move file to the new directory
	#
	if (move($file, "$target/$base") != 1) {
	    warn_msg(48, "failed to mv $file $target/$base: $!\n");
	    return $false;
	}
	print "DEBUG: mv -f $file $target/$base\n" if $verbose;

	# chmod the moved file
	#
	if (chmod($archive_mode, "$target/$base") != 1) {
	    warn_msg(49, "chmod 0%03o $target/$base failed",$archive_mode);
	}
	printf("DEBUG: chmod 0%03o $target/$base\n", $archive_mode)
	    if $verbose;
    }
    return $true;
}


# hard_link - ensure that a file is hardlinked to another
#
# usage:
#	hard_link($from, $to)
#
#	$from		hardlink this file
#	$to		ensure that $to is a hardlink to $from
#
# returns:
#	0 ==> archive was unsuccessful
#	1 ==> archive was successful or ignored
#
# NOTE: This function ignores $opt_n.
#
sub hard_link($$)
{
    my ($from, $to) = @_;	# get args
    my ($f_dev, $f_inum, $f_links);	# $from stat information
    my ($t_dev, $t_inum, $t_links);	# $to stat information

    # the from file must exist
    #
    ($f_dev, $f_inum, undef, $f_links) = stat($from);
    if (! -f $from ||
        !defined $f_dev || !defined $f_inum || !defined $f_links) {
	warn_msg(50, "hard_link: cannot stat or no such file: $from");
	return $false;
    }

    # If the $to file does exist, see if it is a hardlink to $from.
    # We can ignore this if $from does not have enough links.
    #
    if ($f_links > 1 && -f $to) {
        ($t_dev, $t_inum, undef, $t_links) = stat($to);
	if (defined $t_dev && $f_dev == $t_dev &&
	    defined $t_inum && $f_inum == $t_inum &&
	    defined $t_links && $f_links == $t_links) {
	    print "DEBUG: $from already hardlinked onto $to\n" if $verbose;
	    return $true;
	}
    }

    # force $to to be a hardlink of $from
    #
    # untaint the name of $from and $to
    #
    $from = untaint($from);
    $to = untaint($to);

    # hardlink $from onto $to
    #
    rm($to, "removed prior to hard linking of $from") if -f $to;
    if (link($from, $to) <= 0) {
	warn_msg(51, "failed to hardlink $from onto $to");
	return $false;
    }
    print "DEBUG: ln $from $to\n" if $verbose;
    return $true;
}


# archive - archive a file
#
# usage:
#	archive($file, $dir, $gz_dir)
#
#	$file		path of prep file to archive
#	$dir		prep directory of $file
#	$gz_dir		where .gz files are to be placed
#
# returns:
#	0 ==> archive was unsuccessful
#	1 ==> archive was successful or ignored
#
# NOTE: It is assumed that our currently directory has been set to $dir.
#
sub archive($$$)
{
    my ($file, $dir, $gz_dir) = @_;	# get args
    my $list;		# @{$list} of archived files
    my $gz;		# @{$files} of the form file\.\d{9,10}\-\d{9,10}\.gz
    my $plain;		# @{$files} of the form file\.\d{9,10}\-\d{9,10}
    my $double;		# @gz and @plain @{$files}
    my $indx;		# @{$files} of the form file\.\d{9,10}\-\d{9,10}\.indx
    my $base;		# basename of file
    my $now;		# seconds since the epoch of now
    my $status;		# return status from subroutine
    my $tstamp2;	# new file of the form file\.\d{9,10}\-\d{9,10}
    my $old_file;	# $file linked as OLD/$base.$old_file-$now
    my $need_gzip;	# TRUE ==> gzip file, FALSE ==> move file
    my $i;

    # prep work
    #
    $base = basename($file);
    $now = time();
    if (defined $opt_L) {
	$need_gzip = $false;	# move files
    } else {
	$need_gzip = $true;	# gzip files
    }

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
	    if (defined $opt_n) {
		print ":> $file\n";
		printf("chmod 0%03o $file\n", $file_mode);
		print "chown $file_uid $file\n" if defined $file_uid;
		print "chgrp $file_gid $file\n" if defined $file_gid;
	    } else {
		if (! safe_file_create($file, $file_uid, $file_gid,
					$file_mode, $false, undef, undef)) {
		    warn_msg(52, "could not exclusively create $file");
		    return $false;
		}
	    }
	}

	# verify that the file still exists
	#
	if (! defined $opt_n && ! -f $file) {
	    warn_msg(53, "created $file and now it is missing");
	    return $false;
	}
    }

    # step 1 - Remove all but the newest cycle-1 files if not blocked
    #
    ($status, $list) = scan_dir($file, $base, "$dir/$oldname", $gz_dir);
    if (! $status) {
	warn_msg(54, "failed to scan $dir/$oldname\n");
	return $false;
    }
    clean_list($list);
    ($status,$gz,$plain,$double,$indx) = split_list($list);
    if (! $status) {
	warn_msg(55, "splitlist failed on $file\'s dirs\n");
	return $false;
    }
    if ($cycle > 0 && scalar(@{$double}) >= $cycle) {
	rm_cycles($plain, $double);
    }

    # step 2 - gzip or move (of -L) all file.tstamp1-tstamp2 files
    #
    if (scalar(@{$plain}) > 0) {

	# gzip or move (of -L) each plain file
	#
	# If we have an archive dir, all plain files in the archive dir
	# will be gziped in place and all plain files in the
	# OLD dir will be gziped into the archive directory.
	#
	# If we do not have an archive dir, all plain files will be
	# gziped in place.
	#
	for ($i = 0; $i <= $#$plain; ++$i) {

	    # gzip or move files in place
	    #
	    if (! defined $archive_name ||
	    	$$plain[$i] =~ m#/$archive_name/[^/]+$#o) {

		# gzip the file in place
		gzip_or_move($$plain[$i], $need_gzip, $true, $gz_dir);

	    # gzip the file into the archive dir
	    #
	    # If '-A archive' was given then, files will be gziped into
	    # the $gz_dir (which is under OLD/archive);
	    #
	    } else {

		# gzip the file into the archive dir
		gzip_or_move($$plain[$i], $need_gzip, $false, $gz_dir);
	    }
	}
    }
    # If we have "-A archive" and files directly under OLD, move
    # then older OLD/archive.
    #
    if (defined $archive_name && scalar(@{$gz}) > 0) {
	for ($i = 0; $i <= $#$gz; ++$i) {

	    # ignore files already under OLD/archive
	    #
	    next if ($$gz[$i] =~ m#/$archive_name/[^/]+$#o);

	    # move file under archive
	    #
	    gzip_or_move($$gz[$i], $false, $false, $gz_dir);
	}
    }
    if (defined $archive_name && scalar(@{$indx}) > 0) {
	for ($i = 0; $i <= $#$indx; ++$i) {

	    # ignore .indx files already under OLD/archive
	    #
	    next if ($$indx[$i] =~ m#/$archive_name/[^/]+$#o);

	    # move the .indx file under archive
	    #
	    gzip_or_move($$indx[$i], $false, $false, $gz_dir);
	}
    }

    # step 3 - Determine if /a/path/file is empty
    #
    if (-z $file && ! defined $opt_z) {

	print "DEBUG: $file is empty and -z was not given\n" if $verbose;
	print "DEBUG: nothing to do for $file\n" if $verbose;
	return $true;
    }

    # step 4 - Hard link /a/path/file to /a/path/OLD/file.tstamp_last-now
    #
    $old_file = last_tstamp($list);
    $old_file = $now if ! defined $old_file;
    $old_file = "$dir/$oldname/$base.$old_file-$now";
    print "DEBUG: last timestamp: $old_file\n" if $verbose;
    if (defined $opt_n) {
	print "ln -f $file $old_file\n";
    } else {
	if (! hard_link($file, "$old_file")) {
	    warn_msg(56, "failed to hardlink $file onto %s", $old_file);
	    return $false;
	}
    }

    # step 5 - Create /a/path/.file.new with the proper mode, uid and gid
    # step 6 - Move /a/path/.file.new to /a/path/file
    #
    if (defined $opt_n) {
	if (-f "$dir/.$base.new") {
	    print "rm -f $dir/.$base.new\n";
	}
	print ":> $dir/.$base.new\n";
	printf("chmod 0%03o $dir/.$base.new\n", $file_mode);
	print "mv -f $dir/.$base.new $file\n";
	print "chown $file_uid $file\n" if defined $file_uid;
	print "chgrp $file_gid $file\n" if defined $file_gid;
    } else {
	if (-f "$dir/.$base.new") {
	    print "DEBUG: removing $dir/.$base.new\n" if $verbose;
	    rm("$dir/.$base.new", "need filename for new version");
	}
	if (! safe_file_create($file, $file_uid, $file_gid, $file_mode,
				$true, $dir, $base)) {
	    warn_msg(57, "failed to safely create new $file");
	    return $false;
	}
    }
    print "DEBUG: created new $file\n" if $verbose;

    # step 7 - if -i then process the index files for the file.tstamp-now
    #
    # We continue on to step 8 even if something goes wrong with indexing
    # because an indexing failure should not impact later steps.
    #
    if (defined $opt_i) {
	if ($opt_n) {
	    print "$indx_prog $old_file\n";
	    printf("chmod 0%03o last_tstamp\n", $archive_mode);
	} else {
	    print "DEBUG: $indx_prog $old_file\n"
		    if $verbose;
	    if (system("$indx_prog", "$old_file",
	    	       "$old_file.indx") != 0) {
		warm_msg(58, "$indx_prog $old_file " .
			     "$old_file.indx failed");
	    }
	    if (-f "$old_file.indx") {
		if (chmod($archive_mode, "$old_file.indx") != 1) {
		    warn_msg(59, "chmod 0%03o $old_file.indx failed",
		    		  $archive_mode);
		}
		printf("DEBUG: chmod 0%03o $old_file.indx\n",
			$archive_mode) if $verbose;
	    } else {
		warn_msg(60, "index file wasn't made: $old_file.indx");
	    }
	}
    }

    # step 8 - If -1 was given, the gzip /a/path/OLD/file.tstamp-now
    #
    if (defined $opt_1) {
	if (defined $archive_name) {
	    gzip_or_move($old_file, $need_gzip, $false, $gz_dir);
	} else {
	    gzip_or_move($old_file, $need_gzip, $true, $gz_dir);
	}
    }

    # all done
    #
    return $true;
}
