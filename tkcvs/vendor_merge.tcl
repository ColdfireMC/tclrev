
# Tcl Library for TkCVS

#
# Modifications by Eugene Lee 10/16/03 
# 1. .merge window made more robust so user cannot key in incorrect data.
# 2. Name of Vendor Module is selectable by user (no longer hardcoded to Vendor). 
#    proc vendor_wait no longer used
# 3. Added proc vendorDialog
 

proc merge_run {mcode} {
# By: Eugene Lee, Aerospace Corporation, 11/12/95
# Modified by E. Lee 10/16/03
  global cvs
  global cvsglb
  global modbrowse_module
  global from_to
  global sel_to
  global cwd
  global module_dir
  global merge
  gen_log:log T "ENTER ($mcode)"

  if {$mcode == ""} {
    cvsfail "Please select a module!" .modbrowse
    gen_log:log T "LEAVE"
    return
  }

  if {[winfo exists .merge]} {
    .merge.right.tcwd configure -textvariable cwd
    .merge.right.tmodule configure -textvariable modbrowse_module
    wm deiconify .merge
    raise .merge
    #grab set .merge
    gen_log:log T "LEAVE"
    return
  }

  toplevel .merge
  #grab set .merge

  frame .merge.left
  frame .merge.right
  frame .merge.vendor -relief groove -border 2
  frame .merge.down -relief groove -border 2

  pack .merge.down -side bottom -fill x -expand yes
  pack .merge.vendor -side bottom -fill x -expand yes
  pack .merge.left   -side left
  pack .merge.right  -side right -fill x -expand yes

  label .merge.left.lcwd      -text "Current Directory" -width 16  -anchor w
  label .merge.left.lmodule   -text "Module"  -width 16  -anchor w
  label .merge.right.tcwd  -textvariable cwd   -relief sunken -width 40 -anchor w
  label .merge.right.tmodule -textvariable modbrowse_module -relief sunken -width 40 -anchor w

  pack .merge.left.lcwd       -side top   -fill x -pady 3
  pack .merge.left.lmodule    -side top   -fill x
  pack .merge.right.tcwd      -side top   -fill x -pady 3
  pack .merge.right.tmodule   -side top   -fill x

  frame .merge.vendor.name
  pack .merge.vendor.name -side top -fill x -expand yes
  label .merge.vendor.name.l -text "Vendor Module" -width 16 -anchor w
  label .merge.vendor.name.e -relief sunken -textvariable venselect_mcode -anchor w
  button .merge.vendor.name.b -text "Browse ..." -highlightbackground $cvsglb(bg) \
    -command "vendorDialog"
  pack .merge.vendor.name.l -side left -fill x -pady 3
  pack .merge.vendor.name.b -side right -anchor w -fill x 
  pack .merge.vendor.name.e -side right -anchor w -fill x -pady 3 -expand yes
  #.merge.vendor.name.e config -state disabled
  bind .merge.vendor.name.e <Return> { put_rev_tags $venselect_mcode }

  frame .merge.vendor.l
  frame .merge.vendor.r
  pack .merge.vendor.l .merge.vendor.r -side left

  foreach i {l r} {
    if { $i == "l" } {
      set x "From"
    } else {
      set x "To"
    }
    label .merge.vendor.$i.rev -text "$x Revision Tags"
    pack .merge.vendor.$i.rev -side top

    frame .merge.vendor.$i.scroll
      eval {listbox .merge.vendor.$i.scroll.list \
              -yscrollcommand [list .merge.vendor.$i.scroll.sy set] \
              -xscrollcommand [list .merge.vendor.$i.scroll.sx set]} \
      -relief sunken -width 40 -height 8
    scrollbar .merge.vendor.$i.scroll.sx -orient horizontal \
      -command [list .merge.vendor.$i.scroll.list xview] \
      -relief sunken
    scrollbar .merge.vendor.$i.scroll.sy -orient vertical \
      -command [list .merge.vendor.$i.scroll.list yview] \
      -relief sunken
    pack .merge.vendor.$i.scroll.sx -side bottom -fill x
    pack .merge.vendor.$i.scroll.sy -side right -fill y
    pack .merge.vendor.$i.scroll.list -side left -fill both -expand true
    pack .merge.vendor.$i.scroll -side top

    frame .merge.vendor.$i.f
    pack .merge.vendor.$i.f -side bottom
    label .merge.vendor.$i.f.l -text $x
    if { $i == "l" } {
      label .merge.vendor.$i.f.s \
        -textvariable merge(from) -relief sunken -width 15
    } else {
      label .merge.vendor.$i.f.s \
        -textvariable merge(to) -relief sunken -width 15
    }

    pack .merge.vendor.$i.f.l -side left -padx 3 -pady 3
    pack .merge.vendor.$i.f.s -side left -pady 3
  }

  button .merge.ok -text "OK" -highlightbackground $cvsglb(bg) \
    -command {
      if { $venselect_mcode == "" } {
         cvsfail "Please select a Vendor" .merge
         return
      }
      catch do_merge results
      if { $results == "err" } { return }
      grab release .merge
      wm withdraw .merge
    }
  button .merge.quit -text "Cancel" -highlightbackground $cvsglb(bg) \
    -command {
      grab release .merge
      wm withdraw .merge
    }
  pack .merge.ok .merge.quit -in .merge.down -side left \
    -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both 

  bind .merge.vendor.l.scroll.list <<ListboxSelect>> {
    get_j .merge.vendor.l.scroll.list left
  }
  bind .merge.vendor.r.scroll.list <<ListboxSelect>> {
    get_j .merge.vendor.r.scroll.list right
  }

  # Needed for slower framebuffers
  #tkwait visibility .merge

  wm title .merge "Module Level Merge With Vendor Code"
  wm minsize .merge 30 10

  gen_log:log T "LEAVE"
}

