proc git_workdir_status {} {
  global cvscfg
  global Filelist
  global current_tagname
  global module_dir

  gen_log:log T "ENTER"
  set cmd(git_branch) [exec::new "git branch"]
  set branch_lines [split [$cmd(git_branch)\::output] "\n"]
  foreach line $branch_lines {
    if [string match "\* *" $line] {
      set current_tagname [lindex $line 1]
      gen_log:log D "current_tagname=$current_tagname"
    }
  }

  # Get the status of the files (top level only)
  foreach f [glob -nocomplain *] {
    set cmd(git_status) [exec::new "git status -u --porcelain -- \"$f\""]
    set statline [lindex [split [$cmd(git_status)\::output] "\n"] 0]
    if {![file isdirectory $f]} {
      set status [string range $statline 0 1]
      set filepath [lindex $statline 1]
      set good_line ""
      # Format: short hash, commit time, committer
      set command "git log -n 1 --pretty=format:\"%h|%ct|%cn\" -- $f"
      set cmd(git_log) [exec::new "$command"]
      foreach log_line [split [$cmd(git_log)\::output] "\n"] {
        if {[string length $log_line] > 0} {
          set good_line $log_line
        }
      }
      gen_log:log D "good_line $good_line"
      $cmd(git_log)\::destroy
      set items [split $good_line "|"]
      gen_log:log D "items $items"
      set hash [string trim [lindex $items 0] "\""]
      set wdate [string trim [lindex $items 1] "\""]
      set wwho [string trim [lindex $items 2] "\""]
      set Filelist($f:stickytag) $hash
      catch {set Filelist($f:date) [clock format $wdate -format $cvscfg(dateformat)]}
      set Filelist($f:editors) $wwho
      gen_log:log D "$Filelist($f:stickytag)"
      gen_log:log D "$Filelist($f:date)"
      gen_log:log D "$Filelist($f:editors)"

      switch -exact -- $status {
        "M " {
         set Filelist($f:status) "Locally Modified"
         gen_log:log D "$Filelist($f:status)"
        }
        " M" {
         set Filelist($f:status) "Modified, not staged"
         gen_log:log D "$Filelist($f:status)"
        }
        "A " {
         set Filelist($f:status) "Locally Added"
         gen_log:log D "$Filelist($f:status)"
        }
        "D " {
         set Filelist($f:status) "Locally Removed"
         gen_log:log D "$Filelist($f:status)"
        }
        "R " {
         set Filelist($f:status) "Renamed"
         gen_log:log D "$Filelist($f:status)"
        }
        "C " {
         set Filelist($f:status) "Copied"
         gen_log:log D "$Filelist($f:status)"
        }
        "U " {
         set Filelist($f:status) "Updated"
         gen_log:log D "$Filelist($f:status)"
        }
        "??" {
         set Filelist($f:status) "Not managed by Git"
         gen_log:log D "$Filelist($f:status)"
        }
        default {
         set Filelist($f:status) "Up-to-date"
         gen_log:log D "$Filelist($f:status)"
       }
      }
    } else {
      set Filelist($f:status) "<directory:GIT>"
      gen_log:log D "$Filelist($f:status)"
    }
  }
  if [info exists filepath] {
    set module_dir [file dirname $filepath]
  }

  gen_log:log T "LEAVE"
}

proc find_git_remote {dirname} {
  global cvscfg

  gen_log:log T "ENTER ($dirname)"

  set cmd(git_config) [exec::new "git remote -v"]
  set cfgline [lindex [split [$cmd(git_config)\::output] "\n"] 0]
  set cvscfg(origin) [lindex $cfgline 0]
  set cvscfg(url) [lindex $cfgline 1]
  $cmd(git_config)\::destroy
  gen_log:log T "LEAVE"
}

proc git_log {args} {
 global cvscfg
  gen_log:log T "ENTER"

  set filelist [join $args]
  gen_log:log D "detail $cvscfg(ldetail)"
  gen_log:log D "$filelist"

  set commandline "git log "
  switch -- $cvscfg(ldetail) {
    latest {
      append commandline " --pretty=oneline --max-count=1"
    }
    summary {
      append commandline " --pretty=oneline"
    }
  }
  append commandline " -- $filelist"

  set logcmd [viewer::new "Git log ($cvscfg(ldetail))"]
  $logcmd\::do "$commandline"
  busy_done .workdir.main

  gen_log:log T "LEAVE"
}

# does git rm from workdir browser
proc git_rm {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"
  set filelist [join $args]

  set command [exec::new "git rm $filelist"]
  auto_setup_dir $command

  gen_log:log T "LEAVE"
}

# does git add from workdir browser
proc git_add {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"
  set filelist [join $args]
  if {$filelist == ""} {
    set mess "This will add all new files"
  } else {
    set mess "This will add these files:\n\n"
    foreach file $filelist {
      append mess "   $file\n"
    }
  }

  if {$filelist == ""} {
    append filelist [glob -nocomplain $cvscfg(aster) .??*]
  }
  set addcmd [exec::new "git add $filelist"]
  auto_setup_dir $addcmd

  gen_log:log T "LEAVE"
}

