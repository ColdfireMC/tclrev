#
# Tcl Library for TkCVS
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

  gen_log:log T "ENTER"
  set cwd [pwd]
  set pid [pid]

  if {[winfo exists .workdir]} {
    wm deiconify .workdir
    raise .workdir
    return
  }

  # Make a new toplevel and unmap . so that the working directory browser
  # the module browser are equal
  toplevel .workdir
  wm title .workdir "TkCVS $cvscfg(version) Working Directory"
  wm iconname .workdir "TkCVS"
  if {$tcl_platform(platform) eq "unix"} {
    wm iconbitmap .workdir @$cvscfg(bitmapdir)/tkcvs48.xbm
  }
  wm minsize .workdir 430 300
  wm protocol .workdir WM_DELETE_WINDOW { .workdir.close invoke }
  wm withdraw .

  if {[catch "image type Conflict"]} {
    workdir_images
  }
  if {[info exists cvscfg(workgeom)]} {
    wm geometry .workdir $cvscfg(workgeom)
  }

  workdir_menus

  #
  # Top section - where we are, where the module is
  #
  frame .workdir.top -relief groove -border 2
  pack .workdir.top -side top -fill x

  ::picklist::entry .workdir.top.tcwd cwd directory
  ::picklist::bind .workdir.top.tcwd <Return> \
     {if {[pwd] != $cwd} {change_dir "$cwd"}}

  button .workdir.top.updir_btn -image updir \
    -command {change_dir ..}

  label .workdir.top.lmodule -text "Path"
  label .workdir.top.tmodule -textvariable module_dir -anchor w -relief groove

  label .workdir.top.ltagname -text "Tag"
  label .workdir.top.ttagname -textvariable current_tagname \
     -anchor w -relief groove

  # Make the Repository Browser button prominent
  button .workdir.top.bmodbrowse -image Modules \
     -command modbrowse_run

  label .workdir.top.lcvsroot -text "CVSROOT"
  entry .workdir.top.tcvsroot -textvariable cvscfg(cvsroot) \
     -bd 1 -relief sunk -state readonly

  grid columnconf .workdir.top 1 -weight 1
  grid rowconf .workdir.top 3 -weight 1
  grid .workdir.top.updir_btn -column 0 -row 0 -sticky s
  grid .workdir.top.tcwd -column 1 -row 0 -columnspan 2 \
    -sticky sew -padx 4 -pady 1
  grid .workdir.top.lmodule -column 0 -row 1 -sticky nw
  grid .workdir.top.tmodule -column 1 -row 1 -columnspan 2\
     -padx 4 -pady 1 -sticky new
  grid .workdir.top.bmodbrowse -column 2 -row 2 -rowspan 2 -sticky w
  grid .workdir.top.ltagname -column 0 -row 2 -sticky nw
  grid .workdir.top.ttagname -column 1 -row 2 -padx 4 -pady 1 -sticky new
  grid .workdir.top.lcvsroot -column 0 -row 3 -sticky nw
  grid .workdir.top.tcvsroot -column 1 -row 3 -padx 3 -sticky new


  # Pack the bottom before the middle so it doesnt disappear if
  # the window is resized smaller
  frame .workdir.bottom
  frame .workdir.bottom.filters -relief raised
  pack .workdir.bottom -side bottom -fill x
  pack .workdir.bottom.filters -side top -fill x

  label .workdir.bottom.filters.showlbl -text "Show:" -anchor w
  entry .workdir.bottom.filters.showentry -textvariable cvscfg(file_filter) -width 12
  label .workdir.bottom.filters.hidelbl -text "   Hide:" -anchor w
  entry .workdir.bottom.filters.hideentry -width 12 \
     -textvariable cvsglb(default_ignore_filter)
  label .workdir.bottom.filters.space -text "    "
  button .workdir.bottom.filters.cleanbutton -text "Clean:" \
     -pady 0 -highlightthickness 0 \
     -command workdir_cleanup
  entry .workdir.bottom.filters.cleanentry -width 12 \
     -textvariable cvscfg(clean_these)
  bind .workdir.bottom.filters.showentry <Return> {setup_dir}
  bind .workdir.bottom.filters.hideentry <Return> {
     set cvsglb(default_ignore_filter) [.workdir.bottom.filters.hideentry get]
     setup_dir}
  bind .workdir.bottom.filters.cleanentry <Return> {workdir_cleanup}
  pack .workdir.bottom.filters.showlbl -side left
  pack .workdir.bottom.filters.showentry -side left
  pack .workdir.bottom.filters.hidelbl -side left
  pack .workdir.bottom.filters.hideentry -side left
  pack .workdir.bottom.filters.space -side left
  pack .workdir.bottom.filters.cleanbutton -side left -ipadx 2 -ipady 0
  pack .workdir.bottom.filters.cleanentry -side left

  frame .workdir.bottom.buttons -relief groove -bd 2
  frame .workdir.bottom.buttons.funcs -relief groove -bd 2
  frame .workdir.bottom.buttons.dirfuncs -relief groove -bd 2
  frame .workdir.bottom.buttons.cvsfuncs -relief groove -bd 2
  frame .workdir.bottom.buttons.oddfuncs -relief groove -bd 2
  frame .workdir.bottom.buttons.closefm
  pack .workdir.bottom.buttons -side top -fill x -expand yes
  pack .workdir.bottom.buttons.closefm -side right -expand yes
  pack .workdir.bottom.buttons.funcs -side left -expand yes -anchor w
  pack .workdir.bottom.buttons.dirfuncs -side left -expand yes -anchor w
  pack .workdir.bottom.buttons.cvsfuncs -side left -expand yes -anchor w
  pack .workdir.bottom.buttons.oddfuncs -side left -expand yes -anchor w

  #
  # Action buttons along the bottom of the screen.
  #
  button .workdir.bottom.buttons.funcs.bedit_files -image Fileedit \
     -command { workdir_edit_file [workdir_list_files] }
  button .workdir.bottom.buttons.funcs.bview_files -image Fileview \
     -command { workdir_view_file [workdir_list_files] }
  button .workdir.bottom.buttons.funcs.bdelete_file -image Delete \
     -command { workdir_delete_file [workdir_list_files] }
  button .workdir.bottom.buttons.funcs.bmkdir -image Dir_new \
     -command { file_input_and_do "New Directory" workdir_newdir}

  button .workdir.bottom.buttons.dirfuncs.brefresh -image Refresh \
     -command { setup_dir }
  button .workdir.bottom.buttons.dirfuncs.bcheckdir -image Check \
     -command { cvs_check }
  button .workdir.bottom.buttons.cvsfuncs.blogfile -image Branches \
     -command { cvs_branches [workdir_list_files] }
  button .workdir.bottom.buttons.cvsfuncs.bannotate -image Annotate \
     -command { cvs_annotate $current_tagname [workdir_list_files] }
  button .workdir.bottom.buttons.cvsfuncs.bfilelog -image Log \
    -command { cvs_log $cvscfg(ldetail) [workdir_list_files] }
  button .workdir.bottom.buttons.cvsfuncs.bdiff -image Diff \
     -command { comparediff [workdir_list_files] }
  button .workdir.bottom.buttons.cvsfuncs.bconflict -image Conflict \
     -command { cvs_merge_conflict [workdir_list_files] }
  button .workdir.bottom.buttons.cvsfuncs.btag -image Tag \
     -command { file_tag_dialog "tag" }
  button .workdir.bottom.buttons.cvsfuncs.bbranchtag -image Branchtag \
     -command { file_tag_dialog "branch" }
  button .workdir.bottom.buttons.cvsfuncs.badd_files -image Add \
     -command { add_dialog [workdir_list_files] }
  button .workdir.bottom.buttons.cvsfuncs.bremove -image Remove \
     -command { subtract_dialog [workdir_list_files] }
  button .workdir.bottom.buttons.cvsfuncs.bcheckin -image Checkin \
      -command cvs_commit_dialog
  button .workdir.bottom.buttons.cvsfuncs.bupdate -image Checkout 
  button .workdir.bottom.buttons.cvsfuncs.bupdateopts -image CheckoutOpts \
     -command { cvs_update_options }
  button .workdir.bottom.buttons.cvsfuncs.brevert -image Revert \
     -command { cvs_revert [workdir_list_files] }
  button .workdir.bottom.buttons.cvsfuncs.bjoin -image DirBranches \
     -command cvs_joincanvas

  button .workdir.bottom.buttons.oddfuncs.bcvsedit_files -image Edit \
     -command { cvs_edit [workdir_list_files] }
  button .workdir.bottom.buttons.oddfuncs.bunedit_files -image Unedit \
     -command { cvs_unedit [workdir_list_files] }
  button .workdir.bottom.buttons.oddfuncs.block -image Lock
  button .workdir.bottom.buttons.oddfuncs.bunlock -image UnLock
  button .workdir.bottom.buttons.oddfuncs.bpush -image Checkin \
     -command { git_push }
  button .workdir.bottom.buttons.oddfuncs.bfetch -image Checkout \
     -command { git_fetch }
  button .workdir.close -text "Close" \
      -command {
        global cvscfg
        set cvscfg(workgeom) [wm geometry .workdir]
        destroy .workdir
        exit_cleanup 0
      }

  # These buttons work in any directory
  grid .workdir.bottom.buttons.funcs.bdelete_file -column 0 -row 0 \
    -ipadx 4
  grid .workdir.bottom.buttons.funcs.bedit_files -column 1 -row 0 \
     -ipadx 4
  grid .workdir.bottom.buttons.funcs.bmkdir -column 0 -row 1 \
     -ipadx 4
  grid .workdir.bottom.buttons.funcs.bview_files -column 1 -row 1 \
     -ipadx 4

  # Directory functions
  grid rowconf .workdir.bottom.buttons.dirfuncs 0 -weight 1
  grid .workdir.bottom.buttons.dirfuncs.brefresh       -column 0 -row 0 \
     -ipadx 4 -ipady 4
  grid .workdir.bottom.buttons.dirfuncs.bcheckdir      -column 1 -row 0 \
     -ipadx 4 -ipady 4

  # Revcontrol functions
  grid .workdir.bottom.buttons.cvsfuncs.blogfile      -column 0 -row 0 \
    -ipadx 4
  grid .workdir.bottom.buttons.cvsfuncs.bjoin         -column 0 -row 1 \
    -ipadx 4
  grid .workdir.bottom.buttons.cvsfuncs.bdiff         -column 1 -row 0 \
    -ipadx 2
  grid .workdir.bottom.buttons.cvsfuncs.bconflict     -column 1 -row 1 \
    -ipadx 2
  grid .workdir.bottom.buttons.cvsfuncs.bfilelog      -column 2 -row 0
  grid .workdir.bottom.buttons.cvsfuncs.bannotate     -column 2 -row 1
  grid .workdir.bottom.buttons.cvsfuncs.bupdate       -column 3 -row 0 \
    -ipadx 4
  grid .workdir.bottom.buttons.cvsfuncs.bcheckin      -column 3 -row 1 \
    -ipadx 4
  grid .workdir.bottom.buttons.cvsfuncs.bupdateopts   -column 4 -row 0 \
    -ipadx 4
  grid .workdir.bottom.buttons.cvsfuncs.brevert       -column 4 -row 1 \
    -ipadx 4
  grid .workdir.bottom.buttons.cvsfuncs.badd_files    -column 5 -row 0
  grid .workdir.bottom.buttons.cvsfuncs.bremove       -column 5 -row 1
  grid .workdir.bottom.buttons.cvsfuncs.btag          -column 6 -row 0 \
    -ipadx 4
  grid .workdir.bottom.buttons.cvsfuncs.bbranchtag    -column 6 -row 1 \
    -ipadx 4
  grid .workdir.bottom.buttons.oddfuncs.block          -column 0 -row 0
  grid .workdir.bottom.buttons.oddfuncs.bunlock        -column 0 -row 1
  grid .workdir.bottom.buttons.oddfuncs.bcvsedit_files -column 1 -row 0
  grid .workdir.bottom.buttons.oddfuncs.bunedit_files  -column 1 -row 1

  pack .workdir.close -in .workdir.bottom.buttons.closefm \
    -side right -fill both -expand yes

  set_tooltips .workdir.top.updir_btn \
     {"Go up (..)"}
  set_tooltips .workdir.bottom.buttons.funcs.bedit_files \
     {"Edit the selected files"}
  set_tooltips .workdir.bottom.buttons.funcs.bview_files \
     {"View the selected files"}
  set_tooltips .workdir.bottom.buttons.funcs.bdelete_file \
     {"Delete the selected files from the current directory"}
  set_tooltips .workdir.bottom.buttons.funcs.bmkdir \
     {"Make a new directory"}

  set_tooltips .workdir.bottom.buttons.dirfuncs.brefresh \
     {"Re-read the current directory"}
  set_tooltips .workdir.bottom.buttons.cvsfuncs.bjoin \
     {"Directory Branch Diagram and Merge Tool"}
  set_tooltips .workdir.bottom.buttons.dirfuncs.bcheckdir \
     {"Check the status of the directory"}

  set_tooltips .workdir.bottom.buttons.cvsfuncs.blogfile \
     {"Graphical Branch Diagram of the selected files"}
  set_tooltips .workdir.bottom.buttons.cvsfuncs.bfilelog \
     {"Revision Log of the selected files"}
  set_tooltips .workdir.bottom.buttons.cvsfuncs.bannotate \
     {"Revision where each line was modified (annotate/blame)"}
  set_tooltips .workdir.bottom.buttons.cvsfuncs.bdiff \
     {"Compare the selected files with the committed version"}
  set_tooltips .workdir.bottom.buttons.cvsfuncs.bconflict \
     {"Merge Conflicts using TkDiff"}

  set_tooltips .workdir.bottom.buttons.cvsfuncs.btag \
     {"Tag the selected files"}
  set_tooltips .workdir.bottom.buttons.cvsfuncs.bbranchtag \
     {"Branch the selected files"}
  set_tooltips .workdir.bottom.buttons.cvsfuncs.bupdateopts \
     {"Update with options (-A, -r, -f, -d, -kb)"}

  set_tooltips .workdir.bottom.buttons.oddfuncs.block \
     {"Lock the selected files"}
  set_tooltips .workdir.bottom.buttons.oddfuncs.bunlock \
     {"Unlock the selected files"}
  set_tooltips .workdir.bottom.buttons.oddfuncs.bcvsedit_files \
     {"Set the Edit flag on the selected files"}
  set_tooltips .workdir.bottom.buttons.oddfuncs.bunedit_files \
     {"Unset the Edit flag on the selected files"}
  set_tooltips .workdir.bottom.buttons.oddfuncs.bpush \
     {"Push to origin"}
  set_tooltips .workdir.bottom.buttons.oddfuncs.bfetch \
     {"Fetch from origin"}

  set_tooltips .workdir.top.bmodbrowse \
     {"Open the Repository Browser"}
  set_tooltips .workdir.close \
     {"Close the Working Directory Browser"}


  frame .workdir.main
  pack .workdir.main -side bottom -fill both -expand 1 -fill both
  update idletasks

  if {! [winfo ismapped .workdir]} {
    wm deiconify .workdir
  }

  #change_dir "[pwd]"
  setup_dir
  gen_log:log T "LEAVE"
}