proc get_j { list side} {
# Written by Eugene A. Lee, Aerospace Corp., 12/20/94
  global merge

  gen_log:log T "ENTER ($list $side)"
  gen_log:log D "[$list curselection]"
  if {[string compare [$list curselection] ""] == 0} return
  set Sel [$list get [$list curselection]]

  if {$side == "left"} {
    set merge(from) [lindex [split $Sel] 0]
  } else {
    set merge(to) [lindex [split $Sel] 0]
  }
  gen_log:log T "LEAVE"
}

proc put_rev_tags {code} {
# Written by Eugene A. Lee, Aerospace Corp., 11/12/95
# Called by button .venselect.ok in venget.tcl
# Made usable for remote repositories by MK
#
# Go to the tmpdir aka cvs.tcl
# Retrieve the whole friggin stuff into the directory (update from head)
# Get the tags for all the files by calling put_rv_tags
# Parse that result
#
  global cvscfg
  global merge
  global venselect_mcode
  global cwd
  global cvs
  global filenames

  set tmpwdir [pwd]

  gen_log:log T "ENTER"
  .merge.vendor.l.scroll.list delete 0 end
  .merge.vendor.r.scroll.list delete 0 end

  set ret [cvs_sandbox_runcmd \
     "$cvs -d $cvscfg(cvsroot) checkout $venselect_mcode" cmd_output]
  if {$ret == $cwd} {
    cd $cwd
    gen_log:log T "leave -- failed cvs checkout statement"
    return
  }
  cd $venselect_mcode
  gen_log:log F "CD [pwd]"

  set view_lines [split $cmd_output "\n"]
  foreach line $view_lines {
    gen_log:log D "Evaluating line $line"
    if {[string match "U *" $line]} {
      set dname [lindex [split $line] 1]
      regsub "$venselect_mcode/" $dname "" fname
      if {[info exists filenames($venselect_mcode)]} {
        lappend filenames($venselect_mcode) $fname
      } else {
        set filenames($venselect_mcode) $fname
      }
    }
  }

  gen_log:log F "filenames($venselect_mcode) existence:[info exists filenames($venselect_mcode)]"

  #  get the module into the source
  if {[info exists filenames($venselect_mcode)]}  {
    get_rv_tags $venselect_mcode r_tag_list v_tag_list
  }

  cd $tmpwdir
  if { [info exists r_tag_list] == 0 } {
    foreach i {l r} {
      .merge.vendor.$i.scroll.list insert end "No revision tags found"
    }
  } else {
    for {set i 0} {$i < [llength $r_tag_list]} {incr i} {
      set tmp [lindex $r_tag_list $i]
      .merge.vendor.l.scroll.list insert end $tmp
      .merge.vendor.r.scroll.list insert end $tmp
    }
  }
  cd $cwd
  gen_log:log T "LEAVE"
}

