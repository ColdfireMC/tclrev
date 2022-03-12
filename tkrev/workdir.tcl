
# Tcl Library for TkRev
#

#
# Current working directory display.  Handles all of the functions
# concerned with navigating about the current directory on the main
# window.
#

proc workdir_setup {} {
  global cwd
  global module_dir
  global cvscfg
  global cvsglb
  global current_tagname
  global logclass
  global tcl_platform
  global incvs insvn inrcs ingit
 set vrbl 1  
  global dot_workdir
  #gen_log:log T "ENTER"
  set cwd [pwd]
  set pid [pid]
  
#  if {[winfo exists .workdir]} {
#    wm deiconify .workdir
#    raise .workdir
#    return
#  }
  
   if {[exists dot_workdir]} {
    return
  }

  
  # Make a new toplevel and unmap . so that the working directory browser
  # the module browser are not in a parent-child relation
#  toplevel .workdir
#  wm title .workdir "TkRev Working Directory"
#  wm iconname .workdir "TkRev Working Directory"
#  wm iconphoto .workdir -default AppIcon64
#  wm minsize .workdir 430 300
#  wm protocol .workdir WM_DELETE_WINDOW { .workdir.close invoke }
#  wm withdraw .
#  
#  if {[info exists cvscfg(workgeom)]} {
#    wm geometry .workdir $cvscfg(workgeom)
#  }
#  
#  menubar_menus .workdir
#  workdir_menus .workdir
#  help_menu .workdir
#  
#  #
#  # Top section - where we are, where the module is
#  #
#  frame .workdir.top -relief groove -border 2
#  pack .workdir.top -side top -fill x
#  
#  ttk::combobox .workdir.top.tcwd -textvariable cwd
#  .workdir.top.tcwd configure -values $cvsglb(directory)
#  bind .workdir.top.tcwd <Return>             {if {[pwd] != $cwd} {change_dir "$cwd"}}
#  bind .workdir.top.tcwd <<ComboboxSelected>> {if {[pwd] != $cwd} {change_dir "$cwd"}}
#  
#  button .workdir.top.updir_btn -image updir \
#      -command {change_dir ..}
#  
#  label .workdir.top.lmodule -text "Path"
#  label .workdir.top.tmodule -textvariable module_dir -anchor w -relief groove -bd 2
#  
#  label .workdir.top.ltagname -text "Tag"
#  label .workdir.top.ttagname -textvariable current_tagname \
#      -anchor w -relief groove -bd 2
#  
#  # Make the Repository Browser button prominent
#  button .workdir.top.bmodbrowse -image Modules -command modbrowse_run
#  
#  label .workdir.top.lcvsroot -text "CVSROOT"
#  entry .workdir.top.tcvsroot -textvariable cvscfg(cvsroot) \
#      -bd 1 -relief sunk -state readonly
#  
#  grid columnconf .workdir.top 1 -weight 1
#  grid rowconf .workdir.top 3 -weight 1
#  grid .workdir.top.updir_btn -column 0 -row 0 -sticky s
#  grid .workdir.top.tcwd -column 1 -row 0 -columnspan 2 \
#      -sticky sew -padx 4 -pady 1
#  grid .workdir.top.lmodule -column 0 -row 1 -sticky nw
#  grid .workdir.top.tmodule -column 1 -row 1 -columnspan 2\
#      -padx 4 -pady 1 -sticky new
#  grid .workdir.top.bmodbrowse -column 2 -row 2 -rowspan 2 -sticky w
#  grid .workdir.top.ltagname -column 0 -row 2 -sticky nw
#  grid .workdir.top.ttagname -column 1 -row 2 -padx 4 -pady 1 -sticky new
#  grid .workdir.top.lcvsroot -column 0 -row 3 -sticky nw
#  grid .workdir.top.tcvsroot -column 1 -row 3 -padx 3 -sticky new
#  
#  
#  # Pack the bottom before the middle so it doesnt disappear if
#  # the window is resized smaller
#  frame .workdir.bottom
#  frame .workdir.bottom.filters -relief raised
#  pack .workdir.bottom -side bottom -fill x
#  pack .workdir.bottom.filters -side top -fill x
#  
#  label .workdir.bottom.filters.showlbl -text "Show:" -anchor w
#  entry .workdir.bottom.filters.showentry -width 12 \
#      -textvariable cvscfg(show_file_filter)
#  label .workdir.bottom.filters.hidelbl -text "   Hide:" -anchor w
#  entry .workdir.bottom.filters.hideentry -width 12 \
#      -textvariable cvscfg(ignore_file_filter)
#  label .workdir.bottom.filters.space -text "    "
#  button .workdir.bottom.filters.cleanbutton -text "Clean:" \
#      -pady 0 -highlightthickness 0 \
#      -command workdir_cleanup
#  entry .workdir.bottom.filters.cleanentry -width 12 \
#      -textvariable cvscfg(clean_these)
#  label .workdir.bottom.filters.vcshidelbl -text " \[vcs\]ignore"
#  entry .workdir.bottom.filters.vcshideentry -textvariable cvsglb(vcs_hidden_files) \
#      -width 8 -state readonly
#  bind .workdir.bottom.filters.showentry <Return> {setup_dir}
#  bind .workdir.bottom.filters.hideentry <Return> {setup_dir}
#  bind .workdir.bottom.filters.cleanentry <Return> {workdir_cleanup}
#  pack .workdir.bottom.filters.showlbl -side left
#  pack .workdir.bottom.filters.showentry -side left
#  pack .workdir.bottom.filters.hidelbl -side left
#  pack .workdir.bottom.filters.hideentry -side left
#  pack .workdir.bottom.filters.space -side left
#  pack .workdir.bottom.filters.cleanbutton -side left -ipadx 2 -ipady 0
#  pack .workdir.bottom.filters.cleanentry -side left
#  pack .workdir.bottom.filters.vcshidelbl -side left
#  pack .workdir.bottom.filters.vcshideentry -side left
#  
#  frame .workdir.bottom.buttons -relief groove -bd 2
#  frame .workdir.bottom.buttons.funcs -relief groove -bd 2
#  frame .workdir.bottom.buttons.dirfuncs -relief groove -bd 2
#  frame .workdir.bottom.buttons.cvsfuncs -relief groove -bd 2
#  frame .workdir.bottom.buttons.oddfuncs -relief groove -bd 2
#  frame .workdir.bottom.buttons.closefm
#  pack .workdir.bottom.buttons -side top -fill x -expand yes
#  pack .workdir.bottom.buttons.closefm -side right -expand yes
#  pack .workdir.bottom.buttons.funcs -side left -expand yes -anchor w
#  pack .workdir.bottom.buttons.dirfuncs -side left -expand yes -anchor w
#  pack .workdir.bottom.buttons.cvsfuncs -side left -expand yes -anchor w
#  pack .workdir.bottom.buttons.oddfuncs -side left -expand yes -anchor w
#  
#  #
#  # Action buttons along the bottom of the screen.
#  #
#  button .workdir.bottom.buttons.funcs.bedit_files -image Fileedit \
#      -command { workdir_edit_file [workdir_list_files] }
#  button .workdir.bottom.buttons.funcs.bview_files -image Fileview \
#      -command { workdir_view_file [workdir_list_files] }
#  button .workdir.bottom.buttons.funcs.bdelete_file -image Delete \
#      -command { workdir_delete_file [workdir_list_files] }
#  button .workdir.bottom.buttons.funcs.bmkdir -image Dir_new \
#      -command { file_input_and_do "New Directory" workdir_newdir}
#  
#  button .workdir.bottom.buttons.dirfuncs.brefresh -image Refresh \
#      -command { setup_dir }
#  button .workdir.bottom.buttons.dirfuncs.bcheckdir -image Check \
#      -command { cvs_check }
#  button .workdir.bottom.buttons.dirfuncs.patchdiff -image Patches
#  button .workdir.bottom.buttons.cvsfuncs.blogfile -image Branches \
#      -command { cvs_branches [workdir_list_files] }
#  button .workdir.bottom.buttons.cvsfuncs.bannotate -image Annotate \
#      -command { cvs_annotate $current_tagname [workdir_list_files] }
#  button .workdir.bottom.buttons.cvsfuncs.bfilelog -image Log \
#      -command { cvs_log verbose [workdir_list_files] }
#  button .workdir.bottom.buttons.cvsfuncs.bdiff -image Diff \
#      -command { comparediff [workdir_list_files] }
#  button .workdir.bottom.buttons.cvsfuncs.bconflict -image Conflict \
#      -command { cvs_reconcile_conflict [workdir_list_files] }
#  button .workdir.bottom.buttons.cvsfuncs.btag -image Tag \
#      -command { tag_dialog }
#  button .workdir.bottom.buttons.cvsfuncs.bbranchtag -image Branchtag \
#      -command { branch_dialog }
#  button .workdir.bottom.buttons.cvsfuncs.badd_files -image Add \
#      -command { add_dialog [workdir_list_files] }
#  button .workdir.bottom.buttons.cvsfuncs.bremove -image Remove \
#      -command { subtract_dialog [workdir_list_files] }
#  button .workdir.bottom.buttons.cvsfuncs.bcheckin -image Checkin \
#      -command cvs_commit_dialog
#  button .workdir.bottom.buttons.cvsfuncs.bupdate -image Checkout
#  button .workdir.bottom.buttons.cvsfuncs.bupdateopts -image CheckoutOpts \
#      -command { cvs_update_options }
#  button .workdir.bottom.buttons.cvsfuncs.brevert -image Revert \
#      -command { cvs_revert [workdir_list_files] }
#  button .workdir.bottom.buttons.cvsfuncs.bjoin -image DirBranches \
#      -image DirBranches -command cvs_joincanvas
#  
#  button .workdir.bottom.buttons.oddfuncs.bcvsedit_files -image Edit \
#      -command { edit_dialog [workdir_list_files] }
#  button .workdir.bottom.buttons.oddfuncs.bunedit_files -image Unedit \
#      -command { unedit_dialog [workdir_list_files] }
#  button .workdir.bottom.buttons.oddfuncs.block -image Lock
#  button .workdir.bottom.buttons.oddfuncs.bunlock -image UnLock
#  button .workdir.bottom.buttons.oddfuncs.bpush -image Checkin \
#      -command { git_push }
#  button .workdir.bottom.buttons.oddfuncs.bfetch -image Checkout \
#      -command { git_fetch }
#  button .workdir.close -text "Close" \
#      -command {
#    global cvscfg
#    set cvscfg(workgeom) [wm geometry .workdir]
#    destroy .workdir
#    exit_cleanup 0
#  }
#  
#  # These buttons work in any directory
#  grid .workdir.bottom.buttons.funcs.bdelete_file     -column 0 -row 0 -ipadx 4
#  grid .workdir.bottom.buttons.funcs.bedit_files      -column 1 -row 0 -ipadx 4
#  grid .workdir.bottom.buttons.funcs.bmkdir           -column 0 -row 1 -ipadx 4
#  grid .workdir.bottom.buttons.funcs.bview_files      -column 1 -row 1 -ipadx 4
#  
#  # Directory functions
#  grid rowconf .workdir.bottom.buttons.dirfuncs 0 -weight 1
#  grid .workdir.bottom.buttons.dirfuncs.brefresh      -column 0 -row 0 -ipadx 4 -ipady 4
#  grid .workdir.bottom.buttons.dirfuncs.bcheckdir     -column 1 -row 0 -ipadx 4 -ipady 4
#  grid .workdir.bottom.buttons.dirfuncs.patchdiff         -column 2 -row 0 -ipadx 4 -ipady 4
#  
#  # Revcontrol functions
#  grid .workdir.bottom.buttons.cvsfuncs.blogfile      -column 0 -row 0 -ipadx 4
#  grid .workdir.bottom.buttons.cvsfuncs.bjoin         -column 0 -row 1 -ipadx 4
#  grid .workdir.bottom.buttons.cvsfuncs.bdiff         -column 1 -row 0 -ipadx 2
#  grid .workdir.bottom.buttons.cvsfuncs.bconflict     -column 1 -row 1 -ipadx 2
#  grid .workdir.bottom.buttons.cvsfuncs.bfilelog      -column 2 -row 0
#  grid .workdir.bottom.buttons.cvsfuncs.bannotate     -column 2 -row 1
#  grid .workdir.bottom.buttons.cvsfuncs.bupdate       -column 3 -row 0 -ipadx 4
#  grid .workdir.bottom.buttons.cvsfuncs.bcheckin      -column 3 -row 1 -ipadx 4
#  grid .workdir.bottom.buttons.cvsfuncs.bupdateopts   -column 4 -row 0 -ipadx 4
#  grid .workdir.bottom.buttons.cvsfuncs.brevert       -column 4 -row 1 -ipadx 4
#  grid .workdir.bottom.buttons.cvsfuncs.badd_files    -column 5 -row 0
#  grid .workdir.bottom.buttons.cvsfuncs.bremove       -column 5 -row 1
#  grid .workdir.bottom.buttons.cvsfuncs.btag          -column 6 -row 0 -ipadx 4
#  grid .workdir.bottom.buttons.cvsfuncs.bbranchtag    -column 6 -row 1 -ipadx 4
#  grid .workdir.bottom.buttons.oddfuncs.block          -column 0 -row 0
#  grid .workdir.bottom.buttons.oddfuncs.bunlock        -column 0 -row 1
#  grid .workdir.bottom.buttons.oddfuncs.bcvsedit_files -column 1 -row 0
#  grid .workdir.bottom.buttons.oddfuncs.bunedit_files  -column 1 -row 1
#  
#  pack .workdir.close -in .workdir.bottom.buttons.closefm \
#      -side right -fill both -expand yes
#  
#  set_tooltips .workdir.top.updir_btn \
#      {"Go up (..)"}
#  set_tooltips .workdir.bottom.buttons.funcs.bedit_files \
#      {"Edit the selected files"}
#  set_tooltips .workdir.bottom.buttons.funcs.bview_files \
#      {"View the selected files"}
#  set_tooltips .workdir.bottom.buttons.funcs.bdelete_file \
#      {"Delete the selected files from the current directory"}
#  set_tooltips .workdir.bottom.buttons.funcs.bmkdir \
#      {"Make a new directory"}
#  
#  set_tooltips .workdir.bottom.buttons.dirfuncs.brefresh \
#      {"Re-read the current directory"}
#  set_tooltips .workdir.bottom.buttons.cvsfuncs.bjoin \
#      {"Directory Branch Diagram and Merge Tool"}
#  set_tooltips .workdir.bottom.buttons.dirfuncs.bcheckdir \
#      {"Check the status of the directory"}
#  set_tooltips .workdir.bottom.buttons.dirfuncs.patchdiff \
#      {"Show diffs in the changed files"}
#  
#  set_tooltips .workdir.bottom.buttons.cvsfuncs.blogfile \
#      {"Graphical Branch Diagram of the selected files"}
#  set_tooltips .workdir.bottom.buttons.cvsfuncs.bfilelog \
#      {"Revision log of the selected files"}
#  set_tooltips .workdir.bottom.buttons.cvsfuncs.bannotate \
#      {"Revision where each line was modified (annotate/blame)"}
#  set_tooltips .workdir.bottom.buttons.cvsfuncs.bdiff \
#      {"Side-by-side comparison of files to the committed version"}
#  set_tooltips .workdir.bottom.buttons.cvsfuncs.bconflict \
#      {"Merge Conflicts using TkDiff"}
#  
#  set_tooltips .workdir.bottom.buttons.cvsfuncs.btag \
#      {"Tag the selected files"}
#  set_tooltips .workdir.bottom.buttons.cvsfuncs.bbranchtag \
#      {"Branch the selected files"}
#  set_tooltips .workdir.bottom.buttons.cvsfuncs.bupdateopts \
#      {"Update with options (-A, -r, -f, -d, -kb)"}
#  
#  set_tooltips .workdir.bottom.buttons.oddfuncs.block \
#      {"Lock the selected files"}
#  set_tooltips .workdir.bottom.buttons.oddfuncs.bunlock \
#      {"Unlock the selected files"}
#  set_tooltips .workdir.bottom.buttons.oddfuncs.bcvsedit_files \
#      {"Set the Edit flag on the selected files"}
#  set_tooltips .workdir.bottom.buttons.oddfuncs.bunedit_files \
#      {"Unset the Edit flag on the selected files"}
#  set_tooltips .workdir.bottom.buttons.oddfuncs.bpush \
#      {"Push to origin"}
#  set_tooltips .workdir.bottom.buttons.oddfuncs.bfetch \
#      {"Fetch from origin"}
#  
#  set_tooltips .workdir.top.bmodbrowse \
#      {"Open the Repository Browser"}
#  set_tooltips .workdir.close \
#      {"Close the Working Directory Browser"}
#  
#  
#  frame .workdir.main
#  pack .workdir.main -side bottom -fill both -expand 1 -fill both
#  update idletasks
#  
  if {! [winfo ismapped .workdir]} {
    wm deiconify .workdir
  }
  
#  #change_dir "[pwd]"
  setup_dir
  #gen_log:log T "LEAVE"
}

