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

  # This lists the files that git tracks. It's the only way to list up-to-date
  # files.
  #set cmd(git_list) [exec::new "git ls-tree --name-status -r $current_tagname"]
  set cmd(git_list) [exec::new "git ls-tree --name-only -r $current_tagname"]
  set gitlist_lines [split [$cmd(git_list)\::output] "\n"]
  if {[info exists cmd(git_list)]} {
    $cmd(git_list)\::destroy
    catch {unset cmd(git_list)}
    foreach line $gitlist_lines {
      gen_log:log D "$line"
      if {[string length $line]} {
        if {[regsub {/.*$} $line "" head]} {
          set Filelist($head:status) "<directory:GIT>"
        } else {
          set f $line
          # temporary, should be overwritten in next loop
        }
        lappend tracked_files $head
      }
    }
  }

  # Get the status of the tracked files (top level only)
  foreach f [lsort -unique $tracked_files] {
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

  # Deal with the ones that aren't tracked
  foreach f [glob -nocomplain *] {
    if {! [info exists Filelist($f:status)]} {
      set Filelist($f:status) "Not Managed"
      gen_log:log D "$Filelist($f:status)"
      #This might list some missing files, in which case some things
      #like stickytag might not have been set
      #set Filelist($f:stickytag) ""
      #set Filelist($f:option) ""
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

