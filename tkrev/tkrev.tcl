#!/bin/sh
#-*-tcl-*-
# the next line restarts using tclsh \
    exec tclsh "$0" -- ${1+"$@"}

#
# TkRev Main program -- A Tk interface to CVS.
#
# Uses a structured modules file -- see the manpage for more details.
#
# Author:  Del (del@babel.dialix.oz.au)
    
#
#package require parse_args


proc make_src_ctrled { type } {
	
}
proc checkout_proj { } {
	
}
proc checkout_files { } {
	
}
proc commit_project { } {
	
}
proc commit_files { } {
	
}
proc redef_project_commands { } {
	
}
proc autobuild_project_from_repo { } {
	
}
proc srcctrlchk {cvscfg_str} {
	global env
	global cvsglb
	set srcdirtype_str ""
	set srcdirtype(insvn) 0
	set srcdirtype(ingit) 0
	set srcdirtype(inrcs) 0
	set srcdirtype(incvs) 0
	array set cvscfg $cvscfg_str 
	# Detect whether we're in a revision-controlled directory  
	puts [pwd]
#	set srcdirtype_str [cvsroot_check [pwd] [array get cvscfg] [array get cvsglb]]
#	array set srcdirtype $srcdirtype_str
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
	if {$srcdirtype(insvn) == 1} {
		set cvsglb(root) $cvscfg(svnroot)
		set cvsglb(vcs) svn
		puts "svn"
	} elseif {$srcdirtype(incvs) == 1} {
		set cvsglb(root) $cvscfg(cvsroot)
		set cvsglb(vcs) cvs
		puts "cvs"
	} elseif {$srcdirtype(ingit) == 1} {
       set cvsglb(root) $cvscfg(url)
       set cvsglb(vcs) git
       puts "git"
    } else {
     puts "Directory doesn't seem to be in CVS or SVN"
    }
	# We'll respect CVSROOT environment variable if it's set
    if {[info exists env(CVSROOT)]} {
		set cvsglb(root) $env(CVSROOT)
		set cvscfg(cvsroot) $env(CVSROOT)
		set cvsglb(vcs) cvs
    }
	return [array get srcdirtype]
}
proc usgprint {argv} {
	# Command line options	
	set usage "Usage:"
	append usage "\n tkrev \[-root <cvsroot>\] \[-win workdir|module|merge\]"
	append usage "\n tkrev \[-log|blame <file>\]"
	append usage "\n tkrev <file> - same as tkrev -log <file>"
	if {[info exists argv]}	{
		for {set i 0} {$i < [llength $argv]} {incr i} {
			set arg [lindex $argv $i]
			set val [lindex $argv [expr {$i+1}]]
			switch -regexp -- $argv {
				{^--*d.*} {
					# -ddir: Starting directory
					set dir $val; incr i
					cd $val
					}
				{^--*r.*} {
					# -root: CVS root
					set cvscfg(cvsroot) $val; incr i}
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
					if {1} {
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
					
				} default {
					puts $usage
					}
			}
		}
	}
	else
	{
		puts $usage
	}
}

proc tkrevinit { cvscfg_str } {
	array set cvscfg $cvscfg_str
  	global auto_path
	global TCDIR
	global HOME
	global TCLROOT
	global USERNAME
	global cvsglb
	global Script
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
	puts "ScriptBin $ScriptBin"
	set TclRoot [file join [file dirname $ScriptBin]]
	puts "TclRoot $TclRoot"
	if {$TclRoot == "."} {
	 	set TclRoot [pwd]
	}
	puts "TclRoot $TclRoot"
	set TclRoot [file join [file dirname $TclRoot] "lib"]
	puts "TclRoot $TclRoot"
	# allow runtime replacement
	if {[info exists env(TCLROOT)]}	{
	  set TclRoot $env(TCLROOT)
	}
	puts "TclRoot $TclRoot"
	set cvscfg(version) "9.4.2"
	set TCDIR [file join $TclRoot tkrev]      
	if {! [info exists cvscfg(editorargs)]}	{
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
	if { [file exists [file join $TCDIR tkrev_def.tcl]] }	{
		source [file join $TCDIR tkrev_def.tcl]
	}
	set optfile [file join $cvscfg(home) .tkrev]
	set old_optfile [file join $cvscfg(home) .tkcvs]
	if { [file exists $old_optfile] && ![file exists $optfile] } {
		file copy -- $old_optfile $optfile
	}
	if {[file exists $optfile]} {
		catch {source $optfile}
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
		cvserror "cvscfg(terminal) is required if cvscfg(use_cvseditor) is set \a"
	}
	return [array get cvscfg]
}
puts $argv 
# puts $dir
array set cvsglb ""
array set cvscfg ""
if {[string equal $argv "help"]} {
	usgprint $argv 
	exit -1
} else {
	set cvscfg_str [tkrevinit [array get cvscfg]]
	array set cvscfg $cvscfg_str
	set src_ctrl_str [srcctrlchk [array get cvscfg]]
	array set src_ctrl $src_ctrl_str
	exit 0 	
}
exit -1 
