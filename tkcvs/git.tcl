# Find where we are in path
proc read_git_dir {dirname} {
  global cvsglb
  global current_tagname

  # See what branch we're on
  set cmd(git_branch) [exec::new "git branch --no-color"]
  set branch_lines [split [$cmd(git_branch)\::output] "\n"]
  foreach line $branch_lines {
    if [string match {\* *} $line] {
      # Could be something like (HEAD detached at 960c171)
      set current_tagname [join [lrange $line 1 end]]
      gen_log:log D "current_tagname=$current_tagname"
    }
  }
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
    catch {set Filelist($f:date) \
       [clock format [file mtime ./$i] -format $cvscfg(dateformat)]}
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
  if {! [info exists cvscfg(origin)] } {
    set cvscfg(origin) ""
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
    gen_log:log D "$tv insert {} end -id $dname -values [list $dname $modval($dname)]"
    $tv insert {} end -id "$dname" -values [list "$dname" $modval($dname)]
  }
  update idletasks
  # Then you can do something like this to list the files
  # git ls-tree -r refs/heads/master --name-only
  gen_log:log T "LEAVE"
}

proc git_push {} {
  global cvsglb

  gen_log:log T "ENTER"

  set command "git push --dry-run"
  set ret [catch {eval "exec $command"} dryrun_output]
  gen_log:log C "$dryrun_output"

  # push will return "Everything up-to-date" if it is
  if {! [string match "Everyt*" $dryrun_output]} {
    set mess "This will push your committed changes to\
            $cvsglb(push_origin) $cvsglb(push_url).\n"

    append mess "\n$dryrun_output"
    append mess "\n\n Are you sure?"

    set title {Confirm!}
    set answer [tk_messageBox \
          -icon question \
          -title $title \
          -message $mess \
          -parent .workdir \
          -type okcancel]

    if {$answer == {ok}} {
      set commandline "git push"
      set v [viewer::new "Push"]
      $v\::do "$commandline"
      $v\::wait
      $v\::clean_exec
    }
  } else {
    cvsok "$dryrun_output" .workdir
  }

  gen_log:log T "LEAVE"
}

proc git_fetch {} {
  global cvsglb

  gen_log:log T "ENTER"

  set command "git fetch --dry-run"
  set ret [catch {eval "exec $command"} dryrun_output]
  gen_log:log C "$dryrun_output"

  # Fetch is just quiet if it's up to date
  if {[llength $dryrun_output] > 1} {
    set mess "This will fetch changes from\
            $cvsglb(fetch_origin) $cvsglb(fetch_url).\n"

    append mess "\n$dryrun_output"
    append mess "\n\n Are you sure?"

    set title {Confirm!}
    set answer [tk_messageBox \
          -icon question \
          -title $title \
          -message $mess \
          -parent .workdir \
          -type okcancel]

    if {$answer == {ok}} {
      set commandline "git fetch"
      set v [viewer::new "Fetch"]
      $v\::do "$commandline"
      $v\::wait
      $v\::clean_exec
    }
  } else {
    cvsok "Everything up to date" .workdir
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
  set filter ""

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
      #append flags " --graph --all --pretty=oneline"
      append flags " --graph --all --format=%h\\ \\ %aN\\ %s\\DdDdD%d"
      set filter truncate_git_graph
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
    $v\::do "$command" 1 $filter
    $v\::wait
    $v\::width 120
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
      append flags " --porcelain"
    }
    summary {
      append flags " --long"
    }
    verbose {
      append flags " --verbose"
    }
  }
  # There doesn't seem to be a way to suppress color. This option is invalid.
  #append flags " --no-color"
  set stat_cmd [viewer::new $title]
  set commandline "git status $flags $filelist"
  $stat_cmd\::do "$commandline" 0

  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

# called from the branch browser
proc git_log_rev {rev file} {
  global cvscfg

  gen_log:log T "ENTER ($rev $file)"
  set title "Git log"
  set commandline "git log --graph --all $cvscfg(gitlog_opts) --format=%h\\ \\ %aN\\ %s\\DdDdD%d"
  if {$rev ne ""} {
    append commandline " $rev"
    append title " $rev"
  } else {
    append title " $cvscfg(gitlog_opts)"
  }
  append commandline " \"$file\""
  append title " $file"

  set v_log [viewer::new "$title"]
  $v_log\::width 120
  $v_log\::do $commandline 1 truncate_git_graph
  $v_log\::wait

  gen_log:log T "LEAVE"
}

