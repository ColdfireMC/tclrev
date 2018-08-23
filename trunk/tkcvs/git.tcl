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
  set cmd(git_branch) [exec::new "git branch"]
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
    set status [string range $statline 0 1]
    set f [lindex $statline 1]
    if {[regexp {/} $f]} {
      #set dir [lindex [file split $f] 0]
      #set Filelist($dir:status) "<directory:GIT>"
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

  set globfiles [glob -nocomplain *]
  set allfiles [lsort -unique -dictionary [concat $statfiles $globfiles]]
  foreach f $allfiles {
    # --porcelain=1 out: XY <filename>, where X is the modification state of the index
    #   and Y is the state of the work tree.  ' ' = unmodified.
    # --porcelain=2 out has an extra interger field before the status and 6 extra
    # fields before the filename.
    # XY, now the second field, has "." for unmodified.
    if {![file isdirectory $f]} {
      set good_line ""
      # Format: short hash, commit time, committer
      set command "git log -n 1 --pretty=format:\"%h|%ct|%cn\" -- \"$f\""
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
      set command "git log -n 1 -- \"$f\""
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

# Called from "Log" in Reports menu
proc git_log {detail args} {
 global cvscfg
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

  set commandline "git log --color"
  switch -- $detail {
    latest {
      append flags " --pretty=oneline --max-count=1"
    }
    summary {
      append flags " --pretty=oneline"
    }
    verbose {
      append flags " --graph --all"
    }
  }

  set v [viewer::new "$title"]
  foreach file $filelist {
    set command "git log $flags -- \"$file\""
    $v\::log "----------------------------------------\n"
    $v\::log "$file\n"
    $v\::do "$command" 1 ansi_colortags
    $v\::wait
  }

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

# called by "Status" in the Reports menu. Uses status_filter.
proc git_status {detail args} {
  global cvscfg
 
  gen_log:log T "ENTER ($detail $args)"

  busy_start .workdir.main
  set filelist [join $args]
  set flags ""
  set title "GIT Status ($detail)"
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
  # enable some color highlighting
  set stat_cmd [viewer::new $title]
  set commandline "git status $flags $filelist"
  $stat_cmd\::do "$commandline" 0 ansi_colortags

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
  $check_cmd\::do "$command" 0 ansi_colortags

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
    set v [viewer::new "GIT Commit"]
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

      # Implementation of Perl-like "grep {/re/} in_list"
      proc grep_filter { re in_list } {
        set res ""
        foreach x $in_list {
          if {[regexp $re $x]} {
            lappend res $x
          }
        }
        return $res
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
        variable filename
        variable cmd_log
        variable lc
        variable ln
        variable allrevs
        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable revkind
        variable revpath
        variable revname
        variable revtags
        variable revbtags
        variable revmergefrom
        variable branchrevs
        variable allrevs
        variable revbranches
        variable logstate
        variable relpath
        variable filename
        variable show_tags
        variable show_merges

        gen_log:log T "ENTER"
        catch { $lc.canvas delete all }
        catch { unset allrevs }
        catch { unset revwho }
        catch { unset revdate }
        catch { unset revtime }
        catch { unset revcomment }
        catch { unset revtags }
        catch { unset revbtags }
        catch { unset revmergefrom }
        catch { unset branchrevs }
        catch { unset revbranches }
        catch { unset revkind }
        catch { unset revpath }
        catch { unset revname }

        pack forget $lc.close
        pack $lc.stop -in $lc.down.closefm -side right
        $lc.stop configure -state normal

        # gets sys, loc, revnum_current
        $ln\::ConfigureButtons $filename

        #set show_merges [set $ln\::opt(show_merges)]
        #set show_tags [set $ln\::opt(show_tags)]
        set show_merges 0
        set show_tags 0

        set path $relpath

        # Find out where to put the working revision icon (if anywhere)
        set revnum_current [set $ln\::revnum_current]
        #set highest_revision $revnum_current

        # Get a list of the branches from the repository
        set command "git branch --format=\'%(refname:short)\'"
        set cmd_branch [exec::new $command {} 0 {} 1]
        set branch_output [$cmd_branch\::output]
        $cmd_branch\::destroy
        set blines [split $branch_output "\n"]
        foreach bl $blines {
          if {[string length $bl] > 0} {
            lappend branches [string trim $bl "'"]
          }
        }
        gen_log:log D "branches: $branches"

        # Get all the date, comment, etc data at once. In Git it's not so
        # useful to do a branch at a time
        set command "git log --all --abbrev-commit --date=iso --no-color -- \"$filename\""
        set cmd_log [exec::new $command {} 0 {} 1]
        set log_output [$cmd_log\::output]
        $cmd_log\::destroy
        set log_lines [split $log_output "\n"]
        set log_data [parse_gitlog $log_lines]

        # Trick to find the base of a branch is to list all the revs in the
        # branch and in its parent, and exclude those that aren't exclusive
        # to that branch.

        # First make a list of all the revision hashes
        set command "git rev-list --all --abbrev-commit --no-merges --reverse --topo-order origin/master -- $filename"
        set cmd_revlist [exec::new $command {} 0 {} 1]
        set revlist_output [$cmd_revlist\::output]
        $cmd_revlist\::destroy
        foreach ro [split $revlist_output "\n"] {
          if {[string length $ro] > 0} {
            lappend allrevs $ro
          }
        }
        # Compare this list with the branches, including master
        foreach branch $branches {
          set branchrevs($branch) [isolate_branchrevs $branch $filename]
        }

        # See if the current revision is on the trunk
        set curr 0
        set brevs $branchrevs(trunk)
        set tip [lindex $brevs 0]
        set revpath($tip) $path
        set revkind($tip) "revision"
        set brevs [lreplace $brevs 0 0]
        if {$tip == $revnum_current} {
          # If current is at end of trunk do this.
          set branchrevs(trunk) [linsert $branchrevs(trunk) 0 {current}]
          set curr 1
        }
        foreach r $brevs {
          if {$r == $revnum_current} {
            # We need to make a new artificial branch off of $r
            lappend revbranches($r) {current}
          }
          gen_log:log D " $r $revdate($r) ($revcomment($r))"
          set revkind($r) "revision"
          set revpath($r) $path
        }
        set branchrevs($rr) $branchrevs(trunk)
        set revkind($rr) "root"
        set revname($rr) "trunk"
        set revbtags($rr) "trunk"
        set revpath($rr) $path

        # if root is not empty added it to the branchlist
        if { $rr ne "" } {
          lappend branchlist $rr
        }
        if {$branch eq "master"} {continue}
        gen_log:log D "$branch"
        set branch [string trimright $branch "/"]

        gen_log:log T "LEAVE"
        return
      }

      proc parse_gitlog {lines} {
        variable revwho
        variable revdate
        variable revtime
        variable revcomment

        gen_log:log T "ENTER (<...>)"
        set revnum ""
        set i 0
        set l [llength $lines]
        set last ""
        while {$i < $l} {
          set line [lindex $lines $i]
          gen_log:log D "$i of $l:  $line"
          if { [ regexp {^\s*$} $last ] && [ string match {commit *} $line] } {
            # ^ the last line was empty and this one starts with commit
            if {[expr {$l - $i}] < 0} {break}
            # ^ we came to the last line!
            set line [lindex $lines $i]
            set revnum [lindex $line 1]
            incr i
            set line [lindex $lines $i]
            # Author: dorothyr <dorothyr@tadg>
            if { [string match {Author:*} $line] } {
              set revwho($revnum) [lindex $line 1]
            }
            incr i 1
            set line [lindex $lines $i]
            # Date:   2018-08-17 20:10:15 -0700
            if { [string match {Date:*} $line] } {
              set revdate($revnum) [lindex $line 1]
              set revtime($revnum) [lindex $line 2]
            }
            set last [lindex $lines $i]

            incr i 1
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
              set commentlines [lrange $lines [expr {$j + 1}] [expr {$c - 2}]]
              set revcomment($revnum) [join $commentlines "\n"]
              set i [expr {$c - 1}]
            }
            incr i 1

            gen_log:log D "revnum $revnum"
            gen_log:log D "revwho($revnum) $revwho($revnum)"
            gen_log:log D "revdate($revnum) $revdate($revnum)"
            gen_log:log D "revtime($revnum) $revtime($revnum)"
            gen_log:log D "revcomment($revnum) $revcomment($revnum)"
          }
        }
        gen_log:log T "LEAVE \"$revnum\""
        return $revnum
      }

      # Find which revs are on which branches
      proc isolate_branchrevs {branch file} {
        variable allrevs

        gen_log:log T "ENTER ($branch $file)"

        # List the revisions accessible from this branch. The list may go all the way back
        # to the master root.
        set command "git rev-list --abbrev-commit --no-merges --reverse --topo-order origin/$branch -- $file"
        set cmd_revlist [exec::new $command {} 0 {} 1]
        set revlist_output [$cmd_revlist\::output]
        $cmd_revlist\::destroy
        foreach ro [split $revlist_output "\n"] {
          if {[string length $ro] > 0} {
            lappend long_branchrevs $ro
          }
        }
        puts "===== $branch ====="
        puts "All revs:        $allrevs"
        puts "long_branchrevs: $long_branchrevs"
        # Find the revs that appear only in the allrevs list, not in branch
        puts -nonewline "not  branchrevs: "
        foreach arev $allrevs {
          if {$arev in $long_branchrevs} {
             puts -nonewline "        "
          } else {
             puts -nonewline "$arev "
          }
        }
        puts ""
        gen_log:log T "LEAVE "
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
          #if {![info exists revbranches($r)]} {set revbranches($r) {} }
        }
        foreach r [lsort -dictionary [array names revpath]] {
          gen_log:log D "revpath($r) $revpath($r)"
          #if {![info exists revbranches($r)]} {set revbranches($r) {} }
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names branchrevs]] {
          gen_log:log D "branchrevs($a) $branchrevs($a)"
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names revbranches]] {
          # sort the rev branches to they will be displayed in increasing order
          set revbranches($a) [lsort -dictionary $revbranches($a)]
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
          # Only take the highest rev of the messsy list that you might have here
          set revmergefrom($a) [lindex [lsort -dictionary $revmergefrom($a)] end]
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

