#
# Tcl Library for TkRev
#

#
# Adds a new document to the repository.
#

proc svn_import_run {} {
  global cvsglb
  global cvscfg
  global incvs insvn inrcs ingit
  
  ##gen_log:log T "ENTER"
  
  lassign [cvsroot_check [pwd]] incvs insvn inrcs ingit
  if {$insvn} {
    cvsok "This directory is already in Subversion.\nCan\'t import here!" .svn_import
    ##gen_log:log T "LEAVE"
    return
  } elseif {$incvs} {
    cvsok "There are CVS directories here.\nPlease remove them first." .svn_import
    ##gen_log:log T "LEAVE"
    return
  }
  
  set cvsglb(imdir) [file tail [pwd]]
  # This is just a default.  The user can change it.
  if {[info exists cvscfg(svnroot)] && $cvscfg(svnroot) != ""} {
    set cvsglb(imtop) $cvscfg(svnroot)
  } else {
    set cvsglb(imtop) "< URL Required >"
  }
  # Can't use file join or it will mess up the URL
  set cvsglb(imtop) "$cvsglb(imtop)/trunk"
  
  if {[winfo exists .svn_import]} {
    wm deiconify .svn_import
    raise .svn_import
    grab set .svn_import
    #gen_log:log T "LEAVE"
    return
  }
  
  toplevel .svn_import
  grab set .svn_import
  
  frame .svn_import.top
  
  message .svn_import.top.explain -justify left -width 500 -relief groove \
    -text "This will import the current directory and its sub-directories\
          into SVN.  If you haven't created a Subversion repository,\
      you must do that first with \"svnadmin create.\""
  label .svn_import.top.lsvnroot  -text "URL of SVN Repository" -anchor w
  
  entry .svn_import.top.tsvnroot -textvariable cvsglb(imtop)
  
  grid .svn_import.top.explain -column 0 -row 0 -columnspan 3 -sticky ew
  #grid .svn_import.top.lnewdir -column 0 -row 1 -sticky w
  #grid .svn_import.top.tnewdir -column 1 -row 1 -sticky ew
  grid .svn_import.top.lsvnroot -column 0 -row 2 -sticky e
  grid .svn_import.top.tsvnroot -column 1 -row 2 -sticky ew
  
  
  frame .svn_import.down -relief groove -border 2
  button .svn_import.down.ok -text "OK" \
      -command {
    grab release .svn_import
    wm withdraw .svn_import
    svn_do_import $cvsglb(imtop) $cvsglb(imdir)
  }
  button .svn_import.down.quit -text "Cancel" \
      -command {
    grab release .svn_import
    wm withdraw .svn_import
  }
  
  pack .svn_import.down -side bottom -expand yes -fill x
  pack .svn_import.top -side top -expand yes -fill x
  pack .svn_import.down.ok -side left -expand yes
  pack .svn_import.down.quit -side left -expand yes
  
  
  wm title .svn_import "Import a Project into Subversion"
  wm minsize .svn_import 1 1
  
  #gen_log:log T "LEAVE"
}

proc svn_do_import {imtop imdir} {
  global cvscfg
  
  #gen_log:log T "ENTER"
  set imdir [pwd]
  set cwd [pwd]
  
  set commandline "svn import . $imtop -m \"Imported using TkRev\""
  set v [viewer::new "Import Project"]
  $v\::log "\nSVN Import\n"
  $v\::do "$commandline"
  $v\::wait
  update
  
  
  # Now check out the new module
  cd ..
  #gen_log:log F "CD [pwd]"
  # We have to move the original stuff entirely out of the way.
  # Otherwise checkout won't do the whole tree.
  #gen_log:log F "MOVE $imdir $imdir.orig"
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
    cvsok "$err" .isvn_mport
  } else {
    #gen_log:log F "CD [pwd]"
  }
  
  setup_dir
  modbrowse_run svn
  #gen_log:log T "LEAVE"
}

