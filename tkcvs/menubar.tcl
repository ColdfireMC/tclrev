# The menus for the top menubar(s)

# First, set up the more or less universal ones that we want
# on all toplevels
proc menubar_menus {topwin} {
  global cvscfg
  global cvsglb
  global cvsmenu
  global usermenu
  global execmenu
  global bookmarks
  global git_log_opt

  gen_log:log T "ENTER"
  set startdir "[pwd]"

  if [winfo exists $topwin.menubar] {
    destroy $topwin.menubar
  }
  menu $topwin.menubar

  $topwin.menubar add cascade -label "TkCVS" -menu [menu $topwin.menubar.about]
  about_menus $topwin.menubar.about

  $topwin.menubar add cascade -label "File" -menu [menu $topwin.menubar.file] -underline 0
  if {$topwin eq ".workdir"} {
    $topwin.menubar add cascade -label "Options" -menu [menu $topwin.menubar.options] -underline 0
  } else {
    $topwin.menubar add cascade -label "Git" -menu [menu $topwin.menubar.gitopts]
  }

  $topwin.menubar add cascade -label "Go" -menu [menu $topwin.menubar.goto] -underline 0
  $topwin.menubar.goto add command -label "Go Home" \
     -command {change_dir $cvscfg(home)}
  $topwin.menubar.goto add command -label "Add Bookmark" \
     -command add_bookmark
  $topwin.menubar.goto add command -label "Delete Bookmark" \
     -command delete_bookmark_dialog
  $topwin.menubar.goto add separator
  foreach mark [lsort [array names bookmarks]] {
    # Backward compatibility.  Value used to be a placeholder, is now a revsystem type
    if {$bookmarks($mark) == "t"} {set bookmarks($mark) ""}
    $topwin.menubar.goto add command -label "$mark $bookmarks($mark)" \
       -command "change_dir \"$mark\""
  }
  # Have to do this after the apple menu
  $topwin configure -menu $topwin.menubar

  $topwin.menubar.file add separator
  $topwin.menubar.file add command -label "Shell" -underline 0 \
     -command { exec::new $cvscfg(shell) }
  $topwin.menubar.file add separator
  $topwin.menubar.file add command -label "Close window" -underline 1 \
     -command {$topwin.close invoke}
  $topwin.menubar.file add command -label Exit -underline 1 \
     -command { exit_cleanup 1 }
}

