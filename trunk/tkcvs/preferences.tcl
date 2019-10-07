
# Make a tabbed notebook for Preferences
proc prefdialog {} {
  global cvscfg
  
  if {[winfo exists .prefdlg]} {
    destroy .prefdlg
  }
  
  set pd .prefdlg
  toplevel $pd
  wm title $pd "TkCVS Preferences"
  wm protocol $pd WM_DELETE_WINDOW { prefs_close }
  wm withdraw .prefdlg
  
  lassign [winfo pointerxy .] x y
  incr x -350
  wm geometry .prefdlg +$x+$y
  
  ttk::notebook $pd.prefnb
  ttk::notebook::enableTraversal $pd.prefnb
  
  frame $pd.bot -relief raised -bd 2
  button $pd.bot.save -text "Save" -command save_options
  button $pd.bot.close -text "Close" -command { prefs_close }
  
  pack $pd.bot.save -side left -padx 4 -pady 2
  pack $pd.bot.close -side right -padx 4 -pady 2
  pack $pd.bot -side bottom -expand 0 -fill x
  
  # Build the pages
  prefs_general $pd.prefnb
  prefs_diagram $pd.prefnb
  prefs_git $pd.prefnb
  prefs_subversion $pd.prefnb
  prefs_cvs $pd.prefnb
  
  pack $pd.prefnb -side top -expand y -fill both
  
  if {[info exists cvscfg(preftab)]} {
    .prefdlg.prefnb select $cvscfg(preftab)
  }
  if {! [winfo ismapped .prefdlg]} {
    wm deiconify .prefdlg
  }
  
  bind .prefdlg.prefnb <<NotebookTabChanged>> {set cvscfg(preftab) [.prefdlg.prefnb select]}
  raise $pd
}

# General preferences
proc prefs_general {w} {
  frame $w.general
  $w add $w.general -text "General" -sticky nsew
  
  checkbutton $w.general.allfiles -text "Show Dotfiles" \
      -variable cvscfg(allfiles) -onvalue true -offvalue false
  checkbutton $w.general.confirmation -text "Show Confirmation Dialogs" \
      -variable cvscfg(confirm_prompt) -onvalue true -offvalue false
  checkbutton $w.general.auto -text "Automatic Workdir Status" \
      -variable cvscfg(auto_status) -onvalue true -offvalue false
  label $w.general.lshell -text "Terminal"
  entry $w.general.eshell -textvariable cvscfg(shell)
  label $w.general.leditor -text "Text Editor"
  entry $w.general.eeditor -textvariable cvscfg(editor)
  checkbutton $w.general.ext_editor -text "Use Native Editor for Check In" \
      -variable cvscfg(use_cvseditor) -onvalue true -offvalue false
  label $w.general.ldiff -text "Diff Visualizer"
  entry $w.general.ediff -textvariable cvscfg(tkdiff)
  
  grid columnconf $w.general 1 -weight 1
  grid $w.general.allfiles -sticky w -column 0 -row 0 -columnspan 2
  grid $w.general.confirmation -sticky w -column 0 -row 1 -columnspan 2
  grid $w.general.auto -sticky w -column 0 -row 2 -columnspan 2
  grid $w.general.ext_editor -sticky w -column 0 -row 3 -columnspan 2
  grid $w.general.leditor -sticky w -column 0 -row 4
  grid $w.general.eeditor -sticky ew -column 1 -row 4 -padx 2
  grid $w.general.ldiff -sticky w -column 0 -row 5
  grid $w.general.ediff -sticky ew -column 1 -row 5 -padx 2
  grid $w.general.lshell -sticky w -column 0 -row 6
  grid $w.general.eshell -sticky ew -column 1 -row 6 -padx 2
}

