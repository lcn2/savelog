# savelog

Save old log files, compress really old log files.


## TL;DR


### To install:

```sh
make test
sudo make install
```

### To use, for example:

```sh
/usr/local/sbin/savelog logfile
```

### Here is a demo:

```sh
date > logfile
/usr/local/sbin/savelog logfile

ls -lRa logfile OLD

date -u > logfile
/usr/local/sbin/savelog logfile

ls -lRa logfile OLD

date > logfile
/usr/local/sbin/savelog logfile

ls -lRa logfile OLD
```


## Usage

```
savelog [-m mode] [-M mode] [-o owner] [-g group] [-c cycle]
	[-h] [-n] [-1] [-z] [-T] [-L] [-v] [-V]
	[-i indx_type [-I typedir]] [-a OLD] [-A archive] file ...

	-m mode	 chmod current files to mode (def: 0644)
	-M mode	 chmod archived files to mode (def: 0444)
	-o owner chown files to user (def: do not chown)
	-g group chgrp files to group (def: do not chgrp)
	-c count cycles of the file to keep, 0=>unlimited (def: 14)
	-h	 display this message and exit
	-n	 do not do anything, just print cmds (def: do something)
	-1	 gzip the new 1st cycle now (def: wait 1 cycle)
	-z	 force the processing of empty files (def: don't)
	-T	 do not create if missing
	-L	 do not gziped any new files (def: gzip after 1st cycle)
	-v		 verbose output
	-V		 print version and exit
	-i indx_type	 form index files of a given type (def: don't)
	-I typedir	 type file prog dir (def: /usr/local/lib/savelog)
	-a OLD		 OLD directory name (not a path) (def: OLD)
	-A archive	 files beyond cycle 1 under OLD/archive (def: OLD)

savelog [... same flags as above ...] -R dir ...

	-R	 args are directories under which most files are archived

savelog version: 1.0.0 2025-03-16
```


## The details

The savelog tool can archive, compress (gzip) and index files such as
mailboxes or log files.  Care is taken to ensure that:

      * If a file exists, then there will be some file by the same name
        during the savelog processing (avoids time gaps where the
        file is missing).

      * The current file is renamed but it otherwise kept untouched in
        the same file system for 1 cycle (in case some process still
        has it open for writing).

      * Permission and ownership are preserved as command args request.

-#-

By default, given a file:

      /a/path/file

will be archived into an OLD sub-directory:

      /a/path/OLD

      [[ The ``-a OLDname'' can rename OLD to another so long as
         it is directly under the same directory as the file. ]]

The archived and compressed (gziped) cycle of the file have names such as:

      /a/path/OLD/file.948209998-948296401.gz

where the 1st number, '948209998' is the timestamp when the file
was first created (started to be use) and the 2nd number '948296401'
is when the file was moved aside.  Thus the file was active approximately
between the same 948209998 and 948296401.  This range is approximate
because on the first cycle, it is possible that some process still
had the file opened for writing and later flushed its buffers into it.

      [[ NOTE: The timestamps are determined by POSIX P1003.1 ``seconds
         since the Epoch'' which is effectively the number of 1 second
         intervals since 1970-01-01 00:00:00 UTC epoch not counting
         leap seconds. ]]

-#-

In order to deal with the possibility that some process may still have file
open for writing, the file is renamed but otherwise not touched for a cycle.
Thus, by default, the most recent cycle of the file is not gziped and
will be found in a name (without the .gz) such as:

      /a/path/OLD/file.948209998-948296401

      [[ NOTE: If '-1' is given, then this file is immediately gziped
         when it is formed instead of waiting a cycle. ]]

Any previously archived files (files of the form name.timestamp-timestamp)
found in OLD that are not gziped will be gziped during savelog processing
unless '-L' was given.  The '-L' option prevents the 1st cycle from
being gziped as well as preventing other archived files from being gziped.

-#-

When '-i type' is given an parallel index file is created when a file
is archived.  Index files are of the form:

      /a/path/OLD/file.948346647-948433048.indx

An index file consists lines with 3 fields separated by a single tab:

      offset_start <tab> offset_len <tab> element name <newline>

      offset_start    octet file offset for start of element
      offset_len      length of element in octets
      element name    name of this element

For example:

      0       1345    the 1st item
      1345    1410    the 2nd item
      2755    1350    the 3rd item

The element name follows the 2nd tab.  It may contain tabs and spaces.
The element name is terminated by a newline.  An element name may be
empty; i.e., a newline may immediately follow the 2nd tab.

There may be gaps between elements.  It is not required that the
entire file consist of element.  For example, a /var/log/messages
file may only have elements for important blocks of lines.

The index file is sorted by offset_start and then offset_len and
then by element name.

The offset_len may be 0.  The offset_len must be >= 0.  The offset_start
must be >= 0.

Elements may overlap other elements.  If an element runs off the
end of the file, the extra area is assumed to be NUL byte filled.

What constitutes a block of text depends on the 'type' given with the
flag.  For example, '-i mail' will search for starts of mail messages
and tag them with the subject line or (no subject).  For example:

      0       3507    A mail message subject line
      3507    3121    Another subject line
      6628    2717    (no subject)
      9345    930     A mail message subject line