# The Working Directory menubar
proc workdir_menus {topwin} {
  global cvscfg
  global cvsglb
  global cvsmenu
  global usermenu
  global execmenu
  global bookmarks
  global git_log_opt

  gen_log:log T "ENTER"

  # File menu
  $topwin.menubar.file insert 1 command -label "Browse Modules" -underline 0 \
     -command modbrowse_run
  $topwin.menubar.file insert 1 separator
  $topwin.menubar.file insert 1 command -label "Cleanup Directory" -underline 4 \
     -command workdir_cleanup
  $topwin.menubar.file insert 1 command -label "Make New Directory" -underline 0 \
     -command { file_input_and_do "New Directory" workdir_newdir}
  $topwin.menubar.file insert 1 command -label "Print Selected File" -underline 0 \
     -command { workdir_print_file  [workdir_list_files ] }
  $topwin.menubar.file insert 1 command -label "Open Selection" -underline 0 \
     -command { workdir_edit_file [workdir_list_files] }

  set filemenu_idx [$topwin.menubar index "File"]
  menu $topwin.menubar.reports
  $topwin.menubar insert [expr {$filemenu_idx + 1}] cascade -label "Reports" \
     -menu $topwin.menubar.reports -underline 2

  # CVS - create it now, but place it later
  menu $topwin.menubar.cvs
  $topwin.menubar.cvs add command -label "Update" -underline 0 \
     -command { \
        cvs_update {BASE} {Normal} {Remove} {recurse} {prune} {No} { } [workdir_list_files] }
  $topwin.menubar.cvs add command -label "Update with Options" -underline 13 \
     -command cvs_update_options
  $topwin.menubar.cvs add command -label "Commit/Checkin" -underline 5 \
     -command cvs_commit_dialog
  $topwin.menubar.cvs add command -label "Revert" -underline 3 \
     -command cvs_revert
  $topwin.menubar.cvs add command -label "Add Files" -underline 0 \
     -command { add_dialog [workdir_list_files] }
  $topwin.menubar.cvs add command -label "Add Recursively" \
     -command { addir_dialog [workdir_list_files] }
  $topwin.menubar.cvs add command -label "Remove Files" -underline 0 \
     -command { subtract_dialog [workdir_list_files] }
  $topwin.menubar.cvs add command -label "Remove Recursively" \
     -command { subtractdir_dialog [workdir_list_files] }
  $topwin.menubar.cvs add command -label "Tag" -underline 0 \
     -command { tag_dialog }
  $topwin.menubar.cvs add command -label "Branch" -underline 0 \
     -command { branch_dialog }
  $topwin.menubar.cvs add command -label "Join (Merge) Directory" \
     -underline 0 -command { cvs_directory_merge }
  $topwin.menubar.cvs add separator
  $topwin.menubar.cvs add command -label "Release" \
     -command { release_dialog [workdir_list_files] }
  $topwin.menubar.cvs add command -label "Import CWD into Repository" \
     -underline 0 -command import_run

  # SVN - create it now, but place it later
  menu $topwin.menubar.svn
  $topwin.menubar.svn add command -label "Update" -underline 0 \
     -command {svn_update [workdir_list_files]}
  $topwin.menubar.svn add command -label "Resolve (Un-mark Conflict)" \
     -command {svn_resolve [workdir_list_files]}
  $topwin.menubar.svn add command -label "Commit/Checkin" -underline 0 \
     -command svn_commit_dialog
  $topwin.menubar.svn add command -label "Revert" -underline 3 \
     -command svn_revert
  $topwin.menubar.svn add command -label "Add Files" -underline 0 \
     -command { add_dialog [workdir_list_files] }
  $topwin.menubar.svn add command -label "Remove Files" -underline 0 \
     -command { subtract_dialog [workdir_list_files] }
  $topwin.menubar.svn add command -label "Tag" -underline 0 \
     -command { tag_dialog }
  $topwin.menubar.svn add command -label "Branch" -underline 0 \
     -command { branch_dialog }
  $topwin.menubar.svn add separator
  $topwin.menubar.svn add command -label "Import CWD into Repository" \
     -underline 0 -command svn_import_run

  # RCS - create it now, but place it later
  menu $topwin.menubar.rcs
  $topwin.menubar.rcs add command -label "Checkout" -underline 6 \
     -command { rcs_checkout [workdir_list_files] }
  $topwin.menubar.rcs add command -label "Checkin" -underline 6 \
     -command { rcs_commit_dialog [workdir_list_files] }
  $topwin.menubar.rcs add command -label "Revert" -underline 3 \
     -command rcs_revert

  # GIT - create it now, but place it later
  menu $topwin.menubar.git
  $topwin.menubar.git add command -label "GiTk" \
     -command {cvs_execcmd gitk [workdir_list_files]}
  $topwin.menubar.git add separator
  $topwin.menubar.git add command -label "Checkout/Update" -underline 6 \
     -command {git_checkout [workdir_list_files]}
  $topwin.menubar.git add command -label "Update with Options" -underline 13 \
     -command { git_update_options }
  $topwin.menubar.git add command -label "Commit/Checkin" -underline 5 \
     -command git_commit_dialog
  $topwin.menubar.git add command -label "Revert/Reset" -underline 3 \
     -command git_reset
  $topwin.menubar.git add command -label "Add Files" -underline 0 \
     -command { add_dialog [workdir_list_files] }
  $topwin.menubar.git add command -label "Remove Files" -underline 0 \
     -command { subtract_dialog [workdir_list_files] }
  $topwin.menubar.git add command -label "Tag" -underline 0 \
     -command { tag_dialog }
  $topwin.menubar.git add command -label "Branch" -underline 0 \
     -command { branch_dialog }

  # Status and log
  $topwin.menubar.reports add command -label "Check Directory" -underline 0
  $topwin.menubar.reports add cascade -label "Status" -underline 0 \
     -menu $topwin.menubar.reports.status_detail
  menu $topwin.menubar.reports.status_detail
  menu $topwin.menubar.reports.log_detail
  $topwin.menubar.reports.status_detail add command -label "Terse"
  $topwin.menubar.reports.status_detail add command -label "Summary"
  $topwin.menubar.reports.status_detail add command -label "Verbose"
  $topwin.menubar.reports add cascade -label "Log" -underline 0 \
     -menu $topwin.menubar.reports.log_detail
  $topwin.menubar.reports.log_detail add command -label "Latest"
  $topwin.menubar.reports.log_detail add command -label "Summary"
  $topwin.menubar.reports.log_detail add command -label "Verbose"

  $topwin.menubar.reports add command -label "Annotate/Blame" -underline 0
  $topwin.menubar.reports add command -label "Info" -underline 0
  $topwin.menubar.reports add separator
  $topwin.menubar.reports add checkbutton -label "Report Unknown Files" \
     -variable cvscfg(status_filter) -onvalue false -offvalue true
  $topwin.menubar.reports add checkbutton -label "Report Recursively" \
     -variable cvscfg(recurse) -onvalue true -offvalue false

  $topwin.menubar.options add checkbutton -label "Show hidden files" \
     -variable cvscfg(allfiles) -onvalue true -offvalue false \
     -command setup_dir
  $topwin.menubar.options add checkbutton -label "Automatic directory status" \
     -variable cvscfg(auto_status) -onvalue true -offvalue false
  $topwin.menubar.options add checkbutton -label "Confirmation Dialogs" \
     -variable cvscfg(confirm_prompt) -onvalue true -offvalue false
  $topwin.menubar.options add separator
  $topwin.menubar.options add checkbutton -label "Status Column" \
     -variable cvscfg(showstatcol) -onvalue true -offvalue false \
     -command "DirCanvas:displaycolumns $topwin.main.tree"
  $topwin.menubar.options add checkbutton -label "Date Column" \
     -variable cvscfg(showdatecol) -onvalue true -offvalue false \
     -command "DirCanvas:displaycolumns $topwin.main.tree"
  $topwin.menubar.options add checkbutton -label "Revision/Hash Column" \
     -variable cvscfg(showwrevcol) -onvalue true -offvalue false \
     -command "DirCanvas:displaycolumns $topwin.main.tree"
  $topwin.menubar.options add checkbutton -label "Editor/Author/Locker Column" \
     -variable cvscfg(showeditcol) -onvalue true -offvalue false \
     -command "DirCanvas:displaycolumns $topwin.main.tree"
  $topwin.menubar.options add separator
  $topwin.menubar.options add checkbutton -label "Git Detailed Status" \
     -variable cvscfg(gitdetail) -onvalue true -offvalue false \
     -command { setup_dir }
  $topwin.menubar.options add separator

  # User-defined commands
  if { [info exists cvsmenu] || \
       [info exists usermenu] || \
       [info exists execmenu]} {
    .workdir.menubar add cascade -label "User Defined" -menu [menu .workdir.menubar.user] -underline 0
    gen_log:log T "Adding user defined menu"
    if {[info exists cvsmenu]} {
      foreach item [array names cvsmenu] {
        $topwin.menubar.user add command -label $item \
           -command "eval cvs_usercmd $cvsmenu($item) \[workdir_list_files\]"
      }
    }
    if {[info exists usermenu]} {
      $topwin.menubar.user add separator
      foreach item [array names usermenu] {
        $topwin.menubar.user add command -label $item \
           -command "eval cvs_catchcmd $usermenu($item) \[workdir_list_files\]"
      }
    }
    if {[info exists execmenu]} {
      $topwin.menubar.user add separator
      foreach item [array names execmenu] {
        $topwin.menubar.user add command -label $item \
           -command "eval cvs_execcmd $execmenu($item) \[workdir_list_files\]"
      }
    }
  }

  $topwin.menubar.options add separator
  $topwin.menubar.options add checkbutton -label "Tracing On/Off" \
     -variable cvscfg(logging) -onvalue true -offvalue false \
     -command log_toggle
  $topwin.menubar.options add command -label "Save Options" -underline 0 \
     -command save_options

  gen_log:log T "LEAVE"
}

