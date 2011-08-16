#
# Tcl Library for TkCVS
#

#
# import2.tcl is similar to import1.tcl except that it is used for
# importing to an existing module.
# By: Eugene Lee, Aerospace Corporation, 10/16/03
#

proc import2_run {} {
  # Called from "Import To An Existing Module"
  global cwd
  global incvs
  global cvsglb

  gen_log:log T "ENTER"

  cvsroot_check [pwd]

  if {[winfo exists .import2]} {
    wm deiconify .import2
    raise .import2
    grab set .import2
    gen_log:log T "LEAVE"
    return
  }

  toplevel .import2
  grab set .import2

  frame .import2.top

  message .import2.top.explain -justify left -width 500 -relief groove \
    -text "This will import the current directory and its sub-directories\
          into an Existing CVS module."
  label .import2.top.lnewcode -text "Module Name" -anchor w
  label .import2.top.lnewdir  -text "Module path relative to \$CVSROOT" -anchor w
  label .import2.top.lnewdesc -text "Descriptive Title" -anchor w
  label .import2.top.lnewvers  -text "Version Number" -anchor w

  # Give it a default
  set cvsglb(existmodule) ""
  set cvsglb(newdir) ""
  set cvsglb(newdesc) ""
  set cvsglb(newvers) ""

#  label .import2.top.tnewcode -textvariable cvsglb(existmodule) -relief sunken -width 40 -anchor w
#  label .import2.top.tnewdir  -textvariable cvsglb(newdir) -relief sunken -width 40 -anchor w
  label .import2.top.tnewcode -textvariable cvsglb(existmodule) -relief sunken -width 40 -anchor w
  label .import2.top.tnewdir  -textvariable cvsglb(newdir) -relief sunken -width 40 -anchor w
#  entry .import2.top.tnewdesc -textvariable cvsglb(newdesc) -width 40
  entry .import2.top.tnewvers -textvariable cvsglb(newvers) -width 40
  
  button .import2.top.bnewcode -text "Browse ..." \
   -command "moduleDialog" 

  grid .import2.top.explain -column 0 -row 0 -columnspan 3 -sticky ew
  grid .import2.top.lnewcode -column 0 -row 1 -sticky w
  grid .import2.top.tnewcode -column 1 -row 1 -sticky w
  grid .import2.top.bnewcode -column 2 -row 1 -sticky e
  grid .import2.top.lnewdir -column 0 -row 2 -sticky w
  grid .import2.top.tnewdir -column 1 -row 2 -sticky w
#  grid .import2.top.lnewdesc -column 0 -row 3 -sticky w
#  grid .import2.top.tnewdesc -column 1 -row 3 -sticky ew
  grid .import2.top.lnewvers -column 0 -row 3 -sticky w
  grid .import2.top.tnewvers -column 1 -row 3 -sticky ew

  frame .import2.down -relief groove -border 2
  button .import2.down.ok -text "OK" \
    -command {
      grab release .import2
#      wm withdraw .import2
      catch do_import2 results
    }
  button .import2.down.quit -text "Cancel" \
    -command {
      grab release .import2
      wm withdraw .import2
    }

  pack .import2.down -side bottom -expand yes -fill x
  pack .import2.top -side top -expand yes -fill x
  pack .import2.down.ok -side left -expand yes
  pack .import2.down.quit -side left -expand yes

  # Needed for slower framebuffers
  #tkwait visibility .import2

  wm title .import2 "Import To An Existing Module"
  wm minsize .import2 1 1

  gen_log:log T "LEAVE"
}

