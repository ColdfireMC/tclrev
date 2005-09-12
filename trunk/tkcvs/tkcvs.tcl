#!/bin/sh
#-*-tcl-*-
# the next line restarts using wish \
exec wish "$0" -- ${1+"$@"}

#
# $Id: tkcvs.tcl,v 1.4 2005/06/06 03:03:22 dorothyr Exp $
#
# TkCVS Main program -- A Tk interface to CVS.
#
# Uses a structured modules file -- see the manpage for more details.
#
# Author:  Del (del@babel.dialix.oz.au)
#

# If we can't get this far (maybe because X display connection refused)
# quit now.  If we get further, the error message is very misleading.
if {! [info exists tk_version] } {
   puts "Initialization failed"
   exit 1
}

if {$tk_version < 8.3} {
  cvserror "TkCVS requires Tcl/Tk 8.3 or better!"
}

if {[info exists TclRoot]} {
   # Perhaps we are being sourced recursively.
   # That would be bad.
   return
}

set Script [info script]
set ScriptTail [file tail $Script]
#puts "Tail $ScriptTail"
if {[file type $Script] == "link"} {
  #puts "$Script is a link"
  set ScriptBin [file join [file dirname $Script] [file readlink $Script]]
} else {
  set ScriptBin $Script
}
#puts "  ScriptBin $ScriptBin"
set TclExe [info nameofexecutable]
if {$tcl_platform(platform) == "windows"} {
  set TclExe [file attributes $TclExe -shortname]
}

set TclRoot [file join [file dirname $ScriptBin]]
#puts "TclRoot $TclRoot"
set TclRoot [file join [file dirname $TclRoot] "lib"]
#puts "TclRoot $TclRoot"

# allow runtime replacement
if {[info exists env(TCLROOT)]} {
   set TclRoot $env(TCLROOT)
}
#puts "TclRoot $TclRoot"

set TCDIR [file join $TclRoot tkcvs]
set cvscfg(bitmapdir) [file join $TclRoot tkcvs bitmaps]
#puts "TCDIR $TCDIR"
#puts "BITMAPDIR $cvscfg(bitmapdir)"

if {! [info exists cvscfg(editorargs)]} {
  set cvscfg(editorargs) {}
}
set auto_path [linsert $auto_path 0 $TCDIR]
set cvscfg(allfiles) false
set cvscfg(checkrecursive) {}
if {! [info exists cvscfg(startwindow)]} {
  set cvscfg(startwindow) "workdir"
}
set cvscfg(auto_tag) false
set cvscfg(econtrol) false
set cvscfg(use_cvseditor) false

set maxdirs 15
set dirlist {}
set totaldirs 0

if { [info exists env(HOME)] } {
  set cvscfg(home) $env(HOME)
} else {
  set cvscfg(home) "~"
}

# Read in defaults
if {[file exists [file join $TCDIR tkcvs_def.tcl]]} {
  source [file join $TCDIR tkcvs_def.tcl]
}

set optfile [file join $cvscfg(home) .tkcvs]
if {[file exists $optfile]} {
  source $optfile
}

# Set some defaults
set cvsglb(sort_pref) { filecol -decreasing }

if {$cvscfg(use_cvseditor) && ![info exists cvscfg(terminal)]} {
  cvserror "cvscfg(terminal) is required if cvscfg(use_cvseditor) is set"
}

if {! [get_cde_params]} {
  # Fonts.
  # First, see what the native menu font is.
  # This makes it look "normal" on Windows.
  . configure -menu .native
  menu .native
  set menufont [lindex [.native configure -font] 4]
  destroy .native
  # Hilight colors.  Get the colorful ones.
  entry .testent
  set cvsglb(textbg) [lindex [.testent configure -background] 4]
  set cvsglb(textfg) [lindex [.testent configure -foreground] 4]
  set cvsglb(hlbg) [lindex [.testent configure -selectbackground] 4]
  set cvsglb(hlfg) [lindex [.testent configure -selectforeground] 4]
  destroy .testent

  # Find out what the default gui font is
  if { [info exists cvscfg(guifont)] } {
    # If you set a guifont, I'm going to assume you want to use it for
    # the menus too.
    set menufont $cvscfg(guifont)
  } else {
    # Find out what the tk default is
    label .testlbl -text "LABEL"
    set cvscfg(guifont) [lindex [.testlbl configure -font] 4]
    #set cvsglb(canvbg) [lindex [.testlbl configure -background] 4]
    destroy .testlbl
  }
  # Find out what the default font is for listboxes
  if { ! [info exists cvscfg(listboxfont)] } {
    entry .testent
    set cvscfg(listboxfont) [lindex [.testent configure -font] 4]
    destroy .testent
  }
  scrollbar .scrl
  destroy .scrl

  if { ! [info exists cvscfg(dialogfont)] } {
    set cvscfg(dialogfont) $cvscfg(guifont)
  }

  option add *Label.font $cvscfg(guifont) userDefault
  option add *Button.font $cvscfg(guifont) userDefault
  option add *Menu.font $menufont userDefault
}

