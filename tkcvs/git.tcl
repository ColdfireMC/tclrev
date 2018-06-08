proc git_workdir_status {} {
  global cvscfg
  global Filelist
  global current_tagname

  gen_log:log T "ENTER"
  set cmd(git_branch) [exec::new "git branch"]
  set branch_lines [split [$cmd(git_branch)\::output] "\n"]
  foreach line $branch_lines {
    if [string match "\* *" $line] {
      set current_tagname [lindex $line 1]
      gen_log:log D "current_tagname=$current_tagname"
    }
  }

  foreach f [glob -nocomplain *] {
    set cmd(git_status) [exec::new "git status --porcelain \"$f\""]
    set statline [lindex [split [$cmd(git_status)\::output] "\n"] 0]
    if {![file isdirectory $f]} {
      set status [lindex $statline 0]
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
         set Filelist($f:status) "Not Managed"
         gen_log:log D "$Filelist($f:status)"
         #This might list some missing files, in which case some things
         #like stickytag might not have been set
         set Filelist($f:stickytag) ""
         set Filelist($f:option) ""
       }
      }
    } else {
      if {[llength $statline]} {
         set Filelist($f:status) "<directory:GIT>"
         gen_log:log D "$Filelist($f:status)"
      } else {
         set Filelist($f:status) "<directory>"
         gen_log:log D "$Filelist($f:status)"
      }
    }
  }
  
  gen_log:log T "LEAVE"
}

proc read_git_file {dirname} {
  global cvscfg

  gen_log:log T "ENTER ($dirname)"

  if {[file isfile [file join $dirname ".git"]]} {
    gen_log:log F "OPEN .git"
    set f [open [file join $dirname .git] r]
    while {![eof $f]} {
      gets $f gitline
      gen_log:log F $gitline
      if {[string match "gitdir:*" $gitline]} {
        set cvscfg(url) [lindex $gitline 1]
      }
    }
    close $f
  } elseif {[file isdirectory [file join $dirname ".git"]]} {
    #set cmd "git config -l"
    set cmd(git_config) [exec::new "git config remote.origin.url"]
    set cfgline [lindex [split [$cmd(git_config)\::output] "\n"] 0]
    set cvscfg(url) $cfgline
    $cmd(git_config)\::destroy
  }
  gen_log:log T "LEAVE"
}