# Menubar for the Branch Browser
proc branch_menus {topwin} {
  $topwin.menubar.options add separator
  $topwin.menubar.options add checkbutton -label "Tracing On/Off" \
     -variable cvscfg(logging) -onvalue true -offvalue false \
     -command log_toggle
  $topwin.menubar.options add command -label "Save Options" -underline 0 \
     -command save_options
}

# Actions and preferences for Git
proc git_branch_menu {topwin files} {
  global cvscfg
  global git_log_opt

  # gitk takes maximum one filename
  set file [lindex $files 0]
  $topwin.menubar.gitopts add command -label "GiTk" \
     -command "cvs_execcmd gitk $file"
  $topwin.menubar.gitopts add separator
  $topwin.menubar.gitopts add cascade -label "Git log options" -menu [menu $topwin.menubar.gitopts.logopts]
  set all_gitlog_opts [list  "--first-parent" "--full-history" "--sparse" "--no-merges"]
  foreach o $all_gitlog_opts {
    if {$o in $cvscfg(gitlog_opts)} {
      set git_log_opt($o) 1
    } else {
      set git_log_opt($o) 0
    }
  }
  foreach opt $all_gitlog_opts {
     $topwin.menubar.gitopts.logopts add checkbutton -label $opt \
       -variable git_log_opt($opt) -onvalue 1 -offvalue 0 \
       -command {
           global cvscfg
           global git_log_opt

           gen_log:log D "cvscfg(gitlog_opts) $cvscfg(gitlog_opts)"
           set cvscfg(gitlog_opts) ""
           foreach go [array names git_log_opt] {
             if {$git_log_opt($go)} {
               append cvscfg(gitlog_opts) "$go "
             }
           }
           gen_log:log D "cvscfg(gitlog_opts) $cvscfg(gitlog_opts)"
      }
    }
    $topwin.menubar.gitopts add cascade -label "Branches groups" -menu [menu $topwin.menubar.gitopts.branches]
    $topwin.menubar.gitopts.branches add radiobutton -label " File-specific" \
      -variable cvscfg(gitbranchgroups) -value "F"
    $topwin.menubar.gitopts.branches add radiobutton -label " All Local" \
      -variable cvscfg(gitbranchgroups) -value "FL"
    $topwin.menubar.gitopts.branches add radiobutton -label " Local + Remote" \
      -variable cvscfg(gitbranchgroups) -value "FLR"
}

