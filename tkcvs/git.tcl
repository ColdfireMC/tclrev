proc git_workdir_status {} {
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

if {0} {
  foreach f [glob -nocomplain *] {
    set command "git log -n 1 --pretty=format:\"%h|%cd\" -- $f"
    set cmd(git_log) [exec::new "$command"]
    foreach log_line [split [$cmd(git_log)\::output] "\n"] {
      gen_log:log D "log_line $log_line"
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
    set Filelist($f:stickytag) $hash
    set Filelist($f:date) $wdate
    gen_log:log D "$Filelist($f:stickytag)"
    gen_log:log D "$Filelist($f:date)"
  }
}

  foreach f [glob -nocomplain *] {
    if {![file isdirectory $f]} {
      set cmd(git_status) [exec::new "git status --porcelain $f"]
      set logline [lindex [split [$cmd(git_status)\::output] "\n"] 0]
      set status [lindex $logline 0]
      set filename [lindex $logline 1]
      switch -- $status {
        "M" {
         set Filelist($filename:status) "Locally Modified"
         gen_log:log D "$Filelist($filename:status)"
        }
        "A" {
         set Filelist($filename:status) "Locally Added"
         gen_log:log D "$Filelist($filename:status)"
        }
        "D" {
         set Filelist($filename:status) "Locally Removed"
         gen_log:log D "$Filelist($filename:status)"
        }
        "R" {
         set Filelist($filename:status) "Renamed"
         gen_log:log D "$Filelist($filename:status)"
        }
        "C" {
         set Filelist($filename:status) "Copied"
         gen_log:log D "$Filelist($filename:status)"
        }
        "U" {
         set Filelist($filename:status) "Updated"
         gen_log:log D "$Filelist($filename:status)"
        }
        "??" {
         set Filelist($filename:status) "Not Managed"
         gen_log:log D "$Filelist($filename:status)"
          #This might list some missing files, in which case some things
          #like stickytag might not have been set
         set Filelist($filename:stickytag) ""
         set Filelist($filename:option) ""
       }
      }
    }
  }
  
  gen_log:log T "LEAVE"
}