proc do_merge {} {
  global merge
  global cvscfg
  global cvs
  global venselect_mcode
  global modbrowse_module
  
  gen_log:log T "ENTER"
  set merge(3rd_party) $venselect_mcode
  if { $merge(3rd_party) == "" } {
    cvsfail "Vendor Module not specified" .merge
    return err
  }

  if { $merge(from) == "" || $merge(to) == "" } {
    cvsfail "not all entries filled" .merge
    return err
  }
  
  # In order to merge difference between tags of 3rd_party into $modbrowse_module
  # the directory where the merge is to be done later must be in the checkout 
  # directory of $modbrowse_module. If the user just checked out the 
  # $modbrowse_module and invoked the merge command, the current directory at this
  # point in the script is most likely one above directory $modbrowse_module. 
  # Check for this and save the directory where the merge operation is to be done
  # later.
  if { [file tail [pwd]] == $modbrowse_module } {
     set dir4merge [pwd]
  } else {
     set tmpdir [glob -nocomplain $modbrowse_module]
     if { $tmpdir == "" } {
        cvsfail "You must invoke the merge command from the checked out 
directory of $modbrowse_module or one above it" .merge
        return
     }
     set dir4merge [file join [pwd] $tmpdir]
  }
  
  set mess "This will merge differences between $merge(from) and"
  append mess " $merge(to) of $merge(3rd_party) into $modbrowse_module"
  append mess "\n\n Are you sure?"
  if {[cvsconfirm $mess .merge] == 1} {
    return
  }
  # The CVS directory in the checked out $modbrowse_module are associated with
  # $modbrowse_module. Since we are going to merge in differences between 
  # $merge(from) & $merge(to) of $merge(3rd_party), the CVS directory to be used
  # later in directory $dir4merge needs to from directory $merge(3rd_party).
  # Do that next and save it into a temp directory mktemp_dir
  
  set mktemp "$cvscfg(tmpdir)/merge[pid]"
  set mktemp_dir $mktemp.dir
  set v [viewer::new "Vendor Merge"]
  $v\::log "CVS Checkout of temp sandbox for $merge(3rd_party)\n"
  set cmd "$cvs checkout -d $mktemp_dir -r$merge(from) $merge(3rd_party)"
  $v\::do "$cmd"
  $v\::wait
  update
    
  # CVS directory in $mktemp_dir will be copied later

  cd $dir4merge
  gen_log:log F "CD [pwd]"

  # Save CVS directory of $modbrowse_module which is to be restored after
  # the merge command has been completed. Save it to $mktemp_dir
  set sav_dir [file join $mktemp_dir CVS_save]
  gen_log:log F "COPY CVS $sav_dir"
  file copy CVS $sav_dir
  gen_log:log F "DELETE CVS"
  file delete -force CVS; # Need -force for a directory
  # Then copy the CVS file from $mktemp_dir
  set sav_cvs [file join $mktemp_dir CVS]
  gen_log:log F "COPY $sav_cvs CVS"
  file copy -force $sav_cvs CVS

  $v\::log "\nCVS Merge of $merge(3rd_party) into $modbrowse_module\n"
  set cmd "$cvs checkout -d [pwd] -j$merge(from) -j$merge(to) $merge(3rd_party)"
  $v\::do "$cmd"
  $v\::wait

  $v\::log "\nCVS rdiff from $merge(from) to $merge(to) for $merge(3rd_party)\n"
  set cmd "$cvs rdiff -s -r$merge(from) -r$merge(to) $merge(3rd_party)"
  $v\::do "$cmd"
  $v\::wait
  update

  # Restore CVS directory associated with #modbrowse_module
  gen_log:log F "DELETE CVS"
  file delete -force CVS
  file copy $sav_dir CVS
  gen_log:log F "COPY $sav_dir CVS"
  # Remove the temp directory
  gen_log:log F "DELETE $mktemp_dir"
  file delete -force $mktemp_dir
  gen_log:log T "LEAVE"
}

proc unpack_tag_word { tag_word type tag_message} {
  upvar $type typ $tag_message tag_m
#
# Unpacks vendor and release tag information obtained from an RCS ,v file.
# In an RCS ,v file, between the keywords "symbols" and "locks" keywords,
# there are packed words with the following format:
#
#            tag_info:tag_ident
#
# where: tag_info is either the vendortag or releasetag which was entered
#        when a cvs checkin or import command was invoked.
#        tag_ident is of the form:
#          x.y.z for a vendor tag (3 subfields or 2 dots)
#          x.y,  x.y.z.w, or x.y.z.w.u.v for a release tag
#
# Called by:
#
# input: tag_word - word from a RCS ,v file between the "symbols" and "locks"
#                   keywords
# output: type - 0 if tag_word contains packed info on a release tag
#                1 if tag_word contains packed info on a vendor tag
# output: tag_message - a vendortag or releasetag as entered when a cvs
#         checkin or import command was invoked
#
# By: Eugene A. Lee, Aerospace Corporation
# Date: Sept 15, 1995
#
  gen_log:log T "ENTER ($tag_word $type $tag_message)"

  set fields [split $tag_word :]
  set tag_m [string trimleft [lindex $fields 0]]
  set tag_num [string trimleft [lindex $fields 1]]

  # strip off any trailing ; character
  regsub {;$} $tag_num "" tag_num

  if { [llength [split $tag_num . ]]  == 3 } {
    set typ 1; # release tag
  } else {
    set typ 0; # vendor tag
  }
  gen_log:log T "LEAVE"
}