# Returns a list of the selected file names. This is where the arg-list comes
# from for most of the UI buttons and menus.
proc workdir_list_files {} {
  global DirList
  global cvsglb
  
  set wt .workdir.main.tree
  set cvsglb(current_selection) {}
  set DirList($wt:selection) {}
  set selected_items [$wt selection]
  foreach s $selected_items {
    set f [$wt set $s filecol]
    lappend DirList($wt:selection) "$f"
  }
  set cvsglb(current_selection) $DirList($wt:selection)
  
  #gen_log:log T "LEAVE -- ($cvsglb(current_selection))"
  return $cvsglb(current_selection)
}

proc workdir_edit_command {file} {
  global cvscfg
  
  #gen_log:log T "ENTER ($file)"
  if {[info exists cvscfg(editors)]} {
    foreach {editor pattern} $cvscfg(editors) {
      if {[string match $pattern $file]} {
        return "$editor \"$file\""
      }
    }
  }
  return "$cvscfg(editor) \"$file\""
}

proc workdir_newdir {file} {
  global cvscfg
  
  #gen_log:log T "ENTER ($file)"
  
  file mkdir $file
  
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  #gen_log:log T "LEAVE"
}

proc workdir_edit_file {args} {
  global cvscfg
  global cwd
  
  #gen_log:log T "ENTER ($args)"
  
  set filelist [join $args]
  if {$filelist == ""} {
    file_input_and_do "Edit File" workdir_edit_file
    return
  }
  
  #gen_log:log D "$filelist"
  foreach file $filelist {
    if {[file isdirectory $file]} {
      change_dir "$file"
      return
    }
    if {![file exists $file]} {
      cvsfail "$file does not exist" .workdir
      return
    }
    if {![file isfile $file]} {
      cvsfail "$file is not a plain file" .workdir
      return
    }
    regsub -all {\$} $file {\$} file
    set commandline [workdir_edit_command $file]
    set editcmd [exec::new $commandline]
  }
  #gen_log:log T "LEAVE"
}

