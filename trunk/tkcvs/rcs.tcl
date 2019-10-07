
# Get the revision log of an RCS file and send it to the
# branch-diagram browser.
# Disable merge buttons.
proc rcs_branches {files} {
  global cvscfg
  global cwd
  
  gen_log:log T "ENTER ($files)"

  if {$files == {}} {
    cvsfail "Please select one or more files!" .workdir
    return
  }

  foreach filename $files {
    ::cvs_branchlog::new RCS "$filename"
  }

  gen_log:log T "LEAVE"
}

# check out (co) a file.  Called from the "update" button
proc rcs_checkout {files} {
  global cvscfg

  gen_log:log T "ENTER ($files)"

  if {$files == {}} {
    cvsfail "Please select one or more files!" .workdir
    return
  }

  set commandline "co -l $files"
  set v [::viewer::new "RCS Checkout"]
  $v\::do "$commandline" 1
  
  if {$cvscfg(auto_status)} {
    $v\::wait
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc rcs_lock {do files} {
  global cvscfg

  if {$files == {}} {
    cvsfail "Please select one or more files!" .workdir
    return
  }
  switch -- $do {
    lock { set commandline "rcs -l $files"}
    unlock { set commandline "rcs -u $files"}
  }
  gen_log:log C "$commandline"
  set rcscmd [::exec::new "$commandline"]
  
  if {$cvscfg(auto_status)} {
    $rcscmd\::wait
    setup_dir
  }
}

# RCS checkin.
proc rcs_checkin {revision comment args} {
  global cvscfg
  global inrcs

  gen_log:log T "ENTER ($args)"

  set filelist [lindex $args 0]
  if {$filelist == ""} {
    cvsfail "Please select some files!"
    return 1
  }

  set commit_output ""
  foreach file $filelist {
    append commit_output "\n$file"
  }
  set mess "Thi/ will commit your changes to:$commit_output"
  append mess "\n\nAre you sure?"
  set commit_output ""
  if {[cvsconfirm $mess .workdir] != "ok"} {
    return 1
  }

  set revflag ""
  if {$revision != ""} {
    set revflag "-r $revision"
  }

  if {$cvscfg(use_cvseditor)} {
    # Starts text editor of your choice to enter the log message.
    # This way a template in CVSROOT can be used.
    update idletasks
    set commandline \
      "$cvscfg(terminal) ci $revflag $filelist"
    gen_log:log C "$commandline"
    set ret [catch {exec {*}$commandline} view_this]
    if {$ret} {
      cvsfail $view_this .workdir
      gen_log:log T "LEAVE ERROR ($view_this)"
      return
    }
  } else {
    if {$comment == ""} {
      cvsfail "You must enter a comment!" .commit
      return 1
    }
    set v [viewer::new "RCS Checkin"]
    regsub -all {"} $comment {\"} comment
    regsub -all { } $comment {\ } comment
    regsub -all {\n} $comment {\\n} comment

    set now [clock format [clock seconds] -format "$cvscfg(dateformat)"]
    set description "Created $now"
    regsub -all { } $description {_} description

    # The -t is necessary if it's the initial commit (aka "add" in other systems.)
    # It's ignored otherwise, so it does no harm.
    set commandline "ci $revflag -t-$description -m\"$comment\" $filelist"
    $v\::do "$commandline" 1
    $v\::wait
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc rcs_commit_dialog {filelist} {
  global cvsglb
  global cvscfg

  gen_log:log T "ENTER"

  # commit any files selected via listbox selection mechanism.
  set cvsglb(commit_list) $filelist

  # If we want to use an external editor, just do it
  if {$cvscfg(use_cvseditor)} {
    rcs_checkin "" "" $cvsglb(commit_list)
    return
  }

  if {[winfo exists .commit]} {
    destroy .commit
  }

  toplevel .commit

  frame .commit.top -border 8
  frame .commit.vers
  frame .commit.down -relief groove -border 2

  pack .commit.top -side top -fill x
  pack .commit.down -side bottom -fill x
  pack .commit.vers -side top -fill x

  label .commit.lvers -text "Specify Revision (-r) (usually ignore)" \
     -anchor w
  entry .commit.tvers -relief sunken -textvariable version

  pack .commit.lvers .commit.tvers -in .commit.vers \
    -side left -fill x -pady 3

  frame .commit.comment
  pack .commit.comment -side top -fill both -expand 1
  label .commit.comment.lcomment -text "Your log message" -anchor w
  button .commit.comment.history -text "Log History" \
    -command history_browser
  text .commit.comment.tcomment -relief sunken -width 70 -height 10 \
    -bg $cvsglb(textbg) -exportselection 1 \
    -wrap word -border 2 -setgrid yes

  # Explain what it means to "commit" files
  message .commit.message -justify left -aspect 500 -relief groove -bd 2 \
    -text "This will commit changes from your \
           local, working directory into the repository."

  pack .commit.message -in .commit.top -padx 2 -pady 5

  button .commit.ok -text "OK" \
    -command {
      #grab release .commit
      wm withdraw .commit
      set cvsglb(commit_comment) [string trimright [.commit.comment.tcomment get 1.0 end]]
      rcs_checkin $version $cvsglb(commit_comment) $cvsglb(commit_list)
      commit_history $cvsglb(commit_comment)
    }
  button .commit.apply -text "Apply" \
    -command {
      set cvsglb(commit_comment) [string trimright [.commit.comment.tcomment get 1.0 end]]
      rcs_checkin $version $cvsglb(commit_comment) $cvsglb(commit_list)
      commit_history $cvsglb(commit_comment)
    }
  button .commit.clear -text "ClearAll" \
    -command {
      set version ""
      .commit.comment.tcomment delete 1.0 end
    }
  button .commit.quit \
    -command {
      #grab release .commit
      wm withdraw .commit
    }
 
  .commit.ok configure -text "OK"
  .commit.quit configure -text "Close"

  grid columnconf .commit.comment 1 -weight 1
  grid rowconf .commit.comment 1 -weight 1
  grid .commit.comment.lcomment -column 0 -row 0
  grid .commit.comment.tcomment -column 1 -row 0 -rowspan 2 -padx 4 -pady 4 -sticky nsew
  grid .commit.comment.history  -column 0 -row 1

  pack .commit.ok .commit.apply .commit.clear .commit.quit -in .commit.down \
    -side left -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  # Fill in the most recent commit message
  .commit.comment.tcomment insert end [string trimright $cvsglb(commit_comment)]

  wm title .commit "Commit Changes"
  wm minsize .commit 1 1

  gen_log:log T "LEAVE"
}

# Get an rcs status for files in working directory, for the dircanvas
proc rcs_workdir_status {} {
  global cvscfg
  global Filelist

  gen_log:log T "ENTER"

  set rcsfiles [glob -nocomplain -- RCS/* RCS/.??* *,v .??*,v]
  set command "rlog -h $rcsfiles"
  gen_log:log C "$command"
  set ret [catch {exec {*}$command} raw_rcs_log]
  gen_log:log F "$raw_rcs_log"

  # The older version (pre-5.x or something) of RCS is a lot different from
  # the newer versions, explaining some of the ugliness here
  set rlog_lines [split $raw_rcs_log "\n"]
  set lockers ""
  set filenames ""
  foreach rlogline $rlog_lines {
    # Found one!
    if {[string match "*Working file:*" $rlogline]} {
      regsub {^.*Working file:\s+} $rlogline "" filename
      regsub {\s*$} $filename "" filename
      lappend filenames $filename
      gen_log:log D "RCS file $filename"
      set Filelist($filename:wrev) ""
      set Filelist($filename:stickytag) ""
      set Filelist($filename:option) ""
      if {[file exists $filename]} {
        set Filelist($filename:status) "RCS Up-to-date"
        # Do rcsdiff to see if it's changed
        set command "rcsdiff \"$filename\""
        gen_log:log C "$command"
        set ret [catch {exec {*}$command} output]
        gen_log:log F "$output"
        set splitline [split $output "\n"]
        if [string match {====*} [lindex $splitline 0]] {
           set splitline [lrange $splitline 1 end]
        }
        if {[llength $splitline] > 3} {
          set Filelist($filename:status) "RCS Modified"
          gen_log:log D "$filename MODIFIED"
        }
      } else {
        set Filelist($filename:status) "RCS Needs Checkout"
      }
      set who ""
      set lockers ""
      continue
    }
    if {[string match "head:*" $rlogline]} {
      regsub {head:\s+} $rlogline "" revnum
      set Filelist($filename:wrev) "$revnum"
      set Filelist($filename:stickytag) "$revnum on trunk"
      gen_log:log D "  Rev \"$revnum\""
      continue
    } 
    if {[string match "branch:*" $rlogline]} {
      regsub {branch: *} $rlogline "" revnum
      if {[string length $revnum] > 0} {
        set Filelist($filename:wrev) "$revnum"
        set Filelist($filename:stickytag) "$revnum on branch"
        gen_log:log D "  Branch rev \"$revnum\""
      }
      continue
    }
    if { [string index $rlogline 0] == "\t" } {
       set splitline [split $rlogline]
       set who [lindex $splitline 1]
       set who [string trimright $who ":"]
       append lockers ",$who"
       gen_log:log D " lockers $lockers"
    } else {
      if {[string match "access list:*" $rlogline]} {
        set lockers [string trimleft $lockers ","]
        set Filelist($filename:editors) $lockers
        # No more tags after this point
        continue
      }
    }
  }
  foreach f $filenames {
    set lockers $Filelist($f:editors)
    if { $lockers ne "" } {
      if {$cvscfg(user) in $lockers} {
        append Filelist($f:status) "/HaveLock"
      } else {
        append Filelist($f:status) "/Locked"
      }
    }
  }
  gen_log:log T "LEAVE"
}

# for Directory Status Check
proc rcs_check {} {
  global cvscfg

  gen_log:log T "ENTER"

  set v [::viewer::new "RCS Directory Check"]
  set rcsfiles [glob -nocomplain -- RCS/* RCS/.??* *,v .??*,v]
  set command "rlog -h $rcsfiles"
  gen_log:log C "$command"
  set ret [catch {exec {*}$command} raw_rcs_log]
  gen_log:log F "$raw_rcs_log"

  set rlog_lines [split $raw_rcs_log "\n"]
  foreach rlogline $rlog_lines {
    if {[string match "Working file:*" $rlogline]} {
      regsub {Working file: } $rlogline "" filename
      regsub {\s*$} $filename "" filename
      gen_log:log D "RCS file $filename"
      if {[file exists $filename]} {
        # Do rcsdiff to see if it's changed
        set command "rcsdiff -q \"$filename\" > $cvscfg(null)"
        gen_log:log C "$command"
        set ret [catch {exec {*}$command}]
        if {$ret == 1} {
          $v\::log "\nM $filename"
        }
      } else {
        $v\::log "\nU $filename"
      }
    }
  }
  gen_log:log T "LEAVE"
}

# for Log in Reports Menu
proc rcs_log {detail args} {
  global cvscfg

  gen_log:log T "ENTER ($detail $args)"

  set filelist [join $args]
  if {$filelist == ""} {
    set filelist [glob -nocomplain -- RCS/* RCS/.??* *,v .??*,v]
  }
  gen_log:log D "detail $detail"
  gen_log:log D "$filelist"

  set commandline "rlog "
  switch -- $detail {
    latest {
      append commandline "-R "
    }
    summary {
      append commandline "-t "
    }
  }
  append commandline "$filelist"

  set v [viewer::new "RCS log ($detail)"]
  $v\::do "$commandline" 0 rcslog_colortags
  busy_done .workdir.main

  gen_log:log T "LEAVE"
}

proc rcs_log_rev {revision filename} {

  gen_log:log T "ENTER ($revision $filename)"

  set commandline "rlog"
  if {$revision ne ""} {
    append commandline " -r$revision"
  }
  append commandline " \"$filename\""
  set v [viewer::new "RCS log -r$revision $filename "]
  $v\::do "$commandline" 0 rcslog_colortags

  gen_log:log T "LEAVE"
}

proc rcs_fileview_checkout {revision filename} {
#
# This views a specific revision of a file
#
  global cvscfg

  gen_log:log T "ENTER ($revision $filename)"
  if {$revision == {}} {
    set commandline "co -p \"$filename\""
    set v [viewer::new "$filename"]
    $v\::do "$commandline" 0
  } else {
    set commandline "co -p -r$revision \"$filename\""
    set v [viewer::new "$filename Revision $revision"]
    $v\::do "$commandline" 0
  }
  gen_log:log T "LEAVE"
}

# Revert a file to checked-in version by removing the local
# copy and updating it
proc rcs_revert {args} {
  global cvscfg
        
  gen_log:log T "ENTER ($args)"
  set filelist [join $args]

  gen_log:log D "Reverting $filelist"
  gen_log:log F "DELETE $filelist"
  file delete $filelist
  gen_log:log C "co $filelist"
  set rcscmd [exec::new "co $filelist"]
        
  if {$cvscfg(auto_status)} {
    $rcscmd\::wait
    setup_dir 
  }     
        
  gen_log:log T "LEAVE"
}     