# For the Branch diagrams
proc prefs_diagram {w} {
  global logcfg
  
  frame $w.logcanv
  $w add $w.logcanv -text "Branch Browser" -sticky nsew
  
  frame $w.logcanv.layout
  checkbutton $w.logcanv.layout.showtags -text "Show Tags" \
      -variable logcfg(show_tags) -onvalue 1 -offvalue 0
  checkbutton $w.logcanv.layout.showbranches -text "Show Branches" \
      -variable logcfg(show_branches) -onvalue 1 -offvalue 0
  checkbutton $w.logcanv.layout.showempty -text "Show Empty Branches (CVS)" \
      -variable logcfg(show_empty_branches) -onvalue 1 -offvalue 0
  checkbutton $w.logcanv.layout.showintermed -text "Show Intermediate Revisions" \
      -variable logcfg(show_inter_revs) -onvalue 1 -offvalue 0
  checkbutton $w.logcanv.layout.showmerg -text "Show Merges" \
      -variable logcfg(show_merges) -onvalue 1 -offvalue 0
  
  pack $w.logcanv.layout -side top -fill x
  grid columnconf $w.logcanv.layout 1 -weight 1
  grid $w.logcanv.layout.showtags -sticky w -column 0 -row 0 -columnspan 2
  grid $w.logcanv.layout.showbranches -sticky w -column 0 -row 1 -columnspan 2
  grid $w.logcanv.layout.showempty -sticky w -column 0 -row 2 -columnspan 2
  grid $w.logcanv.layout.showintermed -sticky w -column 0 -row 3 -columnspan 2
  grid $w.logcanv.layout.showmerg -sticky w -column 0 -row 4 -columnspan 2
  
  ttk::separator $w.logcanv.sep1
  pack $w.logcanv.sep1 -side top -fill x -pady 3
  
  frame $w.logcanv.scale
  label $w.logcanv.scale.lspin -text "Scale"
  spinbox $w.logcanv.scale.sspin -from .2 -to 1.5 -increment .1 \
      -textvariable logcfg(scale)
  
  pack  $w.logcanv.scale
  grid columnconf $w.logcanv.scale 1 -weight 1
  grid $w.logcanv.scale.lspin -sticky w -column 0 -row 0
  grid $w.logcanv.scale.sspin -sticky w -column 1 -row 0
  
  ttk::separator $w.logcanv.sep2
  pack $w.logcanv.sep2 -side top -fill x -pady 3
  
  frame $w.logcanv.revs
  checkbutton $w.logcanv.revs.showrev -text "Show Revision #" \
      -variable logcfg(show_box_rev) -onvalue 1 -offvalue 0
  checkbutton $w.logcanv.revs.showrevwho -text "Show Author" \
      -variable logcfg(show_box_revwho) -onvalue 1 -offvalue 0
  checkbutton $w.logcanv.revs.showrevdate -text "Show Date" \
      -variable logcfg(show_box_revdate) -onvalue 1 -offvalue 0
  checkbutton $w.logcanv.revs.showrevtime -text "Show Time" \
      -variable logcfg(show_box_revtime) -onvalue 1 -offvalue 0
  pack $w.logcanv.revs -side top -fill x
  grid columnconf $w.logcanv.revs 1 -weight 1
  grid $w.logcanv.revs.showrev -sticky w -column 0 -row 0 -columnspan 2
  grid $w.logcanv.revs.showrevwho -sticky w -column 0 -row 1 -columnspan 2
  grid $w.logcanv.revs.showrevdate -sticky w -column 0 -row 2 -columnspan 2
  grid $w.logcanv.revs.showrevtime -sticky w -column 0 -row 3 -columnspan 2
  
}

# For CVS
proc prefs_cvs {w} {
  frame $w.cvs
  $w add $w.cvs -text "CVS" -sticky nsew
  
  checkbutton $w.cvs.editing -text "Allow cvs edit" \
      -variable cvscfg(econtrol) -onvalue true -offvalue false -state disabled
  checkbutton $w.cvs.locking -text "Allow cvs lock" \
      -variable cvscfg(cvslock) -onvalue true -offvalue false -state disabled
  
  grid columnconf $w.cvs 1 -weight 1
  grid $w.cvs.editing -sticky w -column 0 -row 0
  grid $w.cvs.locking -sticky w -column 0 -row 1
}

# For Subversion
proc prefs_subversion {w} {
  frame $w.svn
  $w add $w.svn -text "Subversion" -sticky nsew
  
  frame $w.svn.dirnames
  label $w.svn.dirnames.ltrunkdir -text "Trunk Directory"
  entry $w.svn.dirnames.etrunkdir -textvariable cvscfg(svn_trunkdir)
  label $w.svn.dirnames.lbranchdir -text "Branches Directory"
  entry $w.svn.dirnames.ebranchdir -textvariable cvscfg(svn_branchdir)
  label $w.svn.dirnames.ltagdir -text "Tags Directory"
  entry $w.svn.dirnames.etagdir -textvariable cvscfg(svn_tagdir)
  
  pack $w.svn.dirnames -side top -fill x
  grid columnconf $w.svn.dirnames 1 -weight 1
  grid $w.svn.dirnames.ltrunkdir -sticky w -column 0 -row 0
  grid $w.svn.dirnames.etrunkdir -sticky ew -column 1 -row 0 -padx 2
  grid $w.svn.dirnames.lbranchdir -sticky w -column 0 -row 1
  grid $w.svn.dirnames.ebranchdir -sticky ew -column 1 -row 1 -padx 2
  grid $w.svn.dirnames.ltagdir -sticky w -column 0 -row 2
  grid $w.svn.dirnames.etagdir -sticky ew -column 1 -row 2 -padx 2
  
  ttk::separator $w.svn.sep1
  pack $w.svn.sep1 -side top -fill x -pady 3
  
  frame $w.svn.branchbr
  label $w.svn.branchbr.lmaxtag -text "Maximum SVN Tags"
  entry $w.svn.branchbr.emaxtag -textvariable cvscfg(toomany_tags)
  
  pack $w.svn.branchbr -side top -fill x
  grid columnconf $w.svn.branchbr 1 -weight 1
  grid $w.svn.branchbr.lmaxtag -sticky w -column 0 -row 0
  grid $w.svn.branchbr.emaxtag -sticky ew -column 1 -row 0 -padx 2
}