# The Help menu
proc help_menu {topwin} {

  # Help menu
  $topwin.menubar add cascade -label "Help" -menu $topwin.menubar.help -underline 0

  menu $topwin.menubar.help
  $topwin.menubar.help add separator
  $topwin.menubar.help add command -label "Current Directory Display" \
     -command current_directory
  $topwin.menubar.help add command -label "Module Browser" \
     -command module_browser
  $topwin.menubar.help add command -label "Branch Diagram Browser" \
     -command log_browser
  $topwin.menubar.help add command -label "Merge Tool" \
     -command directory_branch_viewer
  $topwin.menubar.help add separator
  $topwin.menubar.help add command -label "Repository Browser" \
     -command module_browser
  $topwin.menubar.help add command -label "Importing New Modules" \
     -command importing_new_modules
  $topwin.menubar.help add command -label "Importing To An Existing Module" \
     -command importing_to_existing_module
  $topwin.menubar.help add command -label "Vendor Merge" \
     -command vendor_merge
  $topwin.menubar.help add separator
  $topwin.menubar.help add command -label "Configuration Files" \
     -command configuration_files
  $topwin.menubar.help add command -label "Environment Variables" \
     -command environment_variables
  $topwin.menubar.help add command -label "Command Line Options" \
     -command cli_options
  $topwin.menubar.help add command -label "User Defined Menu" \
     -command user_defined_menu
  $topwin.menubar.help add command -label "CVS modules File" \
     -command cvs_modules_file
}

