# Find where we are in path
proc read_git_dir {dirname} {
  global cvsglb

  # What's the top level, and where are we relative to it?
  set cmd(find_top) [exec::new "git rev-parse --show-toplevel"]
  set cvsglb(repos_top) [lindex [$cmd(find_top)\::output] 0]
  set wd [pwd]
  set l [string length $cvsglb(repos_top)]
  set cvsglb(relpath) [string range $wd [expr {$l+1}] end]
  gen_log:log D "Relative path: $cvsglb(relpath)"
}

proc git_workdir_status {} {
  global cvscfg
  global cvsglb
  global Filelist
  global current_tagname
  global module_dir

  gen_log:log T "ENTER"
  # See what branch we're on
  set cmd(git_branch) [exec::new "git branch --no-color"]
  set branch_lines [split [$cmd(git_branch)\::output] "\n"]
  foreach line $branch_lines {
    if [string match {\* *} $line] {
      set current_tagname [lindex $line 1]
      gen_log:log D "current_tagname=$current_tagname"
    }
  }

  read_git_dir [pwd]
  set module_dir $cvsglb(relpath)

  set statfiles {}
  # Get the status of the files that git reports (current level only)
  # If they're up-to-date, git status is mute about them
  set cmd(git_status) [exec::new "git status -u --porcelain ."]
  foreach statline [split [$cmd(git_status)\::output] "\n" ] {
    gen_log:log D "$statline"
    if {[string length $statline] < 1} {
      continue
    }
    # MM "Dir1/F 3.txt"
    #  M Dir2/F2.txt
    set status [string range $statline 0 1]
    # Strip quotes
    set f [string trim [lindex $statline 1] "\""]
    # Trim path
    regsub "^$module_dir/" $f "" f
    if {[regexp {/} $f]} {
      continue
    }
    lappend statfiles "$f"
    switch -glob -- $status {
        {M } {
         set Filelist($f:status) "Modified, staged"
         gen_log:log D "$Filelist($f:status)"
        }
        { M} {
         set Filelist($f:status) "Modified, unstaged"
         gen_log:log D "$Filelist($f:status)"
        }
        {MM} {
         set Filelist($f:status) "Modified, unstaged"
         gen_log:log D "$Filelist($f:status)"
        }
        {A } {
         set Filelist($f:status) "Added"
         gen_log:log D "$Filelist($f:status)"
        }
        {AD} {
         set Filelist($f:status) "Added, missing"
         gen_log:log D "$Filelist($f:status)"
        }
        {D } {
         set Filelist($f:status) "Removed"
         gen_log:log D "$Filelist($f:status)"
        }
        { D} {
         set Filelist($f:status) "Missing"
         gen_log:log D "$Filelist($f:status)"
        }
        {R*} {
         set Filelist($f:status) "Renamed"
         gen_log:log D "$Filelist($f:status)"
        }
        {C*} {
         set Filelist($f:status) "Copied"
         gen_log:log D "$Filelist($f:status)"
        }
        {AA}
        {AU}
        {DD}
        {DU}
        {UA}
        {UD}
        {UU} {
         set Filelist($f:status) "Conflict"
         gen_log:log D "$Filelist($f:status)"
        }
        {??} {
         set Filelist($f:status) "Not managed by Git"
         gen_log:log D "$Filelist($f:status)"
        }
        default {
         set Filelist($f:status) "Up-to-date"
         gen_log:log D "$Filelist($f:status)"
       }
    }
    # So they're not undefined
    set Filelist($f:date) ""
    set Filelist($f:stickytag) ""
    set Filelist($f:editors) ""
  }

  if {$cvscfg(gitdetail)} {
  # This log-each-file op is time consuming, so it's enabled or disabled in ~/.tkcvs
  # by the gitdetail variable
    set globfiles [glob -nocomplain *]
    set allfiles [lsort -unique -dictionary [concat $statfiles $globfiles]]
    foreach f $allfiles {
      # --porcelain=1 out: XY <filename>, where X is the modification state of the index
      #   and Y is the state of the work tree.  ' ' = unmodified.
      # --porcelain=2 out has an extra integer field before the status and 6 extra
      # fields before the filename.
      # XY, now the second field, has "." for unmodified.
      set good_line ""
      # Format: short hash, commit time, committer
      set command "git log -n 1 --format=%h|%ct|%cn -- \"$f\""
      set cmd(git_log) [exec::new "$command"]
      set log_out [$cmd(git_log)\::output]
      if {[string length $log_out] > 0} {
        # git log returned something, but git status didn't, so
        # I guess it must be up-to-date
        if {! [info exists Filelist($f:status)] || ($Filelist($f:status) eq "<file>")} {
          set Filelist($f:status) "Up-to-date"
          gen_log:log D "$Filelist($f:status)"
        }
      }
      foreach log_line [split $log_out "\n"] {
        if {[string length $log_line] > 0} {
          set good_line $log_line
        }
      }
      $cmd(git_log)\::destroy
      set items [split $good_line "|"]
      set hash [string trim [lindex $items 0] "\""]
      set wdate [string trim [lindex $items 1] "\""]
      set wwho [string trim [lindex $items 2] "\""]
      set Filelist($f:stickytag) $hash
      catch {set Filelist($f:date) [clock format $wdate -format $cvscfg(dateformat)]}
      set Filelist($f:editors) $wwho
      gen_log:log D "$Filelist($f:stickytag)\t$Filelist($f:date)\t$Filelist($f:editors)"
      if {[file isdirectory $f]} {
        if {[string length $log_out] > 0} {
          set Filelist($f:status) "<directory:GIT>"
        } else {
          set Filelist($f:status) "<directory>"
        }
      }
      gen_log:log D "$Filelist($f:status)"
    }
  }

  gen_log:log T "LEAVE"
}

proc find_git_remote {dirname} {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($dirname)"

  if {! [info exists cvscfg(url)] } {
    set cvscfg(url) ""
    set cvscfg(origin) ""
    set cvsglb(fetch_url) ""
  }
  set cmd(git_config) [exec::new "git remote -v"]
  set lines [split [$cmd(git_config)\::output] "\n"]
  set i 0
  foreach line $lines {
    if {$i == 0} {
      # Take the first line, whatever it is, to fill basic info
      set cvscfg(origin) [lindex $line 0]
      set cvscfg(url) [lindex $line 1]
      # In case fetch and push keywords aren't found
      set cvsglb(fetch_origin) $cvscfg(origin)
      set cvsglb(fetch_url) $cvscfg(url)
      set cvsglb(push_origin) $cvscfg(origin)
      set cvsglb(push_url) $cvscfg(url)
    }
    # Then, in case fetch and push urls are different
    if {[string match {*(fetch)} $line]} {
      set cvsglb(fetch_origin) [lindex $line 0]
      set cvsglb(fetch_url) [lindex $line 1]
    } elseif {[string match {*(push)} $line]} {
      set cvsglb(push_origin) [lindex $line 0]
      set cvsglb(push_url) [lindex $line 1]
    }
    incr i
  }
  set cvsglb(root) $cvscfg(url)
  set cvsglb(vcs) git
  gen_log:log T "LEAVE"
}

