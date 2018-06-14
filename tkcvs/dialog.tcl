#
# Tcl Library for TkCVS
#

#
# Smallish dialogs - add, tag
#

if {[catch "image type arr_dn"]} {
  workdir_images
}

# Creates the widgets for the dynamic form dialog
proc dialog_FormCreate { title form_data } {
  global cvscfg
  global cvsglb
  global dynamic_dialog
  global dialog_action

  set font_star $cvscfg(dialogfont)
  set font_normal $cvscfg(listboxfont)
  set font_bold $cvscfg(dialogfont)
  set font_italic [font create -family Helvetica -size -12 -slant italic]

  if {[winfo exists .dynamic_dialog]} {
    destroy .dynamic_dialog
  }
  set w .dynamic_dialog
  toplevel $w

  frame $w.form
  pack $w.form -side top -fill x

  set row 0
  foreach {field req type labeltext data} $form_data {
    # If you wanted another default, set it in the calling function
    if {! [info exists dynamic_dialog($field)]} {
      set dynamic_dialog($field) {}
    }
    if {$type == {l}} {
      # Section label
      frame $w.form.rule$field -relief groove -borderwidth 2 -height 4
      label $w.form.l$field -font $font_bold -text $labeltext
      grid  $w.form.rule$field -column 0 -row [incr row] -columnspan 3 -sticky ew
      grid  $w.form.l$field -column 0 -row [incr row] -sticky w
    } else {
      # It's something else.  It has a label and a req though.
      label $w.form.l$field -anchor w -text "    $labeltext"
      label $w.form.r$field -anchor e -foreground red \
          -font $font_star -text [expr {$req ? "*" : " "}]
        grid  $w.form.l$field -column 0 -row [incr row] -sticky w
        grid  $w.form.r$field -column 1 -row $row -sticky w
      if {$type == {t}} {
        # It's an entry
        entry $w.form.e$field -width 65 \
           -textvariable dynamic_dialog($field)
        grid  $w.form.e$field -column 2 -row $row -sticky w
      } elseif {$type == {r}} {
        # It's a radiobutton
        frame $w.form.f$field
        set k 1
        foreach {text value} $data {
          radiobutton $w.form.f$field$k -text $text -value $value \
              -variable dynamic_dialog($field)
          pack $w.form.f$field$k -in $w.form.f$field -side left
          incr k
        }
        grid $w.form.f$field -column 2 -row $row -sticky ew
      }
    }
  }
  
  incr row
  label $w.form.xstar -anchor e -foreground red \
    -font $font_italic -text "* = required field"
  grid $w.form.xstar -column 1 -columnspan 2 -row $row -sticky w

  frame $w.buttons -relief groove -bd 2
  pack $w.buttons -side top -fill x

  button $w.ok -text "OK" \
    -command "
    if {\[dialog_FormComplete $w [list $form_data]\] } {
      destroy $w
      $dialog_action
      exit_cleanup 0
    }
    "

  button $w.apply -text "Apply" \
    -command "
    if {\[dialog_FormComplete $w [list $form_data]\] } {
      $dialog_action
    }
    "

  button $w.close -text "Cancel" \
    -command "
      destroy $w
      exit_cleanup 0
    "

  pack $w.close $w.apply $w.ok -in $w.buttons -side right \
    -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  wm title $w $title
  wm minsize $w 1 1

  return
}

proc dialog_FormComplete { w form_data } {
  global dynamic_dialog

  gen_log:log T "ENTER ($w ...)"

  foreach a [array names dynamic_dialog] {
    gen_log:log D "$a $dynamic_dialog($a)"
  }

  set section {}
  foreach {field req type labeltext data} $form_data {
    if {$type == {l}} {
      set section $dynamic_dialog($field)
    } else {
      if {$req && [set dynamic_dialog($field)] == {}} {
        cvsok "$field may not be blank" $w.form
        return 0
      }
    }
  }
  return 1
}