proc workdir_view_file {args} {
  global cvscfg
  global cwd
  
  #gen_log:log T "ENTER ($args)"
  
  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select some files to view first!" .workdir
    return
  }
  
  #gen_log:log D "$filelist"
  foreach file $filelist {
    set filelog ""
    if {![file exists $file]} {
      cvsfail "$file does not exist" .workdir
      return
    }
    if {![file isfile $file]} {
      cvsfail "$file is not a plain file" .workdir
      return
    }
    #regsub -all {\$} $file {\$} file
    #gen_log:log F "OPEN $file"
    set f [open $file]
    while { [eof $f] == 0 } {
      append filelog [gets $f]
      append filelog "\n"
    }
    view_output::new "$file" $filelog
  }
  #gen_log:log T "LEAVE"
}

# Let the user mark directories they visit often
proc add_bookmark { } {
  global incvs inrcs insvn ingit
  global bookmarks
  
  #gen_log:log T "ENTER"
  set dir [pwd]
  regsub -all {\$} $dir {\$} dir
  
  #gen_log:log D "directory $dir"
  foreach mark [array names bookmarks] {
    #gen_log:log D "  $mark \"$bookmarks($mark)\""
  }
  
  if {[info exists bookmarks($dir)]} {
    .workdir.menubar.goto delete "$dir $bookmarks($dir)"
  }
  set rtype ""
  if {$inrcs} {
    set rtype "(RCS)"
  } elseif {$incvs} {
    set rtype "(CVS)"
  } elseif {$insvn} {
    set rtype "(SVN)"
  } elseif {$ingit} {
    set rtype "(GIT)"
  }
  set bookmarks($dir) $rtype
  .workdir.menubar.goto add command -label "$dir $rtype" \
      -command "change_dir \"$dir\""
  
  #gen_log:log T "LEAVE"
}

# A listbox to choose a bookmark to delete
proc delete_bookmark_dialog { } {
  global cvscfg
  global cvsglb
  global bookmarks
  
  #gen_log:log T "ENTER"
  set maxlbl 0
  foreach mark [array names bookmarks] {
    #gen_log:log D "  $mark $bookmarks($mark)"
    set len [string length "$mark $bookmarks($mark)"]
    if {$len > $maxlbl} {
      set maxlbl $len
    }
  }
  
  set wname .workdir.bookmarkedit
  toplevel $wname
  grab set $wname
  wm title $wname "Delete Bookmarks"
  listbox $wname.lbx -selectmode multiple \
      -font $cvscfg(listboxfont) -width $maxlbl
  pack $wname.lbx -ipadx 10 -ipady 10 -expand y -fill both
  foreach mark [lsort [array names bookmarks]] {
    $wname.lbx insert end "$mark $bookmarks($mark)"
  }
  frame $wname.buttons
  pack $wname.buttons -side top -fill x
  button $wname.delete -text "Delete" \
      -command "delete_bookmark $wname"
  
  button $wname.close -text "Done" \
     -command "
       grab release $wname
       destroy $wname
  exit_cleanup 0"
  pack $wname.delete $wname.close -in $wname.buttons \
      -side right -ipadx 2 -ipady 2 -padx 4 -pady 4 \
      -expand y
  
  #gen_log:log T "LEAVE"
}