# For Git
proc prefs_git {w} {
  frame $w.git
  $w add $w.git -text "Git" -sticky nsew
  
  frame $w.git.workdir
  checkbutton $w.git.workdir.detail -text "Detailed Workdir Status" \
      -variable cvscfg(gitdetail) -onvalue true -offvalue false
  
  pack $w.git.workdir -side top -fill x
  grid columnconf $w.git.workdir 1 -weight 1
  grid $w.git.workdir.detail -sticky w -column 0 -row 0 -columnspan 2
  
  ttk::separator $w.git.sep1
  pack $w.git.sep1 -side top -fill x -pady 3
  
  frame $w.git.blame
  label $w.git.blame.blamelbl -text "Annotate/Blame"
  label $w.git.blame.lgitblame_since -text "Since"
  entry $w.git.blame.egitblame_since -textvariable cvscfg(gitblame_since)
  
  pack $w.git.blame -side top -fill x
  grid columnconf $w.git.blame 1 -weight 1
  grid $w.git.blame.blamelbl -sticky w -column 0 -row 0 -columnspan 2
  grid $w.git.blame.lgitblame_since -sticky w -column 0 -row 1
  grid $w.git.blame.egitblame_since -sticky ew -column 1 -row 1 -padx 2
  
  ttk::separator $w.git.sep2
  pack $w.git.sep2 -side top -fill x -pady 3
  
  frame $w.git.branchbr
  label $w.git.branchbr.blamelbl -text "Log Browser"
  label $w.git.branchbr.lgitlog_since -text "Since"
  entry $w.git.branchbr.egitlog_since -textvariable cvscfg(gitlog_since)
  label $w.git.branchbr.lmaxhist -text "Maximum Git History"
  entry $w.git.branchbr.emaxhist -textvariable cvscfg(gitmaxhist)
  label $w.git.branchbr.lmaxbranches -text "Maximum Git Branches"
  entry $w.git.branchbr.emaxbranches -textvariable cvscfg(gitmaxbranch)
  label $w.git.branchbr.llogopts -text "Git Log Options"
  entry $w.git.branchbr.elogopts -textvariable cvscfg(gitlog_opts)
  
  radiobutton $w.git.branchbr.br_file -text " File-specific branches only" \
      -variable cvscfg(gitbranchgroups) -value "F"
  radiobutton $w.git.branchbr.br_local -text " All local branches" \
      -variable cvscfg(gitbranchgroups) -value "FL"
  radiobutton $w.git.branchbr.br_remote -text " Local + Remote branches" \
      -variable cvscfg(gitbranchgroups) -value "FLR"
  label $w.git.branchbr.lbrglob -text "Git Branch Filter (regex)"
  entry $w.git.branchbr.ebrglob -textvariable cvscfg(gitbranchregex)
  label $w.git.branchbr.hbrglob -text "master is always included"
  
  pack $w.git.branchbr -side top -fill x
  grid columnconf $w.git.branchbr 1 -weight 1
  grid $w.git.branchbr.blamelbl -sticky w -column 0 -row 0 -columnspan 2
  grid $w.git.branchbr.lgitlog_since -sticky w -column 0 -row 1
  grid $w.git.branchbr.egitlog_since -sticky ew -column 1 -row 1 -padx 2
  grid $w.git.branchbr.lmaxhist -sticky w -column 0 -row 2
  grid $w.git.branchbr.emaxhist -sticky ew -column 1 -row 2 -padx 2
  grid $w.git.branchbr.lmaxbranches -sticky w -column 0 -row 3
  grid $w.git.branchbr.emaxbranches -sticky ew -column 1 -row 3 -padx 2
  grid $w.git.branchbr.llogopts -sticky w -column 0 -row 4
  grid $w.git.branchbr.elogopts -sticky ew -column 1 -row 4 -padx 2
  
  grid $w.git.branchbr.br_file -sticky w -column 1 -row 5
  grid $w.git.branchbr.br_local -sticky w -column 1 -row 6
  grid $w.git.branchbr.br_remote -sticky w -column 1 -row 7
  
  grid $w.git.branchbr.lbrglob -sticky w -column 0 -row 8
  grid $w.git.branchbr.ebrglob -sticky ew -column 1 -row 8 -padx 2
  grid $w.git.branchbr.hbrglob -sticky w -column 1 -row 9
}

proc prefs_close { } {
  global cvscfg
  
  gen_log:log D "Preferences Tab $cvscfg(preftab)"
  
  destroy .prefdlg
  exit_cleanup 0
}