# Check out a CVS module from the Repository Browser
proc dialog_cvs_checkout { cvsroot module {revtag {} } } {
  global dynamic_dialog
  global dialog_action

  gen_log:log T "ENTER ($cvsroot $module $revtag)"

  # Remember tags from last time
  if {$revtag == {} && [info exists dynamic_dialog(revtag)]} {
    set revtag $dynamic_dialog(revtag)
  }
  set dir [pwd]
  set dynamic_dialog(cvsroot) $cvsroot
  set dynamic_dialog(module) $module
  set dynamic_dialog(revtag) $revtag
  set dynamic_dialog(dir) $dir
  set dynamic_dialog(prune) {-P}
  set dynamic_dialog(kflag) {}

  # field  req type labeltext          data
  set dialog_form_checkout {
    1       0   l  {CVS Repository}    1
    cvsroot 1   t  {CVSROOT}           {}
    2       0   l  {Module}            1
    module  1   t  {Name/Path}         {}
    revtag  0   t  {Revision/Tag}      {}
    date    0   t  {Date}              {}
    3       0   l  {Destination}       1
    dir     1   t  {Current Directory} {}
    target  0   t  {Working Directory} {}
    4       0   l  {Merge }            0
    mtag1   0   t  {Old tag}           {}
    mtag2   0   t  {New tag}           {}
    5       0   l  {Advanced}          0
    prune   0   r  {Empty Directories} {{Create} {}
                                        {Don't Create} {-P}}
    kflag   0   r  {Keyword Expansion} {{Default} {}
                                        {Keep as-is} {-ko}
                                        {Treat files as binary} {-kb}
                                        {Keywords only} {-kk}}
  }
  # Action function
  set dialog_action {cvs_checkout $dynamic_dialog(dir) \
     $dynamic_dialog(cvsroot) \
     $dynamic_dialog(prune) $dynamic_dialog(kflag) \
     $dynamic_dialog(revtag) $dynamic_dialog(date) $dynamic_dialog(target) \
     $dynamic_dialog(mtag1) $dynamic_dialog(mtag2) $dynamic_dialog(module)
  }

  set form [dialog_FormCreate "Checkout Module" $dialog_form_checkout]
  gen_log:log T "LEAVE"
}

# Export a CVS module from the Repository Browser
proc dialog_cvs_export { cvsroot module {revtag {}} } {
  global dynamic_dialog
  global dialog_action

  gen_log:log T "ENTER ($cvsroot $module $revtag)"

  # Remember tags from last time
  if {$revtag == {} && [info exists dynamic_dialog(revtag)]} {
    set revtag $dynamic_dialog(revtag)
  }
  set dir [pwd]
  set dynamic_dialog(cvsroot) $cvsroot
  set dynamic_dialog(module) $module
  set dynamic_dialog(revtag) $revtag
  set dynamic_dialog(dir) $dir

  # field  req type labeltext          data
  set dialog_form_export {
    1       0   l {CVS Repository}     1
    cvsroot 1   t {CVSROOT}            {}
    2       0   l {Module}             1
    module  1   t {Name/Path}          {}
    revtag  0   t {Revision/Tag}       {}
    date    0   t {Date}               {}
    3       0   l {Destination}        1
    dir     1   t {Current Directory}  {}
    target  0   t {Target Directory}   {}
    4       0   l {Advanced}           0
    kflag   0   r {Keyword Expansion}  {{Default} {}
                                        {Keep as-is} {-ko}
                                        {Treat files as binary} {-kb}
                                        {Keywords only} {-kk}}
  }
  # Action function
  set dialog_action {cvs_export  $dynamic_dialog(dir) \
     $dynamic_dialog(cvsroot) $dynamic_dialog(kflag) \
     $dynamic_dialog(revtag) $dynamic_dialog(date) \
     $dynamic_dialog(target) $dynamic_dialog(module)
  }

  set form [dialog_FormCreate "Export Module" $dialog_form_export]
  gen_log:log T "LEAVE"
}

# Checkout or Export a SVN module from the Repository Browser
proc dialog_svn_checkout { svnroot path command } {
  global dynamic_dialog
  global dialog_action

  if {[info exists dynamic_dialog(rev)]} {
    set rev $dynamic_dialog(rev)
  }
  set dir [pwd]
  set dynamic_dialog(path) $path
  set dynamic_dialog(svnroot) $svnroot
  set dynamic_dialog(command) $command
  set dynamic_dialog(dir) $dir

  # field  req type labeltext          data
  set dialog_form_export {
    1       0   l {SVN Repository}     1
    svnroot 1   t {SVN URL}            {}
    path    1   t {Path in Repository} {}
    rev     0   t {Revision/Date}      {}
    2       0   l {Destination}        1
    dir     1   t {Current Directory}  {}
    target  0   t {Target Directory}   {}
    3       0   l {Working Copy or Unversioned Copy} {}
    command 0   r {Versioning}         {{Versioned (Checkout)}  {checkout}
                                        {Un-Versioned (Export)} {export}}
  }
  # Action function
  set dialog_action {svn_checkout $dynamic_dialog(dir) \
     $dynamic_dialog(svnroot) $dynamic_dialog(path) \
     $dynamic_dialog(rev) $dynamic_dialog(target) \
     $dynamic_dialog(command)
  }

  set form [dialog_FormCreate "Checkout or Export" $dialog_form_export]
  gen_log:log T "LEAVE"
}


# Make a branch or tag (svn copy) from the Repository Browser
proc dialog_svn_tag { svnroot path b_or_t } {
  global dynamic_dialog
  global dialog_action

  set dynamic_dialog(path) $path
  set dynamic_dialog(svnroot) $svnroot
  set dynamic_dialog(b_or_t) $b_or_t
  set dynamic_dialog(frompath) "$dynamic_dialog(svnroot)/$dynamic_dialog(path)"

  # field     req type labeltext                     data
  set dialog_form_tagcopy {
    1           0   l  {Copy Path to Tag or Branch}  1
    frompath    1   t  {Copy From}                   {}
    b_or_t      0   r  {Tag or Branch}               {{Branch} {branches}
                                                      {Tag} {tags}}
    target      1   t  {New Branch/Tag}              {}
  }
  # Action function
  set dialog_action {svn_rcopy $dynamic_dialog(svnroot)/$dynamic_dialog(path) \
                               $dynamic_dialog(b_or_t) $dynamic_dialog(target)
  }

  set form [dialog_FormCreate "SVN Branch or Tag Copy" $dialog_form_tagcopy]
  gen_log:log T "LEAVE"
}


# Compare two revisions of a module, from the module browser
# Can make a patch file or send a summary to the screen
proc dialog_cvs_patch { cvsroot module summary {revtagA {}} {revtagB {}} } {
  global dynamic_dialog
  global dialog_action

  gen_log:log T "ENTER ( $cvsroot $module $summary $revtagA $revtagB )"

  # Remember tags
  if {$revtagA == {} && [info exists dynamic_dialog(revtagA)]} {
    set revtagA $dynamic_dialog(revtagA)
  }
  if {$revtagB == {} && [info exists dynamic_dialog(revtagB)]} {
    set revtagB $dynamic_dialog(revtagB)
  }

  set dynamic_dialog(cvsroot) $cvsroot
  set dynamic_dialog(module) $module
  set dynamic_dialog(revtagA) $revtagA
  set dynamic_dialog(revtagB) $revtagB
  set dynamic_dialog(outfile) "$module.patch"
  if {$summary} {
    set dynamic_dialog(outmode) 0
    set dynamic_dialog(difffmt) {-s}
  } else {
    set dynamic_dialog(outmode) 1
    set dynamic_dialog(difffmt) {}
  }

  # field  req type labeltext          data
  set dialog_form_patch {
  1         0     l {CVS Repository}   1
  cvsroot   1     t {CVSROOT}          {}
  2         0     l {Module}           1
  module    1     t {Name/Path}        {}
  3         0     l {Destination}      1
  outmode   0     r {Output Mode}      {{To Screen} 0 {To File} 1}
  outfile   0     t {Output File}      {outfile}
  4         0     l {Old Revision}     1
  revtagA   0     t {Revision/Tag}     {}
  dateA     0     t {Date}             {}
  5         0     l {New Revision}     1
  revtagB   0     t {Revision/Tag}     {}
  dateB     0     t {Date}             {}
  6         0     l {Format}           1
  difffmt   0     r {Diff Format}      {{Default}            {}
                                        {Context diff}       {-c}
                                        {Unidiff}            {-u}
                                        {One liner}          {-s}}
  }
  # Action function
  set dialog_action {cvs_patch $dynamic_dialog(cvsroot) \
     $dynamic_dialog(module) $dynamic_dialog(difffmt) \
     $dynamic_dialog(revtagA) $dynamic_dialog(dateA) \
     $dynamic_dialog(revtagB) $dynamic_dialog(dateB) \
     $dynamic_dialog(outmode) $dynamic_dialog(outfile)
  }

  set form [dialog_FormCreate "Diff/Patch Module" $dialog_form_patch]
  gen_log:log T "LEAVE"
}

# Compare two revisions, from the module browser
# Can make a patch file or send a summary to the screen
proc dialog_svn_patch { cvsroot pathA pathB summary } {
  global dynamic_dialog
  global dialog_action

  gen_log:log T "ENTER ( $cvsroot $pathA $pathB $summary )"

  set dynamic_dialog(cvsroot) $cvsroot
  set dynamic_dialog(pathA) $pathA
  set dynamic_dialog(pathB) $pathB
  if {$summary} {
    set dynamic_dialog(outmode) 0
  } else {
    set dynamic_dialog(outmode) 1
  }
  set dynamic_dialog(outfile) "patchfile.patch"
  set dynamic_dialog(fullA) "$cvsroot$pathA"
  if {$pathB == ""} {
    set dynamic_dialog(fullB) ""
  } else {
    set dynamic_dialog(fullB) "$cvsroot$pathB"
  }

  # field  req type labeltext          data
  set dialog_form_patch {
  1         0     l {Repository Paths} 1
  pathA     1     t {Path A}           {}
  pathB     0     t {Path B}           {}
  3         0     l {Destination}      1
  outmode   0     r {Output Mode}      {{To Screen} 0 {To File} 1}
  outfile   0     t {Output File}      {outfile}
  4         0     l {Old Revision}     1
  revA      0     t {Revision}         {}
  dateA     0     t {Date}             {}
  5         0     l {New Revision}     1
  revB      0     t {Revision}         {}
  dateB     0     t {Date}             {}
  }
  # Action function
  set dialog_action {
    # Make new fullA and fullB from the pathA and pathB entries
    set dynamic_dialog(fullA) "$dynamic_dialog(cvsroot)/$dynamic_dialog(pathA)"
    if {$dynamic_dialog(pathB) == ""} {
      set dynamic_dialog(fullB) ""
    } else {
      set dynamic_dialog(fullB) "$dynamic_dialog(cvsroot)/$dynamic_dialog(pathB)"
    }
    svn_patch $dynamic_dialog(fullA) \
       $dynamic_dialog(fullB) \
       $dynamic_dialog(revA) $dynamic_dialog(dateA) \
       $dynamic_dialog(revB) $dynamic_dialog(dateB) \
       $dynamic_dialog(outmode) $dynamic_dialog(outfile)
  }

  set form [dialog_FormCreate "SVN Diff/Patch" $dialog_form_patch]
  gen_log:log T "LEAVE"
}

proc add_dialog {args} {
  global cvs
  global cvsglb
  global incvs
  global insvn
  global ingit

  gen_log:log T "ENTER ($args)"

  set binflag ""
  toplevel .add
  grab set .add

  set filelist [join $args]
  if {$filelist == ""} {
    set mess "This will add all new files"
  } else {
    set mess "This will add these files:\n\n"
    foreach file $filelist {
      append mess "   $file\n"
    }
  }

  message .add.top -justify left -aspect 300 -relief groove \
    -text "Add a file or files to the module.  The repository\
           will not be changed until you do a commit."
  pack .add.top -side top -fill x

  message .add.middle -text $mess -aspect 200
  pack .add.middle -side top -fill x
  frame .add.down
  button .add.down.add -text "Add" 
  if {$incvs} {
    .add.down.add configure -command {
      grab release .add
      destroy .add
      cvs_add $binflag [workdir_list_files]
    }
    checkbutton .add.binary -text "-kb (binary)" \
       -variable binflag -onvalue "-kb" -offvalue ""
    pack .add.binary -side top
  } elseif {$insvn} {
    .add.down.add configure -command {
      grab release .add
      destroy .add
      svn_add [workdir_list_files]
    }
  } elseif {$ingit} {
    .add.down.add configure -command {
      grab release .add
      destroy .add
      git_add [workdir_list_files]
    }
  }

  button .add.down.cancel -text "Cancel" \
    -command { grab release .add; destroy .add }
  pack .add.down -side bottom -fill x -expand 1
  pack .add.down.add .add.down.cancel -side left \
    -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  wm title .add "Add Files"
  wm minsize .add 1 1

  gen_log:log T "LEAVE"
}

proc file_tag_dialog {branch} {
  global incvs insvn inrcs
  global cvscfg
  global cvsglb
  global branchflag

  gen_log:log T "ENTER ($branch)"

  # FIXME: This is too messy and should be split into two dialogs,
  # one for cvs and one for svn
  set branchflag $branch

  toplevel .tag
  #grab set .tag

  frame .tag.top
  pack .tag.top -side top -fill x

  set msg ""
  if {$incvs} {
    set msg "Apply a new tag or branch tag \
             to the marked files, recursively.\
             Will change the repository.\
             If a branch, it can also update local directory if desired."
  } elseif {$insvn} {
    set msg "Create a new branch or tag copy \
             of the files in this directory"
  }

  message .tag.top.msg -justify left -aspect 300 -relief groove \
    -text $msg
  label .tag.top.lbl -text "Tag Name" -anchor w
  entry .tag.top.entry -relief sunken -textvariable usertagname
  checkbutton .tag.top.branch -text "Branch tag (-b)" \
     -variable branchflag -onvalue "branch" -offvalue "tag" \
     -command { 
        if {$branchflag == "tag"} {
           .tag.mid.upd config -state disabled; set updflag "no"
        } else {
           .tag.mid.upd config -state normal
        }
      }
  checkbutton .tag.top.force -text "Move existing (-F)" \
     -variable forceflag -onvalue "yes" -offvalue "no"

  frame .tag.mid -relief groove -bd 2
  checkbutton .tag.mid.upd -text "Update current directory to be on the new tag" \
      -variable updflag -onvalue "yes" -offvalue "no"

  grid columnconf .tag.top 1 -weight 1
  grid rowconf .tag.top 3 -weight 1
  grid .tag.top.msg -column 0 -row 0 -columnspan 2 -pady 2 -sticky ew
  grid .tag.top.lbl -column 0 -row 1 -sticky nw
  grid .tag.top.entry -column 1 -row 1 -sticky ew
  grid .tag.top.branch -column 1 -row 2 -sticky w
  if {$incvs} {
    grid .tag.top.force -column 1 -row 3 -sticky w
  }

  pack .tag.mid -side top
  pack .tag.mid.upd

  frame .tag.down -relief groove -bd 2
  pack .tag.down -side bottom -fill x -expand 1
  button .tag.down.tag -text "Tag" 
  if {$incvs} {
    .tag.down.tag configure -command {
      cvs_tag $usertagname $forceflag $branchflag $updflag \
          [workdir_list_files]
      grab release .tag
      destroy .tag
    }
  } elseif {$insvn} {
    if {$branchflag == "branch"} {set branchtag "branches"}
    if {$branchflag == "tag"} {set branchtag "tags"}
    .tag.down.tag configure -command {
      svn_tag $usertagname $branchflag $updflag [workdir_list_files]
      grab release .tag
      destroy .tag
    }
  }
  button .tag.down.cancel -text "Cancel" \
    -command { grab release .tag; destroy .tag }

  pack .tag.down.tag .tag.down.cancel -in .tag.down -side left \
    -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  if {$branchflag == "tag"} {
     .tag.mid.upd config -state disabled
     set updflag "no"
  } else {
     .tag.mid.upd config -state normal
  }

  wm title .tag "tag"
  wm minsize .tag 1 1
  gen_log:log T "LEAVE"
}

proc rtag_dialog { cvsroot module b_or_t } {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($cvsroot $module $b_or_t)"

  toplevel .modtag
  grab set .modtag

  frame .modtag.top
  pack .modtag.top -side top -fill x

  message .modtag.top.lbl -aspect 300 -relief groove \
    -text "Tag the module \"$module\" with the new tag you specify.\
           If you fill in \"Existing Tag\", the revisions having that tag will get\
           the new tag.  Otherwise, the head revision will be tagged."
  label .modtag.top.olbl -text "Existing Tag" -anchor w
  entry .modtag.top.oentry -textvariable otag \
    -relief sunken
  label .modtag.top.nlbl -text "New Tag" -anchor w
  entry .modtag.top.nentry -textvariable ntag \
    -relief sunken
  checkbutton .modtag.top.branch -text "Branch tag (-b)" \
     -variable b_or_t -onvalue "branch" -offvalue "tag"
  checkbutton .modtag.top.force -text "Move existing (-F)" \
     -variable force -onvalue "yes" -offvalue "no"

  grid columnconf .modtag.top 1 -weight 1
  grid rowconf .modtag.top 4 -weight 1
  grid .modtag.top.lbl -column 0 -row 0 -columnspan 2 -pady 2 -sticky ew
  grid .modtag.top.olbl -column 0 -row 1 -sticky nw
  grid .modtag.top.oentry -column 1 -row 1
  grid .modtag.top.nlbl -column 0 -row 2 -sticky nw
  grid .modtag.top.nentry -column 1 -row 2
  grid .modtag.top.branch -column 1 -row 3 -sticky w
  grid .modtag.top.force -column 1 -row 4 -sticky w

  frame .modtag.down -relief groove -bd 2
  pack .modtag.down -side top -fill x

  button .modtag.down.tag -text "Tag" \
    -command "
               cvs_rtag $cvsroot $module $b_or_t \$force \$otag \$ntag; \
               .modtag.down.cancel invoke
             "

  button .modtag.down.delete -text "Remove" \
    -command "
               cvs_rtag $cvsroot $module tag remove \$otag \$ntag; \
               .modtag.down.cancel invoke
             "

  button .modtag.down.cancel -text "Cancel" \
    -command {
               grab release .modtag
               destroy .modtag
             }

  pack .modtag.down.tag .modtag.down.delete .modtag.down.cancel -in .modtag.down -side left \
    -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  bind .modtag.top.nentry <Return> \
    { .modtag.down.tag invoke }

  wm title .modtag "Tag Module"
  wm minsize .modtag 1 1
  gen_log:log T "LEAVE"
}

proc subtract_dialog {args} {
  global cvsglb
  global incvs
  global insvn
  global ingit

  gen_log:log T "ENTER ($args)"

  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select some files to delete first!" .workdir
    return
  }

  foreach f $filelist {
    if {$incvs && [file isdirectory $f]} {
      cvsfail "$f is a directory. Try \"Remove Recursively\" instead" .workdir
      return
    }
  }

  toplevel .subtract
  grab set .subtract

  set mess "This will remove these files:\n\n"
  foreach file $filelist {
    append mess "   $file\n"
  }

  message .subtract.top -justify left -aspect 300 -relief groove \
    -text "Remove a file or files from the module.  The repository\
           will not be changed until you do a commit."
  pack .subtract.top -side top -fill x

  message .subtract.middle -text $mess -aspect 200
  pack .subtract.middle -side top -fill x
  frame .subtract.down
  button .subtract.down.remove -text "Remove" 
  if {$incvs} {
    .subtract.down.remove configure -command {
      grab release .subtract
      destroy .subtract
      cvs_remove [workdir_list_files]
    }
  } elseif {$insvn} {
    .subtract.down.remove configure -command {
      grab release .subtract
      destroy .subtract
      svn_remove [workdir_list_files]
    }
  } elseif {$ingit} {
    .subtract.down.remove configure -command {
      grab release .subtract
      destroy .subtract
      git_rm [workdir_list_files]
    }
  }
  
  button .subtract.down.cancel -text "Cancel" \
    -command { grab release .subtract; destroy .subtract }
  pack .subtract.down -side bottom -fill x -expand 1
  pack .subtract.down.remove .subtract.down.cancel -side left \
    -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  wm title .subtract "Remove Files"
  wm minsize .subtract 1 1

  gen_log:log T "LEAVE"
}

proc edit_dialog {args} {
  global incvs
  global cvsglb

  gen_log:log T "ENTER ($args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }

  if {$args == "."} {
    cvsfail "Please select some files to edit first!" .workdir
    return
  }
  toplevel .editflag
  grab set .editflag

  set filelist [join $args]
  set mess "This will set the edit flag on these files:\n\n"
  foreach file $filelist {
    append mess "   $file\n"
  }

  message .editflag.top -justify left -aspect 300 -relief groove \
    -text "Set the edit flag on a file or files from the module"
  pack .editflag.top -side top -fill x

  message .editflag.middle -text $mess -aspect 200
  pack .editflag.middle -side top -fill x

  frame .editflag.down
  button .editflag.down.remove -text "Edit" \
    -command {
      grab release .editflag
      destroy .editflag
      cvs_edit [workdir_list_files]
    }
  button .editflag.down.cancel -text "Cancel" \
    -command { grab release .editflag; destroy .editflag }
  pack .editflag.down -side bottom -fill x -expand 1
  pack .editflag.down.remove .editflag.down.cancel -side left \
    -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  wm title .editflag "Edit Files"
  wm minsize .editflag 1 1

  gen_log:log T "LEAVE"
}

proc unedit_dialog {args} {
  global incvs
  global cvsglb

  gen_log:log T "ENTER ($args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }

  if {$args == "."} {
    cvsfail "Please select some files to unedit first!" .workdir
    return
  }
  toplevel .uneditflag
  grab set .uneditflag

  set filelist [join $args]
  set mess "This will reset the edit flag on these files:\n\n"
  foreach file $filelist {
    append mess "   $file\n"
  }

  message .uneditflag.top -justify left -aspect 300 -relief groove \
    -text "Reset the edit flag on a file or files from the module."
  pack .uneditflag.top -side top -fill x

  message .uneditflag.middle -text $mess -aspect 200
  pack .uneditflag.middle -side top -fill x

  frame .uneditflag.down
  button .uneditflag.down.remove -text "Unedit" \
    -command {
      grab release .uneditflag
      destroy .uneditflag
      cvs_unedit [workdir_list_files]
    }
  button .uneditflag.down.cancel -text "Cancel" \
    -command { grab release .uneditflag; destroy .uneditflag }
  pack .uneditflag.down -side bottom -fill x -expand 1
  pack .uneditflag.down.remove .uneditflag.down.cancel -side left \
    -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  wm title .uneditflag "Unedit Files"
  wm minsize .uneditflag 1 1

  gen_log:log T "LEAVE"
}

#
# Set up a small(?) update dialog.
#
proc cvs_update_options {} {
  global cvsglb
  global cvscfg

  gen_log:log T "ENTER"

  if {[winfo exists .update]} {
    wm deiconify .update
    raise .update
    grab set .update
    gen_log:log T "LEAVE"
    return
  }

  # Set defaults
  if {! [info exists cvsglb(tagmode_selection)]} {
    update_set_defaults
  }

  toplevel .update
  grab set .update
  frame .update.explaintop
  # Provide an explanation of this dialog box
  label .update.explaintop.explain -relief raised -bd 1 \
    -text "Update files in local directory"

  frame .update.options
  frame .update.options.whichrev -relief groove -border 2
  frame .update.options.diropts -relief groove -border 2
  frame .update.options.normbin -relief groove -border 2

  frame .update.down

  # Always pack OK/Cancel first so they don't disappear
  pack .update.down -side bottom -fill x
  pack .update.explaintop -side top -fill x -pady 1
  pack .update.explaintop.explain -side top -fill x -pady 1
  pack .update.options -side top -fill x -pady 1

  pack .update.options.whichrev -side top -fill x
  pack .update.options.diropts -side top -fill x
  pack .update.options.normbin -side top -fill x

  # keep-same-tag update
  radiobutton .update.options.whichrev.keep \
    -text "Keep same branch or trunk" \
    -variable cvsglb(tagmode_selection) -value "Keep" -anchor w \
    -command {.update.options.whichrev.getrev.lblentry.tname configure -state disabled
              .update.options.whichrev.getrev.lblentry.dirtag configure -state disabled}
  # update to the head revision
  radiobutton .update.options.whichrev.trunk \
    -text "Update local files to be on main trunk (-A)" \
    -variable cvsglb(tagmode_selection) -value "Trunk" -anchor w \
    -command {.update.options.whichrev.getrev.lblentry.tname configure -state disabled
              .update.options.whichrev.getrev.lblentry.dirtag configure -state disabled}
  # update to different branch/tag or not
  radiobutton .update.options.whichrev.tag \
    -text "Update (-r) local files to be on tag/branch" \
    -variable cvsglb(tagmode_selection) -value "Getrev" -anchor w \
    -command {.update.options.whichrev.getrev.lblentry.tname configure -state normal
              .update.options.whichrev.getrev.lblentry.dirtag configure -state normal}

  message .update.options.whichrev.explainkeep -font $cvscfg(listboxfont) \
    -justify left -width 400 \
    -text "If local directory is on main trunk, get latest on main trunk.
If local directory is on a branch, get latest on that branch.
If local directory/file has \"sticky\" non-branch tag, no update."
  message .update.options.whichrev.explaintrunk -font $cvscfg(listboxfont) \
    -justify left -width 400 \
    -text "Advice:  If your local directories are currently on a branch,
you may want to commit any local changes to that branch first."

  pack .update.options.whichrev.keep -side top -fill x
  pack .update.options.whichrev.explainkeep \
    -side top -fill x -pady 1 -ipady 0
  pack .update.options.whichrev.trunk -side top -fill x
  pack .update.options.whichrev.explaintrunk \
    -side top -fill x -pady 1 -ipady 0
  pack .update.options.whichrev.tag -side top -fill x

  frame .update.options.whichrev.getrev
  frame .update.options.whichrev.getrev.lblentry
  label .update.options.whichrev.getrev.lblentry.tlbl -text "Tag Name" -anchor w
  entry .update.options.whichrev.getrev.lblentry.tname -relief sunken \
    -textvariable cvsglb(updatename)
  button .update.options.whichrev.getrev.lblentry.dirtag -text "Dir Tag" \
    -command {
    set cvsglb(updatename) $current_tagname
    }
  message .update.options.whichrev.getrev.explaintag -font $cvscfg(listboxfont) \
    -justify left -width 400 \
    -text "Advice:  Update local files to main trunk (head) first.
Note:  The tag will be 'sticky' for the directory and for each file."

  pack .update.options.whichrev.getrev -side top -expand 1 -fill x
  pack .update.options.whichrev.getrev.lblentry -side top -expand 1 -fill x
  pack .update.options.whichrev.getrev.lblentry.tlbl -side left
  pack .update.options.whichrev.getrev.lblentry.tname -side left -fill x -padx 2 -pady 4
  pack .update.options.whichrev.getrev.lblentry.dirtag -side left -fill x -padx 2 -pady 4
  pack .update.options.whichrev.getrev.explaintag \
    -side top -fill x -pady 1 -ipady 0

  # Where user chooses the action to take if tag is not on a file
  label .update.options.whichrev.getrev.asknotfound \
    -text "If file doesn't exist on this branch/tag:" -anchor w
  frame .update.options.whichrev.getrev.notfound
  radiobutton .update.options.whichrev.getrev.notfound.remove \
    -text "Remove file from local directory" \
    -variable cvsglb(action_notag) -value "Remove"
  radiobutton .update.options.whichrev.getrev.notfound.gethead \
    -text "Get head revision (-f)" \
    -variable cvsglb(action_notag) -value "Get_head"

  pack .update.options.whichrev.getrev.asknotfound -side top -fill x
  pack .update.options.whichrev.getrev.notfound -side top -expand 1 -fill x
  pack .update.options.whichrev.getrev.notfound.remove -side left
  pack .update.options.whichrev.getrev.notfound.gethead -side left

  # Recurse or not.
  frame .update.options.diropts.radio1
  radiobutton .update.options.diropts.radio1.recurse -text "Recurse the subdirectories" \
     -variable cvsglb(update_recurse) -value "recurse" -anchor w \
     -command {
              .update.options.diropts.getdir configure -state normal
              .update.options.diropts.prune configure -state normal
              .update.options.diropts.lblentry.tdir configure -state normal
              }
  radiobutton .update.options.diropts.radio1.local -text "This directory only (-l)" \
     -variable cvsglb(update_recurse) -value "local" -anchor w \
     -command {
              .update.options.diropts.getdir configure -state disabled
              .update.options.diropts.prune configure -state disabled
              .update.options.diropts.lblentry.tdir configure -state disabled
              }

  pack .update.options.diropts.radio1 -side top -expand 1 -fill x
  pack .update.options.diropts.radio1.recurse -side left
  pack .update.options.diropts.radio1.local -side left

  label .update.options.diropts.prunelbl \
    -text "\nIf directory is here but no longer in repository:" -anchor w
  checkbutton .update.options.diropts.prune -text "Prune it (-P)" \
     -variable cvsglb(update_prune) -onvalue "prune" -offvalue "no-prune" -anchor w
  # Where user chooses whether to pick up directories not currently in local
  label .update.options.diropts.getlbl \
    -text "If directory is in repository but not in local:" -anchor w
  checkbutton .update.options.diropts.getdir -text "Get it (-d)" \
    -variable cvsglb(get_all_dirs) -onvalue "Yes" -offvalue "No" -anchor w \
    -command {
               if {$cvsglb(get_all_dirs) != "Yes"} {
                 .update.options.diropts.lblentry.tdir configure -state disabled
               } else {
                 .update.options.diropts.lblentry.tdir configure -state normal
               }
             }
  frame .update.options.diropts.lblentry
  label .update.options.diropts.lblentry.tlbl -text "Specific directory (optional)" -anchor w
  entry .update.options.diropts.lblentry.tdir -relief sunken -state disabled \
    -textvariable cvsglb(getdirname)
  # State of top radiobuttons (keep same, main, or tag)
  if {$cvsglb(tagmode_selection) != "Getrev"} {
    .update.options.whichrev.getrev.lblentry.tname configure -state disabled
    .update.options.whichrev.getrev.lblentry.dirtag configure -state disabled
  }
  # state of -l radiobuttons
  if {$cvsglb(update_recurse) != "recurse"} {
    .update.options.diropts.getdir configure -state disabled
    .update.options.diropts.prune configure -state disabled
    .update.options.diropts.lblentry.tdir configure -state disabled
  }
  # State of -d checkbutton
  if {$cvsglb(get_all_dirs) != "Yes"} {
    .update.options.diropts.lblentry.tdir configure -state disabled
  }

  pack .update.options.diropts.prunelbl -side top -expand 1 -fill x
  pack .update.options.diropts.prune -side top -expand 1 -fill x
  pack .update.options.diropts.getlbl -side top -expand 1 -fill x
  pack .update.options.diropts.getdir -side top -expand 1 -fill x
  pack .update.options.diropts.lblentry -side top -expand 1 -fill x
  pack .update.options.diropts.lblentry.tlbl -side left
  pack .update.options.diropts.lblentry.tdir -side left -fill x -padx 2 -pady 4

  # normal or binary?
  label .update.options.normbin.lnormbin -text "Treat files as:" -anchor w
  frame .update.options.normbin.radio
  radiobutton .update.options.normbin.radio.normalfile -text "Normal file" \
    -variable cvsglb(norm_bin) -value "Normal" -anchor w
  radiobutton .update.options.normbin.radio.binaryfile -text "Binary file (-kb)" \
    -variable cvsglb(norm_bin) -value "Binary" -anchor w

  pack .update.options.normbin.lnormbin -side top -fill both
  pack .update.options.normbin.radio -side top -expand 1 -fill x
  pack .update.options.normbin.radio.normalfile -side left
  pack .update.options.normbin.radio.binaryfile -side left

  # The OK/Cancel buttons
  button .update.ok -text "OK" \
    -command { grab release .update; wm withdraw .update; update_with_options }
  button .update.apply -text "Apply" \
    -command update_with_options
  button .update.reset -text "Reset defaults" \
    -command update_set_defaults
  button .update.quit -text "Close" \
    -command { grab release .update; wm withdraw .update }

  pack .update.ok .update.apply .update.reset .update.quit -in .update.down \
    -side left -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  # Window Manager stuff
  wm title .update "Update a Module"
  wm minsize .update 1 1
  gen_log:log T "LEAVE"
}

# Set defaults for "Update with Options" dialog
proc update_set_defaults {} {
  global cvsglb

  set cvsglb(tagmode_selection) "Keep"
  set cvsglb(updatename) ""
  set cvsglb(update_recurse) "recurse"
  set cvsglb(action_notag) "Remove"
  set cvsglb(update_prune) "prune"
  set cvsglb(get_all_dirs) "No"
  set cvsglb(getdirname) ""
  set cvsglb(norm_bin) "Normal"
}

# Do what was setup in the "Update with Options" dialog
proc update_with_options {} {
  global cvsglb

  gen_log:log T "ENTER"

  if { $cvsglb(updatename) == "" } {
    set tagname "BASE"
  } else {
    set tagname $cvsglb(updatename)
  }
  if { $cvsglb(get_all_dirs) == "No" } { set cvsglb(getdirname) "" }
  if { $cvsglb(getdirname) == "" } {
    set dirname " "
  } else {
    set dirname $cvsglb(getdirname)
  }
  #puts "from update_setup, tagname $tagname.  norm_bin $cvsglb(norm_bin)"
  if { $cvsglb(tagmode_selection) == "Keep" } {
    set tagname "BASE"
  } elseif { $cvsglb(tagmode_selection) == "Trunk" } {
    set tagname "HEAD"
  }

  eval "cvs_update {$tagname} {$cvsglb(norm_bin)} \
       {$cvsglb(action_notag)} \
       {$cvsglb(update_recurse)} {$cvsglb(update_prune)} \
       {$cvsglb(get_all_dirs)} {$dirname} \
       [workdir_list_files]"

  gen_log:log T "LEAVE"
}

proc addir_dialog {args} {
  global cvs
  global incvs

  gen_log:log T "ENTER ($args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }

  set binflag ""
  toplevel .add
  grab set .add

  set filelist [join $args]
  if {$filelist == ""} {
    set mess "This will add all new directories"
  } else {
    set mess "This will add these directories:\n\n"
    foreach file $filelist {
      append mess "   $file\n"
    }
  }

  message .add.top -justify left -aspect 300 -relief groove \
    -text "Add (recursively) a directory to the module.\
           The repository will not be changed until you do a commit."
  pack .add.top -side top -fill x

  message .add.middle -text $mess -aspect 200
  pack .add.middle -side top -fill x

  checkbutton .add.binary -text "-kb (binary)" \
     -variable binflag -onvalue "-kb" -offvalue ""
  pack .add.binary -side top

  frame .add.down
  button .add.down.add -text "Add" \
    -command {
      grab release .add
      destroy .add
      foreach dir [workdir_list_files] {
        cvs_add_dir $binflag $dir
      }
    }
  button .add.down.cancel -text "Cancel" \
    -command { grab release .add; destroy .add }
  pack .add.down -side bottom -fill x -expand 1
  pack .add.down.add .add.down.cancel -side left \
    -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  wm title .add "Add Directories"
  wm minsize .add 1 1

  gen_log:log T "LEAVE"
}

proc subtractdir_dialog {args} {
  global cvs
  global incvs

  gen_log:log T "ENTER ($args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }

  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select some directories to remove first!" .workdir
    return
  }

  toplevel .subtract
  grab set .subtract

  set mess "This will remove these directories:\n\n"
  foreach file $filelist {
    append mess "   $file\n"
  }

  message .subtract.top -justify left -aspect 300 -relief groove \
    -text "Remove (recursively) a directory from the module.  The repository\
           will not be changed until you do a commit."
  pack .subtract.top -side top -fill x

  message .subtract.middle -text $mess -aspect 200
  pack .subtract.middle -side top -fill x
  frame .subtract.down
  button .subtract.down.remove -text "Remove" \
    -command {
      grab release .subtract
      destroy .subtract
      cvs_remove_dir [workdir_list_files]
    }
  button .subtract.down.cancel -text "Cancel" \
    -command { grab release .subtract; destroy .subtract }
  pack .subtract.down -side bottom -fill x -expand 1
  pack .subtract.down.remove .subtract.down.cancel -side left \
    -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  wm title .subtract "Remove Directories"
  wm minsize .subtract 1 1

  gen_log:log T "LEAVE"
}

