#
# Tcl Library for TkCVS
#

#
# $Id: dialog.tcl,v 1.38 2005/07/07 04:18:50 dorothyr Exp $
#
# Smallish dialogs - add, tag
#

if {[catch "image type arr_dn"]} {
  workdir_images
}

# Creates the widgets for the dynamic form dialog
proc dialog_FormCreate { title form_data } {
  global cvscfg
  global dynamic_dialog
  global dialog_action
  gen_log:log T "ENTER ($form_data)"

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

  gen_log:log T "LEAVE"
  return
}

proc dialog_FormComplete { w form_data } {
  global dynamic_dialog

  gen_log:log T "ENTER ($w <data suppressed>)"

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

# Check out a CVS module from the Module Browser
proc dialog_cvs_checkout { cvsroot module {revtag {} } } {
  global cvscfg
  global dynamic_dialog
  global dialog_action

  gen_log:log T "ENTER ($cvsroot $module $revtag)"
  set dir [pwd]
  set dynamic_dialog(cvsroot) $cvsroot
  set dynamic_dialog(module) $module
  set dynamic_dialog(revtag) $revtag
  set dynamic_dialog(dir) [pwd]
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
  set dialog_action {cvs_checkout $dynamic_dialog(dir) \
     $dynamic_dialog(cvsroot) \
     $dynamic_dialog(prune) $dynamic_dialog(kflag) \
     $dynamic_dialog(revtag) $dynamic_dialog(date) $dynamic_dialog(target) \
     $dynamic_dialog(mtag1) $dynamic_dialog(mtag2) $dynamic_dialog(module)
  }

  set form [dialog_FormCreate "Checkout Module" $dialog_form_checkout]
}

proc add_dialog {args} {
  global cvs
  global incvs
  global insvn
  global cvscfg

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

proc merge_dialog { from since file {fromtag {}} } {
  global cvscfg
  global cvs
  global current_tagname

    set from [uplevel {concat $from}]
    set since [uplevel {concat $since}]
    set file [uplevel {concat $file}]
    set fromtag [uplevel {concat $fromtag}]

    gen_log:log T "ENTER (\"$from\" \"$since\" \"$file\" \"$fromtag\")"

    if {$from == {}} {
       cvsfail "You must specify a branch to merge from!"
       return
    }
    if {$fromtag == {}} {
       set fromtag $from
    }

    # Tag where we merged from
    if {[llength $current_tagname] == 1} {
      set curr_tag $current_tagname
    } else {
      set curr_tag "trunk"
    }

    if {$since == {}} {
      set since "\"\""
      set mess "Merge revision $from"
    } else {
      set mess "Merge the changes between revision $since and $from"
      append mess " (if $since > $from the changes are removed)"
      append commandline "-j$since "
    }
    append mess " to the current revision ($curr_tag)"

    # Construct tag names
    set totagbegin [string first "_BRANCH_" $cvscfg(mergetoformat)]
    set totagend [expr {$totagbegin + 8}]
    set toprefix [string range $cvscfg(mergetoformat) 0 [expr {$totagbegin - 1]}]
    set fromtagbegin [string first "_BRANCH_" $cvscfg(mergefromformat)]
    set fromprefix [string range $cvscfg(mergefromformat) 0 [expr {$fromtagbegin - 1]}]
    set datef [string range $cvscfg(mergetoformat) $totagend end]
    set today [clock format [clock seconds] -format "$datef"]

    set mtag "${toprefix}_${curr_tag}_$today"
    set ftag "${fromprefix}_${fromtag}_$today"

    # I had symbolic tags in mind, but some people are using untagged versions.
    # Substitute the dots, which are illegal for tagnames.
    regsub -all {\.} $mtag {-} mtag
    regsub -all {\.} $ftag {-} ftag

    toplevel .merge
    frame .merge.top

    message .merge.top.m1 -aspect 600 -text "$mess"
    frame .merge.top.f
    checkbutton .merge.top.f.fromtag \
      -text "Apply the tag" \
      -variable cvscfg(auto_tag)
    entry .merge.top.f.ent -textvariable mtag \
      -width 32 -relief raised -bd 1 
    .merge.top.f.ent delete 0 end
    .merge.top.f.ent insert end $mtag
    message .merge.top.m2 -aspect 600 -text "to revision $from"
    frame .merge.bottom -relief raised -bd 2
    button .merge.bottom.apply -text "Apply" \
      -command "cvs_join $from $since \[.merge.top.f.ent get\] $ftag $file"
    button .merge.bottom.ok -text "OK" \
      -command "cvs_join $from $since \[.merge.top.f.ent get\] $ftag $file; destroy .merge"
    button .merge.bottom.cancel -text "Cancel" \
      -command "destroy .merge"

    pack .merge.bottom -side bottom -expand 1 -fill x
    pack .merge.bottom.apply -side left -expand 1
    pack .merge.bottom.ok -side left -expand 1
    pack .merge.bottom.cancel -side left -expand 1

    pack .merge.top -side top -fill x
    pack .merge.top.m1 -side top -fill x -expand y
    pack .merge.top.f -side top -padx 2 -pady 4
    pack .merge.top.f.fromtag -side left
    pack .merge.top.f.ent -side left
    pack .merge.top.m2 -side top -fill x -expand y
    gen_log:log T "LEAVE"
}

proc file_tag_dialog {branch} {
  global incvs insvn inrcs
  global cvscfg
  global branchflag

  gen_log:log T "ENTER"

  set branchflag $branch

  toplevel .tag
  #grab set .tag

  frame .tag.top
  pack .tag.top -side top -fill x

  message .tag.top.msg -justify left -aspect 300 -relief groove \
    -text "Apply a new tag or branch tag \
           to the marked files, recursively.\
           Will change the repository.\
           If a branch, it can also update local directory if desired."

  label .tag.top.lbl -text "Tag Name" -anchor w
  entry .tag.top.entry -relief sunken -textvariable usertagname
  checkbutton .tag.top.branch -text "Branch tag (-b)" \
     -variable branchflag -onvalue "yes" -offvalue "no" \
     -command { 
        if {$branchflag == "no"} {\
           .tag.mid.upd config -state disabled; set updflag "no" } \
        else {.tag.mid.upd config -state normal } \
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
    .tag.down.tag configure -command {
      svn_tag $usertagname no $branchflag $updflag \
          [workdir_list_files]
      grab release .tag
      destroy .tag
    }
  }
  button .tag.down.cancel -text "Cancel" \
    -command { grab release .tag; destroy .tag }

  pack .tag.down.tag .tag.down.cancel -in .tag.down -side left \
    -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  if {$branchflag == "no"} {
     .tag.mid.upd config -state disabled
     set updflag "no"
  } else {
     .tag.mid.upd config -state normal
  }

  wm title .tag "tag"
  wm minsize .tag 1 1
  gen_log:log T "LEAVE"
}

proc rtag_dialog { cvsroot module branch } {
  global cvscfg

  gen_log:log T "ENTER ($cvsroot $module $branch)"

    set cvsroot [uplevel {list $cvsroot}]
    set module [uplevel {list $module}]
    set branch [uplevel {list $branch}]

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
       -variable branch -onvalue "yes" -offvalue "no"
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
      -command {
                 .modtag.down.cancel invoke
                 cvs_rtag $cvsroot $module $branch $force $otag $ntag
               }]

    button .modtag.down.cancel -text "Cancel" \
      -command {
                 grab release .modtag
                 destroy .modtag
               }]

    pack .modtag.down.tag .modtag.down.cancel -in .modtag.down -side left \
      -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

    bind .modtag.top.nentry <Return> \
      { .modtag.down.tag invoke }]

    wm title .modtag "Tag Module"
    wm minsize .modtag 1 1
    gen_log:log T "LEAVE"
}

