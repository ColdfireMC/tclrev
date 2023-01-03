
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
  if {[exists dot_workdir]} {
    return
<<<<<<< HEAD:tkrev/workdir.tcl
  } 
 change_dir "[pwd]"
 setup_dir
=======
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
#  #change_dir "[pwd]"
  setup_dir
  #gen_log:log T "LEAVE"
>>>>>>> 565667aaf4804f355ef7af23e80c98e8daa2d7b0:tclrev/workdir.tcl
}

# Returns a list of the selected file names. This is where the arg-list comes
# from for mostttons and menus.
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
proc auto_setup_dir {command} {
  global cvscfg
    
  if {$cvscfg(auto_status)} {
    $command\::wait
    setup_dir
  } else {
    after 0 "$command\::wait; $command\::destroy"
  }
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
}  
proc root_check { dir cvscfg_str cvsglb_str} {
  #  global cvscfg 
  #  global cvsglb
  array set cvscfg $cvscfg_str
<<<<<<< HEAD:tkrev/workdir.tcl
  array set cvsglb $cvsglb_str 
  set srcdirtype(incvs) 0
  set srcdirtype(insvn) 0
  set srcdirtype(inrcs) 0
  set srcdirtype(ingit) 0
  set cvsrootfile [file join $dir CVS Root] 
=======
  array set cvsglb $cvsglb_str
  
  set srcdirtype(incvs) false
  set srcdirtype(insvn) false
  set srcdirtype(inrcs) false
  set srcdirtype(ingit) false
	
  set cvsrootfile [file join $dir CVS Root]
	
>>>>>>> 565667aaf4804f355ef7af23e80c98e8daa2d7b0:tclrev/workdir.tcl
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
        set srcdirtype(inrcs) true
      } else {
        set srcdirtype(inrcs) false
      }
    }
  }
  set gitret [catch {exec {*}git rev-parse --is-inside-work-tree} gitout]
  if {! $gitret} {
    # revparse may return "false"
    if {$gitout} {
      set srcdirtype(ingit) true
      find_git_remote $dir
    }
  } else {
<<<<<<< HEAD:tkrev/workdir.tcl
    set srcdirtype(ingit) 0
=======
    ###gen_log:log E "gitout $gitout"
    set srcdirtype(ingit) false
>>>>>>> 565667aaf4804f355ef7af23e80c98e8daa2d7b0:tclrev/workdir.tcl
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
  set filelist "" 
  # make sure the file filter is at least set to "*".
  if { $cvscfg(show_file_filter) == "" } {
    set cvscfg(show_file_filter) "*"
  }
  # get the initial file list, including dotfiles if requested, filtered by show_file_filter
  if {$cvscfg(allfiles)} {
    # get hidden as well
    foreach item $cvscfg(show_file_filter) {
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
   catch { set filelist [ concat "CVS" $filelist ] }
  }
  return $filelist
}