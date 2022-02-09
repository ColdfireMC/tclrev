#!/bin/sh
#-*-tcl-*-
# the next line restarts using wish \
    exec wish "$0" -- ${1+"$@"}

#
# TkRev Main program -- A Tk interface to CVS.
#
# Uses a structured modules file -- see the manpage for more details.
#
# Author:  Del (del@babel.dialix.oz.au)
    
#
proc srcctrlchk {1} {
	    
	    # Detect whether we're in a revision-controlled directory   
	    lassign [cvsroot_check [pwd]] incvs insvn inrcs ingit
	    
	    if {[info exists lcfile]} {
	      set d [file dirname $lcfile]
	      set f [file tail $lcfile]
	      set lcfile $f
	      cd $d
	    }
	    
	    if {![info exists cvscfg(ignore_file_filter)]} {
	      set cvscfg(ignore_file_filter) ""
	    }
	    if {[info exists cvscfg(file_filter)]} {
	      unset cvscfg(file_filter)
	    }
	    if {![info exists cvscfg(show_file_filter)]} {
	      set cvscfg(show_file_filter) "*"
	    }
	    
	    
	    set cvsglb(root) ""
	    set cvsglb(vcs) ""
	    
	    if {$insvn} {
	       set cvsglb(root) $cvscfg(svnroot)
	       set cvsglb(vcs) svn
	     } elseif {$incvs} {
	       set cvsglb(root) $cvscfg(cvsroot)
	       set cvsglb(vcs) cvs
	     } elseif {$ingit} {
	       set cvsglb(root) $cvscfg(url)
	       set cvsglb(vcs) git
	     } else {
	       # We'll respect CVSROOT environment variable if it's set
	       if {[info exists env(CVSROOT)]} {
		 set cvsglb(root) $env(CVSROOT)
		 set cvscfg(cvsroot) $env(CVSROOT)
		 set cvsglb(vcs) cvs
	       }
	     }
	     # Othewise we set it to the most recent saved in picklist
	     # which we've saved in cvscfg(cvsroot)
	     if {$cvsglb(root) == ""} {
	       set cvsglb(root) $cvscfg(cvsroot)
	     }
	     modbrowse_run
	    
	    
	    # Create a window
	    # Start with Module Browser
	    if {[string match {mod*} $cvscfg(startwindow)]} {
	    #  wm withdraw .
	      # If we're in a version-controlled directory, open that repository
	     # Start with Branch Browser
	   } elseif {$cvscfg(startwindow) == "log"} {
	     if {! [file exists $lcfile]} {
	       puts "ERROR: $lcfile doesn't exist!"
	       exit 1
	     }
	   #  wm withdraw .
	     if {$incvs} {
	       cvs_branches [list $lcfile]
	     } elseif {$inrcs} {
	       set cwd [pwd]
	       set module_dir ""
	       rcs_branches [list $lcfile]
	     } elseif {$insvn} {
	       svn_branches [list $lcfile]
	     } elseif {$ingit} {
	       git_branches [list $lcfile]
	     } else {
	       puts "File doesn't seem to be in CVS, SVN, RCS, or GIT"
	     }
	     # Start with Annotation Browser
	   } elseif {$cvscfg(startwindow) == "blame"} {
	     if {! [file exists $lcfile]} {
	       puts "ERROR: $lcfile doesn't exist!"
	       exit 1
	     }
	   #  wm withdraw .
	     if {$incvs} {
	       cvs_annotate $current_tagname [list $lcfile]
	     } elseif {$insvn} {
	       svn_annotate rBASE [list $lcfile]
	     } elseif {$ingit} {
	       read_git_dir .
	       git_annotate $current_tagname [list $lcfile]
	     } else {
	       puts "File doesn't seem to be in CVS, SVN, or GIT"
	     }
	     # Start with Directory Merge
	   } elseif {[string match {mer*} $cvscfg(startwindow)]} {
	   #  wm withdraw .
	     if {$incvs} {
	       cvs_joincanvas
	     } elseif {$insvn} {
	       svn_directory_merge
	     } else {
	       puts "Directory doesn't seem to be in CVS or SVN"
	     }
	     # The usual way, with the Workdir Browser
	   } else {
	     setup_dir
	   }
	    
    }
   
