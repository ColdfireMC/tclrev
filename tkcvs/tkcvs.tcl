#!/bin/sh
#-*-tcl-*-
# the next line restarts using wish \
exec wish "$0" -- ${1+"$@"}

#
# TkCVS Main program -- A Tk interface to CVS.
#
# Uses a structured modules file -- see the manpage for more details.
#
# Author:  Del (del@babel.dialix.oz.au)
#

# If we can't get this far (maybe because X display connection refused)
# quit now.  If we get further, the error message is very misleading.
if {[info exists starkit::topdir]} {
  package require Tk
}

if {! [info exists tk_version] } {
   puts "Initialization failed"
   exit 1
}

if {$tk_version < 8.4} {
  puts "TkCVS requires Tcl/Tk 8.4 or better!"
  exit 1
}

if {[info exists starkit::topdir]} {
  set TclRoot [file join $starkit::topdir lib]
  set ScriptBin $starkit::topdir
} else {
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
  set TclRoot [file join [file dirname $ScriptBin]]
  #puts "TclRoot $TclRoot"
  if {$TclRoot == "."} {
    set TclRoot [pwd]
  }
  #puts "TclRoot $TclRoot"
  set TclRoot [file join [file dirname $TclRoot] "lib"]
  #puts "TclRoot $TclRoot"
  
  # allow runtime replacement
  if {[info exists env(TCLROOT)]} {
   set TclRoot $env(TCLROOT)
  }
  #puts "TclRoot $TclRoot"
}

set TclExe [info nameofexecutable]
if {$tcl_platform(platform) == "windows"} {
  set TclExe [file attributes $TclExe -shortname]
}


set TCDIR [file join $TclRoot tkcvs]
set cvscfg(bitmapdir) [file join $TclRoot tkcvs bitmaps]
#puts "TCDIR $TCDIR"
#puts "BITMAPDIR $cvscfg(bitmapdir)"

set cvscfg(version) "9.0a"

if {! [info exists cvscfg(editorargs)]} {
  set cvscfg(editorargs) {}
}
set auto_path [linsert $auto_path 0 $TCDIR]
set cvscfg(allfiles) false
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

# This helps us recover from a problem left behind by tkcvs 7.2
set cvscfg(checkrecursive) false

set optfile [file join $cvscfg(home) .tkcvs]
if {[file exists $optfile]} {
  catch {source $optfile}
}
::picklist::load

# Set some defaults
set cvsglb(commit_comment) ""
set cvsglb(cvs_version) ""
set cvsglb(svn_version) ""

if {$cvscfg(use_cvseditor) && ![info exists cvscfg(terminal)]} {
  cvserror "cvscfg(terminal) is required if cvscfg(use_cvseditor) is set"
}

# Hilight colors.  Get the colorful ones.
entry .testent
set cvsglb(textbg) white
set cvsglb(textfg) black
set cvsglb(hlbg) [lindex [.testent configure -selectbackground] 4]
set cvsglb(hlfg) [lindex [.testent configure -selectforeground] 4]
if {$cvsglb(hlfg) eq {} } {
  # This happens on the Mac
  set cvsglb(hlfg) [lindex [.testent configure -foreground] 4]
}
set cvscfg(listboxfont) [lindex [.testent configure -font] 4]
#puts [font actual $cvscfg(listboxfont) -displayof .testent]
#puts [font metrics $cvscfg(listboxfont) -displayof .testent]
destroy .testent


set WSYS [tk windowingsystem]
#puts "Windowing sytem is $WSYS"
set theme_system "unknown"

