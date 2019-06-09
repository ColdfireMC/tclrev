#
# Columns for listing CVS files and their status
#

proc DirCanvas:create {w} {
  global cvscfg
  global cvsglb
  global incvs insvn inrcs ingit

  gen_log:log T "ENTER ($w)"

  set winwid [winfo width $w]
  set beginwid [expr {$winwid / 5}]

  if {! [winfo exists $w.tree] } {
    frame $w.pw
    pack $w.pw -fill both -expand 1

    ttk::treeview $w.tree -columns {filecol statcol datecol wrevcol editcol} \
      -yscroll "$w.yscroll set"
    scrollbar $w.yscroll -orient vertical \
      -relief sunken -command "$w.tree yview"
    pack $w.yscroll -in $w.pw -side right -fill y
    pack $w.tree -in $w.pw -side left -expand yes -fill both
  
    $w.tree heading filecol -text "File"
    $w.tree heading statcol -text "Status"
    $w.tree heading datecol -text "Date"
    $w.tree heading wrevcol -text "Revision"
    $w.tree heading editcol -text "Author"
  
    $w.tree column #0 -width [expr {$cvscfg(mod_iconwidth) + 4}]
    $w.tree column #0 -stretch no
  }
  foreach col {filecol statcol datecol wrevcol editcol} {
    $w.tree column $col -width $beginwid
    $w.tree heading $col -image "" -command "DirCanvas:sort_by_col $w.tree $col -increasing"
  }
  $w.tree heading #0 -image "" -command "DirCanvas:sort_by_col $w.tree statcol -increasing"

  gen_log:log D "incvs=$incvs insvn=$insvn inrcs=$inrcs ingit=$ingit"

  # We've set preliminary defaults, now use the column and sorting preferences
  gen_log:log D "sort_pref:  $cvscfg(sort_pref)"
  set col [lindex $cvscfg(sort_pref) 0]
  set sense [lindex $cvscfg(sort_pref) 1]
  # If we aren't in a VCS and therefore don't have editcol or wrevcol, sort by filename
  if { (! ($incvs || $inrcs || $insvn || $ingit))  && ( $col == "editcol" || $col == "wrevcol") } {
    gen_log:log T "setting sort to column \"filecol!\""
    set col "filecol"
    set sense "-increasing"
  }
  DirCanvas:displaycolumns $w.tree

  # Put an arrow on the column we're sorting by
  gen_log:log D "will sort by column $col $sense"
  if {[string match "-inc*" $sense]} {
    $w.tree heading $col -image arr_dn
    if {$col == "statcol"} {
      $w.tree heading #0 -image arr_dn
    }
  } else {
    $w.tree heading $col -image arr_up
    if {$col == "statcol"} {
      $w.tree heading #0 -image arr_up
    }
  }

  focus $w.tree
  if {! [winfo exists $w.paper_pop]} {
    DirCanvas:makepopup $w
  }
  gen_log:log T "LEAVE"
}

#
# Insert a new element $v into the list $w.
#
proc DirCanvas:newitem {w f} {
  global DirList
  global Filelist
  global cvsglb
  global incvs insvn inrcs ingit

  #gen_log:log T "ENTER ($w $f)"
  set rtype ""
  if {$inrcs} {
    set rtype "RCS"
  } elseif {$incvs} {
    set rtype "CVS"
  } elseif {$insvn} {
    set rtype "SVN"
  } elseif {$ingit} {
    set rtype "GIT"
  }

  set DirList($w:$f:name) $f
  gen_log:log D "Newitem $f status $Filelist($f:status)"
  set DirList($w:$f:status) $Filelist($f:status)
  set DirList($w:$f:date) $Filelist($f:date)
  if {[info exists Filelist($f:stickytag)]} {
    set DirList($w:$f:sticky) $Filelist($f:stickytag)
  } else {
    set DirList($w:$f:sticky) ""
  }
  if {[info exists Filelist($f:option)]} {
    set DirList($w:$f:option) $Filelist($f:option)
  } else {
    set DirList($w:$f:option) ""
  }
  if { [info exists Filelist($f:editors)]} {
    set DirList($w:$f:editors) $Filelist($f:editors)
  } else {
    set DirList($w:$f:editors) ""
  }
  catch {unset values}
  foreach vtag {name status date sticky editors} {
    lappend values $DirList($w:$f:$vtag)
  }
  DirCanvas:choose_icon $w $f $rtype
  $w.tree insert {} end -image $DirList($w:$f:icon) -values $values -tag fileobj

  #gen_log:log T "LEAVE"
}