option add *ToolTip.background  "LightGoldenrod1" userDefault
option add *ToolTip.foreground  "black" userDefault

# This makes tk_messageBox use our font.  The default tends to be terrible
# no matter what platform
option add *Dialog.msg.font $cvscfg(dialogfont) userDefault
# Sometimes we'll want to override this but let's set a default
option add *Message.font $cvscfg(dialogfont) userDefault


# Initialize logging (classes are CFTD)
if { ! [info exists cvscfg(log_classes)] } {
  set cvscfg(log_classes) "C"
}
foreach class [split $cvscfg(log_classes) {}] {
  set logclass($class) $class
}
if { ! [info exists cvscfg(logging)] } {
  set cvscfg(logging) false
}
if {$cvscfg(logging)} {
  gen_log:init
}

#
# Add directory where we last ran to the menu list
if { ! [info exists cvscfg(lastdir)] } {
  set cvscfg(lastdir) [pwd]
}

#
# Command line options
#
set usage "Usage: tkcvs \[-dir directory\] \[-root cvsroot\] \[-win workdir|module\] \[-log file\]"
for {set i 0} {$i < [llength $argv]} {incr i} {
  set arg [lindex $argv $i]
  set val [lindex $argv [expr {$i+1}]]
  switch -glob -- $arg {
    -dir {
      set dir $val; incr i
      cd $val
    }
    -root {
      set cvscfg(cvsroot) $val; incr i
    }
    -win {
      set cvscfg(startwindow) $val; incr i
    }
    -log {
      set cvscfg(startwindow) log
      set lcfile $val; incr i
    }
    -psn_* {
      # Ignore the Carbon Process Serial Number
      incr i
    }
    -h* {
      puts $usage
      exit 0
    }
    default {
      puts $usage
      exit 1
    }
  }
}

if { ! [info exists cvscfg(cvsroot)] } {
  if { ! [info exists env(CVSROOT)] } {
    puts "warning: your \$CVSROOT environment variable is not set."
    set cvscfg(cvsroot) ""
  } else {
    set cvscfg(cvsroot) $env(CVSROOT)
  }
}
# This helps with Samba-mounted repositories
set cvscfg(cvsroot) [file join $cvscfg(cvsroot)]
 
if {![info exists cvscfg(ignore_file_filter)]} {
  set cvscfg(ignore_file_filter) ""
}
# Remember what the setting was.  We'll have to restore it after
# leaving a directory with a .cvsignore file.
set cvsglb(default_ignore_filter) $cvscfg(ignore_file_filter)

set incvs 0
set insvn 0
set inrcs 0

#foreach c [lsort [array names cvscfg]] {
  #gen_log:log D "cvscfg($c) $cvscfg($c)"
#}

set const(boxx) 80
set const(xfactor) 14
set const(boxy) 30
set const(spacex) 60
set const(spacey) 16
set const(textheight) 12

# Load the images that are used in more than one module
image create photo Checkout \
  -format gif -file [file join $cvscfg(bitmapdir) checkout.gif]
image create photo CheckoutOpts \
  -format gif -file [file join $cvscfg(bitmapdir) checkout_opts.gif]
image create photo Export \
  -format gif -file [file join $cvscfg(bitmapdir) export.gif]
image create photo Tag \
  -format gif -file [file join $cvscfg(bitmapdir) tag.gif]
image create photo Branchtag \
   -format gif -file [file join $cvscfg(bitmapdir) branchtag.gif]

# Create a window
if {$cvscfg(startwindow) == "module"} {
  wm withdraw .
  if {[file isdirectory CVS]} {
    read_cvs_dir CVS
  }
  modbrowse_run
} elseif {$cvscfg(startwindow) == "log"} {
  wm withdraw .
  foreach {incvs insvn inrcs} [cvsroot_check [pwd]] { break }
  if {$incvs} {
    read_cvs_dir CVS
    cvs_logcanvas [pwd] \"$lcfile"\
  } elseif {$inrcs} {
    set cwd [pwd]
    set module_dir ""
    rcs_filelog $lcfile
  } elseif {$insvn} {
    #read_svn_dir .
    svn_branches $lcfile
  } else {
    puts "File doesn't seem to be in CVS, SVN, or RCS"
  }
} else {
  workdir_setup
}
