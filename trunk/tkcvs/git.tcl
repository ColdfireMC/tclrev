# Find where we are in path
proc read_git_dir {dirname} {
  global cvsglb

  # What's the top level, and where are we relative to it?
  set cmd(find_top) [exec::new "git rev-parse --show-toplevel"]
  set repos_top [lindex [$cmd(find_top)\::output] 0]
  set wd [pwd]
  set l [string length $repos_top]
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
    gen_log:log D "TRIMMED $status $f"
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
      if {![file isdirectory $f]} {
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
      } else {
        set command "git log -n 1 --no-color -- \"$f\""
        set cmd(dircheck) [exec::new "$command"]
        set len [$cmd(dircheck)\::output]
        $cmd(dircheck)\::destroy
        if {$len > 0} {
          set Filelist($f:status) "<directory:GIT>"
        } else {
          set Filelist($f:status) "<directory>"
        }
        gen_log:log D "$Filelist($f:status)"
      }
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
proc parse_gitlist {tf gitroot} {
  global cvsglb
  global modval 
  global modtitle

  gen_log:log T "ENTER ($tf $gitroot)"
  # Clear the arrays
  catch {unset modval}
  catch {unset modtitle}

  set command "git ls-remote \"$cvsglb(root)\""
  gen_log:log C "$command"
  set rem_cmd [exec::new $command]
  set remote_output [$rem_cmd\::output]

  foreach line [split $remote_output "\n"] {
    gen_log:log F "$line"
    if  {$line eq ""} {continue}
    set dname [lindex $line 1] 
    gen_log:log D "dname=$dname"
    # This is the hash
    set modval($dname) [lindex $line 0] 
    gen_log:log D "modval($dname)=$modval($dname)"
    #set modtitle($dname) $dname
    #gen_log:log D "modtitle($dname)=$modtitle($dname)"
    ModList:newitem $tf $dname $modval($dname)
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
      append flags " --graph --all --oneline"
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
    #set command "git log --color $flags -- \"$file\""
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
  # --full-history causes merges to be shown
  set commandline "git log --graph --all --oneline --no-color"
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
  set flags ""
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

        gen_log:log D "  $cmd_log\::abort"
        catch {$cmd_log\::abort}
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
        variable branchparent
        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable revkind
        variable revparent
        variable revpath
        variable revname
        variable revtags
        variable revbtags
        variable revmergefrom
        variable rootrev
        variable branchrevs
        variable revbranches
        variable logstate
        variable relpath
        variable filename
        variable show_branch_a
        variable show_tags
        variable show_merges

        gen_log:log T "ENTER"
        catch { $lc.canvas delete all }
        catch { unset revwho }
        catch { unset revdate }
        catch { unset revtime }
        catch { unset revcomment }
        catch { unset revtags }
        catch { unset revbtags }
        catch { unset revmergefrom }
        catch { unset branchrevs }
        catch { unset branchroot }
        catch { unset revbranches }
        catch { unset revkind }
        catch { unset revpath }
        catch { unset revname }
        catch { unset revparent }

        pack forget $lc.close
        pack $lc.stop -in $lc.down.closefm -side right
        $lc.stop configure -state normal

        # gets sys, loc, revnum_current
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

        set path $relpath

        # This will be used to place the You are Here icon
        set revnum_current [set $ln\::revnum_current]
        gen_log:log D "revnum_current: $revnum_current"

        # Get a list of the branches from the repository.
        # This gives you the local branches
        set branches {}
        lappend branches $current_tagname

        # Quick scan for branches and tags. topo-order lists sub-branches before branches I think
        set command "git log --all --first-parent --topo-order -$cvscfg(gitmaxhist) --format=%h:%p:%d -- \"$filename\""
        set branches_log [exec::new $command {} 0 {} 1]
        set log_output [$branches_log\::output]
        $branches_log\::destroy
        set log_lines [split $log_output "\n"]
        # Line could look like this:
        # 8fafe27142ae (tag: tag_1, tag: tag_3, branchA)
        catch {unset allrevs}
        foreach logline $log_lines {
          set splits [split $logline ':']
          set h [lindex $splits 0]
          set p [lindex $splits 1]
          if {$h != ""} {
            lappend allrevs $h
            set revparent($h) $p
            set revpath($h) $path
            gen_log:log D "revparent($h) $p"
            if {$p == ""} {
              set rootrev $h
              set revkind($h) "root"
            }
          }
          catch unset tags
          catch unset branches
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
                  gen_log:log D "Provisionally assigning $raw_btag to revbtags($h)"
                  lappend revbtags($h) $raw_btag
                }
                incr i
              }
            }
          }
        }

        # Decide on a root revision. We may have gotten it from above, or not.
        if {! [info exists rootrev] } {
          gen_log:log D "NO ROOT REVISION"
          set rootrev [lindex $allrevs end]
          gen_log:log D "setting it to $rootrev"
        }
        gen_log:log D "[llength $allrevs] revisions found"
        catch {unset allrevs}
        gen_log:log D "rootrev = $rootrev"

        # Collect and distill the branch list
        foreach a [array names revbtags] {
          set branches [concat $revbtags($a) $branches]
        }
        set branches [concat $current_tagname $branches]
        gen_log:log D "preliminary branches: $branches"
        # Filter out branches listed in two forms. If there's a locally visible
        # branch we prefer it because it may have changes that haven't been
        # pushed to remote
        set branches [prune_branchlist $branches]
        gen_log:log D "final branches: $branches"

        # Distill the branch tags, while we're thinking of it. This can still
        # leave anomalies.
        foreach a [array names revbtags] {
          set revbtags($a) [prune_branchlist $revbtags($a)]
        }

        # Get all the author, date, comment, etc data at once.  Order doesn't
        # matter here.  --full-history causes merges to be shown
        set command "git log --all -$cvscfg(gitmaxhist) --remove-empty --first-parent --full-history --abbrev-commit --date=iso --no-color -- \"$filename\""
        set cmd_log [exec::new $command {} 0 {} 1]
        set log_output [$cmd_log\::output]
        $cmd_log\::destroy
        set log_lines [split $log_output "\n"]
        parse_gitlog $log_lines

        # "master" may or may not be in our list of branches. If it is, we'll
        # use it as trunk as a first guess, though we may have to change it
        set trunk_found 0
        if { "master" in $branches } {
          set trunk "master"
          set trunk_found 1
          gen_log:log D "master is reachable locally, trunk=$trunk"
        }
        if {! $trunk_found} {
          set m [lsearch -glob $branches {*/master}]
          if {$m > -1} {
            set trunk [lindex $branches $m]
            gen_log:log D "remote master is in branches, trunk=$trunk"
            set trunk_found 1
          }
        }
        if {! $trunk_found} {
          # "master" wasn't in our list, but maybe we can reach it
          set command "git branch -r"
          set cmd_brn [exec::new $command {} 0 {} 1]
          set brn_output [$cmd_brn\::output]
          $cmd_brn\::destroy
          set brn_lines [split $brn_output "\n"]
          set m [lsearch -glob $brn_lines {*/master}]
          if {$m > -1} {
            set trunk [string trim [lindex $brn_lines $m]]
            gen_log:log D "remote master is ireachable, trunk=$trunk"
            # Put it in our branch list
            set branches [concat $trunk $branches]
            set trunk_found 1
          }
        }
        if {! $trunk_found} {
          # Give up and use the current branch
          set trunk $current_tagname
          gen_log:log D "Using current branch for trunk=$trunk"
        }

        # Get rev lists for the branches
        catch {unset branch_matches}
        foreach branch $branches {
          gen_log:log D "========= $branch =========="
          set command "git rev-list --reverse --abbrev-commit --first-parent $branch -- \"$filename\""
          set cmd_revlist [exec::new $command {} 0 {} 1]
          set revlist_output [$cmd_revlist\::output]
          $cmd_revlist\::destroy
          foreach ro [split $revlist_output "\n"] {
            if {[string length $ro] > 0} {
               lappend raw_revs($branch) $ro
               set revkind($ro) "revision"
            }
          }
          # For trunk, all the revs go into the list. It's the list the branches are
          # compared to
          if {$branch eq $trunk} {
            set branchrevs(trunk) [lreverse $raw_revs($trunk)]
            set branchroot($trunk) [lindex $branchrevs(trunk) end]
            continue
          }
          
          # The root of a branch is the first one we get back that's only in the branch
          # and not in master
          if {[info exists raw_revs($branch)]} {
            gen_log:log D "COMPARING trunk (listA) vs $branch (listB)"
            set inBonly [list_comm $branchrevs(trunk) $raw_revs($branch)]
            gen_log:log D "== ONLY IN $branch =="
            foreach h $inBonly {
              gen_log:log D " $h"
              set revkind($h) "revision"
            }
            set base [lindex $inBonly 0]
            set branchrevs($branch) [lreverse $inBonly]
            set branchtip($branch) [lindex $branchrevs($branch) 0]
            set branchroot($branch) [lindex $branchrevs($branch) end]
            if {$base != ""} {
              set revkind($base) "branch"
              set parent $revparent($base)
              # Sometimes we get back a parent that our log --all didn't pick
              # up. This may happen if the directory had checkins that didn't
              # affect the file.
              set parent [check_reparent $parent]
              gen_log:log D "$branch: BASE $base PARENT $parent"
              lappend revbranches($parent) $base
            } else {
              gen_log:log D "BASE not found for $branch"
            }
            # Move the branch tags from the tip to the base
            if {$branchtip($branch) != ""} {
              if {[info exists revbtags($branchtip($branch))]} {
                set revbtags($base) $revbtags($branchtip($branch))
                catch {unset revbtags($branchrevtip($branch))}
              } else {
                gen_log:log D "revbtags($branchtip($branch)) not found"
              }
            } else {
              gen_log:log D "TIP not found for $branch"
            }
          }

          # If two branches have the same root, it's a problem. One is likely
          # to be a subbranch of the other. Let's see if we can disambiguate
          # But since we did topo-order, most likely we'll see the subbranch
          # before the branch in the list.  Can we rely on this?
          foreach t [array names branchroot] {
            if {$t eq $branch} continue
            if {$branchroot($branch) eq $branchroot($t)} {
              #gen_log:log D " BRANCHES $t and $branch have the same root"
              # Save the duplicates in a list to deal with next
              lappend branch_matches($branch) $t
            }
          }
        }

        # Here's where we deal with the branch/sub-branch confusions
        # There should be only one because we take care of each as it appears, right?
        # so the foreach is unnecessary?
        foreach a [array names branch_matches] {
          set super_a $branch_matches($a)
          gen_log:log D "BRANCHES $a and $super_a have the same root"
          gen_log:log D "COMPARING branchrevs($super_a)  vs  branchrevs($a)"
          set old_branchroot [lindex $branchrevs($super_a) end]
          set old_branchparent $revparent($old_branchroot)
          gen_log:log D "OLD $a revlist: $branchrevs($a)"
          gen_log:log D "OLD $a root: $old_branchroot"
          gen_log:log D "OLD $a parent: $old_branchparent"
          set branchrevs($a) [list_comm $branchrevs($super_a) $branchrevs($a)]
          # The parent we found may not actually exist in our data. Backtrack to one that does
          set old_branchparent [check_reparent $old_branchparent]
          # This list will have a duplicate in it because it contains the root of both our branches
          gen_log:log D "OLD parents branchlist before fixing:  $revbranches($old_branchparent)"
          set idx [lsearch $revbranches($old_branchparent) $old_branchroot]
          set revbranches($old_branchparent) [lreplace $revbranches($old_branchparent) $idx $idx]
          # Reset the sub-branch revlist, root, and parent
          set branchroot($a) [lindex $branchrevs($a) end]
          set new_branchparent $revparent($branchroot($a))
          gen_log:log D "NEW $a revlist: $branchrevs($a)"
          gen_log:log D "NEW $a parent: $new_branchparent"
          gen_log:log D "NEW $a root: $branchroot($a)"
          # The original parent could conceivably be something that we don't have data for
          if [info exists revbranches($new_branchparent)] {
            gen_log:log D "NEW parents branchlist before fixing:  $revbranches($new_branchparent)"
          } else {
            gen_log:log D "NEW parents branchlist doesn't exist yet"
          }
          lappend revbranches($new_branchparent) $branchroot($a)
          gen_log:log D "NEW parents branchlist after fixing:  $revbranches($new_branchparent)"
          lappend revbtags($branchroot($a)) $a
          gen_log:log D "branchroot($a) $branchroot($a)"
          gen_log:log D "revbtags($branchroot($a)) $revbtags($branchroot($a))"
          # Now we have to get it out of its old parent's revbranches list and into
          # its new parent's one
          # The original branch's root and parent are unchanged but it needs revbtag
          lappend revbtags($branchroot($super_a)) $super_a
          gen_log:log D "ORIG branchrevs($super_a): $branchrevs($super_a)"
          gen_log:log D "branchroot($super_a) $branchroot($super_a)"
          gen_log:log D "revbtags($branchroot($super_a)) $revbtags($branchroot($super_a))"
        }

        # Make sure we know where we're rooted
        if {[info exists rootrev] && $rootrev != "" && [info exists branchrevs(trunk)]} {
          gen_log:log D "rootrev = $rootrev"
          set branchrevs($rootrev) $branchrevs(trunk)
          gen_log:log D "branchrevs(trunk) $branchrevs(trunk)"
          set revkind($rootrev) "root"
          set revname($rootrev) "$current_tagname"
          # revbtags is for DrawTree
          set revbtags($rootrev) $trunk
        } else {
          cvsfail "Can't read trunk revisions for this file" $lc
        }

        # if root is not empty added it to the branchlist
        if { $rootrev ne "" } {
          lappend branchlist $rootrev
        }

        #saved till last, copy branch revlist array to non-symbolic name
        foreach branch $branches {
          if {$branch eq $trunk} continue
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

        pack forget $lc.stop
        pack $lc.close -in $lc.down.closefm -side right
        $lc.close configure -state normal

        [namespace current]::git_sort_it_all_out
        gen_log:log T "LEAVE"
        return
      }

      proc parse_gitlog {lines} {
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
          gen_log:log D "$line"
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
            # Author: dorothyr <dorothyr@tadg>
            if { [string match {Author:*} $line] } {
              set revwho($revnum) [lindex $line 1]
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
                append revcomment($revnum) $commentline
                #append revcomment($revnum) "\n"
              }
              set i [expr {$c - 1}]
            }
            incr i
            set revpath($revnum) $revpath($rootrev)

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
        variable show_branch_a

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

      # We may have got a ref as a parent, which we don't have stats for in the log
      # because it didn't affect the file in question. Go back to a parent that we
      # do have, rather than trying to get the stats and find where to insert it in
      # the reflist
      proc check_reparent {mysteryref} {
        variable revparent
        variable revcomment
  
        gen_log:log T "ENTER ($mysteryref)"
        set parent $mysteryref
        set n 0
        while {! [info exists revcomment($parent)] && ($n < 100) } {
          set command "git log -n 1 --format=%p $parent"
          set cmd_parent [exec::new $command {} 0 {} 1]
          set parent_output [$cmd_parent\::output]
          set grandparent [string trim $parent_output "\n"]
          #gen_log:log D "$mysteryref GRANDPARENT $grandparent"
          gen_log:log D "$mysteryref GRANDPARENT $grandparent"
          set parent $grandparent
          incr n
        }
        # How long should we try?
        if {$n >= 50} {
          gen_log:log D "Gave up finding new parent for $mysteryref"
          gen_log:log D "Gave up finding new parent for $mysteryref"
          set parent $mysteryref
        }
        gen_log:log T "LEAVE ($parent)"
        return $parent
      }

      proc git_sort_it_all_out {} {
        global cvscfg
        global current_tagname
        variable filename
        variable lc
        variable ln
        variable branchparent
        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable revkind
        variable revpath
        variable revname
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
  gen_log:log D "in B only: $inB"
  gen_log:log D "in Both:   $inBoth"

  #return [list $inA $inB $inBoth]
  return $inB
}

# We have both remote and local names of the same branch.
# For duplicated ones, keep only the local
proc prune_branchlist {branchlist} {
  gen_log:log T "ENTER (branchlist)"

  set filtered_branchlist {}
  foreach r $branchlist {
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