proc DirCanvas:deltree {w} {
  global DirList

  foreach t [array names DirList $w:*] {
    unset DirList($t)
  }
  if {[winfo exists $w]} {
    $w delete [$w children {}]
  }
}

# This has the effect that if you click somewhere other than a row,
# the selection is cleared.
proc DirCanvas:unselectall {w} {
  global DirList
  global cvsglb

  gen_log:log T "ENTER ($w)"
  
  $w.tree selection set {}
  set DirList($w:selection) {}
  set cvsglb(current_selection) {}

  gen_log:log T "LEAVE"
}

# Show and hide columns according to the values of cvscfg(show*col)
# Yes we could put them in a list variable, but that wouldn't be
# backward compatible.
proc DirCanvas:displaycolumns {wt} {
  global cvscfg
  global incvs insvn inrcs ingit

  gen_log:log T "ENTER ($wt)"

  set col [lindex $cvscfg(sort_pref) 0]
  set sense [lindex $cvscfg(sort_pref) 1]
  gen_log:log D "[$wt configure -displaycolumns]"
  # The file column is mandatory
  set displayed_columns {filecol}
  # These columns are always possible
  foreach column {statcol datecol} {
    if {$cvscfg(show$column)} {
      lappend displayed_columns $column
    }
  }

  # Deciding whether to show the editcol is complicated.
  # We don't do it if we're not in a VCS, obviously.
  # But we also don't do it if we're in Git but not showing gitdetail,
  # or if we're in CVS but not doing econtrol or locking.
  set can_show(editcol) 0
  set can_show(wrevcol) 0
  if { ($inrcs || $insvn ) } {
    set can_show(editcol) 1
    set can_show(wrevcol) 1
  }
  if {$ingit && $cvscfg(gitdetail)} {
    set can_show(editcol) 1
    set can_show(wrevcol) 1
  }
  if {$incvs} {
    set can_show(wrevcol) 1
    if {$cvscfg(econtrol) || $cvscfg(cvslock)} {
      set can_show(editcol) 1
    }
  }
  foreach column {wrevcol editcol} {
    if {$can_show($column)} {
      if {$cvscfg(show$column)} {
        lappend displayed_columns $column
      }
    }
  }
  $wt configure -displaycolumns $displayed_columns
  gen_log:log D "$displayed_columns"

  DirCanvas:adjust_columnwidths $wt

  gen_log:log T "LEAVE"
}

proc DirCanvas:sort_by_col {wt col sense} {
  global DirList
  global cvscfg

  gen_log:log T "ENTER ($wt $col $sense)"

  set old_columnpref [lindex $cvscfg(sort_pref) 0]
  set old_sensepref [lindex $cvscfg(sort_pref) 1]

  set all_columns [lindex [$wt configure -columns] end]
  set displayed_columns [lindex [$wt configure -displaycolumns] end]
  if {$displayed_columns eq "#all"} {
    set displayed_columns $all_columns
  }

  # Always start with a list sorted by filename.  Collects the values from the
  # filename column, together with the row index
  set list_by_name {}
  foreach item [$wt children {}] {
    lappend list_by_name [list [$wt set $item filecol] $item]
  }
  set list_by_name [lsort -index 0 $list_by_name]

  # Collect the values from the column we want to sort by, together
  # with the row index
  set ID_by_name {}
  foreach item $list_by_name {
    lappend ID_by_name [lindex $item 1]
  }
  set column_items {}
  foreach item $ID_by_name {
    lappend column_items [list [$wt set $item $col] $item]
  }

  # Re-order the rows in the order obtained above
  set r -1
  foreach info [lsort $sense -index 0 $column_items] {
    $wt move [lindex $info 1] {} [incr r]
  }

  # Fix up the arrows
  foreach a $displayed_columns {
    $wt heading $a -image ""
  }
  $wt heading #0 -image ""

  # Reset the columns other than the current one. We're heavily favoring defaulting
  # to increasing sorting order here. This is the way I like it to work, although
  # others might argue. -dar
  foreach c {filecol statcol datecol wrevcol editcol} {
    $wt heading $c -image "" -command "DirCanvas:sort_by_col $wt $c -increasing"
  }
  $wt heading #0 -image "" -command "DirCanvas:sort_by_col $wt statcol -increasing"
  # Then toggle the current column's arrow
  if {[string match "-inc*" $sense]} {
    $wt heading $col -image arr_dn -command "DirCanvas:sort_by_col $wt $col -decreasing"
    if {$col == "statcol"} {
      $wt heading #0 -image arr_dn -command "DirCanvas:sort_by_col $wt $col -decreasing"
    }
  } else {
    $wt heading $col -image arr_up
    if {$col == "statcol"} {
      $wt heading #0 -image arr_up
    }
  }
  DirCanvas:adjust_columnwidths $wt

  gen_log:log T "LEAVE"
}