if {$WSYS eq "x11"} {
  # If X11, see if we can sense our environment somehow
  label .testlbl -text "LABEL"
  if [get_cde_params] {
    set theme_system "CDE" 
    # Find out what the default gui font is
    if { ! [info exists cvscfg(guifont)] } {
      # Find out what the tk default is
      set cvscfg(guifont) [lindex [.testlbl configure -font] 4]
    }
    # Put the Help menu back on the right
    if {$tk_version >= 8.5} {
      tk::classic::restore menu
    }
    #set cvsglb(canvbg) [lindex [.testlbl configure -background] 4]
    set cvsglb(canvbg) $cvsglb(shadow)
  } elseif [get_gtk_params] {
    set theme_system "GTK"
    if { ! [info exists cvscfg(guifont)] } {
      set cvscfg(guifont) [lindex [.testlbl configure -font] 4]
      if {$tk_version >= 8.5} {
       font configure TkDefaultFont -size 9
       set cvscfg(guifont) TkDefaultFont
       option add *Menu.font $cvscfg(guifont)
       option add *Label.font $cvscfg(guifont)
       option add *Button.font $cvscfg(guifont)
      }
    }
    # in KDE or Gnome or some such.  It rather rudely sets all the Tk
    # backgrounds the same which I don't like, so I'm going to use the same
    # trick I use for CDE to give the canvases a little shading.
    set cvsglb(bg) [lindex [.testlbl cget -background] 0]
    set cvsglb(fg) [lindex [.testlbl cget -foreground] 0]
    set cvsglb(canvbg) [rgb_shadow $cvsglb(bg)]
  } else {
    set bg  [lindex [.testlbl cget -background] 0]
    set fg  [lindex [.testlbl cget -foreground] 0]
    set hlbg "#4a6984"
    set hlfg "#ffffff"
    set textbg "#ffffff"
    set textfg "#000000"

    shades $bg

    set cvsglb(bg) $bg
    set cvsglb(fg) $fg
    set cvsglb(textbg) $textbg
    set cvsglb(textfg) $textfg
    set cvsglb(hlbg) $hlbg
    set cvsglb(hlfg) $hlfg

    option add *Canvas.Background $cvsglb(shadow)
    option add *Canvas.Foreground black
    option add *Entry.Background $textbg
    option add *Entry.Foreground $textfg
    option add *Entry.selectBackground $hlbg
    option add *Entry.selectForeground $hlfg
    option add *Entry.readonlyBackground $bg
    option add *Listbox.background $textbg
    option add *Listbox.selectBackground $hlbg
    option add *Listbox.selectForeground $hlfg
    option add *Text.Background $textbg
    option add *Text.Foreground $textfg
    option add *Text.selectBackground $hlbg
    option add *Text.selectForeground $hlfg
    option add *Button.activeForeground $fg
    option add *Menu.activeForeground $fg
    option add *Checkbutton.Background $bg

    # checkbuttons and radiobuttons
    if {$tk_version >= 8.5} {
       option add *Menu.selectColor $fg
       option add *Checkbutton.selectColor "#ffffff"
       option add *Radiobutton.selectColor "#ffffff"
     } else {
       option add *selectColor $hlbg
     }

    if { ! [info exists cvscfg(guifont)] } {
      set cvscfg(guifont) [lindex [.testlbl configure -font] 4]
      if {$tk_version >= 8.5} {
       # This makes it look like tk8.4.  Want?  dunno.
       font configure TkHeadingFont -size 9
       set cvscfg(guifont) TkHeadingFont
       option add *Menu.font $cvscfg(guifont)
       option add *Label.font $cvscfg(guifont)
       option add *Button.font $cvscfg(guifont)
      }
    }
  }
  destroy .testlbl

  if {! [info exists cvscfg(dialogfont)]} {
    set cvscfg(dialogfont) $cvscfg(guifont)
  }

  if {$theme_system == "CDE"} {
    # This makes it consistent with the rest of the CDE interface
    option add *Menu.font $cvscfg(guifont)
    option add *Label.font $cvscfg(guifont)
    option add *Button.font $cvscfg(guifont)
  }
  #puts " Theme system: $theme_system"
} else {
  # Find out what the default gui font is
  label .testlbl -text "LABEL"
  # Find out what the tk default is
  set cvscfg(guifont) [lindex [.testlbl configure -font] 4]
  set cvscfg(dialogfont) $cvscfg(guifont)

  set cvsglb(canvbg) [lindex [.testlbl configure -background] 4]
  set cvsglb(bg) [lindex [.testlbl cget -background] 0]
  set cvsglb(fg) [lindex [.testlbl cget -foreground] 0]
  set cvsglb(canvbg) [rgb_shadow $cvsglb(bg)]
  destroy .testlbl
  if {$WSYS eq "aqua"} {
    # Keep everything from being blinding white
    set arbitrarybg "#dddddd"
    option add *Frame.background $arbitrarybg userDefault
    option add *Label.background $arbitrarybg userDefault
    option add *Entry.highlightBackground $arbitrarybg userDefault
    option add *Canvas.highlightBackground #fefefe userDefault
    option add *Message.Background $arbitrarybg userDefault
    option add *Checkbutton.Background $arbitrarybg userDefault
    option add *Radiobutton.Background $arbitrarybg userDefault
    # button highlightbackground has to be the same as background
    # or else there are little white boxes around the button "pill"
    option add *Button.highlightBackground $arbitrarybg userDefault
    set cvsglb(canvbg) "#eeeeee"
  }
}

