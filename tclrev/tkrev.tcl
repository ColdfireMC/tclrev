

proc srcctrlchk {} { 
	global env
	global cvscfg
	global cvsglb
	set srcdirtype_str ""
	set srcdirtype(insvn) false
	set srcdirtype(ingit) false
	set srcdirtype(inrcs) false
	set srcdirtype(incvs) false
	puts [pwd]
	set srcdirtype_str [cvsroot_check [pwd] [array get cvscfg] [array get cvsglb]]
	array set srcdirtype $srcdirtype_str
	set cvsglb(root) ""
	set cvsglb(vcs) ""
	
	if {{$srcdirtype(insvn) == true} && {$srcdirtype(incvs) == false} && {$srcdirtype(ingit) == false}} {
		set cvsglb(root) $cvscfg(svnroot)
		set cvsglb(vcs) svn
		puts "svn"
	} elseif {{$srcdirtype(insvn) == false} && {$srcdirtype(incvs) == true} && {$srcdirtype(ingit) == false}} {
		set cvsglb(root) $cvscfg(cvsroot)
		set cvsglb(vcs) cvs
		puts "cvs"
	} elseif {{$srcdirtype(insvn) == false} && {$srcdirtype(incvs) == false} && {$srcdirtype(ingit) == true}} {
       set cvsglb(root) $cvscfg(url)
       set cvsglb(vcs) git
       puts "git"
    } else {
		switch repotype_default {
			svn {
				if {$srcdirtype(insvn) == true} {
					set repotype svn
				} 
			}
			git {
				if {$srcdirtype(ingit) == true} {
					set repotype git
				} 
			}
			cvs {
				if {$srcdirtype(incvs) == true} {
					set repotype cvs
				} 
			}
			rcs {
				puts "rcs not supported yet"
			}
			default {
				puts "Error: default not applicable"
		}
    }
		puts "Directory doesn't seem to be in Git, CVS or SVN, or is being controlled by more than one version control system"
		return -1
    }
	# We'll respect CVSROOT environment variable if it's set
    if {[info exists env(CVSROOT)]} {
		set cvsglb(root) $env(CVSROOT)
		set cvscfg(cvsroot) $env(CVSROOT)
		set cvsglb(vcs) cvs
    }
}
proc usgprint {} { 
	# Command line options	
	set usage "Usage:" 
	append usage "\n tkrev \[-root <cvsroot>\] \[-win workdir|module|merge\]" 
	append usage "\n tkrev \[-log|blame <file>\]"
	append usage "\n tkrev <file> - same as tkrev -log <file>"
}	 
	
proc arg_parse { argv } {
	
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
					usgprint
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
				}
			} 
	 }
	}
}
proc tkrevinit { } {
	
	global cvscfg
 global auto_path
	global TCDIR
	global HOME
	global TCLROOT
	global USERNAME
	global cvsglb
	global Script
	set TclExe [info nameofexecutable]
	set auto_path [lappend auto_path [file dirname $TclExe]]    
	if {[info exists TclRoot]} {
		    return 1
		}
	set ScriptBin [info nameofexecutable]
	set TclRoot [file join [file dirname $ScriptBin]]
	set TCDIR [file dirname [info script]]
	puts "TclRoot $TclRoot"
	if {$TclRoot == "."} {
	 	set TclRoot [pwd]
	}
	puts "TclRoot $TclRoot"
	set TclRoot [file join [file dirname $TclRoot] "lib"]
	puts "TclRoot $TclRoot"
	 # Read in defaults
	if { [file exists [file join $TCDIR tkrev_def.tcl]] }	{
		source [file join $TCDIR tkrev_def.tcl]
	}
	set optfile [file join "~" .tkrev]
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
	srcctrlchk    
}
##
# tclrev entry
package require registry

array set repo "" 
array set cvsglb ""
array set cvscfg ""
set repotype_default ""
set repotype ""
if {[info exists argv] } { 
		tkrevinit
} else {
		usgprint
}