proc DirCanvas:adjust_columnwidths {wt} {
  global cvscfg

  gen_log:log T "ENTER ($wt)"

  set displayed_columns [lindex [$wt configure -displaycolumns] end]
  # Try to adjust the width of the columns suitably
  # First, find the longest string in each column
  foreach c $displayed_columns {
    set maxlen($c) 0
    set maxstr($c) " "
    foreach item [$wt children {}] {
      set string [$wt set $item $c]
      set item_len [string length $string]
      if {$item_len > $maxlen($c)} {
        set maxlen($c) $item_len
        set maxstr($c) $string
      }
    }
  }
  # Now use the string lengths to do a font measure and find the desired width
  # of each column
  set n_cols [llength $displayed_columns]
  set tot_colwid 0
  foreach c [array names maxstr] {
    set colwid($c) [font measure $cvscfg(listboxfont) "$maxstr($c)mm"]
    incr tot_colwid $colwid($c)
  }
  set col0_w [$wt column #0 -width]
  set winwid [expr {[winfo width $wt] - $col0_w}]
  gen_log:log D "winwid $winwid"
  # The difference. This can be negative. Divvy it up equqlly.
  set whole_diff [expr {$winwid - $tot_colwid}]
  set col_diff [expr {$whole_diff / $n_cols}]
  foreach c $displayed_columns {
    set col_wid($c) [expr {$colwid($c) + $col_diff}]
    $wt column $c -width $col_wid($c)
    gen_log:log D "$c: \"$maxstr($c)\" $maxlen($c) chars, width $col_wid($c)"
  }

  gen_log:log T "LEAVE"
}

# menu binding for right-cliwinwid on an item. We have to explicitly
# set the selection.
proc DirCanvas:popup {w x y X Y} {
  global DirList

  gen_log:log T "ENTER ($w $x $y $X $Y)"
  set item [$w.tree identify item $x $y]
  $w.tree selection set $item
  update
  set f [$w.tree set $item filecol]
  gen_log:log D "$DirList($w:$f:popup)"
  set pop $DirList($w:$f:popup)
  tk_popup $w.$pop $X $Y
  gen_log:log T "LEAVE"
}

proc DirCanvas:bindings {w} {
  bind $w.tree <1> "DirCanvas:unselectall $w"
  $w.tree tag bind fileobj <2> "DirCanvas:popup $w %x %y %X %Y"
  $w.tree tag bind fileobj <3> "DirCanvas:popup $w %x %y %X %Y"
  $w.tree tag bind fileobj <Double-1> {workdir_edit_file [workdir_list_files]}
}

# Context-sensitive popups for list items.  We build them all at once here,
# then bind canvas items to them as appropriate
proc DirCanvas:makepopup {w} {
  gen_log:log T "ENTER ($w)"

  # For plain files in an un-versioned directory
  menu $w.paper_pop
  $w.paper_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.paper_pop add command -label "Delete" \
    -command { workdir_delete_file [workdir_list_files] }

  # For plain directories in an un-versioned directory
  menu $w.folder_pop
  $w.folder_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.folder_pop add command -label "Delete" \
    -command { workdir_delete_file [workdir_list_files] }

  # For plain, unmanaged files in a versioned directory
  menu $w.stat_local_pop
  $w.stat_local_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_local_pop add command -label "Delete" \
    -command { workdir_delete_file [workdir_list_files] }
  $w.stat_local_pop add command -label "Add" \
    -command { add_dialog [workdir_list_files] }

  # For CVS directories when cwd isn't in CVS
  menu $w.cvsrelease_pop
  $w.cvsrelease_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.cvsrelease_pop add command -label "CVS Release" \
    -command { release_dialog [workdir_list_files] }

  # For plain directories in CVS
  menu $w.incvs_folder_pop
  $w.incvs_folder_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.incvs_folder_pop add command -label "CVS Add Recursively" \
    -command { addir_dialog [workdir_list_files] }
  $w.incvs_folder_pop add command -label "Delete" \
    -command { workdir_delete_file [workdir_list_files] }

  # For CVS subdirectories
  menu $w.cvsdir_pop
  $w.cvsdir_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.cvsdir_pop add command -label "CVS Remove Recursively" \
    -command { subtractdir_dialog [workdir_list_files] }

  # For SVN subdirectories
  menu $w.svndir_pop
  $w.svndir_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.svndir_pop add command -label "SVN Log" \
    -command { svn_log $cvscfg(ldetail) [workdir_list_files] }
  $w.svndir_pop add command -label "SVN Info" \
    -command { svn_info [workdir_list_files] }
  $w.svndir_pop add command -label "Browse the Log Diagram" \
    -command { svn_branches [workdir_list_files] }
  $w.svndir_pop add command -label "SVN Remove" \
    -command { subtract_dialog [workdir_list_files] }

  # For Git subdirectories
  menu $w.gitdir_pop
  $w.gitdir_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.gitdir_pop add command -label "Git Remove Recursively" \
    -command { subtractdir_dialog [workdir_list_files] }

  # For RCS files
  menu $w.rcs_pop
  $w.rcs_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.rcs_pop add command -label "Browse the Log Diagram" \
    -command { rcs_branches [workdir_list_files] }
  $w.rcs_pop add command -label "RCS Lock" \
    -command { rcs_lock lock [workdir_list_files] }
  $w.rcs_pop add command -label "RCS Unlock" \
    -command { rcs_lock unlock [workdir_list_files] }
  $w.rcs_pop add command -label "RCS Revert" \
    -command { rcs_revert [workdir_list_files] }
  $w.rcs_pop add command -label "Delete Locally" \
    -command { workdir_delete_file [workdir_list_files] }

  # For CVS files
  menu $w.stat_cvsok_pop
  $w.stat_cvsok_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "CVS Log" \
    -command { cvs_log $cvscfg(ldetail) [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "Browse the Log Diagram" \
    -command { cvs_branches [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "CVS Annotate/Blame" \
    -command { cvs_annotate $current_tagname [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "CVS Remove" \
    -command { subtract_dialog [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "Set Edit Flag" \
     -command { cvs_edit [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "Unset Edit Flag" \
     -command { cvs_unedit [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "Set Binary Flag" \
     -command { cvs_binary [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "Unset Binary Flag" \
     -command { cvs_ascii [workdir_list_files] }

  # For SVN files
  menu $w.stat_svnok_pop
  $w.stat_svnok_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_svnok_pop add command -label "SVN Log" \
    -command { svn_log $cvscfg(ldetail) [workdir_list_files] }
  $w.stat_svnok_pop add command -label "SVN Info" \
    -command { svn_info [workdir_list_files] }
  $w.stat_svnok_pop add command -label "Browse the Log Diagram" \
    -command { svn_branches [workdir_list_files] }
  $w.stat_svnok_pop add command -label "SVN Annotate/Blame" \
    -command { svn_annotate "" [workdir_list_files] }
  $w.stat_svnok_pop add command -label "SVN Rename" \
    -command { svn_rename_ask [workdir_list_files] }
  $w.stat_svnok_pop add command -label "SVN Remove" \
    -command { subtract_dialog [workdir_list_files] }

  # For Git files
  menu $w.stat_gitok_pop
  $w.stat_gitok_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_gitok_pop add command -label "Git Log" \
    -command { git_log $cvscfg(ldetail) [workdir_list_files] }
  $w.stat_gitok_pop add command -label "Browse the Log Diagram" \
    -command { git_branches [workdir_list_files] }
  $w.stat_gitok_pop add command -label "Git Annotate/Blame" \
    -command { git_annotate "" [workdir_list_files] }
  $w.stat_gitok_pop add command -label "Git Rename" \
    -command { git_rename_ask [workdir_list_files] }
  $w.stat_gitok_pop add command -label "Git Remove" \
    -command { subtract_dialog [workdir_list_files] }

  # For CVS files that are out of date
  menu $w.stat_cvsood_pop
  $w.stat_cvsood_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_cvsood_pop add command -label "Update" \
    -command { \
        cvs_update {BASE} {Normal} {Remove} {recurse} {prune} {No} { } [workdir_list_files] }
  $w.stat_cvsood_pop add command -label "Update with Options" \
    -command cvs_update_options

  # For SVN files that are out of date
  menu $w.stat_svnood_pop
  $w.stat_svnood_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_svnood_pop add command -label "Update" \
    -command { svn_update [workdir_list_files] }

  # For Git files that are out of date
  menu $w.stat_gitood_pop
  $w.stat_gitood_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_gitood_pop add command -label "Update" \
    -command { git_checkout [workdir_list_files] }

  # For CVS files that need merging
  menu $w.stat_merge_pop
  $w.stat_merge_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_merge_pop add command -label "Diff" \
    -command { comparediff [workdir_list_files] }
  $w.stat_merge_pop add command -label "CVS Annotate/Blame" \
    -command { cvs_annotate $current_tagname [workdir_list_files] }
  $w.stat_merge_pop add command -label "Browse the Log Diagram" \
    -command { cvs_branches [workdir_list_files] }

  # For CVS files that are modified
  menu $w.stat_cvsmod_pop
  $w.stat_cvsmod_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_cvsmod_pop add command -label "Diff" \
    -command { comparediff [workdir_list_files] }
  $w.stat_cvsmod_pop add command -label "CVS Commit" \
    -command { cvs_commit_dialog }
  $w.stat_cvsmod_pop add command -label "CVS Revert" \
    -command { cvs_revert [workdir_list_files] }

  # For SVN files that are modified
  menu $w.stat_svnmod_pop
  $w.stat_svnmod_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_svnmod_pop add command -label "Diff" \
    -command { comparediff [workdir_list_files] }
  $w.stat_svnmod_pop add command -label "SVN Commit" \
    -command { svn_commit_dialog }
  $w.stat_svnmod_pop add command -label "SVN Revert" \
    -command { svn_revert [workdir_list_files] }

  # For Git files that are modified
  menu $w.stat_gitmod_pop
  $w.stat_gitmod_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_gitmod_pop add command -label "Diff" \
    -command { comparediff [workdir_list_files] }
  $w.stat_gitmod_pop add command -label "Git Commit" \
    -command { git_commit_dialog }
  #$w.stat_gitmod_pop add command -label "Git Reset (Revert)" \
    -command { git_reset [workdir_list_files] }

  # For CVS files that have been added but not commited
  menu $w.stat_cvsplus_pop
  $w.stat_cvsplus_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_cvsplus_pop add command -label "CVS Commit" \
    -command { cvs_commit_dialog }

  # For SVN files that have been added but not commited
  menu $w.stat_svnplus_pop
  $w.stat_svnplus_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_svnplus_pop add command -label "SVN Commit" \
    -command { svn_commit_dialog }

  # For Git files that have been added but not commited
  menu $w.stat_gitplus_pop
  $w.stat_gitplus_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_gitplus_pop add command -label "Git Commit" \
    -command { git_commit_dialog }

  # For CVS files that have been removed but not commited
  menu $w.stat_cvsminus_pop
  $w.stat_cvsminus_pop add command -label "CVS Commit" \
    -command { cvs_commit_dialog }

  # For SVN files that have been removed but not commited
  menu $w.stat_svnminus_pop
  $w.stat_svnminus_pop add command -label "SVN Commit" \
    -command { svn_commit_dialog }

  # For Git files that have been removed but not commited
  menu $w.stat_gitminus_pop
  $w.stat_gitminus_pop add command -label "Git Commit" \
    -command { git_commit_dialog }

  # For CVS unmanaged files
  menu $w.stat_cvslocal_pop
  $w.stat_cvslocal_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_cvslocal_pop add command -label "Delete" \
    -command { workdir_delete_file [workdir_list_files] }
  $w.stat_cvslocal_pop add command -label "CVS Add" \
    -command { cvs_add [workdir_list_files] }

  # For CVS files with conflicts
  menu $w.cvs_conf_pop
  $w.cvs_conf_pop add command -label "Merge using TkDiff" \
    -command { cvs_merge_conflict [workdir_list_files] }
  $w.cvs_conf_pop add command -label "CVS Annotate/Blame" \
    -command { cvs_annotate $current_tagname [workdir_list_files] }
  $w.cvs_conf_pop add command -label "Browse the Log Diagram" \
    -command { cvs_branches [workdir_list_files] }

  # For SVN files with conflicts
  menu $w.svn_conf_pop
  $w.svn_conf_pop add command -label "Merge using TkDiff" \
    -command { svn_merge_conflict [workdir_list_files] }
  $w.svn_conf_pop add command -label "Mark resolved" \
    -command { svn_resolve [workdir_list_files] }
  $w.svn_conf_pop add command -label "CVS Annotate/Blame" \
    -command { svn_annotate $current_tagname [workdir_list_files] }
  $w.svn_conf_pop add command -label "Browse the Log Diagram" \
    -command { svn_branches [workdir_list_files] }

  # For Git files with conflicts
  menu $w.git_conf_pop
  $w.git_conf_pop add command -label "Merge using TkDiff" \
    -command { git_merge_conflict [workdir_list_files] }
  $w.git_conf_pop add command -label "Stage resolved conflict" \
    -command { git_add [workdir_list_files] }

  gen_log:log T "LEAVE"
}

# Pick an icon for the file status. There are way too many of these.
proc DirCanvas:choose_icon {w f rtype} {
  global DirList
  global incvs insvn inrcs ingit

  # Up-to-date
  #  The file is identical with the latest revision in the repository for the
  #    branch in use
  # Locally Modified
  #  You have edited the file, and not yet committed your changes.
  # Locally Added
  #  You have added the file with add, and not yet committed your changes.
  # Locally Removed
  #  You have removed the file with remove, and not yet committed your changes
  # Needs Checkout
  #  Someone else has committed a newer revision to the repository. The name
  #    is slightly misleading; you will ordinarily use update rather than
  #    checkout to get that newer revision.
  # Needs Patch
  #  Like Needs Checkout, but the CVS server will send a patch rather than the
  #    entire file. Sending a patch or sending an entire file accomplishes
  #    the same thing.
  # Needs Merge
  #  Someone else has committed a newer revision to the repository, and you
  #    have also made modifications to the file.
  # Unresolved Conflict
  #  This is like Locally Modified, except that a previous update command gave
  #    a conflict. You need to resolve the conflict as described in section
  #    Conflicts example.
  # Unknown
  #  CVS doesn't know anything about this file. For example, you have created
  #     a new file and have not run add.

  switch -glob -- $DirList($w:$f:status) {
   "<file>" {
     set DirList($w:$f:icon) paper
     set DirList($w:$f:popup) paper_pop
    }
   "<dir> " {
     set DirList($w:$f:icon) dir
     set DirList($w:$f:popup) svndir_pop
   }
   "<dir> Up-to-date" {
     set DirList($w:$f:icon) dir_ok
     set DirList($w:$f:popup) svndir_pop
   }
   "<dir> Property Modified" {
     set DirList($w:$f:icon) dir_mod
     set DirList($w:$f:popup) svndir_pop
   }
   "<dir> Not managed*" {
     set DirList($w:$f:icon) dir
     set DirList($w:$f:popup) svndir_pop
   }
   "<dir> Locally Added" {
     set DirList($w:$f:icon) dir_plus
     set DirList($w:$f:popup) svndir_pop
   }
   "<dir> Locally Removed" {
     set DirList($w:$f:icon) dir_minus
     set DirList($w:$f:popup) svndir_pop
   }
   "<link> " {
     set DirList($w:$f:icon) link
     set DirList($w:$f:popup) paper_pop
   }
   "<link> Not managed by SVN" {
     set DirList($w:$f:icon) link
     set DirList($w:$f:popup) paper_pop
   }
   "<link> Up-to-date" {
     set DirList($w:$f:icon) link_ok
     set DirList($w:$f:popup) stat_svnok_pop
   }
   "<link> Up-to-date/Locked" {
     set DirList($w:$f:icon) link_okol
     set DirList($w:$f:popup) stat_svnok_pop
   }
   "<link> Up-to-date/HaveLock" {
     set DirList($w:$f:icon) link_okml
     set DirList($w:$f:popup) stat_svnok_pop
   }
   "<link> Locally Modified" {
     set DirList($w:$f:icon) link_mod
     set DirList($w:$f:popup) stat_svnok_pop
   }
   "<link> Locally Modified/Locked" {
     set DirList($w:$f:icon) link_modol
     set DirList($w:$f:popup) stat_svnok_pop
   }
   "<link> Locally Modified/HaveLock" {
     set DirList($w:$f:icon) link_modml
     set DirList($w:$f:popup) stat_svnok_pop
   }
   "<link> Locally Added" {
     set DirList($w:$f:icon) link_plus
     set DirList($w:$f:popup) stat_svnok_pop
   }
   "<directory>" {
     set DirList($w:$f:icon) dir
     switch -- $rtype {
       "CVS" {
          set DirList($w:$f:popup) incvs_folder_pop
        }
        default {
          set DirList($w:$f:popup) folder_pop
        }
      }
    }
   "<directory:???>" {
     regexp {<directory:(...)>} $DirList($w:$f:status) null vcs
     set DirList($w:$f:icon) dir
     set DirList($w:$f:popup) folder_pop
     # What VCS controls the folder? Determines the icon
     switch -- $vcs {
       "CVS" {
          set DirList($w:$f:icon) cvsdir
          set DirList($w:$f:popup) cvsrelease_pop
        }
       "SVN" {
          set DirList($w:$f:icon) svndir
        }
       "GIT" {
          set DirList($w:$f:icon) gitdir
        }
       "RCS" {
          set DirList($w:$f:icon) rcsdir
        }
     }
     # Are we in that VCS now? Determines the popop menu
     switch -- $rtype {
       "CVS" {
          set DirList($w:$f:popup) cvsdir_pop
        }
       "SVN" {
          set DirList($w:$f:popup) svndir_pop
        }
       "GIT" {
          set DirList($w:$f:popup) gitdir_pop
        }
       "RCS" {
          set DirList($w:$f:popup) folder_pop
        }
      }
    }
   "Up-to-date" {
     set DirList($w:$f:icon) stat_ok
     switch -- $rtype {
        "CVS" {
          set DirList($w:$f:popup) stat_cvsok_pop
          if {[string match "*-kb*" $DirList($w:$f:option)]} {
            set DirList($w:$f:icon) stat_kb
          }
        }
        "SVN" {
          set DirList($w:$f:popup) stat_svnok_pop
        }
        "GIT" {
          set DirList($w:$f:popup) stat_gitok_pop
        }
        default {
          set DirList($w:$f:popup) paper_pop
        }
      }
    }
   "Up-to-date/HaveLock" {
     set DirList($w:$f:icon) stat_okml
     set DirList($w:$f:popup) stat_svnok_pop
   }
   "Up-to-date/Locked" {
     set DirList($w:$f:icon) stat_okol
     set DirList($w:$f:popup) stat_svnok_pop
   }
   "Missing*" {
      set DirList($w:$f:icon) stat_ex
     switch -- $rtype {
        "CVS" {
          set DirList($w:$f:popup) stat_cvsood_pop
        }
        "SVN" {
          set DirList($w:$f:popup) stat_svnood_pop
        }
      }
    }
   "Needs Checkout" {
     # Prepending ./ to the filename prevents tilde expansion
     if {[file exists ./$f]} {
       set DirList($w:$f:icon) stat_ood
      } else {
       set DirList($w:$f:icon) stat_ex
      }
      set DirList($w:$f:popup) stat_cvsood_pop
    }
    "Needs Patch" {
     set DirList($w:$f:icon) stat_ood
     set DirList($w:$f:popup) stat_cvsood_pop
    }
    "<dir> Out-of-date" {
     set DirList($w:$f:icon) dir_ood
     switch -- $rtype {
      "CVS" {
          set DirList($w:$f:popup) stat_cvsood_pop
        }
        "SVN" {
          set DirList($w:$f:popup) stat_svnood_pop
        }
        "GIT" {
          set DirList($w:$f:popup) stat_gitood_pop
        }
      }
    }
    "Out-of-date" {
     set DirList($w:$f:icon) stat_ood
     switch -- $rtype {
        "CVS" {
          set DirList($w:$f:popup) stat_cvsood_pop
        }
        "SVN" {
          set DirList($w:$f:popup) stat_svnood_pop
        }
        "GIT" {
          set DirList($w:$f:popup) stat_gitood_pop
        }
      }
    }
    "Needs Merge" {
     set DirList($w:$f:icon) stat_merge
     set DirList($w:$f:popup) stat_merge_pop
    }
    "Locally Modified" {
     set DirList($w:$f:icon) stat_mod
     switch -- $rtype {
        "CVS" {
           set DirList($w:$f:popup) stat_cvsmod_pop
        }
        "SVN" {
           set DirList($w:$f:popup) stat_svnmod_pop
        }
      }
    }
    "Locally Modified/HaveLock" {
     set DirList($w:$f:icon) stat_modml
     set DirList($w:$f:popup) stat_cvsmod_pop
    }
    "Locally Modified/Locked" {
     set DirList($w:$f:icon) stat_modol
     set DirList($w:$f:popup) stat_cvsmod_pop
    }
     "Locally Added" {
     set DirList($w:$f:icon) stat_plus
     switch -- $rtype {
        "CVS" {
           if {[string match "*-kb*" $DirList($w:$f:option)]} {
             set DirList($w:$f:icon) stat_cvsplus_kb
           }
           set DirList($w:$f:popup) stat_cvsplus_pop
        }
        "SVN" {
           set DirList($w:$f:popup) stat_svnplus_pop
        }
      }
    }
    "Added" {
     set DirList($w:$f:icon) stat_plus
     set DirList($w:$f:popup) stat_gitplus_pop
    }
    "Added, missing" {
     set DirList($w:$f:icon) stat_ex
     set DirList($w:$f:popup) stat_gitplus_pop
    }
    "Modified, unstaged" {
     set DirList($w:$f:icon) stat_mod_red
     set DirList($w:$f:popup) stat_gitmod_pop
    }
    "Modified, staged" {
     set DirList($w:$f:icon) stat_mod_green
     set DirList($w:$f:popup) stat_gitmod_pop
    }
    "Removed" {
     set DirList($w:$f:icon) stat_minus
     set DirList($w:$f:popup) stat_gitminus_pop
    }
    "Locally Removed" {
     set DirList($w:$f:icon) stat_minus
     switch -- $rtype {
        "CVS" {
           set DirList($w:$f:popup) stat_cvsminus_pop
        }
        "SVN" {
           set DirList($w:$f:popup) stat_svnminus_pop
        }
        "GIT" {
           set DirList($w:$f:popup) stat_gitminus_pop
        }
      }
    }
    "*onflict*" {
     set DirList($w:$f:icon) stat_conf
     switch -- $rtype {
        "CVS" {
          set DirList($w:$f:popup) cvs_conf_pop
        }
        "SVN" {
          set DirList($w:$f:popup) svn_conf_pop
        }
        "GIT" {
          set DirList($w:$f:popup) git_conf_pop
        }
      }
    }
    "Not managed*" {
     set DirList($w:$f:icon) stat_ques
     set DirList($w:$f:popup) stat_local_pop
    }
    "RCS Up-to-date" {
     set DirList($w:$f:icon) stat_ok
     set DirList($w:$f:popup) rcs_pop
    }
    "RCS Up-to-date/HaveLock" {
     set DirList($w:$f:icon) stat_okml
     set DirList($w:$f:popup) rcs_pop
    }
    "RCS Up-to-date/Locked" {
     set DirList($w:$f:icon) stat_okol
     set DirList($w:$f:popup) rcs_pop
    }
    "RCS Modified" {
     set DirList($w:$f:icon) stat_mod
     set DirList($w:$f:popup) rcs_pop
    }
    "RCS Modified/HaveLock" {
     set DirList($w:$f:icon) stat_modml
     set DirList($w:$f:popup) rcs_pop
    }
    "RCS Modified/Locked" {
     set DirList($w:$f:icon) stat_modol
     set DirList($w:$f:popup) rcs_pop
    }
    "RCS Needs Checkout" {
     set DirList($w:$f:icon) stat_ex
     set DirList($w:$f:popup) rcs_pop
    }
    default {
     set DirList($w:$f:icon) paper
     set DirList($w:$f:popup) paper_pop
    }
  }
}