# Shows which files changed in a commit
# called from the branch browser
proc git_show {rev} {

  gen_log:log T "ENTER ($rev)"
  set commandline "git show --stat --oneline --no-color $rev"
  set title "Git show $rev"
  set v_show [viewer::new "$title"]
  $v_show\::width 120
  $v_show\::do $commandline 1
  $v_show\::wait

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
    "Commit" {
       set command "git checkout $cvsglb(revnumber)"
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
    cvsfail "Please select one file." .workdir
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

  set filelist $args
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

# Called from file viewer annotate button
proc git_annotate_range {v_w revision filename} {

  gen_log:log T "ENTER ($v_w $revision $filename)"
  if {$revision != ""} {
    # We were given a revision
    set revflag "$revision"
  } else {
    set revflag ""
  }
  set range [get_textlines $v_w]
  set firstline [lindex $range 0]
  set lastline [lindex $range 1]
  if {$firstline eq "" || $lastline eq ""} {
    cvsfail "Plesae select a range of lines" $v_w
    return
  }

  annotate::new $revision $filename "git_range" $firstline $lastline
  gen_log:log T "LEAVE"
}

# View a specific revision of a file.
# Called from branch browser
proc git_fileview {revision path files} {

  gen_log:log T "ENTER ($revision $path $files)"
  set filelist [join $files]

  foreach filename $filelist {
    if {$path ne ""} {
      set filepath "$path/$filename"
    } else {
      set filepath "$filename"
    }
    set command "git show \"$revision:$filepath\""
    set v [viewer::new "$filepath Revision $revision"]
    $v\::do "$command"

    # Get the viewer window
    set v_w [namespace inscope $v {set w}]
    frame $v_w.blamefm
    button $v_w.blamefm.blame -text "Annotate selection" \
      -command "git_annotate_range $v_w $revision \"$filename\""
    pack $v_w.blamefm -in $v_w.bottom -side left
    pack $v_w.blamefm.blame
  }
}

# Sends files to the branch browser one at a time
proc git_branches {files} {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($files)"
  set filelist [join $files]

  set cvsglb(lightning) 0

  read_git_dir [pwd]
  gen_log:log D "Relative Path: $cvsglb(relpath)"

  if {$files == {}} {
    ::git_branchlog::new $cvsglb(relpath) .
  } else {
    foreach file $files {
      ::git_branchlog::new $cvsglb(relpath) $file
    }
  }

  gen_log:log T "LEAVE"
}

# Sends files to the branch browser one at a time
proc git_fast_diagram {files} {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($files)"
  set filelist [join $files]

  set cvsglb(lightning) 1

  read_git_dir [pwd]
  gen_log:log D "Relative Path: $cvsglb(relpath)"

  if {$files == {}} {
    ::git_branchlog::new $cvsglb(relpath) .
  } else {
    foreach file $files {
      ::git_branchlog::new $cvsglb(relpath) $file
    }
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
      global logcfg
      global cvsglb
      set my_idx [uplevel {concat $my_idx}]
      set filename [uplevel {concat $filename}]
      set relpath [uplevel {concat $relpath}]
      set directory_merge [uplevel {concat $directory_merge}]
      variable cmd_log
      variable lc
      variable ln
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

      gen_log:log T "ENTER [namespace current]"
      set newlc [logcanvas::new $filename "GIT,loc" [namespace current]]
      set ln [lindex $newlc 0]
      set lc [lindex $newlc 1]

      if {![info exists cvsglb(lightning)]} {
        set cvsglb(lightning) 0
      }
      if {$cvsglb(lightning)} {
        $lc.refresh configure -state disabled
      }

      proc abortLog { } {
        global cvscfg
        variable cmd_log
        variable lc

        if {[info exists cmd_log]} {
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
        global logcfg
        global current_tagname
        variable filename
        variable cmd_log
        variable lc
        variable ln
        variable allrevs
        variable branch_matches
        variable branchtip
        variable branchroot
        variable branchrevs
        variable branchparent
        variable family
        variable raw_revs
        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable revkind
        variable revparent
        variable revpath
        variable revstate
        variable revtags
        variable revbtags
        variable revmergefrom
        variable rootrev
        variable rootrevs
        variable oldest_rev
        variable revbranches
        variable logstate
        variable relpath
        variable filename

        gen_log:log T "ENTER"
        catch { $lc.canvas delete all }
        catch { unset branch_matches }
        catch { unset branchtip }
        catch { unset branchroot }
        catch { unset branchrevs }
        catch { unset branchparent }
        catch { unset raw_revs }
        catch { unset revwho }
        catch { unset revdate }
        catch { unset revstate }
        catch { unset revtime }
        catch { unset revcomment }
        catch { unset revtags }
        catch { unset revbtags }
        catch { unset revbranches }
        catch { unset revkind }
        catch { unset revmergefrom }
        catch { unset revpath }
        catch { unset revparent }
        catch { unset rootrev }
        catch { unset rootrevs }
        catch { unset trunk }
        catch { unset trunks }
        catch { unset family }
        catch { unset fam_trunk }

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
        gen_log:log D "current_tagname $current_tagname"
        set current_revnum [set $ln\::current_revnum]
        gen_log:log D "current_revnum $current_revnum"

        # Start collecting the branches
        catch {unset branches}
        catch {unset logged_branches}
        catch {unset local_branches}
        catch {unset remote_branches}

        # Prepare to draw something on the canvas so user knows we're working
        set cnv_y 20
        set yspc  15
        set cnv_h [winfo height $lc.canvas]
        set cnv_w [winfo width $lc.canvas]
        set cnv_x [expr {$cnv_w / 2- 8}]
        # subtract scrollbars etc
        incr cnv_h -20
        incr cnv_w -20
        $lc.canvas create text $cnv_x $cnv_y -text "Collecting the LOG" -tags {temporary}
        incr cnv_y $yspc
        $lc.canvas configure -scrollregion [list 0 0 $cnv_w $cnv_y]
        $lc.canvas yview moveto 1
        update idletasks

        if {! $logcfg(show_branches)} {
          set cvsglb(lightning) 1
        }

        # Gets all the commit information at once, including the branch, tag,
        # merge, and parent information. Doesn't necessarily pick up all of the
        # locally reachable branches
        set command "git log --all"
        if {$cvsglb(lightning)} {
          # For the fast no-branches mode, it's best with no options but in date order
          append command " --date-order"
        } else {
          append command " $cvscfg(gitlog_opts)"
          if {$cvscfg(gitmaxhist) != ""} {
            append command " -$cvscfg(gitmaxhist)"
          }
          if {$cvscfg(gitsince) != ""} {
            append command " --since=$cvscfg(gitsince)"
          }
        }
        if {$logcfg(show_tags)} {
          append command " --tags"
        }
        append command " --abbrev-commit --parents --format=fuller --date=iso --decorate=short --no-color -- \"$filename\""
        set cmd_log [exec::new $command {} 0 {} 1]
        set log_output [$cmd_log\::output]
        $cmd_log\::destroy
        set log_lines [split $log_output "\n"]
        set logged_branches [parse_gitlog $log_lines]

        catch {unset log_output}
        catch {unset log_lines}
        if {! [info exists allrevs]} {
          cvsfail "Couldn't read git log for $filename" $lc
          return;
        }
        gen_log:log D "[llength $allrevs] REVISIONS picked up by git log --all"
        # If we've found parentless revisions, rootrev is set to the first parentless
        # one we found
        gen_log:log D "Parentless revs $rootrevs"
        gen_log:log D "Last rootrev $rootrev"
        set oldest_rev [lindex $allrevs end]
        gen_log:log D "Oldest rev $oldest_rev $revdate($oldest_rev)"
        set raw_all [lreverse $allrevs]

        # Branches that were in the log decorations
        if {$logged_branches != {}} {
          set logged_branches [prune_branchlist $logged_branches]
        }

        if {! $cvsglb(lightning)} {
          # This gets all the locally reachable branches. We only use all of them if asked,
          # but their order is important. Also if "master" is in there, we want it.
          set cmd(git_branch) [exec::new "git branch --no-color"]
          set branch_lines [split [$cmd(git_branch)\::output] "\n"]
          # If we're in a detached head state, one of these can be like (HEAD detached at 9d24194)
          # but we can just filter it out
          foreach line $branch_lines {
            if {[string length $line] < 1} continue
            if {[regexp {detached} $line]} continue
            regsub {\*\s+} $line {} line
            lappend local_branches [lindex $line 0]
          }
          catch {unset branch_lines}

          # We always want the current branch, though
          if {($current_tagname != "") && ($current_tagname ni $logged_branches)} {
            lappend logged_branches $current_tagname
          }
          if {("master" in $local_branches) && ("master" ni $logged_branches)} {
            lappend logged_branches {master}
          }

          # Don't get the remote branches unless asked to
          if { ! $cvsglb(lightning) && [regexp {R} $cvscfg(gitbranchgroups)] } {
            set cmd(git_rbranch) [exec::new "git branch -r"]
            set branch_lines [split [$cmd(git_rbranch)\::output] "\n"]
            foreach line $branch_lines {
              if {[string length $line] < 1} continue
              if {[string match {*/HEAD} $line]} continue
              lappend remote_branches [lindex $line 0]
            }
            catch {unset branch_lines}
          }
          if {![info exists logged_branches]} { set logged_branches {} }
          if {![info exists local_branches]} { set local_branches {} }
          if {![info exists remote_branches]} { set remote_branches {} }
          gen_log:log D "File-log branches ([llength $logged_branches]): $logged_branches"
          gen_log:log D "Local branches ([llength $local_branches]):    $local_branches"
          gen_log:log D "Remote branches ([llength $remote_branches]):   $remote_branches"

          # Collect and de-duplicate the branch list
          # First, add the logged branches. We always need those, you can't opt out
          set branches $logged_branches
          # The local branch list usually preserves the order the best. So 
          # we try to preserve that order when we blend them, even if we don't add ones
          # that aren't already in the logged branches
          set ovlp_list ""
          set fb_only ""
          set lb_only ""
          if {[llength $local_branches] > 0} {
            foreach lb $local_branches {
              if {$lb in $logged_branches} {
                lappend ovlp_list $lb
              } else {
                lappend lb_only $lb
              }
            }
            foreach fb $logged_branches {
              if {$fb ni $local_branches} {
                lappend fb_only $fb
              }
            }
          }
          # Then add the local branches that weren't in the logged branches, if desired
          if { [regexp {L|R} $cvscfg(gitbranchgroups)] } {
            set branches [concat $ovlp_list $fb_only $lb_only ]
          } else {
            set branches [concat $ovlp_list $fb_only ]
          }
          # Then add the remote branches, if desired
          if { [regexp {R} $cvscfg(gitbranchgroups)] } {
            foreach remb $remote_branches {
              if {$remb ni $branches} {
                lappend branches $remb
              }
            }
          }
          set branches [lrange $branches 0 $cvscfg(gitmaxbranch)]
          set branches [prune_branchlist $branches]
          # Move master to the front
          set idx [lsearch -regexp $branches {master|.*/master}]
          set mstr [lindex $branches $idx]
          set branches [lreplace $branches $idx $idx]
          set branches [concat $mstr $branches]
          catch {unset logged_branches}
          catch {unset local_branches}
        
          gen_log:log D "Overlap:    $ovlp_list"
          gen_log:log D "File only:  $fb_only"
          gen_log:log D "Local only: $lb_only"
          gen_log:log D "Combined branches ([llength $branches]): $branches"

          # De-duplicate the tags, while we're thinking of it.
          foreach a [array names revtags] {
            if {[llength $revtags($a)] > 1} {
              set revtags($a) [prune_branchlist $revtags($a)]
            }
          }

          # Filter the branches
          # We got the master above
          set filtered_branches $mstr
          if {$cvscfg(gitbranchregex) ne ""} {
            gen_log:log D "regexp \{$cvscfg(gitbranchregex)\}"
            foreach b $branches {
              #gen_log:log D "regexp $cvscfg(gitbranchregex) $b"
              if {[catch { regexp "$cvscfg(gitbranchregex)" $b} reg_out]} {
                gen_log:log E "$reg_out"
                cvsfail "$reg_out"
                break
              } else {
                if {$reg_out} {
                  lappend filtered_branches $b
                }
              }
            }
            if {[llength $filtered_branches] < 1} {
              gen_log:log E "filter \{$cvscfg(gitbranchregex)\} didn't match any branches!"
              #cvsfail "filter \{$cvscfg(gitbranchregex)\} didn't match any branches!"
            } else {
              gen_log:log D "Filtered branches: $filtered_branches"
              set branches $filtered_branches
            }
          }
          set current_branches ""
        } else {
          set branches $current_tagname
          set current_branches $current_tagname
          set trunk $current_tagname
          set trunks $current_tagname
          set branchrevs($trunk) $allrevs
          set branchtip($trunk) [lindex $allrevs 0]
          set branchroot($trunk) [lindex $allrevs end]
          set branchrevs($branchroot($trunk)) $branchrevs($trunk)
        }

        # We need to query each branch to know if it's empty, so we collect the
        # revision list while we're at it. We collect the branches into
        # families having the same root, and detect identical ones.
        set empty_branches ""
        set root_branches ""
        set branchtips ""
        list ident_matches
        list family
        
        if {! $cvsglb(lightning)} {
          # This is necessary to reset the view after clearing the canvas
          $lc.canvas configure -scrollregion [list 0 0 $cnv_w $cnv_h]
          set cnv_y [expr {$cnv_y + $yspc}]
          set cnv_x [expr {$cnv_w / 2- 8}]
          $lc.canvas create text $cnv_x $cnv_y -text "Getting BRANCHES" -tags {temporary}
          incr cnv_y $yspc
          $lc.canvas configure -scrollregion [list 0 0 $cnv_w $cnv_y]
          $lc.canvas yview moveto 1
          update idletasks

          foreach br $branches {
            # Draw something on the canvas so the user knows we're working
            $lc.canvas create text $cnv_x $cnv_y -text $br -tags {temporary} -fill $cvscfg(colourB)
            incr cnv_y $yspc
            $lc.canvas configure -scrollregion [list 0 0 $cnv_w $cnv_y]
            $lc.canvas yview moveto 1
            update idletasks

            set command "git rev-list"
            if {$cvscfg(gitmaxhist) != ""} {
              append command " -$cvscfg(gitmaxhist)"
            }
            # If since time is set, use that. Otherwise, use the time of the oldest rev we found in log --all
            if {$cvscfg(gitsince) != ""} {
              set since_time $cvscfg(gitsince)
            } else {
              set seconds [clock scan $revdate($oldest_rev) -gmt yes]
              set since_time [clock add $seconds -1 hour]
            }
            set command "$command --reverse --abbrev-commit $cvscfg(gitlog_opts) --since=$since_time $br -- \"$filename\""
            set cmd_revlist [exec::new $command {} 0 {} 1]
            set revlist_output [$cmd_revlist\::output]
            $cmd_revlist\::destroy
            set revlist_lines [split $revlist_output "\n"]
            if {[llength $revlist_lines] < 1} {
              gen_log:log D "branch $br is EMPTY. Removing from consideration"
              # If it's empty, remove this branch from the list
              set idx [lsearch $branches $br]
              set branches [lreplace $branches $idx $idx]
              lappend empty_branches $br
              continue
            }
            if {[llength $revlist_lines]} {
              foreach ro $revlist_lines {
                if {[string length $ro] > 0} {
                  lappend raw_revs($br) $ro
                  set revpath($ro) $relpath
                  set revkind($ro) "revision"
                }
              }
              catch {unset revlist_output}
              catch {unset revlist_lines}
              set branchtip($br) [lindex $raw_revs($br) end]
              lappend branchtips $branchtip($br)
              lappend ident_matches($branchtip($br)) $br

              if {[llength $ident_matches($branchtip($br))] > 1} {
                gen_log:log D "$br identical to another branch. Setting aside"
                continue
              }
            
              lassign [list_within_list $raw_all $raw_revs($br)] start n_overlap
              # If there is orphaned stuff in here, some branches are disjunct with
              # with our root. Don't process these further now.
              if {$n_overlap == 0} {
                gen_log:log D "branch $br is DISJUNCT with our root"
                #set idx [lsearch $branches $br]
                #set branches [lreplace $branches $idx $idx]
              }
              set overlap_len($br) $n_overlap
              set overlap_start($br) $start
              set branchroot($br) [lindex $raw_revs($br) 0]
              gen_log:log D "$br root is $branchroot($br)"
              if {$branchroot($br) ni $rootrevs} {
                lappend rootrevs $branchroot($br)
              }
              if {$current_revnum in $raw_revs($br)} {
                gen_log:log D "$br contains current_revnum $current_revnum"
                lappend current_branches $br
              }
              foreach r $rootrevs {
                if {$r in $raw_revs($br)} {
                  gen_log:log D "$br contains ROOT $r"
                  if {[lindex $raw_revs($br) 0] eq $r} {
                    lappend family($r) $br
                  }
                }
              }
            }
          }
          # Finished collecting the branches from the repository

          # It's easier to compare the branches if we put identical ones aside.
          # Here we are saving lists of two or more identical branches.
          foreach i [array names ident_matches] {
            if {[llength $ident_matches($i)] < 2} {
              catch {unset ident_matches($i)}
             }
          }
        }

        # Get the branches in each family back in order
        foreach f [array names family] {
          set ofam [list]
          foreach ob $branches {
             if {$ob in $family($f)} {
               lappend ofam $ob
             }
          }
          set family($f) $ofam
          gen_log:log D "FAMILY ($f): $family($f)"
        }
        gen_log:log D "Empty branches: $empty_branches"
        gen_log:log D "You are Here:   $current_branches"
        gen_log:log D "Branches:       $branches"
        if {[llength $branches] < 1} {
          cvsfail "Nothing found by git log $cvscfg(gitlog_opts)"
          busy_done $lc
          return
        }

        # Decide what to use for the trunk. Consider only non-empty,
        # non-disjunct branches.
        foreach f [array names family] {
          set fam_branches $family($f)
          set fam_trunk($f) ""
          set trunk_found 0
          gen_log:log D "Deciding on a trunk for the ($f) $family($f) family"
          if {[llength $fam_branches] == 1} {
            # If there's only one choice, don't waste time looking
            set fam_trunk($f) [lindex $fam_branches 0]
            set trunk_found 1
            gen_log:log D " Only one branch to begin with! That was easy! trunk=$fam_trunk($f)"
          }
          if {! $trunk_found} {
            # If only one branch begins at the beginning, that's a good one
            set os_z ""
            foreach b $fam_branches {
              if {$overlap_start($b) == 0} {
                lappend os_z $b
              }
            }
            if {[llength $os_z] == 1} {
            gen_log:log D " Only one branch begins at the root. trunk=$b"
              set trunk_found 1
            }
          }
          if {! $trunk_found} {
            # Do we have revisions on master?
            set m [lsearch -exact $fam_branches {master}]
            if {$m > -1} {
              gen_log:log D "master is in our branches"
              set fam_trunk($f) "master"
              set trunk_found 1
            }
          }
          if {! $trunk_found} {
            # how about origin/master
            set m [lsearch -glob $fam_branches {*/master}]
            if {$m > -1} {
              set match [lindex $fam_branches $m]
              gen_log:log D "$match is in branches"
              set fam_trunk($f) $match
              set trunk_found 1
            }
          }
          #if {! $trunk_found} {
            #foreach t $fam_branches {
              #if {$t in $current_branches} {
                #gen_log:log D "Found $t in Current branches"
                #set fam_trunk($f) $t
                #set trunk_found 1
              #}
            #}
          #}
          if {! $trunk_found} {
            if {[llength $fam_branches] > 0} {
              set fam_trunk($f) [lindex $fam_branches 0]
              set trunk_found 1
              gen_log:log D " Using first branch as trunk"
            }
            set trunk_found 1
          }
          if {! $trunk_found} {
            gen_log:log D "No named TRUNK found!"
            set fam_trunk($f) ""
          }
          gen_log:log D "TRUNK for FAMILY $f: $fam_trunk($f)"

          # Make sure the trunk is the first in the branchlist
          set idx [lsearch $fam_branches $fam_trunk($f)]
          set fam_branches [lreplace $fam_branches $idx $idx]
          set fam_branches [linsert $fam_branches 0 $fam_trunk($f)]
          set family($f) $fam_branches

          # Get rev lists for the branches
          catch {unset branch_matches}
          # Draw something on the canvas so the user knows we're working

          set empty_branches ""
          gen_log:log D "========================"
          gen_log:log D "FINDING THE MAJOR BRANCHES for family($f)"

          foreach branch $family($f) {
            $lc.canvas create text $cnv_x $cnv_y -text "$branch" -tags {temporary} -fill green
            incr cnv_y $yspc
            $lc.canvas configure -scrollregion [list 0 0 $cnv_w $cnv_y]
            $lc.canvas yview moveto 1
            update

            gen_log:log D "========= $branch =========="
            if {$branch eq $fam_trunk($f)} {
              # sometimes we don't have raw_revs($fam_trunk($f)) if the file is added on branch,
              # but we should have guessed at a rootrev by now
              if {! [info exists raw_revs($fam_trunk($f))]} {
                set raw_revs($fam_trunk($f)) $rootrev
              }
              set branchrevs($f) [lreverse $raw_revs($fam_trunk($f))]
              set branchrevs($fam_trunk($f)) $branchrevs($f)
              set branchtip($fam_trunk($f)) [lindex $branchrevs($fam_trunk($f)) 0]
              set branchroot($fam_trunk($f)) [lindex $branchrevs($fam_trunk($f)) end]
              if {! [info exists rootrev]} {
                set rootrev $branchroot($fam_trunk($f))
                gen_log:log D "USING ROOT $rootrev"
              }
              # Move the trunk's tags from the tip to the base
              # But if there's only one rev, those are the same, so don't do it
              if {[info exists revbtags($branchroot($branch)] && $branch in $revbtags($branchroot($branch))} {
                gen_log:log D "$branch is already in $branchroot($branch)"
              } else {
                gen_log:log D "Adding $branch to revbtags for $branchroot($branch)"
                lappend revbtags($branchroot($branch)) $branch
              }
              if {$branchtip($branch) ne $branchroot($branch)} {
                if [info exists revbtags($branchtip($branch))] {
                  gen_log:log D " and removing it from tip"
                  set idx [lsearch $revbtags($branchtip($branch)) $branch]
                  set revbtags($branchtip($branch)) [lreplace $revbtags($branchtip($branch)) $idx $idx]
                }
              }
              gen_log:log D "BASE of trunk $branch is $branchroot($branch)"
              continue
            }

            # The root for a branch is the first one we get back that's only in the branch
            # and not in master
            if {[info exists raw_revs($branch)]} {
              set raw_revs($branch) [lreverse $raw_revs($branch)]
              # Here, we are establishing the first-level branches off the trunk
              compare_branches $branch $fam_trunk($f)
 
              set parent_ok 0
              set base $branchroot($branch)
              if {[info exists branchparent($branch)]} {
                gen_log:log D "Using branchparent($branch) $branchparent($branch)"
                set revparent($base) $branchparent($branch)
                set parent_ok 1
              }
              if {! $parent_ok} {
                # Was it merged from our root?
                # Just testing this, don't set parent_ok
                if {[info exists revmergefrom($base)]} {
                  set revparent($base) $revmergefrom($base)
                  gen_log:log D "$base was MERGED FROM $revparent($base)"
                }
              }
              # NOPE NOPE NOPE prevent recursion
              if {[info exists revparent($base)] && ($revparent($base) in $branchrevs($branch))} {
                gen_log:log D "PARENT $revparent($base) is in the revision list of $branch!"
                set parent_ok 0
              }
              if {! $parent_ok} {
                gen_log:log D "Ignoring branch $branch"
                catch {unset revparent($base)}
                # Withdraw this branch from the proceedings
                set idx [lsearch $family($f) $branch]
                set branches [lreplace $family($f) $idx $idx]
                continue
              }

              gen_log:log D " $branch: BASE $base PARENT $revparent($base)"
              # Sometimes we get back a parent that our log --all didn't pick
              # up. This may happen if the directory had checkins that didn't
              # affect the file or the file is newly added
              if {! [info exists revdate($revparent($base))] } {
                # Draw it differently because it may not be reachable
                set revpath($revparent($base)) $relpath
                set revstate($revparent($base)) "ghost"
              }

              # We got the parent settled one way or another
              # Add it to revbranches(parent)
              if {! [info exists revbranches($revparent($base))] || $branchroot($branch) ni $revbranches($revparent($base))} {
                lappend revbranches($revparent($base)) $branchroot($branch)
              }

              if {$branchtip($branch) ne $branchroot($branch)} {
                if [info exists revbtags($branchtip($branch))] {
                  gen_log:log D " and removing it from tip"
                  set idx [lsearch $revbtags($branchtip($branch)) $branch]
                  set revbtags($branchtip($branch)) [lreplace $revbtags($branchtip($branch)) $idx $idx]
                }
              }
            }
          }

          gen_log:log D "========================"
          # If two branches have the same root, one is likely
          # a sub-branch of the other. Let's see if we can disambiguate
          foreach t [array names branchroot] {
            if {$t eq $branch} continue
            if {! [info exists branchroot($branch)]} continue
            # Maybe we took it out in the first comparison
            if {$branch ni $family($f)} continue
            if {$branchroot($branch) eq $branchroot($t)} {
              #gen_log:log D "$branch and $t have the same root $branchroot($branch)"
              # Save the duplicates in a list to deal with next
              lappend branch_matches($branch) $t
            }
          }
          if {[info exists branch_matches]} {
            gen_log:log D "SORTING OUT SUB-BRANCHES for FAMILY $f"
          } else {
            gen_log:log D "NO SUB-BRANCHES FOUND for FAMILY $f"
          }

          # Now that we've got sets of matches, process each set
          foreach m [array names branch_matches] {
            set family_base($m) $branchroot($m)
            set peers [concat $m $branch_matches($m)]
            gen_log:log D "FAMILY $peers"
            set limit [llength $peers]
            for {set i 0} {$i < $limit} {incr i} {
              set j [expr {$i+1}]
              if {$j == $limit} {set j 0}
              set peer1 [lindex $peers $i]
              set peer2 [lindex $peers $j]
              # If the next one has been taken out for identity or something, skip it
              if {$peer2 ni $family($f)} continue
              compare_branches $peer1 $peer2
            }
          }
        }
        # Finished finding major branches
        gen_log:log D "========================"

        # Put back the identical branches
        foreach i [array names ident_matches] {
          gen_log:log D "$i IDENTICAL $ident_matches($i)"
          set first [lindex $ident_matches($i) 0]
          foreach next [lrange $ident_matches($i) 1 end] {
            if {! [info exists branchrevs($first)]} {
              gen_log:log E "branchrevs($first) doesn't exist!"
            }
            set branchrevs($next) $branchrevs($first)
            set branchroot($next) $branchroot($first)
            set branchtip($next) $branchtip($first)
            if {$next ni $revbtags($branchroot($first))} {
              lappend revbtags($branchroot($first)) $next
            }
          }
        }

        gen_log:log D "Deciding which family to draw"
        gen_log:log D "CURRENT BRANCH: $current_tagname"
        foreach ft [array names fam_trunk] {
          lappend trunks $fam_trunk($ft)
        }
        gen_log:log D "TRUNK(s) $trunks"
        set trunk_ok 0
        set idx [lsearch -regexp $trunks {master|.*/master}]
        if {$idx > -1} {
          set mstr [lindex $trunks $idx]
          gen_log:log D "Found $mstr in ($trunks)"
          set trunk $mstr
          set trunk_ok 1
        }
        if {! $trunk_ok} {
          foreach t $trunks {
            if {$t in $current_branches} {
              gen_log:log D "Found $t in Current branches"
              set trunk $t
              set trunk_ok 1
            }
          }
        }
        if {! $trunk_ok} {
          foreach t $trunks {
            if {$t eq $current_tagname} {
              gen_log:log D " Using current_tagname $current_tagname"
              set trunk $t
              set trunk_ok 1
            }
          }
        }
        if {! $trunk_ok} {
          gen_log:log D " Using first trunk in list"
          set trunk [lindex $trunks 0]
          set trunk_ok 1
        }
        if {! $trunk_ok} {
          cvsfail "Can't find a trunk for this file" $lc
        }
        foreach f [array names fam_trunk] {
          if {$fam_trunk($f) eq "$trunk"} {
            set rootrev $f
          }
        }
        if {$rootrev eq ""} {
          set rootrev $oldest_rev
        }
        set revkind($rootrev) "root"
        gen_log:log D "USING TRUNK $trunk (rootrev $rootrev)"
        # Little flourish here if we can do it. If the master arises from a merged
        # branch, and we might draw the branch, try to show the merge
        if {[info exists revparent($rootrev)] && $revparent($rootrev) ne ""} {
          set revmergefrom($rootrev) $revparent($rootrev)
        }

        # Make sure we know where we're rooted. Sometimes the initial parent detection went
        # one too far, which would put us on a different branch that's not visible from here.
        gen_log:log D "branchrevs($trunk) $branchrevs($trunk)"

        # Position the the You are Here icon and top up final variables
        gen_log:log D "Looking for current_revnum $current_revnum in branches"
        foreach branch $current_branches {
          if {$branchtip($branch) eq $current_revnum} {
            gen_log:log D "Currently at top of $branch"
            set branchrevs($branch) [linsert $branchrevs($branch) 0 {current}]
          } else {
            # But maybe we're not at the tip
            foreach r $branchrevs($branch) {
              if {$r == $current_revnum} {
                # We need to make a new artificial branch off of $r
                gen_log:log D "appending current to revbranches($r)"
                lappend revbranches($r) {current}
                set revbtags(current) {current}
              }
            }
          }
          if {[info exists branchroot($branch)]} {
            if {[info exists branchrevs($branch)]} {
              set branchrevs($branchroot($branch)) $branchrevs($branch)
            } else {
              gen_log:log D "branchrevs($branch) doesn't exist!"
            }
          } else {
            gen_log:log D "branchroot($branch) doesn't exist!"
          }
        }

        # This causes recursion
        foreach rb [array names revbranches] {
          #gen_log:log D "revbranches($rb)  $revbranches($rb)"
          foreach r $revbranches($rb) {
            foreach rb2 [array names revbranches] {
              if {$rb eq $rb2} continue
              if {$r in $revbranches($rb2)} {
                gen_log:log D "$r is in both $rb and $rb2"
                gen_log:log D " revbranches($rb) $revbranches($rb)"
                gen_log:log D " revbranches($rb2) $revbranches($rb2)"
                # Take it out of the longer one?
                if {[llength $revbranches($rb)] > [llength $revbranches($rb2)]} {
                  set idx [lsearch $revbranches($rb) $r]
                  set revbranches($rb) [lreplace $revbranches($rb) $idx $idx]
                } else {
                  set idx [lsearch $revbranches($rb2) $r]
                  set revbranches($rb2) [lreplace $revbranches($rb2) $idx $idx]
                }
              }
            }
          }
        }

        # We may have added a "current" branch. We have to set all its
        # stuff or we'll get errors
        foreach {revwho(current) revdate(current) revtime(current)
           revlines(current) revcomment(current)
           branchrevs(current) revbtags(current)}\
           {{} {} {} {} {} {} {}} \
           { break }

        pack forget $lc.stop
        pack $lc.close -in $lc.down.closefm -side right
        $lc.close configure -state normal

        [namespace current]::git_sort_it_all_out
        # Little pause before erasing the list of branches we temporarily drew
        after 500
        set new_x [$ln\::DrawTree now]

        # Draw unrooted branches
        gen_log:log D "ROOTREV $rootrev"
        gen_log:log D "ROOTREVS $rootrevs"
        set idx [lsearch $rootrevs $rootrev]
        set rootrevs [lreplace $rootrevs $idx $idx]

        set sidetree_x [expr {$new_x + 2}]
        foreach rv $rootrevs {
          if {[info exists revbtags($rv)]} {
            set broot [lindex $revbtags($rv) 0]
          } else {
            continue
          }
          gen_log:log D "UNROOTED branch $rv: $broot"
          catch {unset revkind}
          set revkind($broot) "root"
          gen_log:log D "revbtags($rv) $revbtags($rv)"
          set new_x [$ln\::DrawSideTree $sidetree_x 0 $rv]
          set sidetree_x [expr {$new_x + 2}]
        }

        gen_log:log T "LEAVE"
        return
      }
 
      proc parse_gitlog {lines} {
        global logcfg
        global cvsglb
        variable allrevs
        variable relpath
        variable revwho
        variable revdate
        variable revparent
        variable revpath
        variable revtime
        variable revcomment
        variable revtags
        variable revbtags
        variable revmergefrom
        variable revstate
        variable rootrev
        variable rootrevs

        gen_log:log T "ENTER (<...>)"
        set revnum ""
        set i 0
        set l [llength $lines]
        set last ""
        set logged_branches ""
        catch {unset allrevs}
        set rootrev ""
        set rootrevs ""

        while {$i < $l} {
          set line [lindex $lines $i]
          #gen_log:log D "$line"
          if { [ regexp {^\s*$} $last ] && [ string match {commit *} $line] } {
            # ^ the last line was empty and this one starts with commit

            # The commit line is complex. It can contain parents, tags, and branch tags.
            # It can look like this:
            # commit aad218525 3590769e6 (tag: tclpro-1-5-0, origin/tclpro-1-5-0-synthetic) 
            if {[expr {$l - $i}] < 0} {break}
            # ^ we came to the last line!

            set line [lindex $lines $i]
            set commits ""
            set parenthetical ""
            regexp {^commit ([\w\s]*)} $line nil commits
            regexp {^commit .*(\(.*\))} $line nil parenthetical
            set revnum [lindex $commits 0]
            lappend allrevs $revnum
            # If it's a merge, there's more than one parent. But for this, we only want
            # the first one
            set parentlist [lindex $commits 1]
            set parent [lindex $parentlist 0]
              set revparent($revnum) $parent
            if {$parent == ""} {
              set rootrev $revnum
              gen_log:log D "FOUND PARENTLESS ROOT $rootrev"
              lappend rootrevs $rootrev
            }
            #strip off the parentheses
            set in_parens [string range $parenthetical 1 end-1]
            set items [split $in_parens " "]
            set p 0
            while {$p < [llength $items]} {
              # First, see if there are tags and peel them off
              if {[lindex $items $p] eq "tag:"} {
                incr p
                lappend revtags($revnum) [string trimright [lindex $items $p] ","]
                incr p
              } else {
                # what's left are branches. This is the tip, not the root, usually
                set raw_btag [string trimright [lindex $items $p] ","]
                if {(! [regexp {HEAD} $raw_btag]) && ($raw_btag ne "->")} {
                  if {$cvsglb(lightning)} {
                    set revbtags($revnum) $raw_btag
                  } else {
                    lappend logged_branches $raw_btag
                  }
                }
                incr p
              }
            }
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
            incr i 3
            set line [lindex $lines $i]
            # Date:   2018-08-17 20:10:15 -0700
            if { [string match {CommitDate:*} $line] } {
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
          }
        }
        gen_log:log T "LEAVE ($logged_branches)"
        return $logged_branches
      }

      proc compare_branches {A B} {
        variable branchrevs
        variable branchroot
        variable branchtip
        variable branchparent
        variable raw_revs
        variable revbranches
        variable revbtags
        variable branch_matches
        variable family

        gen_log:log D " COMPARING $A VS $B"
        # For the main comparisons, we don't have branchrevs yet
        if {! [info exists branchrevs($A)]} {
          set branchrevs($A) $raw_revs($A)
        }
        #gen_log:log D " branchrevs($A) $branchrevs($A)"
        if {! [info exists branchrevs($B)]} {
          set branchrevs($B) $raw_revs($B)
        }
        #gen_log:log D " branchrevs($B) $branchrevs($B)"

        lassign [list_comm $branchrevs($B) $branchrevs($A)] inAonly inBonly inBoth
        gen_log:log D " == ONLY IN $A: $inBonly"
        gen_log:log D " == ONLY IN $B: $inAonly"
        if {$inBonly eq "IDENTICAL"} {
          gen_log:log D " BRANCHES $A and $B are IDENTICAL"
          set branchrevs($A) $branchrevs($B)
          set branchroot($A) $branchroot($B)
          set branchtip($branch) $branchtip($B)
          # Add its tag to the branchroot for the other
          foreach z [list $A $B] {
            if {$z ni $revbtags($branchroot($z))} {
              gen_log:log D "Adding $z to revbtags for ($branchroot($z))"
              lappend revbtags($branchroot($z)) $z
            }
          }
          gen_log:log D "Removing $A as an independent entity"
          set idx [lsearch $branch_matches($m) $A]
          set branch_matches($m) [lreplace $branch_matches($m) $idx $idx]
          set idx [lsearch $family($f) $branch]
          set family($f) [lreplace $family($f) $idx $idx]
          return
        }
        if {$inBonly ne {}} {
          set branchrevs($A) $inBonly
          set branchroot($A) [lindex $branchrevs($A) end]
          set branchtip($A) [lindex $branchrevs($A) 0]
          set new_base $branchroot($A)
          set branchrevs($new_base) $inBonly
          set fork [lindex $inBoth 0]
          if {$fork eq ""} {
            gen_log:log D " $A and $B are now non-overlapping"
            return
          }
          gen_log:log D " NEW PARENT $fork and BASE $new_base of $A"
          set branchparent($A) $fork
          set old_base [lindex $inBoth end]
          set revkind($new_base) "branch"
          # Move revbtags
          if {! [info exists revbtags($new_base)] || ($A ni $revbtags($new_base))} {
            gen_log:log D "Adding $A to revbtags($new_base)"
            lappend revbtags($new_base) $A
          }
          if [info exists revbtags($old_base)] {
            gen_log:log D " and removing it from old base $old_base"
            set idx [lsearch $revbtags($old_base) $A]
            set revbtags($old_base) [lreplace $revbtags($old_base) $idx $idx]
          }
          # Move revbranches
          if {! [info exists revbranches($fork)] || ($new_base ni $revbranches($fork))} {
            lappend revbranches($fork) $new_base
          }
        } elseif {$inAonly ne {} && ! [regexp $B {master|.*/master}]} {
          set branchrevs($B) $inAonly
          set branchroot($B) [lindex $branchrevs($B) end]
          set branchtip($B) [lindex $branchrevs($B) 0]
          set new_base $branchroot($B)
          set branchrevs($new_base) $inAonly
          set fork [lindex $inBoth 0]
          if {$fork eq ""} {
            gen_log:log D " $A and $B are now non-overlapping"
            return
          }
          gen_log:log D " NEW PARENT $fork and BASE $new_base of $B"
          set branchparent($B) $fork
          set old_base [lindex $inBoth end]
          set revkind($new_base) "branch"
          # Move revbtags
          if {! [info exists revbtags($new_base)] || ($A ni $revbtags($new_base))} {
            gen_log:log D "Adding $B to revbtags($new_base)"
            lappend revbtags($new_base) $B
          }
          if [info exists revbtags($old_base)] {
            gen_log:log D " and removing it from old base $old_base"
            set idx [lsearch $revbtags($old_base) $B]
            set revbtags($old_base) [lreplace $revbtags($old_base) $idx $idx]
          }
          # Move revbranches
          if {! [info exists revbranches($fork)] || ($new_base ni $revbranches($fork))} {
            lappend revbranches($fork) $new_base
          }
        } else {
          set fork [lindex $inBoth 0]
          set old_base [lindex $inBoth end]
          if {[info exists family($old_base)]} {
            set idx [lsearch $family($old_base) $A]
            set family($old_base) [lreplace $family($old_base) $idx $idx]
            gen_log:log D " removing $old_base from family($old_base)"
          }
        }
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
        variable revstate
        variable revmergefrom
        variable logstate
        variable revnum
        variable rootbranch
        variable revbranch
        variable rootrev
        variable rootrevs
        variable oldest_rev

        gen_log:log T "ENTER"

        # Sort the revision and branch lists and remove duplicates
        foreach r [lsort -dictionary [array names revkind]] {
          if {$revkind($r) eq "root"} {
            gen_log:log D "revkind($r) $revkind($r)"
          }
        }
        #foreach r [lsort -dictionary [array names revpath]] {
           #gen_log:log D "revpath($r) $revpath($r)"
        #}
        gen_log:log D ""
        foreach a [lsort -dictionary [array names revtags]] {
          gen_log:log D "revtags($a) $revtags($a)"
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names revbtags]] {
          gen_log:log D "revbtags($a) $revbtags($a)"
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names revbranches]] {
           gen_log:log D "revbranches($a) $revbranches($a)"
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names branchrevs]] {
           gen_log:log D "branchrevs($a) $branchrevs($a)"
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names revmergefrom]] {
          ## Only take one from the list that you might have here
          #set revmergefrom($a) [lindex $revmergefrom($a) end]
          gen_log:log D "revmergefrom($a) $revmergefrom($a)"
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names revstate]] {
          gen_log:log D "revstate($a) $revstate($a)"
        }
        # We only needed these to place the you-are-here box.
        catch {unset rootbranch revbranch}
        gen_log:log T "LEAVE"
      }

      [namespace current]::reloadLog
      return [namespace current]
    }

  }
}

