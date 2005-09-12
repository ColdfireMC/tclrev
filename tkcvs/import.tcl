#
# Tcl Library for TkCVS
#

#
# $Id: import.tcl,v 1.47 2005/06/06 03:03:22 dorothyr Exp $
#
# Adds a new document to the repository.
#

proc import_run {} {
  global cwd
  global incvs
  global cvsglb

  gen_log:log T "ENTER"
  
  cvsroot_check [pwd]
  if {$incvs} {
    cvsok "This directory is already in CVS.\nCan\'t import here!" .import
    gen_log:log T "LEAVE"
    return
  }

  # This is just a default.  The user can change it.
  set cvsglb(newcode) [file tail $cwd]
  
  if {[winfo exists .import]} {
    wm deiconify .import
    raise .import
    grab set .import
    gen_log:log T "LEAVE"
    return
  }

  # Give it a default.  This is what you get without the -b option.
  set cvsglb(newvers) 1.1.1
  set cvsglb(newdir) $cvsglb(newcode)

  toplevel .import
  grab set .import

  frame .import.top

  message .import.top.explain -justify left -width 500 -relief groove \
    -text "This will import the current directory and its sub-directories\
          into CVS, creating a new module."
  label .import.top.lnewcode -text "New Module Name"  -anchor w
  label .import.top.lnewdir  -text "New Module path relative to \$CVSROOT" -anchor w
  label .import.top.lnewdesc -text "Descriptive Title" -anchor w
  label .import.top.lnewvers  -text "Version Number" -anchor w

#  entry .import.top.tnewcode -textvariable cvsglb(newcode) -width 40 \
#    -state disabled -borderwidth 1
  entry .import.top.tnewcode -textvariable cvsglb(newcode) -width 40 
  entry .import.top.tnewdir -textvariable cvsglb(newdir) -width 40
  entry .import.top.tnewdesc -textvariable cvsglb(newdesc) -width 40
  entry .import.top.tnewvers -textvariable cvsglb(newvers) -width 40
  

  grid .import.top.explain -column 0 -row 0 -columnspan 3 -sticky ew
  grid .import.top.lnewcode -column 0 -row 1 -sticky w
  grid .import.top.tnewcode -column 1 -row 1 -sticky ew
  grid .import.top.lnewdir -column 0 -row 2 -sticky w
  grid .import.top.tnewdir -column 1 -row 2 -sticky ew
  grid .import.top.lnewdesc -column 0 -row 3 -sticky w
  grid .import.top.tnewdesc -column 1 -row 3 -sticky ew
  grid .import.top.lnewvers -column 0 -row 4 -sticky w
  grid .import.top.tnewvers -column 1 -row 4 -sticky ew

  frame .import.down -relief groove -border 2
  button .import.down.ok -text "OK" \
    -command {
      grab release .import
      wm withdraw .import
      do_import
    }
  button .import.down.quit -text "Cancel" \
    -command {
      grab release .import
      wm withdraw .import
    }

  pack .import.down -side bottom -expand yes -fill x
  pack .import.top -side top -expand yes -fill x
  pack .import.down.ok -side left -expand yes
  pack .import.down.quit -side left -expand yes

  # Needed for slower framebuffers
  #tkwait visibility .import

  wm title .import "Create a New Module"
  wm minsize .import 1 1

  gen_log:log T "LEAVE"
}