# For module browser.
proc parse_gitlist {gitroot} {
  global cvsglb
  global modval 
  global modtitle

  gen_log:log T "ENTER ($gitroot)"

  # Clear the arrays
  catch {unset modval}
  catch {unset modtitle}
  set tv .modbrowse.treeframe.pw

  set command "git ls-remote \"$cvsglb(root)\""
  gen_log:log C "$command"
  set rem_cmd [exec::new $command]
  set remote_output [$rem_cmd\::output]

  foreach line [split $remote_output "\n"] {
    if  {$line eq ""} {continue}
    set dname [lindex $line 1] 
    gen_log:log D "dname=$dname"
    # This is the hash
    set modval($dname) [lindex $line 0] 
    gen_log:log D "modval($dname)=$modval($dname)"
    #ModList:newitem $tf $dname $modval($dname)
    gen_log:log D "$tv insert {} end -id $dname -text $dname -values $modval($dname)"
    $tv insert {} end -id "$dname" -text "$dname" -values $modval($dname)
  }
  update idletasks
  # Then you can do something like this to list the files
  # git ls-tree -r refs/heads/master --name-only
  gen_log:log T "LEAVE"
}

proc git_push {} {
  global cvsglb

  gen_log:log T "ENTER"

  set mess "This will push your committed changes to\
            $cvsglb(push_origin) $cvsglb(push_url).\n\n Are you sure?"

  if {[cvsconfirm $mess .workdir] == "ok"} {
    set cmd(git_push) [exec::new "git push"]
  }

  gen_log:log T "LEAVE"
}

proc git_fetch {} {
  global cvsglb

  gen_log:log T "ENTER"

  set mess "This will fetch changes from\
            $cvsglb(fetch_origin) $cvsglb(fetch_url).\n\n Are you sure?"

  if {[cvsconfirm $mess .workdir] == "ok"} {
    set cmd(git_fetch) [exec::new "git fetch"]
  }

  gen_log:log T "LEAVE"
}

proc git_list_tags {} {
  gen_log:log T "ENTER"

  set commandline "git tag --list"
  set v [viewer::new "Tags"]
  $v\::do "$commandline"
  $v\::wait
  $v\::clean_exec

  gen_log:log T "LEAVE"
}

