
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

set cvscfg(version) "8.2"

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
set cvsglb(sort_pref) { filecol -decreasing }
set cvsglb(commit_comment) ""
set cvsglb(cvs_version) ""
set cvsglb(svn_version) ""

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
  #set cvsglb(textfg) [lindex [.testent configure -foreground] 4]
  set cvsglb(textbg) white
  set cvsglb(textfg) black
  set cvsglb(readonlybg) gray96
  set cvsglb(hlbg) [lindex [.testent configure -selectbackground] 4]
  set cvsglb(hlfg) [lindex [.testent configure -selectforeground] 4]
  set hlbg_rgb [winfo rgb .testent $cvsglb(hlbg)]
  set cvscfg(listboxfont) [lindex [.testent configure -font] 4]
  destroy .testent


  # Find out what the default gui font is
  label .testlbl -text "LABEL"
  if { [info exists cvscfg(guifont)] } {
    # If you set a guifont, I'm going to assume you want to use it for
    # the menus too.
    set menufont $cvscfg(guifont)
  } else {
    # Find out what the tk default is
    set cvscfg(guifont) [lindex [.testlbl configure -font] 4]
  }
  set cvsglb(canvbg) [lindex [.testlbl configure -background] 4]
  # If we're not in CDE but the background option is set, we're probably
  # in KDE or Gnome or some such.  It rather rudely sets all the Tk
  # backgrounds the same which I don't like, so I'm going to use the same
  # trick I use for CDE to give the canvases a little shading.  I don't
  # do this for raw X11 because the user might have set their own options.
  set cvsglb(bg) [lindex [.testlbl cget -background] 0]
  set cvsglb(fg) [lindex [.testlbl cget -foreground] 0]
  set cvslb(dfg) [lindex [.testlbl cget -disabledforeground] 0]
  set cvsglb(canvbg) [rgb_shadow $cvsglb(bg)]
  destroy .testlbl

  #puts "bg $cvsglb(bg)"
  #puts "canvbg $cvsglb(canvbg)"
  #puts "hlbg $cvsglb(hlbg)"
  if {[is_gray $cvsglb(hlbg)]} {
    # Which is better? I like the yellow
    #set cvsglb(hlbg) $cvsglb(sel)
    set sel [option get . selectColor Background]
    if {$sel != ""} {
      #puts "option selectColor: $sel"
      set  cvsglb(hlbg) $sel
    } else {
      set cvsglb(hlbg) "#ffec8b"
    }
    #puts "Changed hlbg so it won't be gray"
  }
  if {[rgb_diff $cvsglb(hlbg) $cvsglb(canvbg)] < 12000} {
    set cvsglb(hlbg) [rgb_shadow  $cvsglb(hlbg)]
    #puts "Changed hlbg because it's nearly the same as the canvas ($rgb_diff < 12000)"
  }
  #puts "hlbg $cvsglb(hlbg)"
   
  scrollbar .scrl
  destroy .scrl

  if { ! [info exists cvscfg(dialogfont)] } {
    set cvscfg(dialogfont) $cvscfg(guifont)
  }

  option add *Entry.background $cvsglb(textbg)
  option add *Label.font $cvscfg(guifont) userDefault
  option add *Button.font $cvscfg(guifont) userDefault
  option add *Menu.font $menufont userDefault
  option add *Scrollbar.troughColor $cvsglb(canvbg) userDefault
  option add *Canvas.Background $cvsglb(canvbg) userDefault
} else {
  set lbf [font actual $cvscfg(listboxfont)]
  set ffam [lindex $lbf 1]
  set fsiz [lindex $lbf 3]
  set cvscfg(listboxfont) [list $ffam $fsiz]
}

set cvscfg(flashfont) $cvscfg(listboxfont)
set fsiz [lindex $cvscfg(listboxfont) 1]
set lbf [font actual $cvscfg(listboxfont)]
#puts "actual listboxfont: $lbf"
set ffam [lindex $lbf 1]
#set fsiz [lindex $lbf 3]
if {$fsiz == ""} {
  # This happens on Windows in tk8.5
  set fsiz [lindex $lbf 3]
}

