
# Make a tabbed notebook for Preferences
proc prefdialog {} {
  global cvscfg
  global cvsglb

  if {[winfo exists .prefdlg]} {
    destroy .prefdlg
  }

  set pd .prefdlg
  toplevel $pd
  wm title $pd "TkCVS Preferences"
  wm protocol $pd WM_DELETE_WINDOW { destroy .prefdlg }

  ttk::notebook $pd.prefnb
  ttk::notebook::enableTraversal $pd.prefnb

  frame $pd.bot
  button $pd.bot.save -text "Save" -command save_options
  button $pd.bot.close -text "Close" -command {destroy .prefdlg}

  pack $pd.bot.save -side left
  pack $pd.bot.close -side right
  pack $pd.bot -side bottom -expand 1 -fill x

  # Build the pages
  prefs_general $pd.prefnb
  prefs_diagram $pd.prefnb
  prefs_subversion $pd.prefnb
  prefs_git $pd.prefnb

  pack $pd.prefnb -side top -expand y -fill both
}

# General preferences
proc prefs_general {w} {
  frame $w.general
  $w add $w.general -text "General" -sticky nsew

  checkbutton $w.general.confirmation -text "Confirmation Dialogs" \
    -variable cvscfg(confirm_prompt) -onvalue true -offvalue false
  label $w.general.lshell -text "Terminal"
  entry $w.general.eshell -textvariable cvscfg(shell)
  label $w.general.leditor -text "Text Editor"
  entry $w.general.eeditor -textvariable cvscfg(editor)
  checkbutton $w.general.ext_editor -text "Use Native Editor for Checkin" \
    -variable cvscfg(use_cvseditor) -onvalue true -offvalue false
  label $w.general.ldiff -text "Diff Visualizer"
  entry $w.general.ediff -textvariable cvscfg(tkdiff)

  grid columnconf $w.general 1 -weight 1
  grid $w.general.confirmation -sticky w -column 0 -row 0 -columnspan 2
  grid $w.general.lshell -sticky w -column 0 -row 1
  grid $w.general.eshell -sticky ew -column 1 -row 1
  grid $w.general.leditor -sticky w -column 0 -row 2
  grid $w.general.eeditor -sticky ew -column 1 -row 2
  grid $w.general.ext_editor -sticky w -column 0 -row 3 -columnspan 2
  grid $w.general.ldiff -sticky w -column 0 -row 4
  grid $w.general.ediff -sticky ew -column 1 -row 4
}

# For the Branch diagrams
proc prefs_diagram {w} {
  frame $w.branchbr
  $w add $w.branchbr -text "Branch Diagrams" -sticky nsew
}

# For Subversion
proc prefs_subversion {w} {
  frame $w.svn
  $w add $w.svn -text "SVN" -sticky nsew

  label $w.svn.ltrunkdir -text "Trunk directory"
  entry $w.svn.etrunkdir -textvariable cvscfg(svn_trunkdir)
  label $w.svn.lbranchdir -text "Branches directory"
  entry $w.svn.ebranchdir -textvariable cvscfg(svn_branchdir)
  label $w.svn.ltagdir -text "Tags directory"
  entry $w.svn.etagdir -textvariable cvscfg(svn_tagdir)

  grid $w.svn.ltrunkdir -sticky w -column 0 -row 0
  grid $w.svn.etrunkdir -sticky ew -column 1 -row 0
  grid $w.svn.lbranchdir -sticky w -column 0 -row 1
  grid $w.svn.ebranchdir -sticky ew -column 1 -row 1
  grid $w.svn.ltagdir -sticky w -column 0 -row 2
  grid $w.svn.etagdir -sticky ew -column 1 -row 2
}

# For Git
proc prefs_git {w} {
  frame $w.git
  $w add $w.git -text "Git" -sticky nsew
}