proc workdir_images {} {
  global cvscfg

  image create photo arr_up \
    -format gif -file [file join $cvscfg(bitmapdir) arrow_up.gif]
  image create photo arh_up \
    -format gif -file [file join $cvscfg(bitmapdir) arrow_hl_up.gif]
  image create photo arr_dn \
    -format gif -file [file join $cvscfg(bitmapdir) arrow_dn.gif]
  image create photo arh_dn \
    -format gif -file [file join $cvscfg(bitmapdir) arrow_hl_dn.gif]
  image create photo updir \
    -format gif -file [file join $cvscfg(bitmapdir) updir.gif]
  image create photo Folder \
    -format gif -file [file join $cvscfg(bitmapdir) dir.gif]
  image create photo Check \
    -format gif -file [file join $cvscfg(bitmapdir) check.gif]
  image create photo Fileview \
    -format gif -file [file join $cvscfg(bitmapdir) fileview.gif]
  image create photo Fileedit \
    -format gif -file [file join $cvscfg(bitmapdir) fileedit.gif]
  image create photo Annotate \
    -format gif -file [file join $cvscfg(bitmapdir) annotate.gif]
  image create photo Delete \
    -format gif -file [file join $cvscfg(bitmapdir) delete.gif]
  image create photo Dir_new \
    -format gif -file [file join $cvscfg(bitmapdir) dir_new.gif]
  image create photo Refresh \
    -format gif -file [file join $cvscfg(bitmapdir) loop-glasses.gif]
  image create photo Branches \
    -format gif -file [file join $cvscfg(bitmapdir) branch.gif]
  image create photo DirBranches \
    -format gif -file [file join $cvscfg(bitmapdir) dirbranch.gif]
  image create photo Add \
    -format gif -file [file join $cvscfg(bitmapdir) add.gif]
  image create photo Remove \
    -format gif -file [file join $cvscfg(bitmapdir) remove.gif]
  image create photo Diff \
    -format gif -file [file join $cvscfg(bitmapdir) diff.gif]
  image create photo Checkin \
    -format gif -file [file join $cvscfg(bitmapdir) checkin.gif]
  image create photo Revert \
    -format gif -file [file join $cvscfg(bitmapdir) loop-ball.gif]
  image create photo Edit \
    -format gif -file [file join $cvscfg(bitmapdir) edit.gif]
  image create photo Unedit \
    -format gif -file [file join $cvscfg(bitmapdir) unedit.gif]
  image create photo Modules \
    -format gif -file [file join $cvscfg(bitmapdir) modbrowse.gif]
  image create photo Modules_cvs \
    -format gif -file [file join $cvscfg(bitmapdir) modbrowse_cvs.gif]
  image create photo Modules_svn \
    -format gif -file [file join $cvscfg(bitmapdir) modbrowse_svn.gif]
  image create photo Modules_git \
    -format gif -file [file join $cvscfg(bitmapdir) modbrowse_git.gif]
  image create photo Lock \
    -format gif -file [file join $cvscfg(bitmapdir) locked.gif]
  image create photo UnLock \
    -format gif -file [file join $cvscfg(bitmapdir) unlocked.gif]
  image create photo Tags \
    -format gif -file [file join $cvscfg(bitmapdir) tags.gif]
  image create photo Mergebranch \
    -format gif -file [file join $cvscfg(bitmapdir) newmerge_simple.gif]
  image create photo Mergediff \
    -format gif -file [file join $cvscfg(bitmapdir) newmerge.gif]
  image create photo Conflict \
    -format gif -file [file join $cvscfg(bitmapdir) conflict.gif]
  image create photo GitCheckin \
    -format gif -file [file join $cvscfg(bitmapdir) git_checkin.gif]
  image create photo GitCheckout \
    -format gif -file [file join $cvscfg(bitmapdir) git_checkout.gif]

  image create photo Man \
    -format gif -file [file join $cvscfg(bitmapdir) man.gif]
}