proc usgprint {argv} {
	# Command line options
	set usage "Usage:"
	append usage "\n tkrev \[-root <cvsroot>\] \[-win workdir|module|merge\]"
	append usage "\n tkrev \[-log|blame <file>\]"
	append usage "\n tkrev <file> - same as tkrev -log <file>"
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
	    {^\.*\w*} {
	      # If a filename is provided as an argument, assume -log
	      # except if it's a directory and it's CVS, which doesn't
	      # version directories
	      if {($insvn || $ingit)} {
		set cvscfg(startwindow) log
		set lcfile $arg; incr i
	      } else {
		if {[file isdirectory $arg]} {
		  set dir $arg
		  cd $arg
		} else {
		  set cvscfg(startwindow) log
		  set lcfile $arg; incr i
		}
	      }
	    }
	    default {
	      puts $usage
	      exit 1
	    }
	  }
	}
}

proc tkrevinit {init} {
		    
	set TclExe [info nameofexecutable]
	    
	if {[info exists TclRoot]} {
		    return 1
	    }    
	set Script [info script]
	set ScriptTail [file tail $Script]
	puts "Tail $ScriptTail"
	if {[file type $Script] == "link"} {
	   	#puts "$Script is a link"
	   	set ScriptBin [file join [file dirname $Script] [file readlink $Script]]
	   	} else {
		  set ScriptBin $Script
		}
	puts "  ScriptBin $ScriptBin"
	set TclRoot [file join [file dirname $ScriptBin]]
	puts "TclRoot $TclRoot"
	if {$TclRoot == "."} {
	 	set TclRoot [pwd]
		}
	puts "TclRoot $TclRoot"
	set TclRoot [file join [file dirname $TclRoot] "lib"]
	puts "TclRoot $TclRoot"
	# allow runtime replacement
	if {[info exists env(TCLROOT)]} {
	  set TclRoot $env(TCLROOT)
	}
	puts "TclRoot $TclRoot"      
	if {$tcl_platform(platform) == "windows"} {
		set TclExe [file attributes $TclExe -shortname]
		}
    
	set cvscfg(version) "9.4.2"
	      
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
        set TCDIR [file join $TclRoot tkrev]
        puts "TCDIR $TCDIR"      
        # Orient ourselves
        if { [info exists env(HOME)] } {
		set cvscfg(home) $env(HOME)
         } else {
	set cvscfg(home) "~"
         }
        if { [info exists env(USER)] } {
	set cvscfg(user) $env(USER)
        } elseif { [info exists env(USERNAME)] } {
        	# Windows
		set cvscfg(user) $env(USERNAME)
         } else {
		set cvscfg(user) ""
	 }
	      
	 # Read in defaults
	 if {[file exists [file join $TCDIR tkrev_def.tcl]]} {
	 	source [file join $TCDIR tkrev_def.tcl]
	 }
	 set optfile [file join $cvscfg(home) .tkrev]
	 set old_optfile [file join $cvscfg(home) .tkcvs]
	 if {[file exists $old_optfile] && ![file exists $optfile]} {
		file copy $old_optfile $optfile
	 }
	 if {[file exists $optfile]} {
		catch {source $optfile}
	 }
	 set pickfile [file join $cvscfg(home) .tkrev-picklists]
	 if {[file exists $pickfile]} {
	 	picklist_load
	      }
	 if {! [info exist cvsglb(directory)]} {
		set cvsglb(directory) [pwd]
	      }
	 if {[info exists cvsglb(cvsroot)]} {
		set cvscfg(cvsroot) [lindex $cvsglb(cvsroot) 0]
	      }
	 # Set some defaults
	 set cvsglb(commit_comment) ""
	 set cvsglb(cvs_version) "" 
	 if {$cvscfg(use_cvseditor) && ![info exists cvscfg(terminal)]} {
		cvserror "cvscfg(terminal) is required if cvscfg(use_cvseditor) is set"
	 }
	return cvscfg
}

    
    
usgprint argv

set cvscfg [tkrevinit argv]

srcctrlchk

return cvscfg