proc file_input_and_do {title command} {
  global filename

  gen_log:log T "ENTER ($title $command)"

  toplevel .file_input_and_do
  grab set .file_input_and_do

  frame .file_input_and_do.top
  pack .file_input_and_do.top -side top -fill both -expand 1 -pady 4 -padx 4

  label .file_input_and_do.top.lbl -text "File Name" -anchor w
  entry .file_input_and_do.top.entry -relief sunken -textvariable filename
  bind .file_input_and_do.top.entry <Return> \
    { .file_input_and_do.ok invoke }
  pack .file_input_and_do.top.lbl -side left
  pack .file_input_and_do.top.entry -side left -fill x -expand 1

  frame .file_input_and_do.bottom
  pack .file_input_and_do.bottom -side bottom -fill x -pady 4 -padx 4

  button .file_input_and_do.ok -text "Ok" \
    -command "
      .file_input_and_do.close invoke
      $command \$filename
    "
  button .file_input_and_do.close -text "Cancel" \
    -command {
      grab release .file_input_and_do
      destroy .file_input_and_do
    }
  pack .file_input_and_do.ok .file_input_and_do.close \
    -in .file_input_and_do.bottom \
    -side left -fill both -expand 1

  wm title .file_input_and_do $title
  wm minsize .file_input_and_do 1 1
  focus .file_input_and_do.top.entry

  gen_log:log T "LEAVE"
}