# Do the actual deletion of the bookmark
proc delete_bookmark {w} {
  global bookmarks
  
  #gen_log:log T "ENTER ($w)"
  set items [$w.lbx curselection]
  foreach item $items {
    set itemstring [$w.lbx get $item]
    #set dir [join [lrange $itemstring 0 end-1]]
    regsub {\s+$} $itemstring {} dir
    regsub {\s+\([A-Z][A-Z][A-Z]\)$} $dir {} dir
    #gen_log:log D "$item \"$itemstring\""
    #gen_log:log D "  directory \"$dir\""
    unset bookmarks($dir)
    $w.lbx delete $item
    .workdir.menubar.goto delete $itemstring
  }
  #gen_log:log T "LEAVE"
}

proc change_dir {new_dir} {
  global cwd
  
  #gen_log:log T "ENTER ($new_dir)"
  if {![file isdirectory $new_dir]} {
    cvsfail "Directory $new_dir doesn\'t exist or isn't a directory" .workdir
    return
  }
  cd $new_dir
  set cwd $new_dir
  #gen_log:log F "CD $cwd"
  # Deleting the tree discards the saved scroll position
  # so we start with yview 0 in a new directory
  if {[winfo exists .workdir]} {
    DirCanvas:deltree .workdir.main.tree
    setup_dir
  }
  if {[winfo exists .modbrowse]} {
    cvsroot_check $cwd
    modbrowse_run
  }
  
  #gen_log:log T "LEAVE"
}

proc auto_setup_dir {command} {
  global cvscfg
  
  if {$cvscfg(auto_status)} {
    $command\::wait
    setup_dir
  } else {
    after 0 "$command\::wait; $command\::destroy"
  }
}