# Fonts for the canvas "listboxes"
set cvscfg(flashfont) $cvscfg(listboxfont)
set fsiz [lindex $cvscfg(listboxfont) 1]
set lbf [font actual $cvscfg(listboxfont)]
#puts "$tcl_platform(os) $tk_patchLevel   [winfo server .]"
#puts "listboxfont: $cvscfg(listboxfont)"
#puts "actual listboxfont: $lbf"
set ffam [lindex $lbf 1]
set fsiz [lindex $lbf 3]

# On X11, fsiz is often 0 because it's a scaled font. Then linespace
# is about the best you can do to deduce the real size.
if {$fsiz == 0} {
  set linespace [font metrics $cvscfg(listboxfont) -linespace]
  #puts "linespace $linespace"
  foreach size {8 9 10 11 12 13 14} {
    set negsize -$size
    font create Z$size -family $ffam -size $negsize
    set lnspc [font metric Z$size -linespace]
    set fsize($lnspc) $negsize
    #puts "fsize($lnspc) = $fsize($lnspc)"
    font delete Z$size
  }
  set fsiz $fsize($linespace)
}
set cvscfg(flashfont) [list $ffam $fsiz underline]

# Prefer underline, but it isn't working at all in tk8.5.0 on linux
if {! [font actual $cvscfg(flashfont) -underline]} {
  puts "Underline font not working.  Trying $ffam $fsiz bold"
  puts " (known problem in Tk 8.5.0 on Linux)"
  set cvscfg(flashfont) [list $ffam $fsiz bold]
}
#puts "final flashfont: $cvscfg(flashfont)"

# Suppress tearoffs in menubars
option add *tearOff 0

option add *ToolTip.background  "LightGoldenrod1" userDefault
option add *ToolTip.foreground  "black" userDefault

# This makes tk_messageBox use our font.  The default tends to be terrible
# no matter what platform
option add *Dialog.msg.font $cvscfg(dialogfont) userDefault
# Sometimes we'll want to override this but let's set a default
option add *Message.font $cvscfg(dialogfont) userDefault


# Initialize logging (classes are C,F,T,D)
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
set usage "Usage:"
append usage "\n tkcvs \[-dir <directory>\] \[-root <cvsroot>\] \[-win workdir|module|merge\]"
append usage "\n tkcvs \[-dir <directory>\] \[-root <cvsroot>\] \[-log|blame <file>\]"
append usage "\n tkcvs <file> - same as tkcvs -log <file>"
append usage "\n tkcvs <dir>  - same as tkcvs -dir <file>"
for {set i 0} {$i < [llength $argv]} {incr i} {
  set arg [lindex $argv $i]
  set val [lindex $argv [expr {$i+1}]]
  switch -regexp -- $arg {
    {^--*d.*} {
      # -ddir: Starting directory
      set dir $val; incr i
      cd $val
    }
    {^--*r.*} {
      # -root: CVS root
      set cvscfg(cvsroot) $val; incr i
    }
    {^--*w.*} {
      # workdir|module|merge: window to start with. workdir is default.
      set cvscfg(startwindow) $val; incr i
    }
    {^--*l.*} {
      # -log <filename>: Browse the log of specified file
      set cvscfg(startwindow) log
      set lcfile $val; incr i
    }
    {^--*[ab].*} {
      # annotate|blame: Browse colorcoded history of specified file
      set cvscfg(startwindow) blame
      set lcfile $val; incr i
    }
    {^-psn_.*} {
      # Ignore the Carbon Process Serial Number
      incr i
    }
    {^--*h.*} {
      puts $usage
      exit 0
    }
    {\w*} {
      # If a filename is provided as an argument, assume -log
      if [file isdirectory $arg] {
        set dir $arg
        cd $arg
      } else {
        set cvscfg(startwindow) log
        set lcfile $arg; incr i
      }
    }
    default {
      puts $usage
      exit 1
    }
  }
}