proc release_dialog { args } {

  gen_log:log T "ENTER ($args)"

  set delflag ""
  toplevel .release
  grab set .release

  set filelist [join $args]
  message .release.top -justify left -aspect 300 -relief groove \
    -text "Tell CVS that the directory is no longer being\
           worked on. CVS will stop tracking it in the\
           CVS history file.  Optionally, delete the directory."
  pack .release.top -side top -fill x
  
  #set mess "This will release these directories:\n\n"
  #foreach file $filelist {
    #append mess "   $file\n"
  #}
  #message .release.middle -text $mess -aspect 200
  #pack .release.middle -side top -fill x

  checkbutton .release.binary -text "delete (-d)" \
     -variable delflag -onvalue "-d" -offvalue ""
  pack .release.binary -side top

  frame .release.down
  button .release.down.release -text "Release" \
    -command {
      grab release .release
      destroy .release
      cvs_release $delflag [workdir_list_files]
    }
  button .release.down.cancel -text "Cancel" \
    -command { grab release .release; destroy .release }
  pack .release.down -side bottom -fill x -expand 1
  pack .release.down.release .release.down.cancel -side left \
    -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  wm title .release "Release Directories"
  wm minsize .release 1 1

  gen_log:log T "LEAVE"
}

proc svn_update_options {} {
  global cvsglb
  global cvscfg

  gen_log:log T "ENTER"

  if {[winfo exists .svn_update]} {
    wm deiconify .svn_update
    raise .svn_update
    grab set .svn_update
    gen_log:log T "LEAVE"
    return
  }

  if {! [info exists cvsglb(tagmode_selection)]} {
    set cvsglb(tagmode_selection) "Keep"
  }

  toplevel .svn_update
  grab set .svn_update
  frame .svn_update.explaintop
  frame .svn_update.options
  frame .svn_update.down

  frame .svn_update.options.keep -relief groove -border 2
  frame .svn_update.options.trunk -relief groove -border 2
  frame .svn_update.options.branch -relief groove -border 2
  frame .svn_update.options.revision -relief groove -border 2

  pack .svn_update.down -side bottom -fill x
  pack .svn_update.explaintop -side top -fill x -pady 1
  pack .svn_update.options -side top -fill x -pady 1

  # Provide an explanation of this dialog box
  label .svn_update.explain -relief raised -bd 1 \
    -text "Update files in local directory"

  pack .svn_update.explain \
    -in .svn_update.explaintop -side top -fill x

  pack .svn_update.options.keep -side top -fill x
  pack .svn_update.options.trunk -side top -fill x
  pack .svn_update.options.branch -side top -fill x
  pack .svn_update.options.revision -side top -fill x

  # If the user wants to simply do a normal update
  radiobutton .svn_update.options.keep.select \
    -text "Update to most recent revision on same branch or trunk." \
    -variable cvsglb(tagmode_selection) -value "Keep" -anchor w

  message .svn_update.options.keep.explain -font $cvscfg(listboxfont) \
    -justify left -width 400 \
    -text "If local directory is on main trunk, get latest on main trunk.
If local directory is on a branch, get latest on that branch."

  pack .svn_update.options.keep.select -side top -fill x
  pack .svn_update.options.keep.explain -side top -fill x -pady 1 -ipady 0

  # If the user wants to update to the head revision
  radiobutton .svn_update.options.trunk.select \
    -text "Switch local files to be on main trunk" \
    -variable cvsglb(tagmode_selection) -value "Trunk" -anchor w

  message .svn_update.options.trunk.explain -font $cvscfg(listboxfont) \
    -justify left -width 400 \
    -text "Advice:  If your local directories are currently on a branch, \
you may want to commit any local changes to that branch first."

  pack .svn_update.options.trunk.select -side top -fill x
  pack .svn_update.options.trunk.explain -side top -fill x -pady 1 -ipady 0

  # If the user wants to update to a branch
  radiobutton .svn_update.options.branch.select \
    -text "Switch local files to be on a branch" \
    -variable cvsglb(tagmode_selection) -value "Branch" -anchor w

  frame .svn_update.options.branch.lblentry
  label .svn_update.lbranch -text "Branch" -anchor w
  entry .svn_update.tbranch -relief sunken -textvariable cvsglb(branchname)

  pack .svn_update.options.branch.select -side top -fill x
  pack .svn_update.options.branch.lblentry -side top -fill x \
    -expand y -pady 1 -ipady 0
  pack .svn_update.lbranch -in .svn_update.options.branch.lblentry \
    -side left -fill x -pady 4
  pack .svn_update.tbranch -in .svn_update.options.branch.lblentry \
    -side left -fill x -padx 2 -pady 4

  # Where user enters a revision number
  radiobutton .svn_update.options.revision.select \
    -text "Update (-r) local files to be a specific revision:" \
    -variable cvsglb(tagmode_selection) -value "Revision" -anchor w

  frame .svn_update.options.revision.lblentry
  label .svn_update.lrev -text "Revision" -anchor w
  entry .svn_update.trev -relief sunken -textvariable cvsglb(revnumber)

  pack .svn_update.options.revision.select -side top -fill x
  pack .svn_update.options.revision.lblentry -side top -fill x \
    -expand y -pady 1 -ipady 0
  pack .svn_update.lrev -in .svn_update.options.revision.lblentry \
    -side left -fill x -pady 4
  pack .svn_update.trev -in .svn_update.options.revision.lblentry \
    -side left -fill x -padx 2 -pady 4

  # The OK/Cancel buttons
  button .svn_update.ok -text "OK" \
    -command { grab release .svn_update
               wm withdraw .svn_update              
               svn_opt_update }

  button .svn_update.apply -text "Apply" \
    -command svn_opt_update

  button .svn_update.quit -text "Close" \
    -command { grab release .svn_update
               wm withdraw .svn_update }

  pack .svn_update.ok .svn_update.apply .svn_update.quit -in .svn_update.down \
    -side left -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  # Window Manager stuff
  wm title .svn_update "Update from Repository"
  wm minsize .svn_update 1 1
  gen_log:log T "LEAVE"
}