#proc setup_dir { } {
#  #
#  # Call this when entering a directory.  It puts all of the file names
#  # in the listbox, and reads the directory.
#  #
#  global cwd
#  global module_dir
#  global incvs insvn inrcs ingit
#  global cvscfg
#  global cvsglb
#  global current_tagname
#  
#  #gen_log:log T "ENTER"
#  
#  set savyview 0
#  if { ! [exists dot_workdir] } {
#    workdir_setup
#    return
#  } else {
#    if {[exists dot_workdir]} {
#      set savyview [lindex [.workdir.main.filecol.list yview] 0]
#    }
##    DirCanvas:deltree .workdir.main.tree
#  }
#  
#  set module_dir ""
#  set current_tagname ""
#  set cvsglb(vcs_hidden_files) {}
#  
#  lassign [cvsroot_check [pwd]] incvs insvn inrcs ingit
##  #gen_log:log D "incvs=$incvs inrcs=$inrcs insvn=$insvn ingit=$ingit"
#  
##  .workdir.top.bmodbrowse configure -image Modules
##  .workdir.top.lmodule configure -text "Path"
##  .workdir.top.ltagname configure -text "Branch/Tag"
##  .workdir.top.lcvsroot configure -text "Repository"
##  .workdir.top.tcvsroot configure -textvariable cvscfg(cvsroot)
#  set cvsglb(root) $cvscfg(cvsroot)
#  set cvsglb(vcs) cvs
#  
#  # Start without revision-control menu
#  #gen_log:log D "CONFIGURE VCS MENUS"
##  foreach label {"RCS" "CVS" "SVN" "GIT" "Git Tools"} {
##    if {! [catch {set vcsmenu_idx [.workdir.menubar index "$label"]}]} {
##      .workdir.menubar delete $vcsmenu_idx
##    }
##  }
##  set filemenu_idx [.workdir.menubar index "File"]
#  
##  # Disable report menu items
##  .workdir.menubar.reports entryconfigure "Check Directory" -state disabled
##  .workdir.menubar.reports entryconfigure "Status" -state disabled
##  .workdir.menubar.reports entryconfigure "Log" -state disabled
##  .workdir.menubar.reports entryconfigure "Info" -state disabled
##  # Start with the revision-control buttons disabled
##  .workdir.bottom.filters.vcshidelbl configure -text "hidden by vcs"
##  .workdir.bottom.buttons.dirfuncs.bcheckdir configure -state disabled
##  .workdir.bottom.buttons.dirfuncs.patchdiff configure -state disabled
##  foreach widget [grid slaves .workdir.bottom.buttons.cvsfuncs ] {
##    $widget configure -state disabled
##  }
##  foreach widget [grid slaves .workdir.bottom.buttons.cvsfuncs ] {
##    $widget configure -state disabled
##  }
##  foreach widget [grid slaves .workdir.bottom.buttons.oddfuncs ] {
##    #$widget configure -state disabled
##    grid forget $widget
##  }
##  
##  # Default for these, only Git is different
##  .workdir.bottom.buttons.cvsfuncs.bcheckin configure -state disabled \
##      -image Checkin
##  .workdir.bottom.buttons.cvsfuncs.bupdate configure -state disabled \
##      -image Checkout
##  set_tooltips .workdir.bottom.buttons.cvsfuncs.bjoin \
##      {"Directory Branch Diagram and Merge Tool"}
##  set_tooltips .workdir.bottom.buttons.cvsfuncs.badd_files \
##      {"Add the selected files to the repository"}
##  set_tooltips .workdir.bottom.buttons.cvsfuncs.bremove \
##      {"Remove the selected files from the repository"}
##  set_tooltips .workdir.bottom.buttons.cvsfuncs.bcheckin \
##      {"Check in (commit) the selected files to the repository"}
##  set_tooltips .workdir.bottom.buttons.cvsfuncs.bupdate \
##      {"Update (checkout, patch) the selected files from the repository"}
##  set_tooltips .workdir.bottom.buttons.cvsfuncs.brevert \
##      {"Revert the selected files, discarding local edits"}
#  
#  # Now enable them depending on where we are
#  if {$inrcs} {
#    # Top
##    #gen_log:log D "CONFIGURE RCS MENUS"
##    .workdir.menubar insert [expr {$filemenu_idx + 1}] cascade -label "RCS" \
##        -menu .workdir.menubar.rcs
##    .workdir.top.lcvsroot configure -text "RCS *,v Path"
##    .workdir.top.tcvsroot configure -textvariable cvscfg(rcsdir)
##    set cvsglb(root) $cvscfg(rcsdir)
##    set cvsglb(vcs) rcs
##    # Buttons
##    .workdir.bottom.buttons.funcs.bview_files configure \
##        -command { workdir_view_file [workdir_list_files] }
##    .workdir.bottom.buttons.dirfuncs.bcheckdir configure -state normal \
##        -command { rcs_check }
##    .workdir.bottom.buttons.cvsfuncs.bdiff configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.blogfile configure -state normal \
##        -command { rcs_branches [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bfilelog configure -state normal \
##        -command { rcs_log "verbose" [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bupdate configure -state normal \
##        -command { rcs_checkout [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bcheckin configure -state normal \
##        -command { rcs_commit_dialog [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.brevert configure -state normal \
##        -command { rcs_revert [workdir_list_files] }
##    grid .workdir.bottom.buttons.oddfuncs.block          -column 0 -row 0
##    grid .workdir.bottom.buttons.oddfuncs.bunlock        -column 0 -row 1
##    .workdir.bottom.buttons.oddfuncs.block configure -state normal \
##        -command { rcs_lock lock [workdir_list_files] }
##    .workdir.bottom.buttons.oddfuncs.bunlock configure -state normal \
##        -command { rcs_lock unlock [workdir_list_files] }
##    # Reports menu for RCS
##    # Check Directory (log & rdiff)
##    .workdir.menubar.reports entryconfigure "Check Directory" -state normal \
##        -command { rcs_check }
##    .workdir.menubar.reports entryconfigure "Status" -state disabled
##    # Log (rlog)
##    .workdir.menubar.reports entryconfigure "Log" -state normal
##    .workdir.menubar.reports.log_detail entryconfigure "Latest" \
##        -command { rcs_log "latest" [workdir_list_files] }
##    .workdir.menubar.reports.log_detail entryconfigure "Summary" \
##        -command { rcs_log "summary" [workdir_list_files] }
##    .workdir.menubar.reports.log_detail entryconfigure "Verbose" \
##        -command { rcs_log "verbose" [workdir_list_files] }
##    
##    .workdir.menubar.reports entryconfigure "Info" -state disabled
##    # Options for reports
##    .workdir.menubar.reports entryconfigure "Report Unknown Files" -state disabled
##    .workdir.menubar.reports entryconfigure "Report Recursively" -state disabled
##  } 
#	elseif {$insvn} {
#}
#    # Top
##    #gen_log:log D "CONFIGURE SVN MENUS"
##    .workdir.menubar insert [expr {$filemenu_idx + 1}] cascade -label "SVN" \
##        -menu .workdir.menubar.svn
##    .workdir.top.bmodbrowse configure -image Modules_svn -command modbrowse_run
##    .workdir.top.lmodule configure -text "Path"
##    .workdir.top.ltagname configure -text "Tag"
##    .workdir.top.lcvsroot configure -text "SVN URL"
##    .workdir.top.tcvsroot configure -textvariable cvscfg(url)
##    set cvsglb(root) $cvscfg(url)
##    set cvsglb(vcs) svn
##    # Buttons
##    .workdir.bottom.buttons.funcs.bview_files configure \
##        -command { workdir_view_file [workdir_list_files] }
##    .workdir.bottom.buttons.dirfuncs.bcheckdir configure -state normal \
##        -command { svn_check }
##    .workdir.bottom.buttons.dirfuncs.patchdiff configure -state normal \
##        -command { svn_patch $cvscfg(url) {} {} {} {} {} 0 {} }
##    .workdir.bottom.buttons.cvsfuncs.bjoin configure -state normal \
##        -image DirBranches -command { svn_branches . }
##    .workdir.bottom.buttons.cvsfuncs.bdiff configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.blogfile configure -state normal \
##        -command { svn_branches [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bfilelog configure -state normal \
##        -command { svn_log "verbose" [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bannotate configure -state normal \
##        -command { svn_annotate rBASE [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bconflict configure -state normal \
##        -command { foreach f [workdir_list_files] {svn_reconcile_conflict \"$f\"} }
##    .workdir.bottom.buttons.cvsfuncs.badd_files configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.bremove configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.bupdate configure -state normal \
##        -command { svn_update [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bupdateopts configure -state normal \
##        -command { svn_update_options }
##    .workdir.bottom.buttons.cvsfuncs.bcheckin configure -state normal \
##        -command svn_commit_dialog
##    .workdir.bottom.buttons.cvsfuncs.brevert configure -state normal \
##        -command { svn_revert [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.btag configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.bbranchtag configure -state normal
##    grid .workdir.bottom.buttons.oddfuncs.block          -column 0 -row 0
##    grid .workdir.bottom.buttons.oddfuncs.bunlock        -column 0 -row 1
##    .workdir.bottom.buttons.oddfuncs.block configure -state normal \
##        -command { svn_lock lock [workdir_list_files] }
##    .workdir.bottom.buttons.oddfuncs.bunlock configure -state normal \
##        -command { svn_lock unlock [workdir_list_files] }
##    # Reports menu for SVN
##    # Check Directory (svn status)
##    .workdir.menubar.reports entryconfigure "Check Directory" -state normal \
##        -command { svn_check }
##    # Status (svn status <filelist>)
##    .workdir.menubar.reports entryconfigure "Status" -state normal
##    .workdir.menubar.reports.status_detail entryconfigure "Terse" \
##        -command { svn_status "terse" [workdir_list_files] }
##    .workdir.menubar.reports.status_detail entryconfigure "Summary" \
##        -command { svn_status "summary" [workdir_list_files] }
##    .workdir.menubar.reports.status_detail entryconfigure "Verbose" \
##        -command { svn_status "verbose" [workdir_list_files] }
##    # Log (svn log)
##    .workdir.menubar.reports entryconfigure "Log" -state normal
##    .workdir.menubar.reports.log_detail entryconfigure "Latest" \
##        -command { svn_log "latest" [workdir_list_files] }
##    .workdir.menubar.reports.log_detail entryconfigure "Summary" \
##        -command { svn_log "summary" [workdir_list_files] }
##    .workdir.menubar.reports.log_detail entryconfigure "Verbose" \
##        -command { svn_log "verbose" [workdir_list_files] }
##    # General info (svn info)
##    .workdir.menubar.reports entryconfigure "Info" -state normal \
##        -command { svn_info [workdir_list_files] }
##    # Options for reports
##    .workdir.menubar.reports entryconfigure "Report Unknown Files" -state normal
##    .workdir.menubar.reports entryconfigure "Report Recursively" -state normal
##  } 
#	elseif {$incvs} {
#    # Top
##    #gen_log:log D "CONFIGURE CVS MENUS"
##    .workdir.menubar insert [expr {$filemenu_idx + 1}] cascade -label "CVS" \
##        -menu .workdir.menubar.cvs
##    .workdir.top.bmodbrowse configure -image Modules_cvs -command modbrowse_run
##    .workdir.top.lmodule configure -text "Module"
##    .workdir.top.ltagname configure -text "Tag"
##    .workdir.top.lcvsroot configure -text "CVSROOT"
##    .workdir.top.tcvsroot configure -textvariable cvscfg(cvsroot)
##    set cvsglb(root) $cvscfg(cvsroot)
#    set cvsglb(vcs) cvs
#    # Buttons
##    .workdir.bottom.buttons.funcs.bview_files configure \
##        -command { workdir_view_file [workdir_list_files] }
##    .workdir.bottom.buttons.dirfuncs.bcheckdir configure -state normal \
##        -command { cvs_check }
##    .workdir.bottom.buttons.dirfuncs.patchdiff configure -state normal \
##        -command { cvs_patch $cvscfg(cvsroot) $module_dir -u {} {} {} {} 0 {} }
##    .workdir.bottom.buttons.cvsfuncs.bjoin configure -state normal \
##        -image DirBranches -command cvs_joincanvas
##    .workdir.bottom.buttons.cvsfuncs.bdiff configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.bconflict configure -state normal \
##        -command { cvs_reconcile_conflict [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bfilelog configure -state normal \
##        -command { cvs_log "verbose" [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bannotate configure -state normal \
##        -command { cvs_annotate $current_tagname [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.badd_files configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.bremove configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.bupdate configure -state normal \
##        -command { \
##        cvs_update {BASE} {Normal} {Remove} {recurse} {prune} {No} { } [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bupdateopts configure -state normal \
##        -command { cvs_update_options }
##    .workdir.bottom.buttons.cvsfuncs.bcheckin configure -state normal \
##        -command cvs_commit_dialog
##    .workdir.bottom.buttons.cvsfuncs.brevert configure -state normal \
##        -command {cvs_revert [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.btag configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.bbranchtag configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.blogfile configure -state normal \
##        -command { cvs_branches [workdir_list_files] }
##    grid .workdir.bottom.buttons.oddfuncs.block          -column 0 -row 0
##    grid .workdir.bottom.buttons.oddfuncs.bunlock        -column 0 -row 1
##    grid .workdir.bottom.buttons.oddfuncs.bcvsedit_files -column 1 -row 0
##    grid .workdir.bottom.buttons.oddfuncs.bunedit_files  -column 1 -row 1
#    if {$cvscfg(econtrol)} {
##      .workdir.bottom.buttons.oddfuncs.bcvsedit_files configure -state normal
##      .workdir.bottom.buttons.oddfuncs.bunedit_files configure -state normal
#    } else {
##      .workdir.bottom.buttons.oddfuncs.bcvsedit_files configure -state disabled
##      .workdir.bottom.buttons.oddfuncs.bunedit_files configure -state disabled
#    }
#    if {$cvscfg(cvslock)} {
##      .workdir.bottom.buttons.oddfuncs.block configure -state normal \
##          -command { cvs_lock lock [workdir_list_files] }
##      .workdir.bottom.buttons.oddfuncs.bunlock configure -state normal \
##          -command { cvs_lock unlock [workdir_list_files] }
#    } else {
##      .workdir.bottom.buttons.oddfuncs.block configure -state disabled
##      .workdir.bottom.buttons.oddfuncs.bunlock configure -state disabled
#    }
#    # Reports menu for CVS
#    # Check Directory (cvs -n -q update)
##    .workdir.menubar.reports entryconfigure "Check Directory" -state normal \
##        -command { cvs_check }
##    # Status (cvs -Q status)
##    .workdir.menubar.reports entryconfigure "Status" -state normal
##    .workdir.menubar.reports.status_detail entryconfigure "Terse" \
##        -command { cvs_status "terse" [workdir_list_files] }
##    .workdir.menubar.reports.status_detail entryconfigure "Summary" \
##        -command { cvs_status "summary" [workdir_list_files] }
##    .workdir.menubar.reports.status_detail entryconfigure "Verbose" \
##        -command { cvs_status "verbose" [workdir_list_files] }
##    # Log (cvs log)
##    .workdir.menubar.reports entryconfigure "Log" -state normal
##    .workdir.menubar.reports.log_detail entryconfigure "Latest" \
##        -command { cvs_log "latest" [workdir_list_files] }
##    .workdir.menubar.reports.log_detail entryconfigure "Summary" \
##        -command { cvs_log "summary" [workdir_list_files] }
##    .workdir.menubar.reports.log_detail entryconfigure "Verbose" \
##        -command { cvs_log "verbose" [workdir_list_files] }
##    .workdir.menubar.reports entryconfigure "Info" -state disabled
##    # Options for reports
##    .workdir.menubar.reports entryconfigure "Report Unknown Files" -state normal
##    .workdir.menubar.reports entryconfigure "Report Recursively" -state normal
##  } elseif {$ingit} {
#    # Top
#    #gen_log:log D "CONFIGURE GIT MENUS"
##    .workdir.menubar insert [expr {$filemenu_idx + 1}] cascade -label "GIT" \
##        -menu .workdir.menubar.git
##    .workdir.menubar insert [expr {$filemenu_idx + 4}] cascade -label "Git Tools" \
##        -menu .workdir.menubar.gittools
##    .workdir.top.bmodbrowse configure -image Modules_git -command modbrowse_run
##    .workdir.top.lmodule configure -text "path"
##    .workdir.top.ltagname configure -text "branch"
##    .workdir.top.lcvsroot configure -text "$cvscfg(origin)"
##    .workdir.top.tcvsroot configure -textvariable cvscfg(url)
#    set cvsglb(root) $cvscfg(url)
#    set cvsglb(vcs) git
#    # Buttons
##    .workdir.bottom.buttons.funcs.bview_files configure \
##        -command { git_fileview HEAD {.} [workdir_list_files] }
##    .workdir.bottom.buttons.dirfuncs.bcheckdir configure -state normal \
##        -command { git_check }
##    .workdir.bottom.buttons.dirfuncs.patchdiff configure -state normal \
##        -command { git_patch "" }
##    .workdir.bottom.buttons.cvsfuncs.bdiff configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.bconflict configure -state normal \
##        -command { foreach f [workdir_list_files] {git_reconcile_conflict \"$f\"} }
##    .workdir.bottom.buttons.cvsfuncs.blogfile configure -state normal \
##        -command { git_branches [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bjoin configure -state normal \
##        -image BranchNo -command { git_fast_diagram [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bfilelog configure -state normal \
##        -command { git_log "verbose" [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bannotate configure -state normal \
##        -command { git_annotate $current_tagname [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bcheckin configure -state normal \
##        -image GitCheckin -command { git_commit_dialog }
##    .workdir.bottom.buttons.cvsfuncs.brevert configure -state normal \
##        -command { git_reset [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bupdate configure -state normal \
##        -image GitCheckout -command { git_checkout [workdir_list_files] }
##    .workdir.bottom.buttons.cvsfuncs.bupdateopts configure -state normal \
##        -command { git_update_options }
##    .workdir.bottom.buttons.cvsfuncs.badd_files configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.bremove configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.btag configure -state normal
##    .workdir.bottom.buttons.cvsfuncs.bbranchtag configure -state normal
##    grid .workdir.bottom.buttons.oddfuncs.bpush  -column 0 -row 0
##    grid .workdir.bottom.buttons.oddfuncs.bfetch  -column 0 -row 1
##    .workdir.bottom.buttons.oddfuncs.block configure -state normal \
##        -command { rcs_lock lock [workdir_list_files] }
##    .workdir.bottom.buttons.oddfuncs.bunlock configure -state normal \
##        -command { rcs_lock unlock [workdir_list_files] }
##    set_tooltips .workdir.bottom.buttons.cvsfuncs.bjoin \
##        {"Fast log diagram"}
##    set_tooltips .workdir.bottom.buttons.cvsfuncs.badd_files \
##        {"Add the selected files to the staging area"}
##    set_tooltips .workdir.bottom.buttons.cvsfuncs.bremove \
##        {"Remove the selected files from the staging area"}
##    set_tooltips .workdir.bottom.buttons.cvsfuncs.bcheckin \
##        {"Check in (commit) the selected files to the staging area"}
##    set_tooltips .workdir.bottom.buttons.cvsfuncs.bupdate \
##        {"Update (checkout, patch) the selected files from the staging area"}
##    set_tooltips .workdir.bottom.buttons.cvsfuncs.brevert \
##        {"Reset, discarding local edits"}
##    # Reports menu for GIT
##    # Check Directory (git status --short)
##    .workdir.menubar.reports entryconfigure "Check Directory" -state normal \
##        -command { git_check }
##    # Status (git status -v)
##    .workdir.menubar.reports entryconfigure "Status" -state normal
##    .workdir.menubar.reports.status_detail entryconfigure "Terse" \
##        -command { git_status "terse" [workdir_list_files] }
##    .workdir.menubar.reports.status_detail entryconfigure "Summary" \
##        -command { git_status "summary" [workdir_list_files] }
##    .workdir.menubar.reports.status_detail entryconfigure "Verbose" \
##        -command { git_status "verbose" [workdir_list_files] }
##    # Log (git log)
##    .workdir.menubar.reports entryconfigure "Log" -state normal
##    .workdir.menubar.reports.log_detail entryconfigure "Latest" \
##        -command { git_log "latest" [workdir_list_files] }
##    .workdir.menubar.reports.log_detail entryconfigure "Summary" \
##        -command { git_log "summary" [workdir_list_files] }
##    .workdir.menubar.reports.log_detail entryconfigure "Verbose" \
##        -command { git_log "verbose" [workdir_list_files] }
##    .workdir.menubar.reports entryconfigure "Info" -state disabled
##    # Options for reports
##    .workdir.menubar.reports entryconfigure "Report Unknown Files" -state normal
##    .workdir.menubar.reports entryconfigure "Report Recursively" -state disabled
#  }
#  
#  picklist_used directory "[pwd]"
#  # Have to do this to display the new value in the list
##  .workdir.top.tcwd configure -values $cvsglb(directory)
##  
##  DirCanvas:create .workdir.main
##  pack .workdir.main.pw -side bottom -fill both -expand yes
#  
#  set cvsglb(current_selection) {}
#  
#  # Check for VCS-specific ignore filters
#  if {$incvs} {
##    .workdir.bottom.filters.vcshidelbl configure -text " .cvsignore"
#    if { [ file exists ".cvsignore" ] } {
#      set fileId [ open ".cvsignore" "r" ]
#      while { [ eof $fileId ] == 0 } {
#        gets $fileId line
#        append cvsglb(vcs_hidden_files) " $line"
#      }
#      close $fileId
#    }
#  } elseif {$insvn} {
#    .workdir.bottom.filters.vcshidelbl configure -text " svn:ignore"
#    # Have to do eval exec because we need the error output
#    set command "svn propget svn:ignore ."
#    #gen_log:log C "$command"
#    set ret [catch {exec {*}$command} output]
#    if {$ret} {
#      #gen_log:log E "$output"
#    } else {
#      #gen_log:log F "$output"
#      foreach infoline [split $output "\n"] {
#        append cvsglb(vcs_hidden_files) " $infoline"
#      }
#    }
#  } elseif {$ingit} {
#    .workdir.bottom.filters.vcshidelbl configure -text " .gitignore"
#    if { [ file exists ".gitignore" ] } {
#      set fileId [ open ".gitignore" "r" ]
#      while { [ eof $fileId ] == 0 } {
#        gets $fileId line
#        append cvsglb(vcs_hidden_files) " $line"
#      }
#      close $fileId
#    }
#  }
#  set filelist [ getFiles ]
#  directory_list $filelist
#  # Update, otherwise it won't be mapped before we restore the scroll position
#  # update
#  
#  #gen_log:log T "LEAVE"
#}