# Called from "Log" in Reports menu
proc git_log {detail args} {
  gen_log:log T "ENTER ($detail $args)"

  busy_start .workdir.main
  set filelist [join $args]
  set flags ""

  if {[llength $filelist] == 0} {
    set filelist {.}
  }
  if {[llength $filelist] > 1} {
    set title "Git Log ($detail)"
  } else {
    set title "Git Log $filelist ($detail)"
  }

  set commandline "git log"
  switch -- $detail {
    latest {
      append flags " --pretty=oneline --max-count=1"
    }
    summary {
      append flags " --graph --all --format=%h\\ \\ %<(12,trunc)%aN\\ %<(54,trunc)%s"
    }
    verbose {
      append flags " --all"
    }
  }

  set v [viewer::new "$title"]
  foreach file $filelist {
    if {[llength $filelist] > 1} {
      $v\::log "-- $file -------------------------------\n" blue
    }
    set command "git log --no-color $flags -- \"$file\""
    $v\::do "$command" 1
    $v\::wait
  }

  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

# does git rm from workdir browser
proc git_rm {args} {
  gen_log:log T "ENTER ($args)"
  set filelist [join $args]

  set command [exec::new "git rm $filelist"]
  auto_setup_dir $command

  gen_log:log T "LEAVE"
}

# does git rm -r from workdir browser popup menu
proc git_remove_dir {args} {
  gen_log:log T "ENTER ($args)"
  set filelist [join $args]

  set command [exec::new "git rm -r $filelist"]
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

# Called from workdir browser popup
proc git_rename_ask {args} {

  gen_log:log T "ENTER ($args)"
  set file [lindex $args 0]
  if {$file eq ""} {
    cvsfail "Rename:\nPlease select a file !" .workdir
    return
  }

  # Send it to the dialog to ask for the filename
  file_input_and_do "Git Rename" "git_rename \"$file\""

  gen_log:log T "LEAVE"
}

# The callback for git_rename_ask and file_input_and_do
proc git_rename {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"

  set v [viewer::new "SVN rename"]
  set command "git mv [lindex $args 0] [lindex $args 1]"
  $v\::do "$command"

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

# Revert. Called from workdir browser
proc git_reset {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"

  set filelist [join $args]
  gen_log:log D "Reverting $filelist"
  set commandline "git reset $filelist"
  set v [viewer::new "Git Reset"]
  $v\::do "$commandline"
  $v\::wait
  $v\::clean_exec
  
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

# called by "Status" in the Reports menu. Uses status_filter.
proc git_status {detail args} {
  global cvscfg

  gen_log:log T "ENTER ($detail $args)"

  busy_start .workdir.main
  set filelist [join $args]
  set flags ""
  set title "Git Status ($detail)"
  # Hide unknown files if desired
  if {$cvscfg(status_filter)} {
    append flags " -uno"
  }
  switch -- $detail {
    terse {
      append flags " --short"
    }
    summary {
      append flags " --long"
    }
    verbose {
      append flags " --verbose"
    }
  }
  append flags " --no-color"
  set stat_cmd [viewer::new $title]
  set commandline "git status $flags $filelist"
  $stat_cmd\::do "$commandline" 0

  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

# called from the branch browser
proc git_log_rev {rev file} {
  gen_log:log T "ENTER ($rev $file)"

  set title "Git log"
  set commandline "git log --graph --all --format=%h\\ \\ %<(12,trunc)%aN\\ %<(54,trunc)%s"
  if {$rev ne ""} {
    append commandline " $rev"
    append title " $rev"
  }
  append commandline " \"$file\""
  append title " $file"

  set logcmd [viewer::new "$title"]
  $logcmd\::do "$commandline" 0

  gen_log:log T "LEAVE"
}

# called from the "Check Directory" button in the workdir and Reports menu
proc git_check {} {
  global cvscfg

  gen_log:log T "ENTER ()"

  busy_start .workdir.main
  set title "Git Directory Check"
  # I know we use a short report for other VCSs, but for Git you really
  # need the full report to know what's staged and what's not
  set flags "--porcelain"
  # Show unknown files if desired
  if {$cvscfg(status_filter)} {
    append flags " -uno"
  }
  set command "git status $flags"
  set check_cmd [viewer::new $title]
  $check_cmd\::do "$command" 0

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
    -text "This will commit changes from your local, working directory
           into the local repository, recursively."

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
    set v [viewer::new "Git Commit"]
    regsub -all "\"" $comment "\\\"" comment
    $v\::do "git commit -m \"$comment\" $filelist" 1
    $v\::wait
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

# git tag - called from tag dialog
proc git_tag {tagname annotate comment args} {
  global cvscfg

  gen_log:log T "ENTER ($tagname $annotate $comment $args)"

  if {$tagname == ""} {
    cvsfail "You must enter a tag name!" .workdir
    return 1
  }
  set filelist [join $args]

  set command "git tag "
  if {$annotate == "yes"} {
    append command "-a -m \"$comment\""
  }
  append command " $tagname $filelist"

  set v [viewer::new "Git Tag"]
  $v\::do "$command" 1
  $v\::wait

  if {$cvscfg(auto_status)} {
    setup_dir
  }

  gen_log:log T "LEAVE"
}

# git branch - called from branch dialog
proc git_branch {branchname updflag args} {
  global cvscfg

  gen_log:log T "ENTER ($branchname $args)"

  if {$branchname == ""} {
    cvsfail "You must enter a branch name!" .workdir
    return 1
  }
  set filelist [join $args]

  set command "git branch $branchname $filelist"
  set v [viewer::new "Git Branch"]
  $v\::do "$command" 1"
  $v\::wait

  if {$updflag == "yes"} {
    set command "git checkout $branchname $filelist"
    $v\::log "$command"
    $v\::do "$command" 0
    $v\::wait
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }

  gen_log:log T "LEAVE"
}

# git checkout with options - called from Update with Options in workdir browser
proc git_opt_update {args} {
  global cvscfg
  global cvsglb

  switch -exact -- $cvsglb(tagmode_selection) {
    "Keep" {
       set command "git checkout"
     }
    "Trunk" {
       set command "git checkout master"
     }
    "Branch" {
       set command "git checkout $cvsglb(branchname)"
     }
    "Tag" {
       set command "git checkout $cvsglb(tagname)"
     }
  }
  set upd_cmd [viewer::new "Git Checkout"]
  $upd_cmd\::do "$command" 0 status_colortags

  auto_setup_dir $upd_cmd
}

# git checkout - called from Update in workdir browser
proc git_checkout {args} {

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

  set co_cmd [viewer::new "Git Update"]
  $co_cmd\::do "$command" 1
  auto_setup_dir $co_cmd

  gen_log:log T "LEAVE"
}

# Make a clone using the Module Browser
proc git_clone {root tag target} {
  global incvs insvn inrcs ingit

  gen_log:log T "ENTER ($root $tag $target)"


  set dir [pwd]
  if {[file pathtype $target] eq "absolute"} {
    set tgt $target
  } else {
    set tgt "$dir/$target"
  }
  set mess "This will clone\n\
     $root $tag\n\
     to directory\n\
     $tgt\n\
     Are you sure?"
  if {[cvsconfirm $mess .modbrowse] == "ok"} {
    set command "git clone"
    if {$tag ne "HEAD"} {
      append command " -b \"$tag\""
    }
    append command " \"$root\" \"$target\""
    set v [viewer::new "Git Clone"]
    $v\::do "$command"
  }

  gen_log:log T "LEAVE"
  return
}

proc git_merge_conflict {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"

  if {[llength $args] != 1} {
    cvsfail "Please select one file."
    return
  }
  set filelist [join $args]

  # See if it's really a conflict file
  foreach file $filelist {
    gen_log:log F "OPEN $file"
    set f [open $file]
    set match 0
    while { [eof $f] == 0 } {
      gets $f line
      if { [string match "<<<<<<< *" $line] } {
        set match 1
        break
      }
    }
    gen_log:log F "CLOSE $file"
    close $f

    if { $match != 1 } {
      cvsfail "$file does not appear to have a conflict." .workdir
      continue
    }
    set tkdiff_command "$cvscfg(tkdiff) -conflict -o \"$file\" \"$file\""
    gen_log:log C "$tkdiff_command"
    set ret [catch {eval "exec $tkdiff_command &"} view_this]
  }

  gen_log:log T "LEAVE"
}

# annotate/blame. Called from workdir.
proc git_annotate {revision args} {
  gen_log:log T "ENTER ($revision $args)"
  if {$revision != ""} {
    # We were given a revision
    set revflag "$revision"
  } else {
    set revflag ""
  }

  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Annotate:\nPlease select one or more files !" .workdir
    gen_log:log T "LEAVE (Unselected files)"
    return
  }
  foreach file $filelist {
    annotate::new $revflag $file "git"
  }
  gen_log:log T "LEAVE"
}

# Called from branch browser annotate button
proc git_annotate_r {revision filepath} {

  gen_log:log T "ENTER ($revision $filepath)"
  if {$revision != ""} {
    # We were given a revision
    set revflag "$revision"
  } else {
    set revflag ""
  }

  annotate::new $revflag $filepath "git_r"
  gen_log:log T "LEAVE"
}

# View a specific revision of a file.
# Called from branch browser
proc git_fileview {revision path filename} {
  gen_log:log T "ENTER ($revision $path $filename)"

  if {$path ne ""} {
    set command "git show \"$revision:$path/$filename\""
  } else {
    set command "git show \"$revision:$filename\""
  }
  set v [viewer::new "$filename Revision $revision"]
  $v\::do "$command"
}

# Sends files to the branch browser one at a time
proc git_branches {files} {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($files)"
  set filelist [join $files]

  if {$files == {}} {
    cvsfail "Please select one or more files!" .workdir
    return
  }

  read_git_dir [pwd]
  gen_log:log D "Relative Path: $cvsglb(relpath)"

  foreach file $files {
    ::git_branchlog::new $cvsglb(relpath) $file
  }

  gen_log:log T "LEAVE"
}

namespace eval ::git_branchlog {
  variable instance 0

  proc new {relpath filename {directory_merge {0}} } {
    variable instance
    set my_idx $instance
    incr instance

    namespace eval $my_idx {
      set my_idx [uplevel {concat $my_idx}]
      set filename [uplevel {concat $filename}]
      set relpath [uplevel {concat $relpath}]
      set directory_merge [uplevel {concat $directory_merge}]
      variable cmd_log
      variable lc
      variable revwho
      variable revdate
      variable revtime
      variable revlines
      variable revstate
      variable revcomment
      variable revparent
      variable tags
      variable revbranches
      variable branchrevs
      variable logstate
      variable show_tags
      variable show_merges

      gen_log:log T "ENTER [namespace current]"
      if {$directory_merge} {
        set newlc [logcanvas::new . "GIT,loc" [namespace current]]
        set ln [lindex $newlc 0]
        set lc [lindex $newlc 1]
        set show_tags 0
      } else {
        set newlc [logcanvas::new $filename "GIT,loc" [namespace current]]
        set ln [lindex $newlc 0]
        set lc [lindex $newlc 1]
        set show_tags [set $ln\::opt(show_tags)]
      }

      proc abortLog { } {
        global cvscfg
        variable cmd_log
        variable lc

        if {[info exists cmd_log]} {
          gen_log:log D "  $cmd_log\::abort"
          catch {$cmd_log\::abort}
        }
        busy_done $lc
        pack forget $lc.stop
        pack $lc.close -in $lc.down.closefm -side right
        $lc.close configure -state normal
      }

      proc reloadLog { } {
        global cvscfg
        global cvsglb
        global current_tagname
        variable filename
        variable cmd_log
        variable lc
        variable ln
        variable branchtip
        variable branchroot
        variable branchrevs
        variable revwho
        variable revdate
        variable revtime
        variable revchildren
        variable revcomment
        variable revkind
        variable revparent
        variable revpath
        variable revtags
        variable revbtags
        variable revmergefrom
        variable rootrev
        variable revbranches
        variable logstate
        variable relpath
        variable filename
        variable show_tags
        variable show_merges

        gen_log:log T "ENTER"
        catch { $lc.canvas delete all }
        catch { unset branchtip }
        catch { unset branchroot }
        catch { unset branchrevs }
        catch { unset revwho }
        catch { unset revdate }
        catch { unset revtime }
        catch { unset revcomment }
        catch { unset revtags }
        catch { unset revbtags }
        catch { unset revbranches }
        catch { unset revkind }
        catch { unset revpath }
        catch { unset revparent }
        catch { unset rootrev }

        pack forget $lc.close
        pack $lc.stop -in $lc.down.closefm -side right
        $lc.stop configure -state normal
        busy_start $lc

        # Start collecting information and initializing the
        # browser
        $ln\::ConfigureButtons $filename
        # in case we got here straight from the command line
        if {! [info exists current_tagname]} {
          set command "git rev-parse --abbrev-ref HEAD"
          set cmd_curbranch [exec::new $command {} 0 {} 1]
          set branch_output [$cmd_curbranch\::output]
          $cmd_curbranch\::destroy
          set current_tagname [string trim $branch_output "\n"]
        }
        gen_log:log D "current_tagname=$current_tagname"

        set show_merges [set $ln\::opt(show_merges)]
        set show_tags [set $ln\::opt(show_tags)]
        set show_merges 0
        set show_tags 0

        # Start collecting the branches
        catch {unset branches}
        catch {unset logged_branches}
        catch {unset reachable_branches}

        # Most efficient way I can think of to collect branch, tag, and parent information
        set command1 "git log --all -$cvscfg(gitmaxhist) --first-parent --date-order --format=%h:%p:%d -- \"$filename\""
        set branches_log1 [exec::new $command1 {} 0 {} 1]
        set log_output1 [$branches_log1\::output]
        $branches_log1\::destroy
        set logresults1 [parents_and_branches $log_output1]
        set h [lindex $logresults1 0]
        if {$h == ""} {
          set rootrev ""
        }

        set logged_branches [lindex $logresults1 1]
        set logged_branches [prune_branchlist $logged_branches]

        # That doesn't always pick up the reachable branches though
        set cmd(git_branch) [exec::new "git branch --format=%(refname:short)"]
        set branch_lines [split [$cmd(git_branch)\::output] "\n"]
        foreach line $branch_lines {
          if {[string length $line] < 1} continue
          lappend reachable_branches [lindex $line 0]
        }
        gen_log:log D "Reachable branches: $reachable_branches"
        gen_log:log D "Logged branches: $logged_branches"

        # Collect and de-duplicate the branch list
        set branches $reachable_branches
        if {[llength $logged_branches] > 0} {
          set branches [concat $reachable_branches $logged_branches]
        }
        set branches [prune_branchlist $branches]

        # De-duplicate the tags, while we're thinking of it.
        foreach a [array names revtags] {
          if {[llength $revtags($a)] > 1} {
            set revtags($a) [prune_branchlist $revtags($a)]
          }
        }

        # Decide what to use for the trunk.
        set trunk ""
        set trunk_found 0
        # If there's only one choice, don't waste time looking
        if {[llength $branches] == 1} {
           set trunk [lindex $branches 0]
           set trunk_found 1
           gen_log:log D "Only one branch to begin with! That was easy! trunk=$trunk"
        }
        if {! $trunk_found} {
          # Now we go through the branches and eliminate the ones that this file
          # doesn't inhabit
          foreach br $branches {
            gen_log:log D "$br"
            set cmd(git_revtest) [exec::new "git rev-list -n 1 --abbrev-commit $br -- \"$filename\""]
            set revtest_lines [split [$cmd(git_revtest)\::output] "\n"]
            # Dont' bother parsing, we only need to know if it's something or nothing
            gen_log:log D $revtest_lines
            if { [llength $revtest_lines] < 1 } {
              # We can remove that one
              set idx [lsearch $branches $br]
              set branches [lreplace $branches $idx $idx]
              gen_log:log D "Removing $br from consideration"
            }
          }
          if {[llength $branches] == 1} {
           set trunk [lindex $branches 0]
           set trunk_found 1
           gen_log:log D "Only one branch left after the revlist test. trunk=$trunk"
          }
        }
        if {! $trunk_found} {
          # master may or may not be in our list of branches. If it is, try to use it
          if { "master" in $branches } {
            set trunk "master"
            set trunk_found 1
            gen_log:log D "master is in branches, trunk=$trunk"
          }
        }
        if {! $trunk_found} {
          set m [lsearch -glob $branches {*/master}]
          if {$m > -1} {
            set trunk [lindex $branches $m]
            gen_log:log D "*/master is in branches, trunk=$trunk"
            set trunk_found 1
          }
        }
        if {! $trunk_found} {
          # since we did the branch detection in date-order, newest to oldest, the
          # oldest branch may be at the end of the list?
          gen_log:log D "Using the end of logged branches"
          set trunk [lindex $logged_branches end]
        }
        gen_log:log D "TRUNK: $trunk"
        # Make sure the trunk is the first in the branchlist
        set idx [lsearch $branches $trunk]
        set branches [lreplace $branches $idx $idx]
        set branches [linsert $branches 0 $trunk]

        # Get the info for all the revs.
        set command "git log --all --abbrev-commit --first-parent --date=iso --tags --decorate=short --no-color -- \"$filename\""
        set cmd_log [exec::new $command {} 0 {} 1]
        set log_output [$cmd_log\::output]
        $cmd_log\::destroy
        set log_lines [split $log_output "\n"]
        parse_gitlog $log_lines

        # Get rev lists for the branches
        catch {unset branch_matches}
        gen_log:log D "Final branches: $branches"
        foreach branch $branches {
          gen_log:log D "========= $branch =========="
          set command "git rev-list --reverse --abbrev-commit --first-parent $branch -- \"$filename\""
          set cmd_revlist [exec::new $command {} 0 {} 1]
          set revlist_output [$cmd_revlist\::output]
          $cmd_revlist\::destroy
          set revlist_lines [split $revlist_output "\n"]
          if {[llength $revlist_lines]} {
            foreach ro $revlist_lines {
              if {[string length $ro] > 0} {
                 lappend raw_revs($branch) $ro
                 set revpath($ro) $relpath
                 set revkind($ro) "revision"
              }
            }
          } else {
            # This shouldn't happen because we pruned already, no harm in checking
            gen_log:log D "branch $branch is EMPTY. Removing from the list"
            # If it's empty, remove this branch from the list
            set idx [lsearch $branches $branch]
            set branches [lreplace $branches $idx $idx]
            continue
          }

          if {$branch eq $trunk} {
            # sometimes we don't have raw_revs($trunk) if the file is added on branch,
            # but we should have guessed at a rootrev by now
            if {! [info exists raw_revs($trunk)]} {
              set raw_revs($trunk) $rootrev
            }
            set branchrevs($trunk) [lreverse $raw_revs($trunk)]
            set branchtip($trunk) [lindex $branchrevs($trunk) 0]
            set branchroot($trunk) [lindex $branchrevs($trunk) end]
            if {! [info exists rootrev]} {
              set rootrev $branchroot($trunk)
              gen_log:log D "USING ROOT $rootrev"
            }
            # Move the branch tags from the tip to the base
            # (if there's only one rev, those are the same, so watch out)
            if {[info exists revbtags($branchtip($branch)]} {
               set revbtags($branchroot($branch)) $revbtags($branchtip($branch))
            } else {
               set revbtags($branchroot($branch)) $branch
            }
            if {$branchtip($branch) ne $branchroot($branch)} {
              catch {unset revbtags($branchtip($branch))}
            }

            continue
          }
          
          # The root of a branch is the first one we get back that's only in the branch
          # and not in master
          if {[info exists raw_revs($branch)]} {
            gen_log:log D "COMPARING $trunk (listA) vs $branch (listB)"
            lassign [list_comm $branchrevs($trunk) $raw_revs($branch)] inBonly inBoth
            gen_log:log D "== ONLY IN $branch =="
            if {[llength $inBonly] < 1} {
              # If it's empty, remove this branch from the list
              set idx [lsearch $branches $branch]
              set branches [lreplace $branches $idx $idx]
              continue
            }
            foreach h $inBonly {
              gen_log:log D "$h"
              set revkind($h) "revision"
            }
            set base [lindex $inBonly 0]
            set branchrevs($branch) [lreverse $inBonly]
            set branchtip($branch) [lindex $branchrevs($branch) 0]
            set branchroot($branch) [lindex $branchrevs($branch) end]
            if {$base eq ""} {
              gen_log:log D "BASE not found for $branch"
              set base [lindex $inBoth 0]
              gen_log:log D "using $base"
            }

            set revkind($base) "branch"
            if {[info exists revparent($base)]} {
              # We may have found a parent in the very first git log
              set parent $revparent($base)
              gen_log:log D "PARENT $revparent($base) of $branch already picked up"
            } else {
              # If not, we can try to get it
              set parent [find_parent $base]
              gen_log:log D "PARENT $revparent($base) of $branch determined by new git log %p"
              set revparent($base) $parent
            }
            # But it will very likely not be in our revlists, so always do this instead
            set test_parent [lindex $inBoth end]
            if {$test_parent != ""} {
              if {$test_parent ne $revparent($base)} {
                gen_log:log D "PARENT $revparent($base) from log %p DOESN'T MATCH end of inBoth $test_parent for $branch"
              } else {
                gen_log:log D "PARENT $revparent($base) from log %p MATCHES end of inBoth $test_parent for $branch"
              }
              set parent $test_parent
              set revparent($base) $parent
              gen_log:log D "Using end of inBoth for PARENT $revparent($base) of $branch"
            }

            gen_log:log D "$branch: BASE $base PARENT $parent"
            # Sometimes we get back a parent that our log --all didn't pick
            # up. This may happen if the directory had checkins that didn't
            # affect the file or the file is newly added
            if {! [info exists revcomment($parent)] } {
              gen_log:log D "MISSING INFO for PARENT $parent of $branch"
              load_mystery_info $revparent($base) .
            }

            # Adding this to trunk but it doesn't always belong there
            # and it doesn't always belong at the bottom. 
            if {! [info exists parent]} {
              set parent $rootrev
              gen_log:log D "Didn't find a PARENT, so using rootrev $rootrev"
            }
            if {$parent ni $branchrevs($trunk)} {
              gen_log:log D "Adding new PARENT $parent to branchrevs($trunk)"
              set branchrevs($trunk) [concat $branchrevs($trunk) $parent]
            }

            # We got the parent settled one way or another
            if {! [info exists revbranches($parent)] } {
              set revbranches($parent) $branchroot($branch)
            } elseif {$branchroot($branch) ni $revbranches($parent)} {
              lappend revbranches($parent) $branchroot($branch)
            }

            # Move the branch tags from the tip to the base
            # (if there's only one rev, those are the same, so watch out)
            if {[info exists revbtags($branchtip($branch)]} {
               set revbtags($branchroot($branch)) revbtags($branchtip($branch))
            } else {
               set revbtags($branchroot($branch)) $branch
            }
            if {$branchtip($branch) ne $branchroot($branch)} {
              catch {unset revbtags($branchtip($branch))}
            }
          }

          # If two branches have the same root, one is likely
          # a sub-branch of the other. Let's see if we can disambiguate
          foreach t [array names branchroot] {
            if {$t eq $branch} continue
            if {$branchroot($branch) eq $branchroot($t)} {
              # Save the duplicates in a list to deal with next
              lappend branch_matches($branch) $t
            }
          }
          gen_log:log D "========= finished $branch =========="
        }

        # Here's where we deal with the branch/sub-branch confusions
        # There should be only one because we take care of each as it appears, right?
        # so the foreach is unnecessary?
        foreach a [array names branch_matches] {
          foreach b $branch_matches($a) {
            gen_log:log D "BRANCHES $a and $b have the SAME ROOT $branchroot($a)=$branchroot($b)"
            gen_log:log D "COMPARING branchrevs($a) vs branchrevs($b)"
            lassign [list_comm $branchrevs($a) $branchrevs($b)] inBonly inBoth
            gen_log:log D "COMPARING branchrevs($b) vs branchrevs($a)"
            lassign [list_comm $branchrevs($b) $branchrevs($a)] inAonly inBoth
            gen_log:log D " in $a ONLY: $inAonly"
            gen_log:log D " in $b ONLY: $inBonly"

            if {[llength $inBonly] > 0} {
              # branch $b is the first branch. $a is a sub-branch of $b
              # so we re-configure $a
              set stockbranch $a
              set subbranch $b
            } elseif {[llength $inAonly] > 0} {
              # branch $a is the first branch. $b is a sub-branch of $a
              # so we re-configure $b
              set stockbranch $b
              set subbranch $a
            } else {
              gen_log:log D "BRANCHES $a and $b have identical revs!"
            }
            # Now we know who's who.
            # Shorten the sub-branch revlist to revs not on the stock branch
            gen_log:log D "$stockbranch is the stock branch, $subbranch is the sub-branch"
            set stock_old_branchroot $branchroot($stockbranch)
            set stock_old_branchparent $revparent($stock_old_branchroot)

            gen_log:log D "OLD root (of both): $stock_old_branchroot"
            gen_log:log D "OLD parent (of both): $stock_old_branchparent"
            gen_log:log D "OLD $stockbranch revlist: $branchrevs($stockbranch)"
            gen_log:log D "OLD $subbranch revlist: $branchrevs($subbranch)"

            # Shorten the sub-branch revlist to revs not on the stock branch
            #gen_log:log D "ORIG $subbranch branchrevs $branchrevs($subbranch)"
            lassign [list_comm $branchrevs($stockbranch) $branchrevs($subbranch)] inBonly inBoth
            set branchrevs($subbranch) $inBonly
            gen_log:log D "NEW $subbranch revlist $branchrevs($subbranch)"
            set branchroot($subbranch) [lindex $branchrevs($subbranch) end]
            if {[info exists revparent($branchroot($subbranch))]} {
              set sub_new_branchparent $revparent($branchroot($subbranch))
            } else {
              set sub_new_branchparent [find_parent $branchroot($subbranch)]
              set revparent($branchroot($subbranch)) $sub_new_branchparent
            }
            gen_log:log D "NEW $subbranch root: $branchroot($subbranch)"
            gen_log:log D "NEW $subbranch parent: $sub_new_branchparent"

            # Add the new sub-branch to its new parent's revbranches list
            if {! [info exists revbranches($sub_new_branchparent)]} {
              set revbranches($sub_new_branchparent) $branchroot($subbranch)
            } elseif {$branchroot($subbranch) ni $revbranches($sub_new_branchparent)} {
              lappend revbranches($sub_new_branchparent) $branchroot($subbranch)
            }

            gen_log:log D "NEW $subbranch parent branchlist after fixing:  $revbranches($sub_new_branchparent)"

            # The parent for the stock branch may not actually exist in our data
            # for reasons having nothing to do with this process. Let's try to
            # get the data.
            if {! [info exists revcomment($stock_old_branchparent)] } {
              gen_log:log D "MISSING info for PARENT $stock_old_branchparent of MAYBE SUB-BRANCH $stockbranch"
              load_mystery_info $stock_old_branchparent .
              if {! [info exists revbranches($parent)]} {
                set revbranches($parent) $stock_old_branchroot
              } elseif {$stock_old_branchroot ni $revbranches($parent)} {
                lappend revbranches($parent) $stock_old_branchroot
              }
            }

            set stockroot $branchroot($stockbranch)
            set subroot   $branchroot($subbranch)
            # Make sure the revbtags are in the right place for both branches
            if {(! [info exists revbtags($subroot) ]) || $subbranch ni $revbtags($subroot) } {
              lappend revbtags($subroot) $subbranch
            }
            if {(! [info exists revbtags($stockroot) ]) || $stockbranch ni $revbtags($stockroot) } {
            lappend revbtags($stockroot) $stockbranch
            }
            # Now we have to get it out of its old parent's revbranches list and into
            # its new parent's one
            gen_log:log D "ORIG $subbranch $revbtags($stockroot)"
            set idx [lsearch $revbtags($stockroot) $subbranch]
            set revbtags($stockroot) [lreplace $revbtags($stockroot) $idx $idx]
            gen_log:log D "NEW $subbranch $revbtags($stockroot)"
          }
        }
        # All done with sub-branch

        # Make sure we know where we're rooted. Sometimes the initial parent detection went
        # one too far, which would put us on a different branch that's not visible from here.
        if {[info exists rootrev] && $rootrev != "" && [info exists branchrevs($trunk)]} {
          gen_log:log D "rootrev = $rootrev"
          gen_log:log D "branchrevs($trunk) $branchrevs($trunk)"
          if {! [info exists revbtags($rootrev)]} {
            gen_log:log D "No revbtags($rootrev)!"
            set root_ok 0
          }
          # If we have children for this, it's a perfectly good root
          if {[info exists revchildren($rootrev)]} {
            gen_log:log D "revchildren($rootrev) $revchildren($rootrev)"
            # But we may have to move the tag
            foreach a [array names revbtags] {
              if {$trunk in $revbtags($a)} {
                gen_log:log D "$trunk is already in revbtags($a) $revbtags($a)"
                gen_log:log D " take it out of revbtags($a)"
                set idx [lsearch $revbtags($a) $trunk]
                set revbtags($a) [lreplace $revbtags($a) $idx $idx]
                if {[llength $revbtags($a)] < 1} {
                  catch {unset revbtags($a)}
                }
                gen_log:log D " and add it to revbtags($rootrev)"
                lappend revbtags($rootrev) $trunk
                set root_ok 1
                break
              }
            }
          }
          if {! $root_ok} {
            # We can try using the end of the trunk's revlist
            set lastref [lindex $branchrevs($trunk) end]
            if {[info exists revbtags($lastref)]} {
              set rootrev $lastref
              set root_ok 1
            }
          }
          if {! $root_ok} {
            foreach a [array names revbtags] {
              # Use the position that it already got somehow
              if {$trunk in $revbtags($a)} {
                gen_log:log D "$trunk is already in revbtags($a) $revbtags($a)"
                set rootrev $a
                set root_ok
                break
              }
            }
          }
          # This makes the You are Here work
          set branchroot($trunk) $rootrev
        } else {
          cvsfail "Can't read trunk revisions for this file" $lc
        }

        # Position the the You are Here icon and top up final variables
        set revnum_current [set $ln\::revnum_current]
        gen_log:log D "revnum_current: $revnum_current"
        foreach branch $branches {
          if {$branchtip($branch) eq $revnum_current} {
            gen_log:log D "Currently at top of $branch"
            set branchrevs($branch) [linsert $branchrevs($branch) 0 {current}]
          } else {
            # But maybe we're not at the tip
            foreach r $branchrevs($branch) {
              if {$r == $revnum_current} {
                # We need to make a new artificial branch off of $r
                lappend revbranches($r) {current}
              }
            }
          }
  
          # Just checking, for debug output
          if {[info exists branchroot($branch)]} {
            gen_log:log D "branchroot($branch) $branchroot($branch)"
            if {[info exists branchrevs($branch)]} {
              set branchrevs($branchroot($branch)) $branchrevs($branch)
            } else {
              gen_log:log D "branchrevs($branch) doesn't exist!"
            }
          } else {
            gen_log:log D "branchroot($branch) doesn't exist!"
          }
        }
        # Make sure we have a root
        set revkind($rootrev) "root"


        pack forget $lc.stop
        pack $lc.close -in $lc.down.closefm -side right
        $lc.close configure -state normal

        [namespace current]::git_sort_it_all_out
        gen_log:log T "LEAVE"
        return
      }
 
      # Get branches from log --format=%h%P%d
      proc parents_and_branches {lines} {
        variable revparent
        variable revbranches
        variable revchildren
        variable revbtags
        variable revmergefrom
        variable revtags
        variable rootrev

        catch {unset revchildren}

        gen_log:log T "ENTER (<...>)"
        catch {unset my_branches}
        catch {unset parentlist}
        # Line could look like this:
        # 226ff9b:3042a62: (tag: tagAA, origin/branchA, origin/HEAD, branchA)
        # merge commits look like
        # 95fe289:783ae78 226ff9b:
        foreach logline [split $lines "\n"] {
          set splits [split $logline ':']
          set h [lindex $splits 0]
          set p [lindex $splits 1]
          if {$p != ""} {
            # Keep a list of the parents, so we can check for multiply-occurring ones
            # If a commit occurs more than once in the parent column, it must be
            # a branch point
            foreach pl [split $p] {
              # There may be multiple parents if it's a merge
              lappend parentlist $pl
              if {$h != ""} {
                lappend revchildren($pl) $h
              }
            }
          }
          # If it's a merge, there will be more than one parent
          if {$h != ""} {
            set revparent($h) [lindex $p 0]
            set mergefrom [lindex $p 1]
            if {$mergefrom != ""} {
              set revmergefrom($h) $mergefrom
            }
            # If there's a rev without a parent, can we assume it's the root?
            if {$revparent($h) == ""} {
              set rootrev $h
              gen_log:log D "FOUND (unequivocal?) ROOT $rootrev"
            }
            set last_h $h
          }
          # We're interested in what's inside the parentheses
          if {[regexp {\(.*\)} $logline parenthetical]} {
            #strip off the parentheses
            set in_parens [string range $parenthetical 1 end-1]
            set items [split $in_parens " "]
            set i 0
            while {$i < [llength $items]} {
              # First, see if there are tags and peel them off
              if {[lindex $items $i] eq "tag:"} {
                incr i
                lappend revtags($h) [string trimright [lindex $items $i] ","]
                incr i
              } else {
                # what's left are branches. This h is the tip, not the root, usually
                # but the root is where we want the revbtags
                set raw_btag [string trimright [lindex $items $i] ","]
                if {(! [regexp {HEAD} $raw_btag]) && ($raw_btag ne "->")} {
                  #gen_log:log D "Provisionally assigning $raw_btag to revbtags($h)"
                  lappend revbtags($h) $raw_btag
                  lappend my_branches $raw_btag
                }
                incr i
              }
            }
          }
        }
        if {! [info exists last_h] } {
          return "" {}
        }

        if {! [info exists my_branches] } {
          set my_branches {}
        }

        if {! [info exists rootrev] } {
          if {$last_h != ""} {
            if {[info exists revparent($last_h)]} {
              set rootrev $revparent($last_h)
            } else {
              set rootrev $last_h
            }
            gen_log:log D "FOUND likely ROOT $revparent($last_h)"
          }
        }
        if {[info exists rootrev]} {
          gen_log:log T "LEAVE ($rootrev $my_branches)"
          return [list $rootrev $my_branches]
        } else {
          gen_log:log T "LEAVE \"\" $my_branches)"
          return [list "" $my_branches]
        }
      }

      proc parse_gitlog {lines} {
        variable relpath
        variable revwho
        variable revdate
        variable revparent
        variable revpath
        variable revtime
        variable revcomment
        variable revtags
        variable revmergefrom
        variable rootrev

        gen_log:log T "ENTER (<...>)"
        set revnum ""
        set i 0
        set l [llength $lines]
        set last ""
        while {$i < $l} {
          set line [lindex $lines $i]
          #gen_log:log D "Line $i of $l:  $line"
          #gen_log:log D "$line"
          if { [ regexp {^\s*$} $last ] && [ string match {commit *} $line] } {
            # ^ the last line was empty and this one starts with commit
            if {[expr {$l - $i}] < 0} {break}
            # ^ we came to the last line!
            set line [lindex $lines $i]
            set revnum [lindex $line 1]
            incr i
            set line [lindex $lines $i]
            # a line like "Merge: 7ee40c3 d6b18a7" could be next
            if { [string match {Merge:*} $line] } {
              set revmergefrom($revnum) [lindex $line end]
              incr i
            }
            set line [lindex $lines $i]
            # Author: dorothy rob <dorothyr@tadg>
            if { [string match {Author:*} $line] } {
              set remainder [join [lrange $line 1 end]]
              regsub { <.*>} $remainder {} revwho($revnum)
            }
            incr i
            set line [lindex $lines $i]
            # Date:   2018-08-17 20:10:15 -0700
            if { [string match {Date:*} $line] } {
              set revdate($revnum) [lindex $line 1]
              set revtime($revnum) [lindex $line 2]
            }
            set last [lindex $lines $i]

            incr i
            set line [lindex $lines $i]
            # Blank line precedes comment
            set revcomment($revnum) ""
            if { [ regexp {^\s*$} $line ] } {
              set last $line
              set j $i
              set c [expr {$i + 1}]
              set line [lindex $lines $c]
              while { ! [string match {commit *} $line] } {
                incr c
                set line [lindex $lines $c]
                if {$c > $l} {break}
              }
              # The comment lines have leading whitespace (4 spaces)
              foreach commentline [lrange $lines [expr {$j + 1}] [expr {$c - 2}]] {
                set commentline [string range $commentline 4 end]
                append revcomment($revnum) "$commentline\n"
              }
              set i [expr {$c - 1}]
            }
            incr i
            set revpath($revnum) $relpath

            #gen_log:log D "revwho($revnum) $revwho($revnum)"
            #gen_log:log D "revdate($revnum) $revdate($revnum)"
            #gen_log:log D "revtime($revnum) $revtime($revnum)"
            #gen_log:log D "revcomment($revnum) $revcomment($revnum)"
            #gen_log:log D "revparent($revnum) $revparent($revnum)"
          }
        }
        gen_log:log T "LEAVE"
      }

      # Use git show-branch to find the first revision on a branch, and then
      # its parent
      proc identify_parent {branch} {
        variable filename

        gen_log:log T "ENTER ($branch)"
        gen_log:log D "TRACK $branch"

        set base_guess1 [set base_guess2 ""]
        set base_hash1 [set base_hash2 ""]
        set parent_guess1 [set parent_guess2 ""]

        # Second method of finding base of branch
        set capture ""
        set base ""
        set parent ""
        set savlist ""
        set command2 "git show-branch --no-color --reflog $branch"
        set cmd2 [exec::new $command2]
        set cmd2_output [$cmd2\::output]
        $cmd2\::destroy
        foreach br_r_ln [split $cmd2_output "\n"] {
          # Look for someting like "+ [branchB@{0}^] or "++ [branchA@{0}~2]"
          # This time, we want the next to last match
          if [regexp "^\\\++\\\s+\\\[$branch@\\\{\\\S+.*\\\]" $br_r_ln capture] {
            lappend savlist $capture
          }
        }
        # This time, we want the next to last match
        set nextlast [lindex $savlist end-1]
        # attempt to get the bit between the braces
        if [regexp {^.*\[(\S+)\].*$} $nextlast null base_guess2] {
          # Find the hash of the branch base we just identified
          set command "git rev-parse --short $base_guess2 -- \"$filename\""
          set cmd_p2 [exec::new $command]
          set base_hash2 [lindex [$cmd_p2\::output] 0]
          # Now find its immediate parent
          set command "git rev-parse --short $base_guess2^ -- \"$filename\""
          set cmd_p2 [exec::new $command]
          set parent_guess2 [lindex [$cmd_p2\::output] 0]
        }
        gen_log:log D "TRACK method 2: Base: $base_guess2 ($base_hash2)  Parent: $parent_guess2"
        set base $base_hash2
        set parent $parent_guess2
        gen_log:log D "TRACK returning for $branch: BASE $base  PARENT $parent"
        gen_log:log T "return ($base $parent)"
        return [list $base $parent]
      }

      # We may have got a parent which the file log won't list
      # because it didn't affect the file in question.  Request that rev
      # without the filename.
      proc load_mystery_info {mystery repos} {
        variable revparent
        variable revwho
        variable revdate
        variable revtags
        variable revtime
        variable revcomment
  
        gen_log:log T "ENTER ($mystery $repos)"
        set command "git -C $repos log -n 1 --format=%h|%ai|%cn|%s|%D $mystery"
        set cmd_log [exec::new $command {} 0 {} 1]
        set log_output [$cmd_log\::output]
        $cmd_log\::destroy
        set splits [split $log_output "|"]
        set dateandtime [lindex $splits 1]
        set revdate($mystery) [lindex $dateandtime 0]
        set revtime($mystery) [lindex $dateandtime 1]
        set revwho($mystery) [lindex $splits 2]
        set revcomment($mystery) [lindex $splits 3]
        set decorations [string trim [lindex $splits 4] "\n"]
        set items [split $decorations " "]
        set i 0
        while {$i < [llength $items]} {
          # see if there are tags and peel them off
          if {[lindex $items $i] eq "tag:"} {
            incr i
            set tag [string trimright [lindex $items $i] ","]
            lappend revtags($mystery) $tag
            incr i
          }
        }
        set revparent($mystery) ""
   
        gen_log:log D "Got info for mystery rev $mystery"
        gen_log:log T "LEAVE"
      }

      proc find_parent {base} {
        set command "git log -n 1 --format=%p $base"
        set cmd_log [exec::new $command {} 0 {} 1]
        set log_output [$cmd_log\::output]
        set parent [string trim $log_output]
        return $parent
      }

      proc git_sort_it_all_out {} {
        global cvscfg
        global current_tagname
        variable filename
        variable lc
        variable ln
        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable revkind
        variable revpath
        variable revtags
        variable revbtags
        variable branchrevs
        variable revbranches
        variable revmergefrom
        variable logstate
        variable revnum
        variable rootbranch
        variable revbranch

        gen_log:log T "ENTER"

        # Sort the revision and branch lists and remove duplicates
        foreach r [lsort -dictionary [array names revkind]] {
          gen_log:log D "revkind($r) $revkind($r)"
        }
        foreach r [lsort -dictionary [array names revpath]] {
           gen_log:log D "revpath($r) $revpath($r)"
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names branchrevs]] {
          gen_log:log D "branchrevs($a) $branchrevs($a)"
        }
        foreach a [lsort -dictionary [array names revbranches]] {
           gen_log:log D "revbranches($a) $revbranches($a)"
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names revbtags]] {
         gen_log:log D "revbtags($a) $revbtags($a)"
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names revtags]] {
          gen_log:log D "revtags($a) $revtags($a)"
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names revmergefrom]] {
          ## Only take one from the list that you might have here
          set revmergefrom($a) [lindex $revmergefrom($a) end]
          gen_log:log D "revmergefrom($a) $revmergefrom($a)"
        }
        # We only needed these to place the you-are-here box.
        catch {unset rootbranch revbranch}
        $ln\::DrawTree now
        gen_log:log T "LEAVE"
      }

      [namespace current]::reloadLog
      return [namespace current]
    }

  }
}

proc list_comm {listA listB} {
  # Compare two lists. Return items in the second
  # that aren't in the first.

  gen_log:log T "ENTER\n\t$listA\n\t$listB"
  gen_log:log D "listA $listA"
  gen_log:log D "listB $listB"

  set inA ""
  set inB ""
  set inBoth ""
  # Shortcut if lists are identical
  if { $listA == $listB } {
    set inA {}
    set inB {}
    set inBoth $listA
    gen_log:log D "lists are IDENTICAL"
  } else {
    foreach B $listB {
      if {$B in $listA} {
        lappend inBoth $B
      } else {
        lappend inB $B
      }
    }
  }

  #gen_log:log D "in A only: $inA"
  gen_log:log D "in listB only: $inB"
  gen_log:log D "in Both:   $inBoth"

  return [list $inB $inBoth]
  return $inB
}

# We have both remote and local names of the same branch.
# For duplicated ones, keep only the local
proc prune_branchlist {branchlist} {
  gen_log:log T "ENTER ($branchlist)"

  set filtered_branchlist {}
  foreach r $branchlist {
    if {[string match {*/HEAD} $r]} {continue}
    if {[regexp {/} $r]} {
      regsub {.*/} $r {} rtail
      if {$rtail ni $branchlist} {
        lappend filtered_branchlist $r
      }
    } else {
      if {$r ni $filtered_branchlist} {
        lappend filtered_branchlist $r
      }
    }
  }
  gen_log:log T "LEAVE ($filtered_branchlist)"
  return $filtered_branchlist
}