proc assemble_mergetags {from} {
  global cvscfg
  global current_tagname

  gen_log:log T "ENTER ($from)"

  # Construct tag names
  set totagbegin [string first "_BRANCH_" $cvscfg(mergetoformat)]
  set totagend [expr {$totagbegin + 8}]
  set toprefix [string range $cvscfg(mergetoformat) 0 [expr {$totagbegin - 1}]]
  set fromtagbegin [string first "_BRANCH_" $cvscfg(mergefromformat)]
  set fromprefix [string range $cvscfg(mergefromformat) 0 [expr {$fromtagbegin - 1}]]
  set datef [string range $cvscfg(mergetoformat) $totagend end]
  set today [clock format [clock seconds] -format "$datef"]

  if {[llength $current_tagname] == 1} {
    set curr_tag $current_tagname
  } else {
    set curr_tag "trunk"
  }

  set curr $curr_tag
  gen_log:log D "curr_tag $curr"
  if {$curr == "trunk"} {set curr $cvscfg(mergetrunkname)}
  if {$from == "trunk"} {set from $cvscfg(mergetrunkname)}
  set totag "${toprefix}_${curr}_$today"
  set fromtag "${fromprefix}_${from}_$today"
  # I had symbolic tags in mind, but some people are using untagged versions.
  # Substitute the dots, which are illegal for tagnames.
  regsub -all {\.} $totag {-} totag
  regsub -all {\.} $fromtag {-} fromtag

  gen_log:log T "LEAVE ($curr_tag $fromtag $totag)"
  return [list $curr_tag $fromtag $totag]
}