proc directory_list { filenames } {
  global module_dir
  global incvs inrcs insvn ingit
  global cvs
  global cwd
  global cvscfg
  global cvsglb
  global cmd
  global Filelist
  
  #gen_log:log T "ENTER ($filenames)"
  
  if {[info exists Filelist]} {
    unset Filelist
  }
  
  busy_start .workdir.main
  
  ##gen_log:log F "processing files in the local directory"
  set cwd [pwd]
  set my_cwd $cwd
  
  # If we have commands running they were for a different directory
  # and won't be needed now. (i.e. this is a recursive invocation
  # triggered by a button click)
  if {[info exists cmd(cvs_status)]} {
    catch {$cmd(cvs_status)\::abort}
    catch {unset cmd(cvs_status)}
  }
  if {[info exists cmd(cvs_editors)]} {
    catch {$cmd(cvs_editors)\::abort}
    catch {unset cmd(cvs_editors)}
  }
  
  # Select from those files only the ones we want (e.g., no CVS dirs)
  foreach i $filenames {
    if { $i == "."  || $i == ".."} {
      #gen_log:log D "SKIPPING $i"
      continue
    }
    if {[file isdirectory $i]} {
      if {[isCmDirectory $i]} {
        # Read the bookkeeping files but don't list the directory
        if {$i == "CVS" || $i == ".svn" || $i == "RCS" || $i == ".git"} {
          continue
        }
      }
      if {[file exists [file join $i "CVS"]]} {
        set Filelist($i:status) "<directory:CVS>"
      } elseif {[file exists [file join $i ".svn"]]} {
        set Filelist($i:status) "<directory:SVN>"
      } elseif {[file exists [file join $i ".git"]]} {
        set Filelist($i:status) "<directory:GIT>"
      } elseif {[file exists [file join $i "RCS"]]} {
        set Filelist($i:status) "<directory:RCS>"
      } else {
        set Filelist($i:status) "<directory>"
      }
    } else {
      if {$i == ".git"} {continue}
      if {$incvs} {
        set Filelist($i:status) "Not managed by CVS"
      } else {
        if {$ingit} {
          # In case we're not doing gitdetail, set the file as up-to-date
          # and it will be overwritten otherwise
          set Filelist($i:status) "Up-to-date"
        } else {
          set Filelist($i:status) "<file>"
        }
      }
    }
    #set Filelist($i:wrev) ""
    set Filelist($i:stickytag) ""
    set Filelist($i:option) ""
    # Prepending ./ to the filename prevents tilde expansion
    catch {set Filelist($i:date) \
        [clock format [file mtime ./$i] -format $cvscfg(dateformat)]}
  }
  
  #gen_log:log D "incvs=$incvs insvn=$insvn inrcs=$inrcs ingit=$ingit"
  if {$incvs} {
    .workdir.main.tree heading wrevcol -text "Revision"
    .workdir.main.tree heading editcol -text "Author"
    cvs_workdir_status
  }
  if {$inrcs} {
    .workdir.main.tree heading wrevcol -text "Revision"
    .workdir.main.tree heading editcol -text "Locked by"
    rcs_workdir_status
  } elseif {$insvn} {
    .workdir.main.tree heading wrevcol -text "Revision"
    .workdir.main.tree heading editcol -text "Author"
    svn_workdir_status
  } elseif {$ingit} {
    .workdir.main.tree heading wrevcol -text "Commit ID"
    .workdir.main.tree heading editcol -text "Committer"
    # We need the filenames in git for ignore_file_filter
    git_workdir_status $filenames
  }
  
  #gen_log:log D "Sending all files to the canvas"
  set n_show [llength [array names Filelist]]
  if {$n_show == 0} {
    cvsalwaysconfirm "No files matched" .workdir
  }
  foreach i [array names Filelist *:status] {
    regsub {:status$} $i "" j
    # If it's locally removed or missing, it may not have
    # gotten a date especially on a remote client.
    if {! [info exists Filelist($j:date)]} {
      set Filelist($j:date) ""
    }
    DirCanvas:newitem .workdir.main "$j"
  }
  DirCanvas:bindings .workdir.main
  
  set col [lindex $cvscfg(sort_pref) 0]
  set sense [lindex $cvscfg(sort_pref) 1]
  DirCanvas:sort_by_col .workdir.main.tree $col $sense
  
  busy_done .workdir.main
  
  #gen_log:log T "LEAVE"
}

