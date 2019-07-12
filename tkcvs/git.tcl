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
      append flags " --graph --all --format=%h\\ \\ %<(12,trunc)%aN\\ %<(54,trunc)%s\\ %d"
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
  set commandline "git log --graph --all $cvscfg(gitlog_opts) --format=%h\\ \\ %<(12,trunc)%aN\\ %<(54,trunc)%s\\ %d"
  if {$rev ne ""} {
    append commandline " $rev"
    append title " $rev"
  }
  append commandline " \"$file\""
  append title " $file"

  set v [viewer::new "$title"]
  $v\::do "$commandline" 0
  $v\::width 120

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
      } else {
        set newlc [logcanvas::new $filename "GIT,loc" [namespace current]]
      }
      set ln [lindex $newlc 0]
      set lc [lindex $newlc 1]
      set show_tags [set $ln\::opt(show_tags)]

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
        variable allrevs
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
        variable revstate
        variable revtags
        variable revbtags
        variable revmergefrom
        variable rootrev
        variable oldest_rev
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

        # Gets all the commit information at once, including the branch, tag,
        # merge, and parent information Doesn't necessarily pick up all, or
        # any, of the locally reachable branches
        set command "git log --all -$cvscfg(gitmaxhist) --abbrev-commit --topo-order $cvscfg(gitlog_opts) --parents --date=iso --tags --decorate=short --no-color -- \"$filename\""
        set cmd_log [exec::new $command {} 0 {} 1]
        set log_output [$cmd_log\::output]
        $cmd_log\::destroy
        set log_lines [split $log_output "\n"]
        set logged_branches [parse_gitlog $log_lines]


        catch {unset log_output}
        catch {unset log_lines}
        catch {unset log_output}
        #set allrevs [lreverse $allrevs]
        gen_log:log D "[llength $allrevs] REVISIONS picked up by git log --all"
        set oldest_rev [lindex $allrevs end]
        gen_log:log D "OLDEST REV $oldest_rev"

        # Branches tend to come out of this in nearly reverse chronological order, which helps us
        if {$logged_branches != {}} {
          set logged_branches [prune_branchlist $logged_branches]
        }

        # This gets all the locally reachable branches. We only use all of them if asked.
        # But if "master" is in there, we want it, and also the order is helpful
        set cmd(git_branch) [exec::new "git branch --format=%(refname:short)"]
        set branch_lines [split [$cmd(git_branch)\::output] "\n"]
        # If we're in a detached head state, one of these can be like (HEAD detached at 9d24194)
        # but we can just filter it out
        foreach line $branch_lines {
          if {[string length $line] < 1} continue
          if {[regexp {detached} $line]} continue
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
        set logged_branches [lreverse $logged_branches]

        # We aren't necessarily interested in all the remote branches, but we
        # may want to know if master is one of them
        if { [regexp {R} $cvscfg(gitbranchgroups)] } {
          set cmd(git_rbranch) [exec::new "git branch -r --format=%(refname:short)"]
          set branch_lines [split [$cmd(git_rbranch)\::output] "\n"]
          foreach line $branch_lines {
            if {[string length $line] < 1} continue
            lappend remote_branches [lindex $line 0]
          }
          catch {unset branch_lines}
        }
        if {![info exists logged_branches]} { set logged_branches {} }
        if {![info exists local_branches]} { set local_branches {} }
        if {![info exists remote_branches]} { set remote_branches {} }
        gen_log:log D "File-log branches ([llength $logged_branches]):  $logged_branches"
        gen_log:log D "Local branches ([llength $local_branches]):      $local_branches"
        gen_log:log D "Remote branches ([llength $remote_branches]):    $remote_branches"

        # Collect and de-duplicate the branch list
        # The local branch list usually preserves the order the best. So 
        # we try to preserve that order when we blend them
        foreach locb $local_branches {
          # First, add the logged branches in the order in which they appear in local branches
          if {$locb in $logged_branches} {
            lappend branches $locb
          }
        }
        foreach logb $logged_branches {
          # Then add the logged branches that weren't in the local branches
          if {$logb ni $branches} {
            lappend branches $logb
          }
        }
        if { [regexp {L} $cvscfg(gitbranchgroups)] } {
          foreach logb $logged_branches {
            if {$logb ni $branches} {
              lappend branches $logb
            }
          }
        }
        if { [regexp {R} $cvscfg(gitbranchgroups)] } {
          foreach remb $remote_branches {
            lappend branches $remb
          }
        }
        set branches [lrange $branches 0 $cvscfg(gitmaxbranch)]
        set branches [prune_branchlist $branches]
        catch {unset logged_branches}
        catch {unset local_branches}
        gen_log:log D "Combined branches ([llength $branches]): $branches"

        # De-duplicate the tags, while we're thinking of it.
        foreach a [array names revtags] {
          if {[llength $revtags($a)] > 1} {
            set revtags($a) [prune_branchlist $revtags($a)]
          }
        }

        # This is necessary to reset the view after clearing the canvas
        $lc.canvas configure -scrollregion [list 0 0 $cnv_w $cnv_h]
        set cnv_y [expr {$cnv_y + $yspc}]
        set cnv_x [expr {$cnv_w / 2- 8}]
        $lc.canvas create text $cnv_x $cnv_y -text "Getting BRANCHES" -tags {temporary}
        incr cnv_y $yspc
        $lc.canvas configure -scrollregion [list 0 0 $cnv_w $cnv_y]
        $lc.canvas yview moveto 1
        update idletasks

        # We need to query each branch to know if it's empty, so we collect the revision
        # list while we're at it
        foreach br $branches {
          # Draw something on the canvas so the user knows we're working
          $lc.canvas create text $cnv_x $cnv_y -text $br -tags {temporary} -fill $cvscfg(colourB)
          incr cnv_y $yspc
          $lc.canvas configure -scrollregion [list 0 0 $cnv_w $cnv_y]
          $lc.canvas yview moveto 1
          update idletasks

          #set command "git rev-list -$cvscfg(gitmaxhist) --reverse --abbrev-commit $cvscfg(gitlog_opts) $oldest_rev^.. $br -- \"$filename\""
          set command "git rev-list -$cvscfg(gitmaxhist) --reverse --abbrev-commit $cvscfg(gitlog_opts) $br -- \"$filename\""
          set cmd_revlist [exec::new $command {} 0 {} 1]
          set revlist_output [$cmd_revlist\::output]
          $cmd_revlist\::destroy
          set revlist_lines [split $revlist_output "\n"]
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
            gen_log:log D "$br has [llength $raw_revs($br)] revisions"
            catch {unset revlist_lines}
          } else {
            gen_log:log D "branch $br is EMPTY"
            # If it's empty, remove this branch from the list
            set idx [lsearch $branches $br]
            set branches [lreplace $branches $idx $idx]
          }
        }
        gen_log:log D "Non-empty branches: $branches"

        # Decide what to use for the trunk. Consider only those branches
        # which contain the oldest revision.
        # Note: the oldest revision may not be in any named branch!
        set rooted_branches {}
        foreach b $branches {
          if {$oldest_rev in $raw_revs($b)} {
            gen_log:log D "Root $oldest_rev is in branch $b"
            lappend rooted_branches $b
          }
        }

        set trunk ""
        set trunk_found 0
        # If there's only one choice, don't waste time looking
        if {[llength $rooted_branches] == 1} {
           set trunk [lindex $branches 0]
           set trunk_found 1
           gen_log:log D "Only one long branch to begin with! That was easy! trunk=$trunk"
        }
        if {! $trunk_found} {
          # Do we have revisions on master?
          set m [lsearch -exact $rooted_branches {master}]
          if {$m > -1} {
            gen_log:log D "master is in rooted branches"
            set trunk "master"
            set trunk_found 1
          }
        }
        if {! $trunk_found} {
          # how about origin/master
          set m [lsearch -glob $rooted_branches {*/master}]
          if {$m > -1} {
            set match [lindex $branches $m]
            gen_log:log D "$match is in rooted_branches"
            set trunk $match
            set trunk_found 1
          }
        }
        if {! $trunk_found} {
          if {[llength $branches] > 0} {
            set trunk [lindex $rooted_branches 0]
            set trunk_found 1
            gen_log:log D "Using first branch as trunk"
          }
          set trunk_found 1
        }
        if {$trunk_found} {
          gen_log:log D "TRUNK: $trunk"
        } else {
          gen_log:log D "No named TRUNK found!"
          return
        }
        # Make sure the trunk is the first in the branchlist
        set idx [lsearch $branches $trunk]
        set branches [lreplace $branches $idx $idx]
        set branches [linsert $branches 0 $trunk]

        # Get rev lists for the branches
        catch {unset branch_matches}
        gen_log:log D "BRANCHES: $branches"
        # Draw something on the canvas so the user knows we're working
        $lc.canvas create text $cnv_x $cnv_y -text "Sorting out the BRANCHES" -tags {temporary} -fill green
        incr cnv_y $yspc
        $lc.canvas configure -scrollregion [list 0 0 $cnv_w $cnv_y]
        $lc.canvas yview moveto 1
        update idletasks

        set rootless_branches ""
        set empty_branches ""

        set rootrev $oldest_rev
        gen_log:log D "ROOT REV $rootrev"
        #set revkind($oldest_rev) "root"

        foreach branch $branches {
          $lc.canvas create text $cnv_x $cnv_y -text "$branch" -tags {temporary} -fill green
          incr cnv_y $yspc
          $lc.canvas configure -scrollregion [list 0 0 $cnv_w $cnv_y]
          $lc.canvas yview moveto 1
          update idletasks
          gen_log:log D "========= $branch =========="
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
            gen_log:log D "BASE of trunk $branch is $rootrev"
            continue
          }

          # The root of a branch is the first one we get back that's only in the branch
          # and not in master
          if {[info exists raw_revs($branch)]} {
            set raw_revs($branch) [lreverse $raw_revs($branch)]
            gen_log:log D "COMPARING $trunk VS $branch"
            lassign [list_comm $branchrevs($trunk) $raw_revs($branch)] inBonly inBoth
            if {$inBonly eq "IDENTICAL"} {
              gen_log:log D "BRANCHES $trunk and $branch are IDENTICAL"
              set branchrevs($branch) $branchrevs($trunk)
              set branchroot($branch) $branchroot($trunk)
              set branchtip($branch) $branchtip($trunk)
              foreach z [list $trunk $branch] {
                if {$z ni $revbtags($branchroot($z))} {
                  gen_log:log D "Adding $z to revbtags for ($branchroot($z))"
                  lappend revbtags($branchroot($z)) $z
                }
              }
              continue
            }
            gen_log:log D "== ONLY IN $branch =="
            if {[llength $inBonly] < 1} {
              # If it's empty, remove this branch from the list
              gen_log:log D "$branch is EMPTY"
              set idx [lsearch $branches $branch]
              set branches [lreplace $branches $idx $idx]
              lappend empty_branches $branch
              continue
            }
            foreach h $inBonly {
              #gen_log:log D "$h"
              set revkind($h) "revision"
            }
            set branchrevs($branch) $inBonly
            set base [lindex $inBonly end]
            gen_log:log D "branchrevs($branch) $branchrevs($branch)"
            gen_log:log D "BASE of $branch $base"
            set branchtip($branch) [lindex $branchrevs($branch) 0]
            set branchroot($branch) [lindex $branchrevs($branch) end]
            if {$base eq ""} {
              gen_log:log D "BASE not found for $branch"
              set base [lindex $inBoth 0]
              gen_log:log D "BASE of $branch $base"
            }

            set revkind($base) "branch"
            set parent_ok 0
            set fork [lindex $inBoth 0]
            if {$fork eq ""} {
              gen_log:log D  "$trunk and $branch are DISJUNCT"
            } else {
              set revparent($base) $fork
              gen_log:log D "Using end of inBoth $revparent($base) for PARENT of $branch"
              set parent_ok 1
            }
            if {! $parent_ok} {
              # Maybe we got a parent from the log
              if {[info exists revparent($base)]} {
                gen_log:log D "Using logged parent $revparent($base) for PARENT of $branch"
                set parent_ok 1
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
              set idx [lsearch $branches $branch]
              set branches [lreplace $branches $idx $idx]
              lappend rootless_branches $branch
              continue
            }

            gen_log:log D "$branch: BASE $base PARENT $revparent($base)"
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
            } else {
              # If two branches are identical, we only want to draw it once. The
              # header will show all the branchtags.
              gen_log:log D "$branchroot($branch) is already in revbranches($revparent($base))"
            }

            # Move the branch tags from the tip to the base
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
          }
        }
        gen_log:log D "Empty branches:    $empty_branches"
        gen_log:log D "Rootless branches: $rootless_branches"
        gen_log:log D "Drawn branches:    $branches"