proc workdir_menus {} {
  global cvscfg
  global cvsglb
  global cvsmenu
  global usermenu
  global execmenu
  global bookmarks

  gen_log:log T "ENTER"
  set startdir "[pwd]"

  #.workdir configure -menu .workdir.menubar
  menu .workdir.menubar

  #
  # Create the Menu bar
  #
  if {[tk windowingsystem] == "aqua"} {
    # There's an extra menu in the first postion on apple, whether you like it or not.
    # So you have to configure it.
    .workdir.menubar add cascade -label "TkCVS" -menu [menu .workdir.menubar.apple]
  }
  .workdir.menubar add cascade -label "File" -menu [menu .workdir.menubar.file] -underline 0
  .workdir.menubar add cascade -label "Reports" -menu [menu .workdir.menubar.reports] -underline 2
  .workdir.menubar add cascade -label "Options" -menu [menu .workdir.menubar.options] -underline 0

  if { [info exists cvsmenu] || \
       [info exists usermenu] || \
       [info exists execmenu]} {
    .workdir.menubar add cascade -label "User Defined" -menu [menu .workdir.menubar.user] -underline 0
    gen_log:log T "Adding user defined menu"
  }
  .workdir.menubar add cascade -label "Go" -menu [menu .workdir.menubar.goto] -underline 0

  # Populate the help menu
  menu_std_help .workdir.menubar
  # Have to do this after the .apple menu
  .workdir configure -menu .workdir.menubar

  #
  # Create the Menus
  #

  # File
  .workdir.menubar.file add command -label "Open Selection" -underline 0 \
     -command { workdir_edit_file [workdir_list_files] }
  .workdir.menubar.file add command -label "Print Selected File" -underline 0 \
     -command { workdir_print_file  [workdir_list_files ] }
  .workdir.menubar.file add command -label "Make New Directory" -underline 0 \
     -command { file_input_and_do "New Directory" workdir_newdir}
  .workdir.menubar.file add separator
  .workdir.menubar.file add command -label "Browse Modules" -underline 0 \
     -command modbrowse_run
  .workdir.menubar.file add command -label "Cleanup Directory" -underline 4 \
     -command workdir_cleanup
  .workdir.menubar.file add separator
  .workdir.menubar.file add command -label "Shell window" -underline 0 \
     -command { exec::new $cvscfg(shell) }
  .workdir.menubar.file add separator
  .workdir.menubar.file add command -label Close -underline 1 \
     -command {.workdir.close invoke}
  .workdir.menubar.file add command -label Exit -underline 1 \
     -command { exit_cleanup 1 }

  # CVS
  menu .workdir.menubar.cvs
  .workdir.menubar.cvs add command -label "Update" -underline 0 \
     -command { \
        cvs_update {BASE} {Normal} {Remove} {recurse} {prune} {No} { } [workdir_list_files] }
  .workdir.menubar.cvs add command -label "Update with Options" -underline 7 \
     -command cvs_update_options
  .workdir.menubar.cvs add command -label "Commit/Checkin" -underline 0 \
     -command cvs_commit_dialog
  .workdir.menubar.cvs add command -label "Add Files" -underline 0 \
     -command { add_dialog [workdir_list_files] }
  .workdir.menubar.cvs add command -label "Add Recursively" \
     -command { addir_dialog [workdir_list_files] }
  .workdir.menubar.cvs add command -label "Remove Files" -underline 0 \
     -command { subtract_dialog [workdir_list_files] }
  .workdir.menubar.cvs add command -label "Remove Recursively" \
     -command { subtractdir_dialog [workdir_list_files] }
  .workdir.menubar.cvs add command -label "Set Binary Flag" \
     -command { cvs_binary [workdir_list_files] }
  .workdir.menubar.cvs add command -label "Unset Binary Flag" \
     -command { cvs_ascii [workdir_list_files] }
  .workdir.menubar.cvs add command -label "Set Edit Flag (Edit)" -underline 15 \
     -command { cvs_edit [workdir_list_files] }
  .workdir.menubar.cvs add command -label "Unset Edit Flag (Unedit)" -underline 11 \
     -command { cvs_unedit [workdir_list_files] }
  .workdir.menubar.cvs add command -label "Tag Files" -underline 0 \
     -command { file_tag_dialog "tag" }
  .workdir.menubar.cvs add command -label "Browse the Log Diagram" \
     -command { cvs_branches [workdir_list_files] }
  .workdir.menubar.cvs add command -label "Resolve Conflicts" \
     -command { cvs_merge_conflict [workdir_list_files] }
  .workdir.menubar.cvs add separator
  .workdir.menubar.cvs add command -label "Release" \
     -command { release_dialog [workdir_list_files] }
  .workdir.menubar.cvs add command -label "Join (Merge) Directory" \
     -underline 0 -command { cvs_directory_merge }
  .workdir.menubar.cvs add command -label "Import CWD into Repository" \
     -underline 0 -command import_run

  # SVN
  menu .workdir.menubar.svn
  .workdir.menubar.svn add command -label "Update" -underline 0 \
     -command {svn_update [workdir_list_files]}
  .workdir.menubar.svn add command -label "Resolve (Un-mark Conflict)" -underline 0 \
     -command {svn_resolve [workdir_list_files]}
  .workdir.menubar.svn add command -label "Commit/Checkin" -underline 0 \
     -command svn_commit_dialog
  .workdir.menubar.svn add command -label "Add Files" -underline 0 \
     -command { add_dialog [workdir_list_files] }
  .workdir.menubar.svn add command -label "Remove Files" -underline 0 \
     -command { subtract_dialog [workdir_list_files] }
  .workdir.menubar.svn add command -label "Browse the Log Diagram" \
     -command { svn_branches [workdir_list_files] }
  .workdir.menubar.svn add separator
  .workdir.menubar.svn add command -label "Import CWD into Repository" \
     -underline 0 -command svn_import_run

  # RCS
  menu .workdir.menubar.rcs
  .workdir.menubar.rcs add command -label "Checkout" -underline 0 \
     -command { rcs_checkout [workdir_list_files] }
  .workdir.menubar.rcs add command -label "Checkin" -underline 0 \
     -command { rcs_commit_dialog [workdir_list_files] }
  .workdir.menubar.rcs add command -label "Browse the Log Diagram" \
     -command { rcs_branches [workdir_list_files] }

  # GIT
  menu .workdir.menubar.git
  .workdir.menubar.git add command -label "Log" -underline 0 \
     -command { git_log $cvscfg(ldetail) [workdir_list_files] }
  .workdir.menubar.git add command -label "Add Files" -underline 0 \
     -command { add_dialog [workdir_list_files] }
  .workdir.menubar.git add command -label "Remove Files" -underline 0 \
     -command { subtract_dialog [workdir_list_files] }

  # Status and log
  .workdir.menubar.reports add command -label "Check Directory" -underline 0
  .workdir.menubar.reports add cascade -label "Status" -underline 0 \
     -menu .workdir.menubar.reports.status_detail
  menu .workdir.menubar.reports.status_detail
  menu .workdir.menubar.reports.log_detail
  .workdir.menubar.reports.status_detail add command -label "Terse"
  .workdir.menubar.reports.status_detail add command -label "Summary"
  .workdir.menubar.reports.status_detail add command -label "Verbose"
  .workdir.menubar.reports add cascade -label "Log" -underline 0 \
     -menu .workdir.menubar.reports.log_detail
  .workdir.menubar.reports.log_detail add command -label "Latest"
  .workdir.menubar.reports.log_detail add command -label "Summary"
  .workdir.menubar.reports.log_detail add command -label "Verbose"
   
  .workdir.menubar.reports add command -label "Annotate/Blame" -underline 0
  .workdir.menubar.reports add command -label "Info" -underline 0
  .workdir.menubar.reports add separator
  .workdir.menubar.reports add checkbutton -label "Report Unknown Files" \
     -variable cvscfg(status_filter) -onvalue false -offvalue true
  .workdir.menubar.reports add checkbutton -label "Report Recursively" \
     -variable cvscfg(recurse) -onvalue true -offvalue false

  .workdir.menubar.options add checkbutton -label "Show hidden files" \
     -variable cvscfg(allfiles) -onvalue true -offvalue false \
     -command setup_dir
  .workdir.menubar.options add checkbutton -label "Automatic directory status" \
     -variable cvscfg(auto_status) -onvalue true -offvalue false
  .workdir.menubar.options add checkbutton -label "Confirmation Dialogs" \
     -variable cvscfg(confirm_prompt) -onvalue true -offvalue false
  .workdir.menubar.options add separator
  .workdir.menubar.options add checkbutton -label "Editor/Author/Locker Column" \
     -variable cvscfg(showeditcol) -onvalue true -offvalue false \
     -command { if {($incvs || $insvn || $inrcs || $ingit) && $cvscfg(showeditcol)} {
                  DirCanvas:build .workdir.main
                } else {
                  DirCanvas:unmap_column .workdir.main editcol
                }
              }
  .workdir.menubar.options add checkbutton -label "Status Column" \
     -variable cvscfg(showstatcol) -onvalue true -offvalue false \
     -command { if {($incvs || $insvn || $inrcs || $ingit) && $cvscfg(showstatcol)} {
                  DirCanvas:build .workdir.main
                } else {
                  DirCanvas:unmap_column .workdir.main statcol
                }
              }
  .workdir.menubar.options add checkbutton -label "Date Column" \
     -variable cvscfg(showdatecol) -onvalue true -offvalue false \
     -command { if {$cvscfg(showdatecol)} {
                  DirCanvas:build .workdir.main
                } else {
                  DirCanvas:unmap_column .workdir.main datecol
                }
              }
  .workdir.menubar.options add separator
  .workdir.menubar.options add checkbutton -label "Tracing On/Off" \
     -variable cvscfg(logging) -onvalue true -offvalue false \
     -command log_toggle

  .workdir.menubar.options add separator
  .workdir.menubar.options add command -label "Save Options" -underline 0 \
     -command save_options

  .workdir.menubar.goto add command -label "Go Home" \
     -command {change_dir $cvscfg(home)}
  .workdir.menubar.goto add command -label "Add Bookmark" \
     -command add_bookmark
  .workdir.menubar.goto add command -label "Delete Bookmark" \
     -command delete_bookmark_dialog
  .workdir.menubar.goto add separator
  foreach mark [lsort [array names bookmarks]] {
    # Backward compatibility.  Value used to be a placeholder, is now a revsystem type
    if {$bookmarks($mark) == "t"} {set bookmarks($mark) ""}
    .workdir.menubar.goto add command -label "$mark $bookmarks($mark)" \
       -command "change_dir \"$mark\""
  }


  #
  # Add user commands to the menu.
  #
  if {[info exists cvsmenu]} {
    foreach item [array names cvsmenu] {
      .workdir.menubar.user add command -label $item \
         -command "eval cvs_usercmd $cvsmenu($item) \[workdir_list_files\]"
    }
  }
  if {[info exists usermenu]} {
    .workdir.menubar.user add separator
    foreach item [array names usermenu] {
      .workdir.menubar.user add command -label $item \
         -command "eval cvs_catchcmd $usermenu($item) \[workdir_list_files\]"
    }
  }
  if {[info exists execmenu]} {
    .workdir.menubar.user add separator
    foreach item [array names execmenu] {
      .workdir.menubar.user add command -label $item \
         -command "eval cvs_execcmd $execmenu($item) \[workdir_list_files\]"
    }
  }
  gen_log:log T "LEAVE"
}