proc workdir_cleanup {} {
  global cvscfg
  
  #gen_log:log T "ENTER"
  set rmitem ""
  set list [ split $cvscfg(clean_these) " " ]
  foreach pattern $list {
    #gen_log:log D "pattern $pattern"
    if { $pattern != "" } {
      set items [lsort [glob -nocomplain $pattern]]
      #gen_log:log D "$items"
      if {[llength $items] != 0} {
        append rmitem " [concat $items]"
      }
    }
  }
  
  if {$rmitem != ""} {
    if { [ are_you_sure "You are about to delete:\n" $rmitem] == 1 } {
      #gen_log:log F "DELETE $rmitem"
      eval file delete -force -- $rmitem
    }
  } else {
    #gen_log:log F "No files to delete"
    cvsok "Nothing matched $cvscfg(clean_these)" .workdir
    return
  }
  setup_dir
  #gen_log:log T "LEAVE"
}

proc workdir_delete_file {args} {
  global cvscfg
  
  #gen_log:log T "ENTER ($args)"
  
  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select some files to delete first!" .workdir
    return
  }
  
  if { [ are_you_sure "This will delete these files from your local, working directory:\n" $filelist ] == 1 } {
    #gen_log:log F "DELETE $filelist"
    eval file delete -force -- $filelist
    setup_dir
  }
  #gen_log:log T "LEAVE"
}

