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
    set cmd(git_status) [exec::new "git status -u --porcelain \"$f\""]
    set statline [lindex [split [$cmd(git_status)\::output] "\n"] 0]
    if {![file isdirectory $f]} {
      set status [lindex $statline 0]
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

      switch -- $status {
        "M" {
         set Filelist($f:status) "Locally Modified"
         gen_log:log D "$Filelist($f:status)"
        }
        "A" {
         set Filelist($f:status) "Locally Added"
         gen_log:log D "$Filelist($f:status)"
        }
        "D" {
         set Filelist($f:status) "Locally Removed"
         gen_log:log D "$Filelist($f:status)"
        }
        "R" {
         set Filelist($f:status) "Renamed"
         gen_log:log D "$Filelist($f:status)"
        }
        "C" {
         set Filelist($f:status) "Copied"
         gen_log:log D "$Filelist($f:status)"
        }
        "U" {
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
  append commandline " $filelist"

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
proc git_status {args} {
  global cvscfg
 
  gen_log:log T "ENTER ($args)"

  busy_start .workdir.main
  set filelist [join $args]
  set flags ""
  set title "GIT Status ($cvscfg(rdetail))"
  # Hide unknown files if desired
  if {$cvscfg(status_filter)} {
    append flags " -uno"
  }
  if {$cvscfg(rdetail) == "terse"} {
    append flags " --short"
  }
  set commandline "git status $flags $filelist"
  set stat_cmd [viewer::new $title]
  $stat_cmd\::do "$commandline" 0 status_colortags

  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

# called from the "Check Directory" button in the workdir and Reports menu
proc git_check {} {
  global cvscfg

  gen_log:log T "ENTER ()"

  busy_start .workdir.main
  set title "GIT Directory Check"
  set flags "--short"
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

