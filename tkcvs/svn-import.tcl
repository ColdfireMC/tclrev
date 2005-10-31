#
# Tcl Library for TkCVS
#

#
# $Id: import.tcl,v 1.47 2005/06/06 03:03:22 dorothyr Exp $
#
# Adds a new document to the repository.
#

proc svn_import_run {} {
  global incvs insvn
  global cvsglb
  global cvscfg

  gen_log:log T "ENTER"
  
  cvsroot_check [pwd]
  if {$insvn} {
    cvsok "This directory is already in Subversion.\nCan\'t import here!" .import
    gen_log:log T "LEAVE"
    return
  } elseif {$incvs} {
    cvsok "There are CVS directories here.\nPlease remove them first." .import
    gen_log:log T "LEAVE"
    return
  }

  # This is just a default.  The user can change it.
  set cvsglb(imdir) [file tail [pwd]]
  
  if {[winfo exists .import]} {
    wm deiconify .import
    raise .import
    grab set .import
    gen_log:log T "LEAVE"
    return
  }

  toplevel .import
  grab set .import

  frame .import.top

  message .import.top.explain -justify left -width 500 -relief groove \
    -text "This will import the current directory and its sub-directories\
          into SVN.  If you haven't created a Subversion repository,\
          you must do that first with \"svnadmin create.\""
  label .import.top.lsvnroot  -text "URL of SVN Repository" -anchor w
  #label .import.top.lnewdir  -text "New Project path relative to SVN repository" -anchor w

  # Can't use file join or it will mess up the URL
  set cvsglb(imtop) "$cvscfg(svnroot)/trunk"
  entry .import.top.tsvnroot -textvariable cvsglb(imtop) -width 40 
  #entry .import.top.tnewdir -textvariable cvsglb(newdir) -width 40

  grid .import.top.explain -column 0 -row 0 -columnspan 3 -sticky ew
  #grid .import.top.lnewdir -column 0 -row 1 -sticky w
  #grid .import.top.tnewdir -column 1 -row 1 -sticky ew
  grid .import.top.lsvnroot -column 0 -row 2 -sticky e
  grid .import.top.tsvnroot -column 1 -row 2 -sticky ew


  frame .import.down -relief groove -border 2
  button .import.down.ok -text "OK" \
    -command {
      grab release .import
      wm withdraw .import
      svn_do_import $cvsglb(imtop) $cvsglb(imdir)
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


  wm title .import "Import a Project into Subversion"
  wm minsize .import 1 1

  gen_log:log T "LEAVE"
}

proc svn_do_import {imtop imdir} {
  global cvsglb
  global cvscfg

  gen_log:log T "ENTER"
  set imdir [pwd]
  set cwd [pwd]

  # Error checks
  if { $cvscfg(svnroot) == "" } {
    cvsok "Subversion URL missing." .import
    return 1
  }
  
  set commandline "svn import . $imtop -m \"Imported using TkCVS\""

  set v [viewer::new "Import Project"]
  $v\::log "\nSVN Import\n"
  $v\::do "$commandline"
  $v\::wait
  update


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
  set commandline "svn checkout $imtop $imdir"

  $v\::log "\nSVN Checkout\n"
  $v\::do "$commandline"
  $v\::wait
  
  if {[catch "cd $imdir" err]} {
    # If we didn't check out the new dir sucessfully, put the old one back
    file rename $imdir.orig $imdir
    cvsok "$err" .import
  } else {
    gen_log:log F "CD [pwd]"
  }
 
  setup_dir
  modbrowse_run
  gen_log:log T "LEAVE"
}

