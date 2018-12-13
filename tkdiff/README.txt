What this is:

TkDiff is a Tcl/Tk front-end to diff for Unix/Linux, Windows, and MacOS.

TkDiff knows how to work with several revision control systems:
CVS, Subversion, Git, SCCS, RCS, PVCS, BitKeeper, Perforce, Accurev, Mercurial
and ClearCase. It's only tested on the free and open source ones.

================================================================================
Requirements:

As a 'pure' Tcl implementation, the runtime requirements are limited to an
appropriate level of Tcl/Tk support:

Versions *Prior* to V4.3 of TkDiff, needs at least V8.0 of Tcl/Tk and Wish
Versions *At/After* V4.3 of TkDiff, needs at least V8.5 or Tcl/Tk and Wish

Exceeding these requirements (more recent Tcl/Tk releases) is generally harmless

================================================================================
Platforms:

On Unix, simply invoke it from the command line.
tkdiff --help will list the options.

On MacOS, wish is shipped with the OS. You can install tkdiff somewhere in
your path and invoke it from the terminal just as on Unix/Linux. Or you
can double-click on it in the Finder, and a terminal will open and run it.

On Windows, you must find diff.exe somewhere. You must install Wish on your
computer. You can use ActiveTcl from www.activestate.com or get it from the
tcl/tk project on Sourceforge. To run on Windows, it's easiest to rename tkdiff
to tkdiff.tcl. Then when you double-click on it, it will open in Wish. You can
of course make a desktop shortcut for it.

================================================================================
License:

This program is free software; you can redistribute it and/or modify it  under
the terms of the GNU General Public License as published by the  Free Software
Foundation; either version 2 of the License, or (at your  option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or  FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License  for more
details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59  Temple
Place, Suite 330, Boston, MA 02111-1307 USA

================================================================================
Credits:

TkDiff is Copyright (C) 1994-2005 by John M. Klassa.

Many of the toolbar icons were created by Dean S. Jones and used with his
permission. The icons have the following copyright:

Copyright(C) 1998 by Dean S. Jones
dean@gallant.com
http://www.gallant.com/icons.htm
http://www.javalobby.org/jfa/projects/icons/