# The Module Browser menubars
proc modbrowse_menus {topwin} {
  global cvscfg
  global cvsglb
  global cvs
  global logclass

  # File menu
  $topwin.menubar.file insert 1 command -label "Browse Working Directory" -underline 0 \
     -command workdir_setup

  menu $topwin.menubar.cvs
  $topwin.menubar.cvs add command -label "CVS Checkout" \
      -command { dialog_cvs_checkout $cvscfg(cvsroot) $modbrowse_module}
  $topwin.menubar.cvs add command -label "CVS Export" \
      -command { dialog_cvs_export $cvscfg(cvsroot) $modbrowse_module}
  $topwin.menubar.cvs add command -label "Tag Module" -underline 0 \
     -command { rtag_dialog $cvscfg(cvsroot) $modbrowse_module "tag" }
  $topwin.menubar.cvs add command -label "Branch Tag Module" -underline 0 \
     -command { rtag_dialog $cvscfg(cvsroot) $modbrowse_module "branch" }
  $topwin.menubar.cvs add command -label "Make Patch File" -underline 0 \
     -command { dialog_cvs_patch $cvscfg(cvsroot) $modbrowse_module 0 }
  $topwin.menubar.cvs add command -label "View Patch Summary" -underline 0 \
     -command { dialog_cvs_patch $cvscfg(cvsroot) $modbrowse_module 1 }
  $topwin.menubar.cvs add separator
  $topwin.menubar.cvs add command -label "Import CWD to A New Module" -underline 0 \
     -command { import_run }
  $topwin.menubar.cvs add command -label "Import CWD to An Existing Module" -underline 0 \
     -command { import2_run }
  $topwin.menubar.cvs add command -label "Vendor Merge" -underline 0 \
     -command {merge_run $modbrowse_module}
  $topwin.menubar.cvs add separator
  $topwin.menubar.cvs add command -label "Show My Checkouts" -underline 0 \
     -command {cvs_history me ""}
  $topwin.menubar.cvs add command -label "Show Checkouts of Selected Module" -underline 0 \
     -command {cvs_history all $modbrowse_module}
  $topwin.menubar.cvs add command -label "Show All Checkouts" -underline 0 \
     -command {cvs_history all ""}

  menu $topwin.menubar.svn
  $topwin.menubar.svn add command -label "SVN Checkout" \
      -command { dialog_svn_checkout $cvscfg(svnroot) $modbrowse_path checkout}
  $topwin.menubar.svn add command -label "SVN Export" \
      -command { dialog_svn_checkout $cvscfg(svnroot) $modbrowse_path export}
  $topwin.menubar.svn add command -label "Tag Module" -underline 0 \
     -command { dialog_svn_tag $cvscfg(svnroot) $modbrowse_path "tags" }
  $topwin.menubar.svn add command -label "Branch Module" -underline 0 \
     -command { dialog_svn_tag $cvscfg(svnroot) $modbrowse_path "branches" }
  $topwin.menubar.svn add command -label "Make Patch File" -underline 0 \
     -command { dialog_svn_patch $cvscfg(svnroot) $modbrowse_path $selB_path 0 }
  $topwin.menubar.svn add command -label "View Patch Summary" -underline 0 \
     -command { dialog_svn_patch $cvscfg(svnroot) $modbrowse_path $selB_path 1 }
  $topwin.menubar.svn add separator
  $topwin.menubar.svn add command -label "Import CWD into Repository" \
     -command svn_import_run

  menu $topwin.menubar.git
  $topwin.menubar.git add command -label "Git Clone" \
     -command { dialog_git_clone $cvscfg(gitroot) $modbrowse_path }

  $topwin.menubar.options add checkbutton -label "Group Aliases in a Folder (CVS)" \
     -variable cvscfg(aliasfolder) -onvalue true -offvalue false \
     -command {
        $topwin.treeframe.pw delete [$topwin.treeframe.pw children {}]
        cvs_modbrowse_tree [lsort [array names modval]] "/"
     }
  $topwin.menubar.options add separator
  $topwin.menubar.options add checkbutton -label "Tracing On/Off" \
     -variable cvscfg(logging) -onvalue true -offvalue false \
     -command log_toggle
}

proc about_menus {aboutmenu} {

  # This goes in the Help menu unless we're on Apple, in which case
  # it goes at the top of the Apple menu
  $aboutmenu insert 0 command -label "About TkCVS" -underline 0 \
     -command aboutbox
  $aboutmenu insert 1 command -label "About CVS SVN RCS GIT" -underline 6 \
     -command {help_cvs_version 1}
  $aboutmenu insert 1 command -label "About Wish" -underline 6 \
     -command {wish_version}
}