proc workdir_list_files {} {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER (cvsglb(current_selection) = $cvsglb(current_selection))"

  for {set i 0} {$i < [llength $cvsglb(current_selection)]} {incr i} {
    set item [lindex $cvsglb(current_selection) $i]
    regsub {^no file } $item "" item
    # regsub here causes file isfile to return 0.  You have to do it in each
    # proc, just before the cvs command, after file tests have been done.
    #regsub -all {\$} $item {\$} item
    set cvsglb(current_selection) [lreplace $cvsglb(current_selection) $i $i $item]
  }
  gen_log:log T "LEAVE -- ($cvsglb(current_selection))"
  return $cvsglb(current_selection)
}

proc workdir_edit_command {file} {
  global cvscfg

  gen_log:log T "ENTER ($file)"
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

  gen_log:log T "ENTER ($file)"

  file mkdir $file

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc workdir_edit_file {args} {
  global cvscfg
  global cwd

  gen_log:log T "ENTER ($args)"

  set filelist [join $args]
  if {$filelist == ""} {
    file_input_and_do "Edit File" workdir_edit_file
    return
  }

  gen_log:log D "$filelist"
  foreach file $filelist {
    if {[file isdirectory $file]} {
      change_dir "$file"
    } else {
      if {![file exists $file] || [file isfile $file]} {
        # If the file doesn't exist it's tempting to touch the file and
        # trigger a reread, but is an empty file of this type valid?
        regsub -all {\$} $file {\$} file
        set commandline [workdir_edit_command $file]
        set editcmd [exec::new $commandline]
      } else {
        cvsfail "$file is not a plain file" .workdir
      }
    }
  }
  gen_log:log T "LEAVE"
}

proc workdir_view_file {args} {
  global cvscfg
  global cwd

  gen_log:log T "ENTER ($args)"

  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select some files to view first!" .workdir
    return
  }

  gen_log:log D "$filelist"
  foreach file $filelist {
    set filelog ""
    if {[file isfile $file]} {
      #regsub -all {\$} $file {\$} file
      gen_log:log F "OPEN $file"
      set f [open $file]
      while { [eof $f] == 0 } {
        append filelog [gets $f]
        append filelog "\n"
      }
      view_output::new "$file" $filelog
    } else {
      cvsfail "$file is not a plain file" .workdir
    }
  }
  gen_log:log T "LEAVE"
}

