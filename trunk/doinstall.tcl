#!/bin/sh
#-*-tcl-*-
# the next line restarts using wish \
if [ -z "$DISPLAY"  -o "X$1" = "X-nox" ]; then exec tclsh "$0" -- ${1+"$@"}; else exec wish "$0" -- ${1+"$@"}; fi

#
# $Id: doinstall.tcl,v 1.19 2004/03/16 05:40:54 dorothyr Exp $
#
# Usage: doinstall.tcl [-nox] [destination]
#
# For a non-interactive installation which doesn't require an X server, do
##  doinstall.tcl -nox /usr/local
#

proc set_paths {INSTALLROOT} {
  global tcl_platform
  global LIBDIR BINDIR MANDIR

  if {$tcl_platform(platform) == "windows"} {
    set BINDIR [file join $INSTALLROOT bin]
    set LIBDIR [file join $INSTALLROOT lib]
    set MANDIR ""
  } else {
    set BINDIR [file join $INSTALLROOT bin]
    set LIBDIR [file join $INSTALLROOT lib]
    set MANDIR [file join $INSTALLROOT man man1]
  }
}

proc show_paths {INSTALLROOT} {
  global tcl_platform
  global TKCVS TKDIFF
  global LIBDIR BINDIR MANDIR

  set_paths $INSTALLROOT

  set msg(1) [file join $BINDIR $TKCVS]
  set msg(2) [file join $BINDIR $TKDIFF]
  set msg(3) [file join $LIBDIR tkcvs *.tcl]
  set msg(4) [file join $LIBDIR tkcvs bitmaps *.gif,xbm]
  if {$tcl_platform(platform) == "unix"} {
     set msg(5) [file join $MANDIR tkcvs.1]
  }
  foreach m [lsort [array names msg]] {
    if {[winfo exists .messages.$m]} {
      destroy .messages.$m
    }
    global var$m
    set var$m $msg($m)
    label .messages.$m -text $msg($m) -justify left -textvariable var$m
    pack .messages.$m -side top -anchor w
  }
}

proc doinstall { INSTALLROOT } {
  global tcl_platform
  global TKCVS TKDIFF
  global LIBDIR BINDIR MANDIR
  global X

  set_paths $INSTALLROOT

  # Some directories we have to create.
  set TCDIR [file join $LIBDIR tkcvs]
  set GFDIR [file join $LIBDIR tkcvs bitmaps]
  file mkdir $INSTALLROOT
  foreach dir [concat \"$BINDIR\" \"$GFDIR\" \"$TCDIR\"] {
    file mkdir $dir
  }

  set destfile [file join $BINDIR $TKCVS]
  puts "Installing $TKCVS in $BINDIR"
  file copy -force [file join tkcvs tkcvs.tcl] [file join $BINDIR $TKCVS]
  puts "Installing $TKDIFF in $BINDIR"
  file copy -force [file join tkdiff tkdiff] [file join $BINDIR $TKDIFF]

  if {$tcl_platform(platform) == "unix"} {
    file attributes $destfile -permissions 0755
    file attributes [file join $BINDIR $TKDIFF] -permissions 0755
    file mkdir $MANDIR
    puts "Installing manpage tkcvs.1 in $MANDIR"
    file copy -force [file join tkcvs tkcvs.1] $MANDIR
  }

  puts "Installing tcl files in $TCDIR"
  cd tkcvs
  foreach tclfile [glob *.tcl tclIndex] {
    if {$tclfile != "tkcvs.tcl"} {
      puts "  $tclfile"
      file copy -force $tclfile $TCDIR
    }
  }

  puts "Installing icons in $GFDIR"
  cd bitmaps
  foreach pixfile [glob *.gif *.xbm] {
    puts "  $pixfile"
    file copy -force $pixfile $GFDIR
  }
  cd [file join .. ..]
  puts "Finished!"

  if {$X} {
    destroy .bottom.do
    destroy .bottom.not
    button .bottom.done -text "Finished!" -command {destroy .}
    pack .bottom.done
  }
}

################################################################################

set usage "Usage: doinstall.tcl \[-nox\] \[destination\]"
set X 1

# Check Tcl/TK version
if {$tcl_version < 8.3} {
   tk_dialog .wrongversion "Tcl/Tk too old" \
   "TkCVS requires Tcl/Tk 8.3 or better!" \
   error 0 {Bye Bye}
   exit 1
}

# See if the user changed them with command-line args
set ArgInstallRoot ""
for {set i 0} {$i < [llength $argv]} {incr i} {
  set arg [lindex $argv $i]
  switch -exact -- $arg {
    -- { continue }
    -nox { set X 0 }
    --help { puts "$usage"; exit }
    -h { puts "$usage"; exit }
    -finaldir {
       puts "The -finaldir option is obsolete."
       puts "TkCVS now figures out where it is at run-time,"
       puts "so substituting paths is unnecessary."
       exit 1
    }
    default { 
      set ArgInstallRoot $arg
    }
  }
}
    
# Do this after checking tcl version, because 7.x doesn't have it.
if {[string match "*tclsh" [info nameofexecutable]]} {
  set X 0
} else {
  if {$X && [catch {frame .title} err]} {
    puts "\nTk can't draw the UI."
    puts "Something seems to be wrong with your X11 environment."
    set X 0
    puts "You may use the -nox argument to do a command-line install:"
    puts "$usage"
    exit
  }
}


# Some rational and reasonable defaults.
if {$tcl_platform(platform) == "windows"} {
  set INSTALLROOT "C:\\"
  set TKCVS "tkcvs.tcl"
  set TKDIFF "tkdiff.tcl"
} else {
  set INSTALLROOT [file join /usr local]
  set TKCVS "tkcvs"
  set TKDIFF "tkdiff"
}
if {$ArgInstallRoot != ""} {
  set INSTALLROOT $ArgInstallRoot
}

if {$X} {
  # GUI installation
  label .title.lbl -text "TkCVS Installer" -font {Helvetica -14 bold}
  pack .title -side top
  pack .title.lbl -side top
  frame .entry
  label .entry.instlbl -text "Installation Root"
  entry .entry.instent -textvariable INSTALLROOT
  bind .entry.instent <Return> {show_paths $INSTALLROOT}
  bind .entry.instent <KeyRelease> {show_paths $INSTALLROOT}
  pack .entry -side top -pady 10
  pack .entry.instlbl -side left
  pack .entry.instent -side left
  
  frame .messages -relief groove -bd 2
  pack .messages -side top -expand y -fill x
  label .messages.adv -text "These files will be installed:"
  pack .messages.adv -side top
  show_paths $INSTALLROOT

  frame .bottom
  button .bottom.do -text "Install" -command {doinstall $INSTALLROOT}
  button .bottom.not -text "Cancel" -command {destroy .}
  pack .bottom -side top
  pack .bottom.do -side left
  pack .bottom.not -side left
} else {
  # Command-line installation
  if {$ArgInstallRoot != ""} {
    set INSTALLROOT $ArgInstallRoot
  } else {
    puts "Install where? \[/usr/local\]"
    gets stdin IN
    puts "you entered $IN"
  }
  #puts "Will install in $INSTALLROOT"
  doinstall $INSTALLROOT
}