proc are_you_sure {mess args} {
  #
  # General posting message
  #
  global cvscfg
  
  #gen_log:log T "ENTER ($mess $args)"
  
  set filelist [join $args]
  if {$cvscfg(confirm_prompt)} {
    append mess "\n"
    set indent "      "
    
    foreach item $filelist {
      if { $item != {} } {
        append mess " $indent"
        append mess " $item\n"
      }
    }
    append mess "\nAre you sure?"
    if {[cvsconfirm $mess .workdir] != "ok"} {
      #gen_log:log T "LEAVE 0"
      return 0
    }
  }
  #gen_log:log T "LEAVE 1"
  return 1
}

proc workdir_print_file {args} {
  global cvscfg
  
  #gen_log:log T "ENTER ($args)"
  
  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select some files to print first!" .workdir
    return
  }
  
  set mess "This will print these files:\n\n"
  foreach file $filelist {
    append mess "   $file\n"
  }
  append mess "\nUsing $cvscfg(print_cmd)\n"
  append mess "\nAre you sure?"
  if {[cvsconfirm $mess .workdir] == "ok"} {
    set final_result ""
    foreach file $filelist {
      set commandline [concat $cvscfg(print_cmd) \"$file\"]
      exec::new $commandline
    }
  }
  #gen_log:log T "LEAVE"
}

proc cvsroot_check { dir cvscfg_str cvsglb_str} {
#  global cvscfg
#  global cvsglb
  array set cvscfg $cvscfg_str
  array set cvsglb $cvsglb_str
  
  set srcdirtype(incvs) 0
  set srcdirtype(insvn) 0
  set srcdirtype(inrcs) 0
  set srcdirtype(ingit) 0
	
  set cvsrootfile [file join $dir CVS Root]
	
  if {[file isfile $cvsrootfile]} {
    set incvs [ read_cvs_dir [file join $dir CVS]]
    # Outta here, don't check for svn or rcs
    if {$srcdirtype(incvs)} {
      return [array get srcdirtype]
    }
  }
  set svnret [catch {exec {*}svn info} svnout]
  if {! $svnret} {
    set srcdirtype(insvn) [ read_svn_dir $dir ]
    if {$srcdirtype(insvn)} {
      return a
    }
  }
  set rcsdir [file join $dir RCS]
  if {[file exists $rcsdir]} {
    set cvscfg(rcsdir) $rcsdir
    set inrcs 1
  } elseif {[llength [glob -nocomplain -dir $dir *,v]] > 0} {
    set inrcs 1
    set cvscfg(rcsdir) $dir
  } else {
    set cvscfg(rcsdir) ""
  }
  
  if {$srcdirtype(inrcs)} {
    # Make sure we have rcs, and bag this (silently) if we don't
    set command "rcs --version"
    #gen_log:log C "$command"
    set ret [catch {exec {*}$command} raw_rcs_log]
    #gen_log:log F "$raw_rcs_log"
    if {$ret} {
      if [string match {rcs*} $raw_rcs_log] {
        # An old version of RCS, but it's here
        set srcdirtype(inrcs) 1
      } else {
        set srcdirtype(inrcs) 0
      }
    }
  }
  set gitret [catch {exec {*}git rev-parse --is-inside-work-tree} gitout]
  if {! $gitret} {
    # revparse may return "false"
    ##gen_log:log F "gitout $gitout"
    if {$gitout} {
      set srcdirtype(ingit) 1
      find_git_remote $dir
    }
  } else {
    ###gen_log:log E "gitout $gitout"
    set srcdirtype(ingit) 0
  }
  puts [array get srcdirtype]
  return [array get srcdirtype]
}

proc isCmDirectory { file } {
  ##gen_log:log T "ENTER ($file)"
  switch -- $file  {
    "CVS"  -
    "RCS"  -
    ".svn"  -
    ".git"  -
    "SCCS" { set value 1 }
    default { set value 0 }
  }
  return $value
}

# Get the files in the current working directory. Use the file_filter
# values. Add hidden files if desired by the user. Sort them to match
# the ordering that will be returned by cvs commands (this matches the
# default ls ordering.).
proc getFiles { } {
  global cvscfg
  global cvsglb
  
  #gen_log:log T "ENTER"
  set filelist ""
  
  # make sure the file filter is at least set to "*".
  if { $cvscfg(show_file_filter) == "" } {
    set cvscfg(show_file_filter) "*"
  }
  
  # get the initial file list, including dotfiles if requested, filtered by show_file_filter
  if {$cvscfg(allfiles)} {
    # get hidden as well
    foreach item $cvscfg(show_file_filter) {
      #gen_log:log T "glob -nocomplain .$item $item"
      set filelist [ concat [ glob -nocomplain .$item $item ] $filelist ]
    }
  } else {
    foreach item $cvscfg(show_file_filter) {
      set filelist [ concat [ glob -nocomplain $item ] $filelist ]
    }
  }
  # ignore files if requested by ingore_file_filter
  set ignore_file_filter [concat $cvscfg(ignore_file_filter) $cvsglb(vcs_hidden_files)]
  if { $ignore_file_filter != "" } {
    foreach item $ignore_file_filter {
      # for each pattern
      if { $item != "*" } {
        # if not "*"
        set idx [lsearch $filelist $item]
        while { [set idx [lsearch $filelist $item]] != -1 } {
          # for each occurence, delete
          catch { set filelist [ lreplace $filelist $idx $idx ] }
        }
      }
    }
  }
  
  # make sure "." is always in the list for 'cd' purposes
  if { "." ni $filelist} {
    set filelist [ concat "." $filelist ]
  }
  
  # make sure ".." is always in the list for 'cd' purposes
  if { ".." ni $filelist} {
    set filelist [ concat ".." $filelist ]
  }
  
  # sort it
  set filelist [ lsort $filelist ]
  
  # if this directory is under CVS and CVS is not in the list, add it. Its
  # presence is needed for later processing
  if { ( [ file exists "CVS" ] ) && ("CVS" ni $filelist) } {
    #puts "********* added CVS"
    catch { set filelist [ concat "CVS" $filelist ] }
  }
  
  #gen_log:log T "return ($filelist)"
  return $filelist
}

proc exit_cleanup { force } {
  global cvscfg
  
  # Count the number of toplevels that are currently interacting
  # with the user (i.e. exist and are not withdrawn)
  set wlist {}
  foreach w [winfo children .] {
    if {[wm state $w] != {withdrawn}} {
      lappend wlist $w
    }
  }
  
  if {$force == 0 && [llength $wlist] != 0 \
        && $wlist != {.trace} && $wlist != {.bgerrorTrace}} {
    return
  }
  
  # If toplevel windows exist ask them to close gracefully if possible
  foreach w $wlist {
    # Except .trace!
    if {$w != {.trace}} {
      catch {$w.close invoke}
    } else {
      # Invoking trace's close turns off logging. We don't want that,
      # but we do want to save its geometry.
      if {[winfo exists .trace]} {
        set cvscfg(tracgeom) [wm geometry .trace]
      }
    }
  }
  
#  save_options
  set pid [pid]
  #gen_log:log F "DELETE $cvscfg(tmpdir)/cvstmpdir.$pid"
  catch {file delete -force [file join $cvscfg(tmpdir) cvstmpdir.$pid]}
  exit
}