By default, savelog uses the program found under /usr/local/lib/savelog
that as the same name as type.  The '-I typedir' can change the location
of this type forming script.  For example:

      -i ipchain -I /some/test/dir

Will cause savelog to look for the program:

      /some/test/dir/ipchain

If this program does not exist or is not executable, savelog will not
process the file.

-#-

One can control the number of cycles that savelog will archive a file
via the '-c count' option.  By default savelog keeps 14 cycles.

If '-c 1' is given, then only the plain text cycle file is kept.
If '-c 2' is given, the plain text file and 1 gziped file is kept.
If '-c 3' is given, the plain text file and 2 gziped files are kept.

When savelog finds that too many cycles exist, it will removed those
with the oldest starting timestamps until the number of cycles is
reduced.  For example, if ``-c 3'' is given and the follow files exist:

      /a/path/OLD/file.947396249-947482648            (cycle 1)
      /a/path/OLD/file.947309849-947396249.gz         (cycle 2)
      /a/path/OLD/file.947223450-947309849.gz         (cycle 3)
      /a/path/OLD/file.947137058-947050649.gz         (cycle 4)
      /a/path/OLD/file.947050649-947137050.gz         (cycle 5)

Then the files associated with cycle 4 and 5 would be removed.  Also
the file associated with cycle would be removed if /a/path/file was
processed (say because it was non-empty).  This 3 cycle files would
remain afterwards:

      /a/path/OLD/file.947482648-947569049            (new cycle 1)
      /a/path/OLD/file.947396249-947482648.gz         (new cycle 2)
      /a/path/OLD/file.947309849-947396249.gz         (new cycle 3)

The count of 0 means that all cycles are to be kept.  Cycles of < 0
are reserved for future use.

Index files are removed when their corresponding archive file is removed.

-#-

On the use of '-A archive':

It is possible to preserve space in the file's filesystem by placing
gziped files into another directory.  If the OLD directory contains a
symlink named 'archive':

      /a/path/OLD/archive -> /b/history/directory

and '-A archive' is given, then files will be gziped into the path:

      /a/path/OLD/archive/file.948209998-948296401.gz

which, by way of the archive symlink, will be placed into:

      /b/history/directory/file.948209998-948296401.gz

NOTE: The cycle 1 file will never be placed under OLD/archive.  Only
      files beyond cycle 1 will be placed under OLD/archive when
      -A archive is given.

-#-

If '-z' is used, then a file will be processed ONLY if it is not empty.
If the file does not exist, savelog will create it.  The '-T' flag will
prevent creation of missing files.  Missing files are never processed.
Therefore:

      args            empty file              missing file
      ----
      (default)       do not process          create empty but do not process
      -z              process file            create and then process
      -T              do not process          do not create or process
      -z -T           process file            do not create or process

-#-

If -R is used, then the arguments are assumed to directories under
which files will be found.  A tree walk is performed and appropriate
files are processed.

The following files are NOT archived when -R is given:

      * non-files (dirs, symlinks, sockets, named pipes, special files, ...)
      * basename of files starting with .
      * files ending in .gz, .indx or .new
      * files that match m#\.\d{9,10}$|\.\d{9,10}\-\d{9,10}$#

During the tree walk, the following directories will NOT be walked and
hence all files under them will be ignored:

      * directories that start with .
      * directories with the name CVS, RCS or SCCS
      * directories with the name OLD or archive
      * if -a was given, directories with the same OLD directory name
      * directories that are not writable or readable
      * directories that are not searchable (have no x bits)

If a filename is along with with -R, that filename is processed as
a regular file without filename restrictions

NOTE: By use of the phrase 'During the tree walk' we refer to files
      found under the given dir command line argument, not the dir
      argument itself.  For example, of one gives the a command
      line argument of OLD, files under OLD will be processed
      however files under OLD/OLD will not.

-#-