if {1} {
        gen_log:log D "========================"
        gen_log:log D "SORTING OUT SUB-BRANCHES"
        # If two branches have the same root, one is likely
        # a sub-branch of the other. Let's see if we can disambiguate
        foreach t [array names branchroot] {
          if {$t eq $branch} continue
          if {! [info exists branchroot($branch)]} continue
          if {$branchroot($branch) eq $branchroot($t)} {
            gen_log:log D "$branch and $t have the same root $branchroot($branch)"
            # Save the duplicates in a list to deal with next
            lappend branch_matches($branch) $t
          }
        }
        # Now that we've got sets of matches, process each set
        foreach m [array names branch_matches] {
          set family_base($m) $branchroot($m)
          set peers [concat $m $branch_matches($m)]
          gen_log:log D "FAMILY $peers"
          #set list_of_lists ""
          #foreach n $peers {
            #lappend list_of_lists [list $n [lreverse $branchrevs($n)] ]
          #}
          #foreach o $list_of_lists {
             #gen_log:log D " $o"
          #}
          #gen_log:log D "SORTED"
          #foreach sorted [lsort -index 1 -command compare_nested_branches $list_of_lists] {
            #gen_log:log D " $sorted"
            #lappend ordered_peers [lindex $sorted 0]
          #}
          #set ordered_peers [lreverse $peers]
          #set ordered_peers $peers
          # Now we have them from tip-most to base-most, or something like it.  We proceed to compare
          # them in pairs, trimming their revlists and assigning their parents
          #gen_log:log D "ORDERED: $ordered_peers"
          set limit [llength $peers]
          for {set i 0} {$i < $limit} {incr i} {
            set j [expr {$i+1}]
            if {$j == $limit} {set j 0}
            set peer1 [lindex $peers $i]
            set peer2 [lindex $peers $j]
            gen_log:log D " COMPARING $peer1 VS $peer2"
            lassign [list_comm $branchrevs($peer2) $branchrevs($peer1)] inBonly inBoth
            gen_log:log D " == ONLY IN $peer1: $inBonly"
            if {$inBonly eq "IDENTICAL"} {
              gen_log:log D " BRANCHES $peer1 and $peer2 are IDENTICAL"
              set branchrevs($peer1) $branchrevs($peer2)
              set branchroot($peer1) $branchroot($peer2)
              set branchtip($branch) $branchtip($peer2)
              foreach z [list $peer1 $peer2] {
                if {$z ni $revbtags($branchroot($z))} {
                  gen_log:log D " Adding $z to revbtags for ($branchroot($z))"
                  lappend revbtags($branchroot($z)) $z
                }
              }
              continue
            }
            set branchrevs($peer1) $inBonly
            set branchroot($peer1) [lindex $branchrevs($peer1) end]
            set branchtip($peer1) [lindex $branchrevs($peer1) 0]
            set new_base $branchroot($peer1)
            set branchrevs($new_base) $inBonly
            set fork [lindex $inBoth 0]
            if {$fork eq ""} {
              gen_log:log D " $peer1 and $peer2 are now non-overlapping"
              continue
            }
            gen_log:log D " NEW PARENT $fork and BASE $new_base of $peer1"
            set old_base [lindex $inBoth end]
            set revkind($new_base) "branch"
            # Move revbtags
            if {! [info exists revbtags($new_base)] || ($peer1 ni $revbtags($new_base))} {
              gen_log:log D " Adding $peer1 to revbtags($new_base)"
              lappend revbtags($new_base) $peer1
            }
            if [info exists revbtags($old_base)] {
               gen_log:log D " and removing it from old base $old_base"
               set idx [lsearch $revbtags($old_base) $peer1]
               set revbtags($old_base) [lreplace $revbtags($old_base) $idx $idx]
            }
            # Move revbranches
            if {! [info exists revbranches($fork)] || ($new_base ni $revbranches($fork))} {
              gen_log:log D " Adding new BASE $new_base to PARENT revbranches($fork)"
              lappend revbranches($fork) $new_base
            }
          }
        }
        gen_log:log D "========================"
}

        gen_log:log D "CURRENT BRANCH: $current_tagname"
        gen_log:log D "TRUNK $trunk"
        # Make sure we know where we're rooted. Sometimes the initial parent detection went
        # one too far, which would put us on a different branch that's not visible from here.
        set root_ok 0
        if {[info exists rootrev] && $rootrev != "" && [info exists branchrevs($trunk)]} {
          gen_log:log D "rootrev = $rootrev"
          gen_log:log D "branchrevs($trunk) $branchrevs($trunk)"
          if {! [info exists revbtags($rootrev)]} {
            gen_log:log D "No revbtags($rootrev)!"
          }

          # If we have children for this, it's a perfectly good root
          if {[info exists revchildren($rootrev)]} {
            gen_log:log D "revchildren($rootrev) $revchildren($rootrev)"
            # But we may have to move the tag
            foreach a [array names revbtags] {
              if {$a eq $trunk} {continue}
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
                gen_log:log D "appending current to revbranches($r)"
                lappend revbranches($r) {current}
                set revbtags(current) {current}
              }
            }
          }
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

        gen_log:log D "Rootless branches: $rootless_branches"
        foreach rb $rootless_branches {
          gen_log:log D " $rb $branchrevs($rb)"
          #gen_log:log D " BASE $branchroot($rb)"
          if {! [info exists branchrevs($branchroot($rb))]} {
            set branchrevs($branchroot($rb)) $branchrevs($rb)
          }
        }
        # We may have added a "current" branch. We have to set all its
        # stuff or we'll get errors
        foreach {revwho(current) revdate(current) revtime(current)
           revlines(current) revcomment(current)
           branchrevs(current) revbtags(current)}\
           {{} {} {} {} {} {} {}} \
           { break }

        # Make sure we have a root. We're doing this last in case
        # revkind($rootrev) got overwritten
        set revkind($rootrev) "root"

        pack forget $lc.stop
        pack $lc.close -in $lc.down.closefm -side right
        $lc.close configure -state normal

        [namespace current]::git_sort_it_all_out
        # Little pause before erasing the list of branches we temporarily drew
        after 500
        $ln\::DrawTree now
        set sidetree_x 100
        #if {$rootrev ne $oldest_rev} {
          #gen_log:log D "UNROOTED branch: $oldest_rev"
          #set revkind($oldest_rev) "root"
          #$ln\::DrawSideTree $sidetree_x -18 $oldest_rev
          #incr sidetree_x 100
        #}
        foreach rb $rootless_branches {
          set broot $branchroot($rb)
          gen_log:log D "UNROOTED branch $rb: $broot"
          #set revkind($broot) "root"
          #lappend revbtags($broot) $rb
          #gen_log:log D "revbtags($broot) $revbtags($broot)"
          #$ln\::DrawSideTree $sidetree_x 0 $broot
          #incr sidetree_x 100
        }
        #foreach rl [array names family_base] {
        #  set newroot $family_base($rl)
        #  gen_log:log D "family_base($rl) $newroot"
        #  gen_log:log D "Adding UNROOTED branch: $newroot"
        #  set revkind($newroot) "root"
        #  $ln\::DrawSideTree $sidetree_x 18 $newroot
        #  incr sidetree_x 100
        #}

        gen_log:log T "LEAVE"
        return
      }
 
      proc parse_gitlog {lines} {
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

        gen_log:log T "ENTER (<...>)"
        set revnum ""
        set i 0
        set l [llength $lines]
        set last ""
        set logged_branches ""
        catch {unset allrevs}

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
              gen_log:log D "FOUND (unequivocal?) ROOT $rootrev"
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
                  lappend logged_branches $raw_btag
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
            if {$revparent($revnum) == ""} {
              gen_log:log D "FOUND A PARENTLESS ROOT. QUITTING HERE."
              return $logged_branches
            }
          }
        }
        gen_log:log T "LEAVE ($logged_branches)"
        return $logged_branches
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
        gen_log:log T "ENTER ($base)"
        if {$base == ""} {
          cvsfail "Null argument not allowed"
        }
        set command "git log -n 1 --format=%p $base"
        set cmd_log [exec::new $command {} 0 {} 1]
        set log_output [$cmd_log\::output]
        $cmd_log\::destroy
        set parent [string trim $log_output]

        # If it's a merge, there can be more than one. Take the first one
        set parent [lindex $parent 0]
        gen_log:log T "LEAVE ($parent)"
        return $parent
      }

      proc find_branch_creation {branch} {
        gen_log:log T "ENTER ($branch)"

        # Multi-line output where the bottom line is something like
        # 02d2c75 branchA@{1561320283}: clone: from /Users/dorothyr/teststuff/git_test_master
        # or
        # f2a69c2 branchAA@{1561320286}: branch: Created from HEAD
        set command "git reflog show --date=unix --no-decorate $branch"
        set cmd_reflog [exec::new $command {} 0 {} 1]
        set reflog_lines [split [$cmd_reflog\::output] "\n"]
        $cmd_reflog\::destroy
        set final_line [lindex $reflog_lines end-1]
        catch {unset reflog_lines}
        gen_log:log D $final_line
        set timestamp 0
        # We're interested in what's inside the brackets
        if {[regexp {\{.*?\}} $final_line bracketed]} {
          #strip off the brackets
          set timestamp [string range $bracketed 1 end-1]
          gen_log:log D "timestamp $timestamp"
        }
        gen_log:log T "LEAVE ($timestamp)"
        return $timestamp
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
        variable oldest_rev

        gen_log:log T "ENTER"

        # Sort the revision and branch lists and remove duplicates
        #foreach r [lsort -dictionary [array names revkind]] {
          #gen_log:log D "revkind($r) $revkind($r)"
        #}
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
          foreach t $revbtags($a) {
            if {$t ne ""} {lappend btags $t}
          }
        }
        gen_log:log D ""
        foreach a $btags {
          gen_log:log D "branchrevs($a) $branchrevs($a)"
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names revbranches]] {
           gen_log:log D "revbranches($a) $revbranches($a)"
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

# Sort lists which may be the same for several items
# Return -1 if a<b, 0 if a=b, and 1 if a>b
proc compare_nested_branches {listA listB} {
  gen_log:log T "listA: ([llength $listA]) $listA"
  gen_log:log T "listB: ([llength $listB]) $listB"

  # Shortcut if lists are identical
  if { $listA == $listB } {
    return 0
  }

  lassign [list_comm [lreverse $listA] [lreverse $listB]] inBonly inBoth
  lassign [list_comm [lreverse $listB] [lreverse $listA]] inAonly inBoth

  if {$inBonly > $inAonly} {
    return -1
  } elseif {$inAonly > $inBonly} {
    return 1
  } else {
    return 0
  }
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
    gen_log:log D "lists are IDENTICAL"
    return [list {IDENTICAL} $listA]
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
  #gen_log:log D "in listB only: $inB"
  #gen_log:log D "in Both:   $inBoth"

  gen_log:log T "LEAVE B only: ([llength $inB]) $inB"
  gen_log:log T "LEAVE in Both: ([llength $inBoth]) $inBoth"
  return [list $inB $inBoth]
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