# Let the user mark directories they visit often
proc add_bookmark { } {
  global incvs inrcs insvn ingit
  global bookmarks

  gen_log:log T "ENTER"
  set dir [pwd]
  regsub -all {\$} $dir {\$} dir

  gen_log:log D "directory $dir"
  foreach mark [array names bookmarks] {
    gen_log:log D "  $mark \"$bookmarks($mark)\""
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

  gen_log:log T "LEAVE"
}

# A listbox to choose a bookmark to delete
proc delete_bookmark_dialog { } {
   global cvscfg
   global cvsglb
   global bookmarks

   gen_log:log T "ENTER"
   set maxlbl 0
   foreach mark [array names bookmarks] {
   gen_log:log D "  $mark $bookmarks($mark)"
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

   gen_log:log T "LEAVE"
}

# Do the actual deletion of the bookmark
proc delete_bookmark {w} {
  global bookmarks

  gen_log:log T "ENTER ($w)"
  set items [$w.lbx curselection]
  foreach item $items {
    set itemstring [$w.lbx get $item]
    #set dir [join [lrange $itemstring 0 end-1]]
    regsub {\s+$} $itemstring {} dir
    regsub {\s+\([A-Z][A-Z][A-Z]\)$} $dir {} dir
    gen_log:log D "$item \"$itemstring\""
    gen_log:log D "  directory \"$dir\""
    unset bookmarks($dir)
    $w.lbx delete $item
    .workdir.menubar.goto delete $itemstring
  }
   gen_log:log T "LEAVE"
}

proc change_dir {new_dir} {
  global cwd

  gen_log:log T "ENTER ($new_dir)"
  if {![file exists $new_dir]} {
    set cwd [pwd]
    cvsfail "Directory $new_dir doesn\'t exist!" .workdir
    return
  }
  set cwd $new_dir
  # Deleting the tree discards the saved scroll position
  # so we start with yview 0 in a new directory
  DirCanvas:deltree .workdir.main
  setup_dir

  gen_log:log T "LEAVE"
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

proc setup_dir { } {
  #
  # Call this when entering a directory.  It puts all of the file names
  # in the listbox, and reads the directory.
  #
  global cwd
  global module_dir
  global incvs insvn inrcs ingit
  global cvscfg
  global current_tagname
  global cvsglb

  gen_log:log T "ENTER"

  set savyview 0
  if { ! [winfo exists .workdir.main] } {
    workdir_setup
    return
  } else {
    if {[winfo exists .workdir.main.filecol.list]} {
      set savyview [lindex [.workdir.main.filecol.list yview] 0]
    }
    DirCanvas:deltree .workdir.main
  }
  gen_log:log D "YVIEW $savyview"

  if {![file isdirectory $cwd]} {
    gen_log:log D "$cwd is not a directory"
    gen_log:log T "LEAVE -- $cwd is not a directory"
    return
  }

  cd $cwd
  gen_log:log F "CD [pwd]"

  set module_dir ""
  set current_tagname ""
  ::picklist::used directory [pwd]

  lassign [cvsroot_check [pwd]] incvs insvn inrcs ingit
  gen_log:log D "incvs=$incvs inrcs=$inrcs insvn=$insvn ingit=$ingit"

  .workdir.top.bmodbrowse configure -image Modules
  .workdir.top.lmodule configure -text "Path"
  .workdir.top.ltagname configure -text "Tag"
  .workdir.top.lcvsroot configure -text "CVSROOT"
  .workdir.top.tcvsroot configure -textvariable cvscfg(cvsroot)
  set cvsglb(root) $cvscfg(cvsroot)
  set cvsglb(vcs) cvs

  # Start without revision-control menu
  gen_log:log D "CONFIGURE VCS MENUS"
  set rptmenu_idx [.workdir.menubar index "Reports"]
  foreach label {"RCS" "CVS" "SVN" "GIT"} {
    if {! [catch {set vcsmenu_idx [.workdir.menubar index "$label"]}]} {
      .workdir.menubar delete $vcsmenu_idx
    }
  }
  set rptmenu_idx [.workdir.menubar index "Reports"]
  #puts "reports $rptmenu_idx"
  #puts "----------"

  # Disable report menu items 
  .workdir.menubar.reports entryconfigure "Check Directory" -state disabled
  .workdir.menubar.reports entryconfigure "Status" -state disabled
  .workdir.menubar.reports entryconfigure "Log" -state disabled
  .workdir.menubar.reports entryconfigure "Annotate/Blame" -state disabled
  .workdir.menubar.reports entryconfigure "Info" -state disabled
  # Start with the revision-control buttons disabled
  .workdir.bottom.buttons.dirfuncs.bcheckdir configure -state disabled
  foreach widget [grid slaves .workdir.bottom.buttons.cvsfuncs ] {
    $widget configure -state disabled
  }
  foreach widget [grid slaves .workdir.bottom.buttons.cvsfuncs ] {
    $widget configure -state disabled
  }
  foreach widget [grid slaves .workdir.bottom.buttons.oddfuncs ] {
    #$widget configure -state disabled
    grid forget $widget 
  }

  # Default for these, only Git is different
  .workdir.bottom.buttons.cvsfuncs.bcheckin configure -state normal \
    -image Checkin
  .workdir.bottom.buttons.cvsfuncs.bupdate configure -state normal \
    -image Checkout
  set_tooltips .workdir.bottom.buttons.cvsfuncs.badd_files \
     {"Add the selected files to the repository"}
  set_tooltips .workdir.bottom.buttons.cvsfuncs.bremove \
     {"Remove the selected files from the repository"}
  set_tooltips .workdir.bottom.buttons.cvsfuncs.bcheckin \
     {"Check in (commit) the selected files to the repository"}
  set_tooltips .workdir.bottom.buttons.cvsfuncs.bupdate \
     {"Update (checkout, patch) the selected files from the repository"}
  set_tooltips .workdir.bottom.buttons.cvsfuncs.brevert \
     {"Revert the selected files, discarding local edits"}

  # Now enable them depending on where we are
  if {$inrcs} {
    # Top
    gen_log:log D "CONFIGURE RCS MENUS"
    .workdir.menubar insert $rptmenu_idx cascade -label "RCS" \
      -menu .workdir.menubar.rcs
    .workdir.top.lcvsroot configure -text "RCS *,v Path"
    .workdir.top.tcvsroot configure -textvariable cvscfg(rcsdir)
    set cvsglb(root) $cvscfg(rcsdir)
    set cvsglb(vcs) rcs
    # Buttons
    .workdir.bottom.buttons.dirfuncs.bcheckdir configure -state normal \
      -command { rcs_check }
    .workdir.bottom.buttons.cvsfuncs.bdiff configure -state normal
    .workdir.bottom.buttons.cvsfuncs.blogfile configure -state normal \
      -command { rcs_branches [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bfilelog configure -state normal \
      -command { rcs_log $cvscfg(ldetail) [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bupdate configure -state normal \
      -command { rcs_checkout [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bcheckin configure -state normal \
      -command { rcs_commit_dialog [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.brevert configure -state normal \
      -command { rcs_revert [workdir_list_files] }
    grid .workdir.bottom.buttons.oddfuncs.block          -column 0 -row 0
    grid .workdir.bottom.buttons.oddfuncs.bunlock        -column 0 -row 1
    .workdir.bottom.buttons.oddfuncs.block configure -state normal \
      -command { rcs_lock lock [workdir_list_files] }
    .workdir.bottom.buttons.oddfuncs.bunlock configure -state normal \
      -command { rcs_lock unlock [workdir_list_files] }
    # Reports menu for RCS
    # Check Directory (log & rdiff)
    .workdir.menubar.reports entryconfigure "Check Directory" -state normal \
       -command { rcs_check }
    .workdir.menubar.reports entryconfigure "Status" -state disabled
    # Log (rlog)
    .workdir.menubar.reports entryconfigure "Log" -state normal
    .workdir.menubar.reports.log_detail entryconfigure "Latest" \
       -command { rcs_log "latest" [workdir_list_files] }
    .workdir.menubar.reports.log_detail entryconfigure "Summary" \
       -command { rcs_log "summary" [workdir_list_files] }
    .workdir.menubar.reports.log_detail entryconfigure "Verbose" \
       -command { rcs_log "verbose" [workdir_list_files] }

    .workdir.menubar.reports entryconfigure "Annotate/Blame" -state disabled
    .workdir.menubar.reports entryconfigure "Info" -state disabled
    # Options for reports
    .workdir.menubar.reports entryconfigure "Report Unknown Files" -state disabled
    .workdir.menubar.reports entryconfigure "Report Recursively" -state disabled
  } elseif {$insvn} {
    # Top
    gen_log:log D "CONFIGURE SVN MENUS"
    .workdir.menubar insert $rptmenu_idx cascade -label "SVN" \
      -menu .workdir.menubar.svn
    .workdir.top.bmodbrowse configure -image Modules_svn \
      -command {modbrowse_run}
    .workdir.top.lmodule configure -text "Path"
    .workdir.top.ltagname configure -text "Tag"
    .workdir.top.lcvsroot configure -text "SVN URL"
    .workdir.top.tcvsroot configure -textvariable cvscfg(url)
    set cvsglb(root) $cvscfg(url)
    set cvsglb(vcs) svn
    # Buttons
    .workdir.bottom.buttons.dirfuncs.bcheckdir configure -state normal \
      -command { svn_check }
    .workdir.bottom.buttons.cvsfuncs.bjoin configure -state normal \
      -command { svn_branches . }
    .workdir.bottom.buttons.cvsfuncs.bdiff configure -state normal
    .workdir.bottom.buttons.cvsfuncs.blogfile configure -state normal \
      -command { svn_branches [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bfilelog configure -state normal \
      -command { svn_log $cvscfg(ldetail) [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bannotate configure -state normal \
      -command { svn_annotate BASE [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bconflict configure -state normal \
      -command { foreach f [workdir_list_files] {svn_merge_conflict \"$f\"} }
    .workdir.bottom.buttons.cvsfuncs.badd_files configure -state normal
    .workdir.bottom.buttons.cvsfuncs.bremove configure -state normal
    .workdir.bottom.buttons.cvsfuncs.bupdate configure -state normal \
      -command { svn_update [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bupdateopts configure -state normal \
     -command { svn_update_options }
    .workdir.bottom.buttons.cvsfuncs.bcheckin configure -state normal \
      -command svn_commit_dialog
    .workdir.bottom.buttons.cvsfuncs.brevert configure -state normal \
      -command { svn_revert [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.btag configure -state normal
    .workdir.bottom.buttons.cvsfuncs.bbranchtag configure -state normal
    grid .workdir.bottom.buttons.oddfuncs.block          -column 0 -row 0
    grid .workdir.bottom.buttons.oddfuncs.bunlock        -column 0 -row 1
    .workdir.bottom.buttons.oddfuncs.block configure -state normal \
      -command { svn_lock lock [workdir_list_files] }
    .workdir.bottom.buttons.oddfuncs.bunlock configure -state normal \
      -command { svn_lock unlock [workdir_list_files] }
    # Reports menu for SVN
    # Check Directory (svn status)
    .workdir.menubar.reports entryconfigure "Check Directory" -state normal \
       -command { svn_check }
    # Status (svn status <filelist>)
    .workdir.menubar.reports entryconfigure "Status" -state normal
    .workdir.menubar.reports.status_detail entryconfigure "Terse" \
       -command { svn_status "terse" [workdir_list_files] }
    .workdir.menubar.reports.status_detail entryconfigure "Summary" \
       -command { svn_status "summary" [workdir_list_files] }
    .workdir.menubar.reports.status_detail entryconfigure "Verbose" \
       -command { svn_status "verbose" [workdir_list_files] }
    # Log (svn log)
    .workdir.menubar.reports entryconfigure "Log" -state normal
    .workdir.menubar.reports.log_detail entryconfigure "Latest" \
       -command { svn_log "latest" [workdir_list_files] }
    .workdir.menubar.reports.log_detail entryconfigure "Summary" \
       -command { svn_log "summary" [workdir_list_files] }
    .workdir.menubar.reports.log_detail entryconfigure "Verbose" \
       -command { svn_log "verbose" [workdir_list_files] }
    # Annotate/Blame (svn blame)
    .workdir.menubar.reports entryconfigure "Annotate/Blame" -state normal \
       -command { svn_annotate BASE [workdir_list_files] }
    # General info (svn info)
    .workdir.menubar.reports entryconfigure "Info" -state normal \
       -command { svn_info [workdir_list_files] }
    # Options for reports
    .workdir.menubar.reports entryconfigure "Report Unknown Files" -state normal
    .workdir.menubar.reports entryconfigure "Report Recursively" -state normal
  } elseif {$incvs} {
    # Top
    gen_log:log D "CONFIGURE CVS MENUS"
    .workdir.menubar insert $rptmenu_idx cascade -label "CVS" \
      -menu .workdir.menubar.cvs
    .workdir.top.bmodbrowse configure -image Modules_cvs \
      -command {modbrowse_run}
    .workdir.top.lmodule configure -text "Module"
    .workdir.top.ltagname configure -text "Tag"
    .workdir.top.lcvsroot configure -text "CVSROOT"
    .workdir.top.tcvsroot configure -textvariable cvscfg(cvsroot)
    set cvsglb(root) $cvscfg(cvsroot)
    set cvsglb(vcs) cvs
    # Buttons
    .workdir.bottom.buttons.dirfuncs.bcheckdir configure -state normal \
      -command { cvs_check }
    .workdir.bottom.buttons.cvsfuncs.bjoin configure -state normal \
      -command cvs_joincanvas
    .workdir.bottom.buttons.cvsfuncs.bdiff configure -state normal
    .workdir.bottom.buttons.cvsfuncs.bconflict configure -state normal \
      -command { cvs_merge_conflict [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bfilelog configure -state normal \
      -command { cvs_log $cvscfg(ldetail) [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bannotate configure -state normal \
      -command { cvs_annotate $current_tagname [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.badd_files configure -state normal
    .workdir.bottom.buttons.cvsfuncs.bremove configure -state normal
    .workdir.bottom.buttons.cvsfuncs.bupdate configure -state normal \
       -command { \
       cvs_update {BASE} {Normal} {Remove} {recurse} {prune} {No} { } [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bupdateopts configure -state normal \
     -command { cvs_update_options }
    .workdir.bottom.buttons.cvsfuncs.bcheckin configure -state normal \
      -command cvs_commit_dialog
    .workdir.bottom.buttons.cvsfuncs.brevert configure -state normal \
      -command {cvs_revert [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.btag configure -state normal
    .workdir.bottom.buttons.cvsfuncs.bbranchtag configure -state normal
    .workdir.bottom.buttons.cvsfuncs.blogfile configure -state normal \
      -command { cvs_branches [workdir_list_files] }
    grid .workdir.bottom.buttons.oddfuncs.block          -column 0 -row 0
    grid .workdir.bottom.buttons.oddfuncs.bunlock        -column 0 -row 1
    grid .workdir.bottom.buttons.oddfuncs.bcvsedit_files -column 1 -row 0
    grid .workdir.bottom.buttons.oddfuncs.bunedit_files  -column 1 -row 1
    if {$cvscfg(econtrol)} {
      .workdir.bottom.buttons.oddfuncs.bcvsedit_files configure -state normal \
        -command { cvs_edit [workdir_list_files] }
      .workdir.bottom.buttons.oddfuncs.bunedit_files configure -state normal \
        -command { cvs_edit [workdir_list_files] }
    } else {
      .workdir.bottom.buttons.oddfuncs.bcvsedit_files configure -state disabled
      .workdir.bottom.buttons.oddfuncs.bunedit_files configure -state disabled
    }
    if {$cvscfg(cvslock)} {
      .workdir.bottom.buttons.oddfuncs.block configure -state normal \
        -command { cvs_lock lock [workdir_list_files] }
      .workdir.bottom.buttons.oddfuncs.bunlock configure -state normal \
        -command { cvs_lock unlock [workdir_list_files] }
    } else {
      .workdir.bottom.buttons.oddfuncs.block configure -state disabled
      .workdir.bottom.buttons.oddfuncs.bunlock configure -state disabled
    }
    # Reports menu for CVS
    # Check Directory (cvs -n -q update)
    .workdir.menubar.reports entryconfigure "Check Directory" -state normal \
       -command { cvs_check }
    # Status (cvs -Q status)
    .workdir.menubar.reports entryconfigure "Status" -state normal
    .workdir.menubar.reports.status_detail entryconfigure "Terse" \
       -command { cvs_status "terse" [workdir_list_files] }
    .workdir.menubar.reports.status_detail entryconfigure "Summary" \
       -command { cvs_status "summary" [workdir_list_files] }
    .workdir.menubar.reports.status_detail entryconfigure "Verbose" \
       -command { cvs_status "verbose" [workdir_list_files] }
    # Log (cvs log)
    .workdir.menubar.reports entryconfigure "Log" -state normal
    .workdir.menubar.reports.log_detail entryconfigure "Latest" \
       -command { cvs_log "latest" [workdir_list_files] }
    .workdir.menubar.reports.log_detail entryconfigure "Summary" \
       -command { cvs_log "summary" [workdir_list_files] }
    .workdir.menubar.reports.log_detail entryconfigure "Verbose" \
       -command { cvs_log "verbose" [workdir_list_files] }
    # Annotate/Blame (cvs annotate)
    .workdir.menubar.reports entryconfigure "Annotate/Blame" -state normal \
       -command { cvs_annotate $current_tagname [workdir_list_files] }
    .workdir.menubar.reports entryconfigure "Info" -state disabled
    # Options for reports
    .workdir.menubar.reports entryconfigure "Report Unknown Files" -state normal
    .workdir.menubar.reports entryconfigure "Report Recursively" -state normal
  } elseif {$ingit} {
    # Top
    gen_log:log D "CONFIGURE GIT MENUS"
    .workdir.menubar insert $rptmenu_idx cascade -label "GIT" \
      -menu .workdir.menubar.git
    .workdir.top.bmodbrowse configure -image Modules_git \
      -command {modbrowse_run}
    .workdir.top.lmodule configure -text "path"
    .workdir.top.ltagname configure -text "branch"
    .workdir.top.lcvsroot configure -text "$cvscfg(origin)"
    .workdir.top.tcvsroot configure -textvariable cvscfg(url)
    set cvsglb(root) $cvscfg(url)
    set cvsglb(vcs) git
    # Buttons
    .workdir.bottom.buttons.dirfuncs.bcheckdir configure -state normal \
      -command { git_check }
    .workdir.bottom.buttons.cvsfuncs.bdiff configure -state normal
    .workdir.bottom.buttons.cvsfuncs.bconflict configure -state normal \
      -command { foreach f [workdir_list_files] {git_merge_conflict \"$f\"} }
    .workdir.bottom.buttons.cvsfuncs.blogfile configure -state normal \
      -command { git_branches [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bfilelog configure -state normal \
      -command { git_log $cvscfg(ldetail) [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bannotate configure -state normal \
      -command { git_annotate $current_tagname [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bcheckin configure -state normal \
      -image GitCheckin -command { git_commit_dialog }
    .workdir.bottom.buttons.cvsfuncs.brevert configure -state normal \
      -command { git_reset [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.bupdate configure -state normal \
      -image GitCheckout -command { git_checkout [workdir_list_files] }
    .workdir.bottom.buttons.cvsfuncs.badd_files configure -state normal
    .workdir.bottom.buttons.cvsfuncs.bremove configure -state normal
    grid .workdir.bottom.buttons.oddfuncs.bpush  -column 0 -row 0
    grid .workdir.bottom.buttons.oddfuncs.bfetch  -column 0 -row 1
    .workdir.bottom.buttons.oddfuncs.block configure -state normal \
      -command { rcs_lock lock [workdir_list_files] }
    .workdir.bottom.buttons.oddfuncs.bunlock configure -state normal \
      -command { rcs_lock unlock [workdir_list_files] }
    set_tooltips .workdir.bottom.buttons.cvsfuncs.badd_files \
       {"Add the selected files to the staging area"}
    set_tooltips .workdir.bottom.buttons.cvsfuncs.bremove \
       {"Remove the selected files from the staging area"}
    set_tooltips .workdir.bottom.buttons.cvsfuncs.bcheckin \
       {"Check in (commit) the selected files to the staging area"}
    set_tooltips .workdir.bottom.buttons.cvsfuncs.bupdate \
       {"Update (checkout, patch) the selected files from the staging area"}
    set_tooltips .workdir.bottom.buttons.cvsfuncs.brevert \
       {"Reset, discarding local edits"}
    # Reports menu for GIT
    # Check Directory (git status --short)
    .workdir.menubar.reports entryconfigure "Check Directory" -state normal \
       -command { git_check }
    # Status (git status -v)
    .workdir.menubar.reports entryconfigure "Status" -state normal
    .workdir.menubar.reports.status_detail entryconfigure "Terse" \
       -command { git_status "terse" [workdir_list_files] }
    .workdir.menubar.reports.status_detail entryconfigure "Summary" \
       -command { git_status "summary" [workdir_list_files] }
    .workdir.menubar.reports.status_detail entryconfigure "Verbose" \
       -command { git_status "verbose" [workdir_list_files] }
    # Log (git log)
    .workdir.menubar.reports entryconfigure "Log" -state normal
    .workdir.menubar.reports.log_detail entryconfigure "Latest" \
       -command { git_log "latest" [workdir_list_files] }
    .workdir.menubar.reports.log_detail entryconfigure "Summary" \
       -command { git_log "summary" [workdir_list_files] }
    .workdir.menubar.reports.log_detail entryconfigure "Verbose" \
       -command { git_log "verbose" [workdir_list_files] }
    # Annotate/Blame
    .workdir.menubar.reports entryconfigure "Annotate/Blame" -state disabled
    .workdir.menubar.reports entryconfigure "Info" -state disabled
    # Options for reports
    .workdir.menubar.reports entryconfigure "Report Unknown Files" -state normal
    .workdir.menubar.reports entryconfigure "Report Recursively" -state disabled
  }

  DirCanvas:create .workdir.main
  pack .workdir.main.pw -side bottom -fill both -expand yes

  set cvsglb(current_selection) {}

  set cvscfg(ignore_file_filter) $cvsglb(default_ignore_filter)

  if { [ file exists ".cvsignore" ] } {
    set fileId [ open ".cvsignore" "r" ]
    while { [ eof $fileId ] == 0 } {
      gets $fileId line
      append cvscfg(ignore_file_filter) " $line"
    }
    close $fileId
  } else {
    if {$insvn} {
      # Have to do eval exec because we need the error output
      set command "svn propget svn:ignore"
      gen_log:log C "$command"
      set ret [catch {eval "exec $command"} output]
      if {$ret} {
        gen_log:log E "$output"
      } else {
        gen_log:log F "$output"
        foreach infoline [split $output "\n"] {
          append cvscfg(ignore_file_filter) " $infoline"
        }
      }
    }
  }

  set filelist [ getFiles ]
  directory_list $filelist
  # Update, otherwise it won't be mapped before we restore the scroll position
  update
  DirCanvas:yview_windows .workdir.main $savyview

  gen_log:log T "LEAVE"
}

proc directory_list { filenames } {
  global module_dir
  global incvs inrcs insvn ingit
  global cvs
  global cwd
  global cvscfg
  global cvsglb
  global cmd
  global Filelist

  gen_log:log T "ENTER ($filenames)"

  if {[info exists Filelist]} {
    unset Filelist
  }

  busy_start .workdir.main

  #gen_log:log F "processing files in the local directory"
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
      gen_log:log D "SKIPPING $i"
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
      if {$incvs} {
        set Filelist($i:status) "Not managed by CVS"
      } else {
        set Filelist($i:status) "<file>"
      }
    }
    #set Filelist($i:wrev) ""
    set Filelist($i:stickytag) ""
    set Filelist($i:option) ""
    # Prepending ./ to the filename prevents tilde expansion
    catch {set Filelist($i:date) \
       [clock format [file mtime ./$i] -format $cvscfg(dateformat)]}
  }

  gen_log:log D "incvs=$incvs insvn=$insvn inrcs=$inrcs ingit=$ingit"
  if {$incvs} {
    DirCanvas:headtext .workdir.main editcol "editors"
    cvs_workdir_status
  }

  if {$inrcs} {
    DirCanvas:headtext .workdir.main editcol "locked by"
    rcs_workdir_status
  }

  if {$insvn} {
    DirCanvas:headtext .workdir.main editcol "author"
    svn_workdir_status
  }

  if {$ingit} {
    DirCanvas:headtext .workdir.main wrevcol "hash"
    DirCanvas:headtext .workdir.main editcol "committer"
    git_workdir_status
  }

  gen_log:log D "Sending all files to the canvas"
  foreach i [array names Filelist *:status] {
    regsub {:status$} $i "" j
    # If it's locally removed or missing, it may not have
    # gotten a date especially on a remote client.
    if {! [info exists Filelist($j:date)]} {
      set Filelist($j:date) ""
    }
    DirCanvas:newitem .workdir.main "$j"
  }

  busy_done .workdir.main

  gen_log:log T "LEAVE"
}

proc workdir_cleanup {} {
  global cvscfg

  gen_log:log T "ENTER"
  set rmitem ""
  set list [ split $cvscfg(clean_these) " " ]
  foreach pattern $list {
    gen_log:log D "pattern $pattern"
    if { $pattern != "" } {
      set items [lsort [glob -nocomplain $pattern]]
      gen_log:log D "$items"
      if {[llength $items] != 0} {
        append rmitem " [concat $items]"
      }
    }
  }

  if {$rmitem != ""} {
    if { [ are_you_sure "You are about to delete:\n" $rmitem] == 1 } {
      gen_log:log F "DELETE $rmitem"
      eval file delete -force -- $rmitem
    }
  } else {
    gen_log:log F "No files to delete"
    cvsok "Nothing matched $cvscfg(clean_these)" .workdir
    return
  }
  setup_dir
  gen_log:log T "LEAVE"
}

proc workdir_delete_file {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"

  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select some files to delete first!" .workdir
    return
  }

  if { [ are_you_sure "This will delete these files from your local, working directory:\n" $filelist ] == 1 } {
    gen_log:log F "DELETE $filelist"
    eval file delete -force -- $filelist
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc are_you_sure {mess args} {
#
# General posting message
#
  global cvscfg

  gen_log:log T "ENTER ($mess $args)"

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
      gen_log:log T "LEAVE 0"
      return 0
    }
  }
  gen_log:log T "LEAVE 1"
  return 1
}

proc workdir_print_file {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"

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
  gen_log:log T "LEAVE"
}

proc cvsroot_check { dir } {
  global cvscfg
  global cvsglb
  global incvs insvn inrcs ingit

  gen_log:log T "ENTER ($dir)"

  lassign {0 0 0 0} incvs insvn inrcs ingit

  if {[file isfile [file join $dir CVS Root]]} {
    set incvs [ read_cvs_dir [file join $dir CVS] ]
    # Outta here, don't check for svn or rcs
    if {$incvs} {
      gen_log:log T "LEAVE ($incvs $insvn $inrcs $ingit)"
      return [list $incvs $insvn $inrcs $ingit]
    }
  }

  gen_log:log C "svn info"
  set svnret [catch {eval "exec svn info"} svnout]
  if {$svnret} {
    gen_log:log E $svnout
  } else {
    gen_log:log F $svnout
    set insvn [ read_svn_dir $dir ]
    if {$insvn} {
      gen_log:log T "LEAVE ($incvs $insvn $inrcs $ingit)"
      return [list $incvs $insvn $inrcs $ingit]
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

  if {$inrcs} {
    # Make sure we have rcs, and bag this (silently) if we don't   
    set command "rcs --version"
    gen_log:log C "$command"
    set ret [catch {eval "exec $command"} raw_rcs_log]
    gen_log:log F "$raw_rcs_log"
    if {$ret} {
       if [string match {rcs*} $raw_rcs_log] {
         # An old version of RCS, but it's here
         set inrcs 1
       } else {
         set inrcs 0
       }
    }
  }

  gen_log:log C "git rev-parse --is-inside-work-tree"
  set gitret [catch {eval "exec git rev-parse --is-inside-work-tree"} gitout]
  if {$gitret} {
    gen_log:log E "gitout $gitout"
    set ingit 0
  } else {
    # revparse may return "false" 
    gen_log:log F "gitout $gitout"
    if {$gitout} {
      set ingit 1
      find_git_remote $dir
    }
  }
  gen_log:log T "LEAVE ($incvs $insvn $inrcs $ingit)"
  return [list $incvs $insvn $inrcs $ingit]
}

proc isCmDirectory { file } {
  #gen_log:log T "ENTER ($file)"
  switch -- $file  {
    "CVS"  -
    "RCS"  -
    ".svn"  -
    ".git"  -
    "SCCS" { set value 1 }
    default { set value 0 }
  }
  #gen_log:log T "LEAVE ($value)"
  return $value
}

# Get the files in the current working directory.  Use the file_filter
# values Add hidden files if desired by the user.  Sort them to match
# the ordering that will be returned by cvs commands (this matches the
# default ls ordering.).
proc getFiles { } {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER"
  set filelist ""

  # make sure the file filter is at least set to "*".
  if { $cvscfg(file_filter) == "" } {
    set cvscfg(file_filter) "* .svn"
  }

  # get the initial file list, including hidden if requested
  if {$cvscfg(allfiles)} {
    # get hidden as well
    foreach item $cvscfg(file_filter) {
      set filelist [ concat [ glob -nocomplain .$item $item ] $filelist ]
    }
  } else {
    foreach item $cvscfg(file_filter) {
      set filelist [ concat [ glob -nocomplain $item ] $filelist ]
    }
  }
  #gen_log:log D "filelist ($filelist)"

  # ignore files if requested
  if { $cvscfg(ignore_file_filter) != "" } {
    foreach item $cvscfg(ignore_file_filter) {
      # for each pattern
      if { $item != "*" } {
        # if not "*"
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

  set cvscfg(ignore_file_filter) $cvsglb(default_ignore_filter)
  gen_log:log T "return ($filelist)"
  return $filelist
}

proc log_toggle { } {
  global cvscfg

  if {$cvscfg(logging)} {
    gen_log:init
  } else {
    gen_log:quit
  }
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

  save_options
  set pid [pid]
  gen_log:log F "DELETE $cvscfg(tmpdir)/cvstmpdir.$pid"
  catch {file delete -force [file join $cvscfg(tmpdir) cvstmpdir.$pid]}
  exit
}

proc save_options { } {
#
# Save the options which are configurable from the GUI
#
  global cvscfg
  global logcfg
  global bookmarks

  gen_log:log T "ENTER"

  # There are two kinds of options we can set
  set BOOLopts { allfiles auto_status confirm_prompt \
                 showstatcol showdatecol showeditcol auto_tag \
                 status_filter recurse logging blame_linenums }
  set STRGopts { file_filter ignore_file_filter clean_these \
                 printer log_classes lastdir sort_pref editor editorargs \
                 workgeom modgeom loggeom tracgeom }

  # Plus the logcanvas options
  set LOGopts [concat [array names logcfg show_*] scale]

  # set this to current directory, so we'll add it to the menu next time
  if ([catch pwd]) {
    return
  }
  set cvscfg(lastdir) [pwd]

  if {[info exists cvscfg(editorargs)] } {
    # editorargs is no longer necessary
    if {$cvscfg(editorargs) != ""} {
      set cvscfg(editor) [concat $cvscfg(editor) $cvscfg(editorargs)]
    }
    unset cvscfg(editorargs)
  }

  # Save the list so we can keep track of what we've done
  set BOOLset $BOOLopts
  set STRGset $STRGopts
  set LOGset $LOGopts

  set optfile [file join $cvscfg(home) .tkcvs]
  set bakfile [file join $cvscfg(home) .tkcvs.bak]
  # Save the old .tkcvs file
  gen_log:log F "MOVE $optfile $bakfile"
  catch {file rename -force $optfile $bakfile}

  gen_log:log F "OPEN $optfile"
  if {[catch {set fo [open $optfile w]}]} {
    cvsfail "Cannot open $optfile for writing" .workdir
    return
  }
  gen_log:log F "OPEN $bakfile"

  if {! [catch {set fi [open $bakfile r]}]} {
    while { [eof $fi] == 0 } {
      gets $fi line
      set match 0
      if {[regexp {^#} $line]} {
        # Don't try to scan comments.
        #gen_log:log D "PASSING \"$line\""
        puts $fo "$line"
        continue
      } elseif {[string match "*set *bookmarks*" $line]} {
        # Discard old bookmarks
        continue
      } else {
        foreach opt $BOOLopts {
          if {! [info exists cvscfg($opt)]} { continue }
          if {[string match "*set *cvscfg($opt)*" $line]} {
            # Print it and remove it from the list
            gen_log:log D "REPLACING $line  w/ set cvscfg($opt) $cvscfg($opt)"
            puts $fo "set cvscfg($opt) $cvscfg($opt)"
            set idx [lsearch $BOOLset $opt]
            set BOOLset [lreplace $BOOLset $idx $idx]
            set match 1
            break
          }
        }
        if {[string match "*set *cvscfg(checkrecursive)*" $line]} {
          # This helps us recover from a problem left behind by tkcvs 7.2
          continue
        }
        foreach opt $STRGopts {
          if {! [info exists cvscfg($opt)]} { continue }
          if {[string match "*set *cvscfg($opt)*" $line]} {
            # Print it and remove it from the list
            gen_log:log D "REPLACING $line  w/ set cvscfg($opt) $cvscfg($opt)"
            puts $fo "set cvscfg($opt) \{$cvscfg($opt)\}"
            set idx [lsearch $STRGset $opt]
            set STRGset [lreplace $STRGset $idx $idx]
            set match 1
            break
          }
        }
        if {[string match "*set *cvscfg(editorargs)*" $line]} {
          # editorargs is no longer necessary
          continue
        }
        foreach opt $LOGopts {
          if {! [info exists logcfg($opt)]} { continue }
          if {[string match "*set *logcfg($opt)*" $line]} {
            # Print it and remove it from the list
            gen_log:log D "REPLACING \"$line\"  w/ set logcfg($opt) \"$logcfg($opt)\""
            puts $fo "set logcfg($opt) \"$logcfg($opt)\""
            set idx [lsearch $LOGset $opt]
            set LOGset [lreplace $LOGset $idx $idx]
            set match 1
            break
          }
        }
        if {$match == 0} {
          # We didn't do a replacement
          gen_log:log D "PASSING \"$line\""
          # If we don't check this, we get an extra blank line every time
          # we save the file.  Messy.
          if {[eof $fi] == 1} { break }
          puts $fo "$line"
        }
      }
    }
    foreach mark [lsort [array names bookmarks]] {
      gen_log:log D "Adding bookmark \"$mark\""
      puts $fo "set \"bookmarks($mark)\" \"$bookmarks($mark)\""
    }

    close $fi
  }

  # Print what's left over
  foreach opt $BOOLset {
    if {! [info exists cvscfg($opt)]} { continue }
    gen_log:log D "ADDING cvscfg($opt) $cvscfg($opt)"
    puts $fo "set cvscfg($opt) $cvscfg($opt)"
  }

  foreach opt $STRGset {
    if {! [info exists cvscfg($opt)]} { continue }
    gen_log:log D "ADDING cvscfg($opt) \"$cvscfg($opt)\""
    puts $fo "set cvscfg($opt) \"$cvscfg($opt)\""
  }

  foreach opt $LOGset {
    if {! [info exists logcfg($opt)]} { continue }
    gen_log:log D "ADDING logcfg($opt) \"$logcfg($opt)\""
    puts $fo "set logcfg($opt) \"$logcfg($opt)\""
  }

  close $fo
  ::picklist::save
  gen_log:log T "LEAVE"
}