set cvscfg(flashfont) [list $ffam $fsiz underline]
#puts "\nflashfont: $cvscfg(flashfont)"
#puts "actual flashfont: [font actual $cvscfg(flashfont)]"
# Prefer underline, but it isn't working at all in tk8.5 on linux
if {! [font actual $cvscfg(flashfont) -underline]} {
  #puts "Underline font not working.  Trying $ffam $fsiz bold"
  set cvscfg(flashfont) [list [lindex $lbf 1] $fsiz bold]
  #set cvscfg(flashfont) [list [lindex $lbf 1] [lindex $lbf 3] bold]
}
#puts "final flashfont: $cvscfg(flashfont)"

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
set usage "Usage:"
append usage "\n tkcvs \[-dir <directory>\] \[-root <cvsroot>\] \[-win workdir|module|merge\]"
append usage "\n tkcvs \[-dir <directory>\] \[-root <cvsroot>\] \[-log|blame <file>\]"
append usage "\n tkcvs <file> - same as tkcvs -log <file>"
for {set i 0} {$i < [llength $argv]} {incr i} {
  set arg [lindex $argv $i]
  set val [lindex $argv [expr {$i+1}]]
  switch -regexp -- $arg {
    {--*d.*} {
      # -ddir: Starting directory
      set dir $val; incr i
      cd $val
    }
    {--*r.*} {
      # -root: CVS root
      set cvscfg(cvsroot) $val; incr i
    }
    {--*w.*} {
      # workdir|module|merge: window to start with. workdir is default.
      set cvscfg(startwindow) $val; incr i
    }
    {--*l.*} {
      # -log <filename>: Browse the log of specified file
      set cvscfg(startwindow) log
      set lcfile $val; incr i
    }
    {--*[ab].*} {
      # annotate|blame: Browse colorcoded history of specified file
      set cvscfg(startwindow) blame
      set lcfile $val; incr i
    }
    -psn_* {
      # Ignore the Carbon Process Serial Number
      incr i
    }
    {--*h.*} {
      puts $usage
      exit 0
    }
    {\w*} {
      # If a filename is provided as an argument, assume -log
      set cvscfg(startwindow) log
      set lcfile $arg; incr i
    }
    default {
      puts $usage
      exit 1
    }
  }
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
# This helps with Samba-mounted CVS repositories
# And also completely messes up SVN repositories
#set cvscfg(cvsroot) [file join $cvscfg(cvsroot)]
# If SVNROOT is set, use that instead.  SVNROOT isn't
# known by Subversion itself, so if it's set we must have
# done it for the present purpose
if {! [info exists cvscfg(svnroot)] } {
  if { [info exists env(SVNROOT)] } {
    set cvscfg(svnroot) $env(SVNROOT)
  } else {
    set cvscfg(svnroot) ""
  }
}
set cvsglb(root) $cvscfg(cvsroot)
if {$cvscfg(svnroot) != ""} {
  set cvsglb(root) $cvscfg(svnroot)
}
# Thought better of saving this
catch unset cvscfg(svnconform_seen)

if {![info exists cvscfg(ignore_file_filter)]} {
  set cvscfg(ignore_file_filter) ""
}
# Remember what the setting was.  We'll have to restore it after
# leaving a directory with a .cvsignore file.
set cvsglb(default_ignore_filter) $cvscfg(ignore_file_filter)

#foreach c [lsort [array names cvscfg]] {
  #gen_log:log D "cvscfg($c) $cvscfg($c)"
#}

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



set incvs 0
set insvn 0
set inrcs 0

# Create a window
# Start with Module Browser
if {[string match {mod*} $cvscfg(startwindow)]} {
  wm withdraw .
  foreach {incvs insvn inrcs} [cvsroot_check [pwd]] { break }

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
  foreach {incvs insvn inrcs} [cvsroot_check [pwd]] { break }
  if {$incvs} {
    cvs_branches \"$lcfile"\
  } elseif {$inrcs} {
    set cwd [pwd]
    set module_dir ""
    rcs_branches \"$lcfile\"
  } elseif {$insvn} {
    svn_branches \"$lcfile\"
  } else {
    puts "File doesn't seem to be in CVS, SVN, or RCS"
  }
# Start with Annotation Browser
} elseif {$cvscfg(startwindow) == "blame"} {
  if {! [file exists $lcfile]} {
    puts "ERROR: $lcfile doesn't exist!"
    exit 1
  }
  wm withdraw .
  foreach {incvs insvn inrcs} [cvsroot_check [pwd]] { break }
  if {$incvs} {
    cvs_annotate "" \"$lcfile"\
  } elseif {$insvn} {
    svn_annotate "" \"$lcfile\"
  } else {
    puts "File doesn't seem to be in CVS or SVN"
  }
# Start with Directory Merge
} elseif {[string match {mer*} $cvscfg(startwindow)]} {
  wm withdraw .
  foreach {incvs insvn inrcs} [cvsroot_check [pwd]] { break }
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