proc get_rv_tags { mcode r_tag_list v_tag_list } {
  global filenames
  upvar $v_tag_list vtag_list
  upvar $r_tag_list rtag_list
#
#  From the original code of E.A. Lee
# Rewrite by M.R. Koelewijn, trying to make this work with a remote repository
#  Assumption:
#    The caller has created the sandbox in a local tmpdir, containing the
#    relevant files for this 'mcode'
#    The global 'filenames' has been set up to contain the names of the files
#  So, with merge_taglist the filenames are passed to CVS, with the request
# to cough up some info. This info contains the tags (thanks, whoever did the
# logcanvas): one big list of tags. Than we sort out the uniqe ones.
#
# Packed releasetag word has the format:
#                releasetag:branch_id
#   where: releasetag was specified when the cvs import command was invoked.
#          branch_id is of the forms: x.y, x.y.z.w, x.y.z.w.u.v, etc,
#          (odd number or subfields)
#
# Packed vendortag word has the format:
#                vendortag:branch_id
#   where: vendortag was specified when the cvs import command was invoked.
#          branch_id is of the forms: x.y.z (3 subfields or 2 dots)
#
# Output: r_tag_list    - sorted releasetag list for the CVS module
# Output: v_tag_list    - sorted vendortag list for the CVS module
#
# Note: v_tag_list has no planned use for tkcvs yet. They are returned just
#       because this information was available.
#

  gen_log:log T "ENTER ($mcode $r_tag_list $v_tag_list)"

  set rlist ""  ;# easies way to allow lsearch to work without having to
  set vlist ""  ;# use info exists statements

  foreach tag [cvs_sandbox_filetags $mcode $filenames($mcode)] {
    gen_log:log D "Next tag: $tag"
    unpack_tag_word $tag type tag_message
    gen_log:log D "$tag is type $type message $tag_message"
    if {$type == 0 } {
      if {[lsearch -exact $rlist $tag_message] < 0} {
        gen_log:log D "New Release tag found: $tag_message"
        lappend rlist $tag_message
      }
    }
    if {$type == 1 } {
      if {[lsearch -exact $rlist $tag_message] < 0} {
        gen_log:log D "New Vendor tag found: $tag_message"
        lappend vlist $tag_message
      }
    }
  }
  # Unsorted master releasetag and versiontag lists have been found.
  if { [info exists rlist] == 1 } {
    set rtag_list [lsort $rlist]
  } else {
    gen_log:log D "no mrlist created"
  }
  if { [info exists vlist] == 1 } {
    set vtag_list [lsort $vlist]
  } else {
    gen_log:log D "no mvlist created"
  }
  gen_log:log T "LEAVE"
}

proc merge_taglist {files} {
  global cvscfg
  global cvs

  gen_log:log T "ENTER ($files)"
  set commandline "$cvs -d $cvscfg(cvsroot) log $files"
  gen_log:log C "$commandline"
  set ret [catch {eval "exec $commandline"} view_this]
  gen_log:log "C" "$view_this"
  if {$ret} {
    cvsfail $view_this .merge
    gen_log:log T "LEAVE ERROR"
    return $keepers
  }
  set view_lines [split $view_this "\n"]
  foreach line $view_lines {
    if {[string index $line 0] == "\t" } {
      regsub -all {[\t ]*} $line "" tag
      append keepers "$tag "
    }
  }
  gen_log:log T "LEAVE"
  return $keepers
}

proc vendorDialog {} {
  global ExModList ExModDirList
  global venselect_mcode
  global cvsglb

  set w .venDialog
  grab release .merge
  catch {destroy $w}
  toplevel $w
  wm title $w "Select A Vendor"
  grab set $w

  frame $w.buttons
  pack $w.buttons -side bottom -fill x -pady 2m
  button $w.buttons.ok -text Ok -highlightbackground $cvsglb(bg) \
    -command {
      if {$venselect_mcode == ""} {
         return
      }
      put_rev_tags $venselect_mcode
      destroy .venDialog
      raise .merge
      #grab set .merge
    }
  button $w.buttons.cancel -text Cancel -highlightbackground $cvsglb(bg) \
    -command {
      grab release .venDialog
      wm withdraw .venDialog
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
    set venselect_mcode [%W get [%W nearest %y] ]
  }
}