proc dialog_merge_notice {sys from frombranch fromtag totag filelist} {
  global cvscfg

  toplevel .reminder
  wm title .reminder "Tag and Commit"
  label .reminder.m1 -text \
    "Now, you must examine the merged files and resolve any conflicts.\
    \nLeave this dialog up, and when you are ready to commit,\
    press the Ready button" 
  button .reminder.ready -text "I'm ready" \
    -command {
       foreach w {m2 totag fromtag bottom.ok} {
         .reminder.$w configure -state normal
       }
       foreach w {m1 ready} {
         .reminder.$w configure -state disabled
       }
    }
  label .reminder.m2 -text \
    "If you check the box, TkCVS will apply the \"to\" tag,\
    \ncommit your changes, and finally\napply the \"from\" tag.\
    \nIf you don't check the box, the changes will be committed\
    \nbut no tagging will be done"
  checkbutton .reminder.autotag -text "Apply these tags" \
    -variable cvscfg(auto_tag)
  entry .reminder.totag -width 32
  .reminder.totag insert end $totag 
  entry .reminder.fromtag -width 32
  .reminder.fromtag insert end $fromtag 
  frame .reminder.bottom -relief raised -bd 2
  button .reminder.bottom.cancel -text "Cancel" \
    -command {destroy .reminder}
  button .reminder.bottom.ok -text "OK" \
    -command "${sys}_merge_tag_seq $from $frombranch $totag $fromtag $filelist;\
              destroy .reminder"
  pack .reminder.bottom -side bottom -fill x
  pack .reminder.bottom.ok -side left -expand yes
  pack .reminder.bottom.cancel -side right -expand yes
  pack .reminder.m1 -side top
  pack .reminder.ready -side top
  pack .reminder.m2 -side top
  pack .reminder.autotag -side top
  pack .reminder.fromtag -side top -padx 2
  pack .reminder.totag -side top -padx 2
  foreach w {m2 totag fromtag bottom.ok} {
    .reminder.$w configure -state disabled
  }
}