proc do_import2 {} {
  global cvs
  global cvsglb
  global cvscfg
  global cwd
  global modlist_sorted
  global modval

  gen_log:log T "ENTER"
  set imdir [pwd]

  # Error checks
  if { $cvsglb(existmodule) == "" } {
    cvsok "You must select an existing module from the repository." .import2
    raise .import2
    grab set .import2
    return 1
  }
  if { $cvsglb(newdir) == "" } {
    cvsok "You must select an existing module from the repository." .import2
    raise .import2
    grab set .import2
    return 1
  }
  if { $cvsglb(newvers) == "" } {
    cvsok "You must type in a version number." .import2
    raise .import2
    grab set .import2
    return 1
    return
  }
  
  wm withdraw .import2; # After no more errors

  # We may have gotten here before opening the module browser
  if {! [info exists modlist_sorted]} {
     modbrowse_run cvs
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

  set v [viewer::new "Import Module"]

  set commandline "$cvs -d $cvscfg(cvsroot) import -m \"Imported using TkCVS\" \
	    $cvsglb(newdir) VENDOR $baseline"
  $v\::log "\nCVS Import\n"
  $v\::do "$commandline"
  $v\::wait
  update

  # No need to update the modules file.

  cd ../
  gen_log:log F "CD [pwd]"
  set commandline "$cvs -d $cvscfg(cvsroot) -Q release -d CVSROOT"
  $v\::do "$commandline"
  $v\::wait
  cd $cwd
  gen_log:log F "CD [pwd]"

  #modbrowse_run cvs

  # Now check out the new module
  cd ..
  gen_log:log F "CD [pwd]"
  set ckmoddir $cwd; # save later for use in checking out
  # We have to move the original stuff entirely out of the way.
  # Otherwise checkout won't do the whole tree.
  gen_log:log F "MOVE $imdir $imdir.orig"
  file rename $imdir $imdir.orig
  set $cwd $cwd.orig
  set commandline \
          "$cvs -d $cvscfg(cvsroot) checkout -r$baseline \"$cvsglb(existmodule)\""
  $v\::log "\nCVS Checkout\n"
  $v\::do "$commandline"
  $v\::wait

  set cwd $imdir.orig
  
  # cd to the checked out module. $cwd is the correct directory to cd to
  # only if the name of the existing module is the same as the directory name
  # where the source code is in. If the existing module name is different modify
  # ckmoddir
  if { $cvsglb(existmodule) != [file tail $ckmoddir] } {
     set ckmoddir [file join [file dirname $ckmoddir] $cvsglb(existmodule)]
  }  
  change_dir $ckmoddir
  #gen_log:log F "CD [pwd]"
 
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}


proc import_wait { } {
# For importing to an existing module
# By: Eugene Lee, Aerospace Corporation, 7/10/01
  global modbrowse_module
  global dparent
  global cvsglb
  global dcontents
  global modlist

#  gen_log:log T "ENTER"

#  raise .modbrowse
#  tkwait variable modbrowse_module
  set modbrowse_module Vendor
  set importselect $modbrowse_module
  # Check to see if importselect is an existing module. First, 
  # 1. See if is a module in the root, then 
  # 2. See if is a module that is in a directory instead.
  #
  # 1. importselect in root?
  set dirlist {}; # List of directories (not modules)
  foreach {dir contents} [array get dcontents] {
    lappend dirlist $dir
  }
  
  set module_in_root 0 
  foreach tmp $modlist {
    set f [split $tmp "\t"]
    set module [lindex [split $tmp "\t"] 0]
    if {$importselect == $module} {
      # Make sure that $importselect is not a directory
      if {[lsearch -exact $dirlist $importselect] == -1} {
         incr module_in_root  
      }
    }
  }
  set cvsglb(existmodule) $importselect
  set cvsglb(newdir) $importselect
  
  # 2. importselect in a directory?
  set module_in_dir 0
  foreach {key value} [array get dparent] {
     # dparent will be of the form: Examples/Vendor Examples ...
     # key = Examples/Vendor, value = Examples
     set filetail [file tail $key]
     if {$filetail == $importselect} {
        puts "found $filetail"
        incr module_in_dir
        set cvsglb(newdir) [file join $value $importselect]
	break; #eal 10/13/03
     }
  }
  
  if { $module_in_root == 0 && $module_in_dir == 0 } {
     cvsok "$importselect is not an existing module" .import2
     set cvsglb(existmodule) ""
     set cvsglb(newdir) ""
     raise .import2
     return 1
  }
  
  if { $module_in_root > 0 && $module_in_dir > 0 } {
     cvsok "Error: $importselect found in more that one module." .import2
     set cvsglb(existmodule) ""
     set cvsglb(newdir) ""
     raise .import2
     return 1
  }
  raise .import2
}

proc getExistModDialog { } {
  global modval
  global ExModList ExModDirList
  
  set ExModList {}
  set ExModDirList {}
  foreach {key value} [array get modval] {
     if { $key != "" } {
        lappend ExModList $key
	lappend ExModDirList $value
     }
  } 
}

proc moduleDialog {    } {
   global ExModList ExModDirList
   set w .modDialog
   grab release .import2
   catch {destroy $w}
   toplevel $w
   wm title $w "Select An Existing Module" 
   wm minsize $w 28 3
   grab set $w

frame $w.buttons
pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.ok -text Ok -command {
   destroy .modDialog
   raise .import2
   grab set .import2
   }
button $w.buttons.cancel -text Cancel \
   -command {
     grab release .modDialog
     wm withdraw .modDialog
   }
pack $w.buttons.ok -side left -expand 1
pack $w.buttons.cancel -side left -expand 1

frame $w.frame -borderwidth .5c
pack $w.frame -side top -expand yes -fill y 

scrollbar $w.frame.scroll -command "$w.frame.list yview"
listbox $w.frame.list -yscroll "$w.frame.scroll set" -setgrid 1 -height 5
pack $w.frame.scroll -side right -fill y
pack $w.frame.list -side left -expand 1 -fill both

   getExistModDialog 
   set nModule [llength $ExModList]
   for {set i 0} {$i < $nModule} {incr i} {
     $w.frame.list insert end [lindex $ExModList $i]
   }

bind $w.frame.list <Button-1> {
  set cvsglb(existmodule) [%W get [%W nearest %y] ]
  set tmp [%W get [%W nearest %y] ]
  set cvsglb(newdir) $tmp
  set index [lsearch -exact $ExModList $tmp]
  set cvsglb(newdir) [lindex $ExModDirList $index]
}


}   