# Expect two lists. We look for the second one inside the
# first one.
# Return the length of the matching part and the first
# item, if any, that's only in listB.
proc list_within_list {listA listB} {
  set lA [llength $listA]
  set lB [llength $listB]

  # The lists may not actually be the same, but we can
  # look for where B might start in A
  set firstB [lindex $listB 0]
  set idx [lsearch $listA $firstB]
  if {$idx > -1} {
    set listA [lrange $listA $idx end]
  }

  # Find shorter list, end there
  set n_items [expr {$listA < $listB} ? {$lA} : {$lB}]
  for {set i 0} {$i < $n_items} {incr i} {
    set iA [lindex $listA $i]
    set iB [lindex $listB $i]
    if {$iA ne $iB} {
      break
    }
  }
  return [list $idx $i]
}

# Expect two lists that are the same after some point.
# Collect the items that are different, and the first
# one that's the same
proc list_comm {listA listB} {
  gen_log:log T "listA: ([llength $listA]) $listA"
  gen_log:log T "listB: ([llength $listB]) $listB"

  set inA ""
  set inB ""
  set inBoth ""
  # Shortcut if lists are identical
  if { $listA == $listB } {
    set inA {}
    set inB {}
    set inBoth $listA
    #gen_log:log D "lists are IDENTICAL"
    return [list {IDENTICAL} $listA]
  } else {
    foreach B $listB {
      if {$B in $listA} {
        lappend inBoth $B
      } else {
        lappend inB $B
      }
    }
    foreach A $listA {
      if {$A ni $listB} {
        lappend inA $A
      }
    }
  }

  gen_log:log T "LEAVE A only: ([llength $inA]) $inA"
  gen_log:log T "LEAVE B only: ([llength $inB]) $inB"
  gen_log:log T "LEAVE in Both: ([llength $inBoth]) $inBoth"
  return [list $inA $inB $inBoth]
}

# We have both remote and local names of the same branch.
# For duplicated ones, keep only the local
proc prune_branchlist {branchlist} {
  gen_log:log T "ENTER ($branchlist)"

  set filtered_branchlist {}
  foreach r $branchlist {
    if {$r in $filtered_branchlist} {continue}
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