# Keep a log of commit log messages.  We want to do this whether the
# history has ever been examined by the user or not
proc commit_history {comment} {
  global cvsglb

  set comment [string trimright $comment]
  set c 0
  foreach ch [array names cvsglb commit_comment,*] {
    if {$comment eq $cvsglb($ch)} {
      # We already have this one.  We don't have to
      # do anything else.
      gen_log:log D "Comment is a duplicate"
      return
    }
    incr c
  }
  # We don't have this one yet
  set cvsglb(commit_comment,$c) $comment
  gen_log:log D "New comment $c"
  if [winfo exists .ci_history] {
    .ci_history.text insert end "$comment"
    .ci_history.text insert end "\n"
    .ci_history.text insert end "================================================================================\n"
  }
}

# See the previous log messages
proc history_browser {} {
  global cvsglb

  gen_log:log T "ENTER history_browser"

  if {! [winfo exists .ci_history]} {
    toplevel .ci_history
    wm protocol .ci_history WM_DELETE_WINDOW { wm withdraw .ci_history }
    wm title .ci_history "Commit Log History for Session"

    text .ci_history.text -setgrid yes -relief sunken -border 2 \
      -exportselection 1 -yscroll ".ci_history.scroll set"
    scrollbar .ci_history.scroll -relief sunken \
      -command ".ci_history.text yview"
    frame .ci_history.bottom
    search_textwidget_init
    button .ci_history.bottom.srchbtn -text Search \
      -command "search_textwidget .ci_history.text"
    entry .ci_history.bottom.entry -width 20 -textvariable cvsglb(searchstr)
    bind .ci_history.bottom.entry <Return> \
        "search_textwidget .ci_history.text"
    button .ci_history.bottom.close -text "Close" \
       -command { wm withdraw .ci_history }

    pack .ci_history.bottom -side bottom -fill x
    pack .ci_history.scroll -side right -fill y
    pack .ci_history.text -fill both -expand 1
    pack .ci_history.bottom.srchbtn -side left
    pack .ci_history.bottom.entry -side left
    pack .ci_history.bottom.close -side right

    # If this is the first time we've built the window, add the history we have so far
    foreach ch [array names cvsglb commit_comment,*] {
      .ci_history.text insert end $cvsglb($ch)
      .ci_history.text insert end "\n"
      .ci_history.text insert end "================================================================================\n"
    }
  }

  wm deiconify .ci_history
  gen_log:log T "LEAVE"
}