proc do_import {} {
  global cvs
  global cvsglb
  global cvscfg
  global cwd
  global modlist_sorted
  global modval
  global modtitle
  global ExModList ExModDirList

  gen_log:log T "ENTER"
  set imdir [pwd]

  # Error checks
  if { $cvsglb(newcode) == "" } {
    cvsok "You must type in a new module name." .import
    return 1
  }
  if { $cvsglb(newdir) == "" } {
    cvsok "You must type in a new module path directory." .import
    return 1
  }
  
  # We may have gotten here before opening the module browser
  if {! [info exists modlist_sorted]} {
     modbrowse_run
  }
  # Make sure it isn't a duplicate key
  foreach {key value} [array get modval] {
     if { $cvsglb(newcode) == $key } {
        cvsok "$cvsglb(newcode) is not a new Module" .import
	return 1
     }
  }
  
  # See if all apropriate Directories in newdirname exist.  CVS import will
  # create them, but we'll want to make a #D entry.
  set cvsglb(newdir) [string trimleft $cvsglb(newdir) "/"]
  set pathname [file dirname $cvsglb(newdir)]
  set need_Dir 0
  if {$pathname != "."} {
    foreach idx $modlist_sorted {
      lappend knowndirs [lindex $idx 0]
    }
    gen_log:log D "looking for $pathname in known directories ($knowndirs)"
    if {[lsearch -exact $knowndirs $pathname] == -1} {
      set need_Dir 1
    }
  }

  # Make a baseline tag
  set versions [split $cvsglb(newvers) ".,/ -"]
  set baseline "baseline-[join $versions {_}]"

  set commandline "$cvs -d $cvscfg(cvsroot) import -m \"Imported using TkCVS\""
  # Let it default to 1.1.1 or you will have big problems later from cvs.
  #if {$cvsglb(newvers) != ""} {
    #append commandline " -b 1.1.1"
  #}
  append commandline " \"$cvsglb(newdir)\" IMPORT $baseline"

  set v [viewer::new "Import Module"]
  $v\::log "\nCVS Import\n"
  $v\::do "$commandline"
  $v\::wait
  update

  # Update the modules file.
  set commandline "$cvs -d $cvscfg(cvsroot) -w checkout CVSROOT/modules"
  $v\::log "\nCheckout New Module\n"
  $v\::do "$commandline"
  $v\::wait

  cd CVSROOT
  gen_log:log F "CD [pwd]"
  set modfile [open modules a]
  if {$need_Dir} {
    puts $modfile ""
    gen_log:log D "#D	$pathname"
    puts $modfile "#D	$pathname"
  }
  gen_log:log D "#M\t$cvsglb(newcode)\t$cvsglb(newdesc)"
  puts $modfile "#M\t$cvsglb(newcode)\t$cvsglb(newdesc)"
  gen_log:log D "$cvsglb(newcode)\t$cvsglb(newdir)"
  puts $modfile "$cvsglb(newcode)\t$cvsglb(newdir)"
  close $modfile
  set commandline "$cvs -d $cvscfg(cvsroot) ci -m \"added $cvsglb(newcode)\" modules"
  $v\::log "\nCVS Checkin CVSROOT\n"
  $v\::do "$commandline"
  $v\::wait
  cd ../
  gen_log:log F "CD [pwd]"
  set commandline "$cvs -d $cvscfg(cvsroot) -Q release -d CVSROOT"
  $v\::do "$commandline"
  $v\::wait

  modbrowse_run

  # Now check out the new module
  cd ..
  gen_log:log F "CD [pwd]"
  # We have to move the original stuff entirely out of the way.
  # Otherwise checkout won't do the whole tree.
  gen_log:log F "MOVE $imdir $imdir.orig"
  if {[file isdirectory $imdir.orig]} {
     file delete -force -- $imdir.orig
  }
  file rename $imdir $imdir.orig
  set commandline \
          "$cvs -d $cvscfg(cvsroot) checkout -R \"$cvsglb(newcode)\""
  #gen_log:log C "$commandline"
  $v\::log "\nCVS Checkout\n"
  $v\::do "$commandline"
  $v\::wait
  
  # cd to the checked out module. $cwd is the correct directory to cd to
  # only if the name of the new module is the same as the directory name
  # where the source code is in. Define ckmoddir to be used instead.
  
  set ckmoddir $cwd
  if { $cvsglb(newcode) != [file tail $cwd] } {
     set ckmoddir [file join [file dirname $cwd] $cvsglb(newcode)]
  }  
  if { [catch "cd $ckmoddir" err]} {
    cvsok "$err" .import
  } else {
    gen_log:log F "CD [pwd]"
  }
 
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