The following pre-checks are performed at the start of savelog:

      -1) Pre-check:  :-)

           * case no -a and no -A:
              + If /a/path/OLD exists, it must be a writable directory
                or we will abort.
              + If /a/path/OLD does not exist and we cannot create it
                as a writable directory, we will abort.

           * case -a FOO and no -A:
              + If /a/path/FOO exists, it must be a writable directory
                or we will abort.
              + If /a/path/FOO does not exist and we cannot create it
                as a writable directory, we will abort.

           * case no -a and -A archive:
              + If /a/path/OLD exists, it must be a writable directory
                or we will abort.
              + If /a/path/OLD does not exist and we cannot create it
                as a writable directory, we will abort.
              + If /a/path/OLD/name exists, it must be a writable directory
                or we will abort.
              + If /a/path/OLD/name not exist and we cannot create it
                as a writable directory, we will abort.

           * case -a FOO and -A archive:
              + If /a/path/FOO exists, it must be a writable directory
                or we will abort.
              + If /a/path/FOO does not exist and we cannot create it
                as a writable directory, we will abort.
              + If /a/path/FOO/name exists, it must be a writable directory
                or we will abort.
              + If /a/path/FOO/name not exist and we cannot create it
                as a writable directory, we will abort.

           * case -i indx_type and no -I:
              + /usr/local/lib/savelog/indx_type must be an executable
                file or we will abort.

           * case -i indx_type and -I /indx/prog/dir:
              + /indx/prog/dir/indx_type must be an executable
                file or we will abort.

         Assertion: The args are reasonable sane.  The proper directories
                    and if needed, executable files exist.

  NOTE: As this point we will carry on as of -a FOO was not given.
        If it was, replace 'OLD' with 'FOO' below.

  NOTE: As this point we will carry on as of -I /some/dir was not given.
        If it was, replace /usr/local/lib/savelog with '/some/dir' below.

  NOTE: If -n was given, we will not perform any actions, just go thru
        the motions and print shell commands that perform the equivalent
        of what would happen.

  NOTE: If -R was given, we will assume that the args are directories
        and walk the trees under them and perform the equivalent below
        as if -R dir ... was replaced with the appropriate files
        found under the directories.  See above for information on -R.

The order of processing of /a/path/file is as follows:

      0) Determine if /a/path/file exists.  Touch it (while setting the
         proper mode, uid and gid) if it does not unless -T was given.
         Do nothing else if the file missing and was not created.

         Assertion: At this point the file exists or we have stopped.

      1) Remove all but the newest count-1 cycles and, if they exist
         unless count is 0.  Remove any index file that is not associated
         with a (non-removed) file.  If both foo and foo.gz are found,
         the foo file will be removed.  Files are removed from under
         /a/path/OLD or from under /a/path/OLD/archive if archive exists.

         Assertion: At this point only count-1 cycles exist, or '-c 0'
                    was given and no files were removed.

      2) If -L was NOT given, then gzip all files of the form
         /a/path/OLD/file.tstamp1-tstamp2.  The gziped files will be
         placed under /a/path/OLD/archive if '-A archive' was given,
         or under /a/path/OLD if it was not.

         If -L was NOT given and if '-A archive' was given then also gzip
         any files of the form /a/path/OLD/archive/file.tstamp1-tstamp2
         into the /a/path/OLD/archive directory if it exists.

         If -L was given and '-A archive' was given then any files of the
         form /a/path/OLD/file.tstamp1-tstamp2 are moved to
         /a/path/OLD/archive/file.tstamp1-tstamp2.

         If -L was given and '-A archive' was NOT given, then no files
         are touched in this step.

         Assertion: At this point, all files of the form file.tstamp1-tstamp2
                    have been gziped, or -L was given and no additional files
                    were gziped.

         NOTE: Even if '-A archive' was given on the previous run, a file
               of the form /a/path/OLD/file.tstamp1-tstamp2 was previously
               formed.  For this run, either /a/path/OLD/file.tstamp1-tstamp2
               will be gzipped under /a/path/OLD/archive (without -L
               or moved under /a/path/OLD/archive (with -L).

      3) Determine if /a/path/file is empty.  Do nothing else if empty
         unless -z was given.

         Assertion: At this point the file is non-empty or -z was given
                    and the file is empty.

      4) Hard link /a/path/file to /a/path/OLD/file.tstamp_last-now.
         Here, 'tstamp_last' is the most recent tstamp2 value from
         files of the form /a/path/OLD/file.tstamp1-tstamp2 found
         in step 3).  If no such files were found in step 3), then
         'tstamp_last' will be set to 'now'.

         Assertion: /a/path/OLD/file.tstamp_last-now is a hard link
                    to the file /a/path/file.

         NOTE: The hard link to /a/path/OLD/file.tstamp_last-now is
               done even if '-A archive' was given.  See NOTE in step 3).

      5) Create /a/path/.file.new with the proper mode, uid and gid.

         Assertion: /a/path/.file.new exists with the proper mode, uid & gid.

      6) Move /a/path/.file.new to /a/path/file (and thus unlinking the
         old /a/path/file inode).

         Assertion: /a/path/file exists with the proper mode, uid and gid.

         Assertion: The file /a/path/OLD/file.tstamp_last-now (referred
                    to in step 4) exists and is not had linked to
                    /a/path/file.

      7) If -i, then /usr/local/lib/savelog /a/path/OLD/file.tstamp_last-now
         is executed to form /a/path/OLD/file.tstamp_last-now.indx.  If -i
         was not given, we will skip this step.

         Assertion: The file /a/path/OLD/file.tstamp_last-now exists.

         Assertion: The file /a/path/OLD/file.tstamp_last-now.indx exists and
                    -i was given.

      8) If -1 was given, the gzip /a/path/OLD/file.tstamp-now.  Place the
         result under /a/path/OLD or /a/path/OLD/archive if it exists.
         If -1 was not given, then we will ship this step.

         Assertion: The file /a/path/OLD/file.tstamp-now.gz exists and -1


# Reporting Security Issues

To report a security issue, please visit "[Reporting Security Issues](https://github.com/lcn2/savelog/security/policy)".