proc subtract_dialog {args} {
  global cvs
  global incvs
  global insvn
  global cvscfg

  gen_log:log T "ENTER ($args)"

  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select some files to delete first!" .workdir
    return
  }

  foreach f $filelist {
    if {[file isdirectory $f]} {
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
  global cvs
  global incvs
  global cvscfg

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
  global cvs
  global incvs
  global cvscfg

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
proc update_run {} {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER"

  if {[winfo exists .update]} {
    wm deiconify .update
    raise .update
    grab set .update
    gen_log:log T "LEAVE"
    return
  }

  # Set defaults if not already set
  if {! [info exists cvsglb(tagmode_selection)]} {
    update_set_defaults
  }

  toplevel .update
  grab set .update
  frame .update.explaintop
  frame .update.options
  frame .update.down

  frame .update.options.keep -relief groove -border 2
  frame .update.options.trunk -relief groove -border 2
  frame .update.options.getrev -relief groove -border 2
  frame .update.options.newdir -relief groove -border 2
  frame .update.options.normbin -relief groove -border 2
  frame .update.getrevleft
  frame .update.getrevright
  frame .update.getreventry

  frame .update.getdirsleft
  frame .update.getdirsright
  frame .update.getdirsentry

  pack .update.down -side bottom -fill x
  pack .update.explaintop -side top -fill x -pady 1
  pack .update.options -side top -fill x -pady 1


  # Provide an explanation of this dialog box
  label .update.explain1 -relief raised -bd 1 \
    -text "Update files in local directory"

 message .update.explain2 -font $cvscfg(listboxfont) \
     -justify left -width 400 \
     -text "Always recursive.
Empty directories always pruned (-P).
'Reset defaults' button will show defaults."

  pack .update.explain1 .update.explain2 \
    -in .update.explaintop -side top -fill x

  pack .update.options.keep -in .update.options -side top -fill x
  pack .update.options.trunk -in .update.options -side top -fill x
  pack .update.options.getrev -in .update.options -side top -fill x
  pack .update.options.newdir -in .update.options -side top -fill x
  pack .update.options.normbin -in .update.options -side top -fill x



  # If the user wants to simply do a normal update
  radiobutton .update.options.keep.select -text "Keep same branch or trunk." \
    -variable cvsglb(tagmode_selection) -value "Keep" -anchor w

  message .update.options.keep.explain1 -font $cvscfg(listboxfont) \
    -justify left -width 400 \
    -text "If local directory is on main trunk, get latest on main trunk.
If local directory is on a branch, get latest on that branch.
If local directory/file has \"sticky\" non-branch tag, no update."

  pack .update.options.keep.select -in .update.options.keep \
    -side top -fill x
  pack .update.options.keep.explain1 \
    -in .update.options.keep -side top -fill x -pady 1 -ipady 0

  # If the user wants to update to the head revision
  radiobutton .update.options.trunk.select \
    -text "Update local files to be on main trunk (-A)" \
    -variable cvsglb(tagmode_selection) -value "Trunk" -anchor w

  message .update.options.trunk.explain1 -font $cvscfg(listboxfont) \
    -justify left -width 400 \
    -text "Advice:  If your local directories are currently on a branch, \
you may want to commit any local changes to that branch first."

  pack .update.options.trunk.select \
    -in .update.options.trunk -side top -fill x
  pack .update.options.trunk.explain1 \
    -in .update.options.trunk -side top -fill x -pady 1 -ipady 0

  # If the user wants to update local files to a branch/tag

  # Where user enters a tag name (optional)
  radiobutton .update.options.getrev.select \
    -text "Update (-r) local files to be on tag/branch:" \
    -variable cvsglb(tagmode_selection) -value "Getrev" -anchor w

  message .update.options.getrev.explain -font $cvscfg(listboxfont) \
    -justify left -width 400 \
    -text "Advice:  Update local files to main trunk (head) first.
Note:  The tag will be 'sticky' for the directory and for each file."

  label .update.lname -text "Tag Name" -anchor w

  entry .update.tname -relief sunken -textvariable cvsglb(updatename)

  # bind_motifentry .update.tname

  pack .update.lname -in .update.getrevleft \
    -side top -fill x -pady 4

  pack .update.tname -in .update.getrevright \
    -side top -fill x -padx 2 -pady 4

  # Where user chooses the action to take if tag is not on a file
  label .update.lnotfound -text "If tag not found for file," \
    -anchor w

  radiobutton .update.notfoundremove -text "Remove file from local directory" \
    -variable cvsglb(action_notag) -value "Remove"

  radiobutton .update.notfoundhead -text "Get head revision (-f)" \
    -variable cvsglb(action_notag) -value "Get_head"

  pack .update.options.getrev.select -in .update.options.getrev \
    -side top -fill x
  pack .update.options.getrev.explain -in .update.options.getrev \
    -side top -fill x
  pack .update.getreventry -in .update.options.getrev \
    -side top -fill x
  pack .update.lnotfound -in .update.options.getrev \
    -side top -fill x
  pack .update.notfoundhead .update.notfoundremove \
    -in .update.options.getrev -side bottom -anchor w \
    -ipadx 8 -padx 4

  pack .update.getrevleft -in .update.getreventry \
     -side left -fill y
  pack .update.getrevright -in .update.getreventry \
     -side left -fill both -expand 1


  # Where user chooses whether to pick up directories not currently in local
  label .update.lalldirs \
    -text "If directory is in repository but not in local:" -anchor w

  radiobutton .update.noalldirs -text "Ignore it" \
    -variable cvsglb(get_all_dirs) -value "No" -anchor w
  radiobutton .update.getalldirs -text "Get it (-d)" \
    -variable cvsglb(get_all_dirs) -value "Yes" -anchor w

  label .update.lgetdirname -text "Specific directory (optional)" -anchor w
  entry .update.tgetdirname -relief sunken -textvariable cvsglb(getdirname)

  pack .update.lgetdirname -in .update.getdirsleft \
    -side top -fill x
  pack .update.tgetdirname -in .update.getdirsright \
    -side top -fill x -padx 2 -pady 1

  pack .update.getdirsleft -in .update.getdirsentry \
    -side left -fill y
  pack .update.getdirsright -in .update.getdirsentry \
    -side left -fill both -expand 1

  pack .update.lalldirs -in .update.options.newdir \
    -side top -fill x
  pack .update.getdirsentry -in .update.options.newdir \
    -side bottom -fill x
  pack .update.noalldirs .update.getalldirs -in .update.options.newdir \
    -side left -fill both -ipadx 2 -ipady 2 -padx 4 -expand 1

  # Where user chooses whether file is normal or binary
  label .update.lnormalbinary -text "Treat each file as:" -anchor w

  radiobutton .update.normalfile -text "Normal File" \
    -variable cvsglb(norm_bin) -value "Normal" -anchor w
  radiobutton .update.binaryfile -text "Binary File (-kb)" \
    -variable cvsglb(norm_bin) -value "Binary" -anchor w

  pack .update.lnormalbinary -in .update.options.normbin -side top -fill both
  pack .update.normalfile .update.binaryfile -in .update.options.normbin \
    -side left -fill both -ipadx 2 -ipady 2 -padx 4 -expand 1

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
# wm withdraw .update
  wm title .update "Update a Module"
  wm minsize .update 1 1
  gen_log:log T "LEAVE"
}

# Set defaults for "Update with Options" dialog
proc update_set_defaults {} {
  global cvsglb

  set cvsglb(tagmode_selection) "Keep"
  set cvsglb(updatename) ""
  set cvsglb(action_notag) "Remove"
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
    eval "cvs_update {BASE} \
       {$cvsglb(norm_bin)} {$cvsglb(action_notag)} {$cvsglb(get_all_dirs)} \
       {$dirname} [workdir_list_files]"
  } elseif { $cvsglb(tagmode_selection) == "Trunk" } {
    eval "cvs_update {HEAD} \
       {$cvsglb(norm_bin)} {$cvsglb(action_notag)} {$cvsglb(get_all_dirs)} \
       {$dirname} [workdir_list_files]"
  } elseif { $cvsglb(tagmode_selection) == "Getrev" } {
    eval "cvs_update {$tagname} \
       {$cvsglb(norm_bin)} {$cvsglb(action_notag)} {$cvsglb(get_all_dirs)} \
       {$dirname} [workdir_list_files]"
  } else {
    cvsfail "Internal TkCVS error.\ntagmode_selection $cvsglb(tagmode_selection)." \
        .workdir
  }
  gen_log:log T "LEAVE"
}

proc addir_dialog {args} {
  global cvs
  global incvs
  global cvscfg

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
      cvs_add_dir $binflag [workdir_list_files]
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
  global cvscfg

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

proc file_input_and_do {title cmd} {
  global filename

  gen_log:log T "ENTER ($title $cmd)"

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
      $cmd \$filename
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