# called by "Status" in the Reports menu. Uses the rdetail and recurse settings
proc git_status {} {
  global cvscfg
 
  gen_log:log T "ENTER ()"

  busy_start .workdir.main
  set flags ""
  set title "GIT Status ($cvscfg(rdetail))"
  # Hide unknown files if desired
  if {$cvscfg(status_filter)} {
    append flags " -uno"
  }
  if {$cvscfg(rdetail) == "terse"} {
    append flags " --porcelain"
  } elseif {$cvscfg(rdetail) == "summary"} {
    append flags " --long"
  } elseif {$cvscfg(rdetail) == "verbose"} {
    append flags " --verbose"
  }
  # do some highlighting
  set stat_cmd [viewer::new $title]
  set commandline "git status $flags"
  if {$cvscfg(rdetail) == "terse"} {
    $stat_cmd\::do "$commandline" 0 status_colortags
  } elseif {$cvscfg(rdetail) == "summary"} {
    $stat_cmd\::do "$commandline"
  } elseif {$cvscfg(rdetail) == "verbose"} {
    $stat_cmd\::do "$commandline" 0 patch_colortags
  }

  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

# called from the "Check Directory" button in the workdir and Reports menu
proc git_check {} {
  global cvscfg

  gen_log:log T "ENTER ()"

  busy_start .workdir.main
  set title "GIT Directory Check"
  # I know we use a short report for other VCSs, but for Git you really
  # need the full report to know what's staged and what's not
  set flags ""
  # Show unknown files if desired
  if {$cvscfg(status_filter)} {
    append flags " -uno"
  }
  set command "git status $flags"
  set check_cmd [viewer::new $title]
  $check_cmd\::do "$command" 0 status_colortags

  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

# dialog for git commit - called from workdir browser
proc git_commit_dialog {} {
  global cvsglb
  global cvscfg

  # If marked files, commit these.  If no marked files, then
  # commit any files selected via listbox selection mechanism.
  # The cvsglb(commit_list) list remembers the list of files
  # to be committed.
  set cvsglb(commit_list) [workdir_list_files]
  # If we want to use an external editor, just do it
  if {$cvscfg(use_cvseditor)} {
    git_commit "" "" $cvsglb(commit_list)
    return
  }

  if {[winfo exists .commit]} {
    destroy .commit
  }

  toplevel .commit
  #grab set .commit

  frame .commit.top -border 8
  frame .commit.down -relief groove -border 2

  pack .commit.top -side top -fill x
  pack .commit.down -side bottom -fill x
  frame .commit.comment
  pack .commit.comment -side top -fill both -expand 1
  label .commit.comment.lcomment -text "Your log message" -anchor w
  button .commit.comment.history -text "Log History" \
    -command history_browser
  text .commit.comment.tcomment -relief sunken -width 70 -height 10 \
    -bg $cvsglb(textbg) -exportselection 1 \
    -wrap word -border 2 -setgrid yes


  # Explain what it means to "commit" files
  message .commit.message -justify left -aspect 800 \
    -text "This will commit changes from your \
           local, working directory into the repository, recursively."

  pack .commit.message -in .commit.top -padx 2 -pady 5

  button .commit.ok -text "OK" \
    -command {
      #grab release .commit
      wm withdraw .commit
      set cvsglb(commit_comment) [.commit.comment.tcomment get 1.0 end]
      git_commit $cvsglb(commit_comment) $cvsglb(commit_list)
      commit_history $cvsglb(commit_comment)
    }
  button .commit.apply -text "Apply" \
    -command {
      set cvsglb(commit_comment) [.commit.comment.tcomment get 1.0 end]
      git_commit $cvsglb(commit_comment) $cvsglb(commit_list)
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
  .commit.comment.tcomment insert end $cvsglb(commit_comment)

  wm title .commit "Commit Changes"
  wm minsize .commit 1 1

  gen_log:log T "LEAVE"
}

# git commit - called from commit dialog
proc git_commit {comment args} {
  global cvscfg

  gen_log:log T "ENTER ($comment $args)"

  set filelist [join $args]

  set commit_output ""
  if {$filelist == ""} {
    set mess "This will commit your changes to ** ALL ** files in"
    append mess " and under this directory."
  } else {
    foreach file $filelist {
      append commit_output "\n$file"
    }
    set mess "This will commit your changes to:$commit_output"
  }
  append mess "\n\nAre you sure?"
  set commit_output ""

  if {[cvsconfirm $mess .workdir] != "ok"} {
    return 1
  }

  if {$cvscfg(use_cvseditor)} {
    # Starts text editor of your choice to enter the log message.
    update idletasks
    set command \
      "$cvscfg(terminal) git commit $filelist"
    gen_log:log C "$command"
    set ret [catch {eval "exec $command"} view_this]
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
    set v [viewer::new "SVN Commit"]
    regsub -all "\"" $comment "\\\"" comment
    $v\::do "git commit -m \"$comment\" $filelist" 1
    $v\::wait
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

# git checkout - called from workdir browser
proc git_checkout {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"

  set filelist [join $args]

  if {$filelist == ""} {
    append mess "\nThis will download from"
    append mess " the repository to your local"
    append mess " filespace ** ALL ** files which"
    append mess " have changed in it."
  } else {
    append mess "\nThis will download from"
    append mess " the repository to your local"
    append mess " filespace these files which"
    append mess " have changed:\n"
  }
  foreach file $filelist {
    append mess "\n\t$file"
  }
  append mess "\n\nAre you sure?"

  set command "git checkout"

  if {[cvsconfirm $mess .workdir] == "ok"} {
    foreach file $filelist {
      append command " \"$file\""
    }
  } else {
    return;
  }

  set co_cmd [viewer::new "GIT Update"]
  $co_cmd\::do "$command" 1 status_colortags
  auto_setup_dir $co_cmd

  gen_log:log T "LEAVE"
}