if {[info exists lcfile]} {
  set d [file dirname $lcfile]
  set f [file tail $lcfile]
  set lcfile $f
  cd $d
}

# If CVSROOT envvar is set, use it
if { ! [info exists cvscfg(cvsroot)] } {
  if { ! [info exists env(CVSROOT)] } {
    #puts "warning: your \$CVSROOT environment variable is not set."
    set cvscfg(cvsroot) ""
  } else {
    set cvscfg(cvsroot) $env(CVSROOT)
  }
}
# Find out which of the supported VCSs we can run. Maybe we can use it later.
# This sets cvscfg(have_cvs) and so on.
#help_cvs_version 0

# Thought better of saving this
catch unset cvscfg(svnconform_seen)

if {![info exists cvscfg(ignore_file_filter)]} {
  set cvscfg(ignore_file_filter) ""
}
# Remember what the setting was.  We'll have to restore it after
# leaving a directory with a .cvsignore file.
set cvsglb(default_ignore_filter) $cvscfg(ignore_file_filter)

# Load the images that are used in more than one module
image create photo Log \
  -format gif -file [file join $cvscfg(bitmapdir) log.gif]
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
image create photo Import \
   -format gif -file [file join $cvscfg(bitmapdir) import.gif]
image create photo Mergebranch \
  -format gif -file [file join $cvscfg(bitmapdir) newmerge_simple.gif]
image create photo Mergediff \
  -format gif -file [file join $cvscfg(bitmapdir) newmerge.gif]
image create photo Man \
  -format gif -file [file join $cvscfg(bitmapdir) man.gif]

lassign [cvsroot_check [pwd]] incvs insvn inrcs ingit

# Create a window
# Start with Module Browser
if {[string match {mod*} $cvscfg(startwindow)]} {
  wm withdraw .

  if {$insvn} {
    set cvsglb(root) $cvscfg(svnroot)
    modbrowse_run svn
  } else {
    # We still don't know if it's SVN or CVS.  Let modbrowse_run figure out.
    modbrowse_run
  }
# Start with Branch Browser
} elseif {$cvscfg(startwindow) == "log"} {
  if {! [file exists $lcfile]} {
    puts "ERROR: $lcfile doesn't exist!"
    exit 1
  }
  wm withdraw .
  if {$incvs} {
    cvs_branches \"$lcfile"\
  } elseif {$inrcs} {
    set cwd [pwd]
    set module_dir ""
    rcs_branches \"$lcfile\"
  } elseif {$insvn} {
    svn_branches \"$lcfile\"
  } elseif {$ingit} {
    git_branches \"$lcfile\"
  } else {
    puts "File doesn't seem to be in CVS, SVN, RCS, or GIT"
  }
# Start with Annotation Browser
} elseif {$cvscfg(startwindow) == "blame"} {
  if {! [file exists $lcfile]} {
    puts "ERROR: $lcfile doesn't exist!"
    exit 1
  }
  wm withdraw .
  if {$incvs} {
    cvs_annotate "" \"$lcfile"\
  } elseif {$insvn} {
    svn_annotate "" \"$lcfile\"
  } elseif {$ingit} {
    git_annotate "" \"$lcfile\"
  } else {
    puts "File doesn't seem to be in CVS, SVN, or GIT"
  }
# Start with Directory Merge
} elseif {[string match {mer*} $cvscfg(startwindow)]} {
  wm withdraw .
  if {$incvs} {
    cvs_joincanvas
  } elseif {$insvn} {
    svn_directory_merge
  } else {
    puts "Directory doesn't seem to be in CVS or SVN"
  }
# The usual way, with the Workdir Browser
} else {
  workdir_setup
}

