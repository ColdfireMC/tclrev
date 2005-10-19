# Find SVN URL
proc read_svn_dir {dirname} {
  global cvscfg
  global cvsglb
  global current_tagname
  global cmd

  gen_log:log T "ENTER ($dirname)"
  # svn info gets the URL
  set cmd(info) [exec::new "svn info"]
  set info_lines [split [$cmd(info)\::output] "\n"]
  foreach infoline $info_lines {
    if {[string match "URL:*" $infoline]} {
      #gen_log:log D "$infoline"
      set cvscfg(url) [lrange $infoline 1 end]
    }
  }
  if {$cvscfg(url) == ""} {
    cvsfail "Can't get the SVN URL"
    return
  }

  foreach s {trunk branches tags} {
    if {[regexp "/$s/" $cvscfg(url)] || [regexp "/$s" $cvscfg(url)]} {
      set spl [split $cvscfg(url) "/"]
      set root ""
      set relp ""
      set current_tagname ""
      puts $spl
      set state P
      for {set j 0} {$j < [llength $spl]} {incr j} {
        set word [lindex $spl $j]
        switch -- $state {
          P {
            switch -- $word {
              "trunk" {
                set type $word
                set state E
              } 
              "branches" {
                set type $word
                set state W
              }
              default { append root "$word/" }
             }
          }
          W {
            set current_tagname $word
            set state E
          }
          E {
              lappend relp "$word"
          }
          default {}
        }
      }
      puts $current_tagname
      puts "***"
      set cvscfg(svnroot) [string trimright $root "/"]
      gen_log:log D "SVN URL: $cvscfg(url)"
      gen_log:log D "svnroot: $cvscfg(svnroot)"
      set cvsglb(relpath) $relp
      gen_log:log D "relpath: $cvsglb(relpath)"
      gen_log:log D "tagname: $current_tagname"
    }
  }
  gen_log:log T "LEAVE"
}

# Get stuff for main workdir browser
proc svn_workdir_status {} {
  global cmd
  global Filelist

  gen_log:log T "ENTER"
  set cmd(cvs_status) [exec::new "svn status -uvN"]
  set status_lines [split [$cmd(cvs_status)\::output] "\n"]
  unset cmd(cvs_status)
  # The first five columns in the output are each one character wide
  foreach logline $status_lines {
    if {[string match "Status*" $logline]} {continue}
    if {[string length $logline] < 1} {continue}
    set cauthor ""
    set crev ""
    set wrev ""
    set status ""
    
    set varcols [string range $logline 8 end]
    if {[llength $varcols] > 1} {
      set wrev [lindex $varcols 0]
      set crev [lindex $varcols 1]
      set cauthor [lindex $varcols 2]
    }
    set filename [lindex $varcols end]
    set modstat [string range $logline 0 7]
    set m1 [string index $modstat 0]
    set displaymod ""
    if [file isdirectory $filename] {
      set displaymod "<dir> "
    }
    switch -exact -- $m1 {
      " " { append displaymod "Up-to-date" }
      M { append displaymod "Locally Modified" }
      A { append displaymod "Locally Added" }
      D { append displaymod "Locally Removed" }
      ? { append displaymod "Not managed by SVN" }
      C { append displaymod "Conflict" }
      L { append displaymod "Locked" }
      S { append displaymod "Switched to Branch" }
      ! { append displaymod "Missing or Incomplete Directory" }
      ~ { append displaymod "Dir/File Mismatch" }
    }

    if {[string index $modstat 7] == "*"} {
       set displaymod "Out-of-date"
    }
    set Filelist($filename:wrev) $wrev
    set Filelist($filename:status) $displaymod
    set Filelist($filename:stickytag) "$wrev $crev"
    if {$wrev != "" && $crev != ""} {
      #set Filelist($filename:stickytag) "working:$wrev committed:$crev"
      set Filelist($filename:stickytag) "$wrev   (committed:$crev)"
    }
    set Filelist($filename:option) ""
    set Filelist($filename:editors) "$cauthor"
  }
  gen_log:log T "LEAVE"
}

# does svn add from workdir browser
proc svn_add {args} {
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
  set cmd(svnadd) [exec::new "svn add $filelist"]
  if {$cvscfg(auto_status)} {
    $cmd(svnadd)\::wait
    setup_dir
  }

  gen_log:log T "LEAVE"
}

# does svn remove from workdir browser
proc svn_remove {args} {
  global cvscfg
  global cmd

  gen_log:log T "ENTER ($args)"
  set filelist [join $args]

  set cmd(svndel) [exec::new "svn remove $filelist"]
  if {$cvscfg(auto_status)} {
    $cmd(svndel)\::wait
    setup_dir
  }

  gen_log:log T "LEAVE"
}

# called from the workdir browser checkmark button
proc svn_check {directory} {
  global cvscfg

  gen_log:log T "ENTER ($directory)"

  busy_start .workdir.main

  set commandline "svn status $cvscfg(checkrecursive) $directory"
  set check_cmd [viewer::new "Directory Status Check"]
  $check_cmd\::do $commandline 0 status_colortags

  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

# svn update - called from workdir browser
proc svn_update {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"

  set filelist [join $args]

  set mess ""
  foreach file $filelist {
    append mess "\n\t$file"
  }
  append mess "\n\nAre you sure?"

  set commandline "svn update"

  if {[cvsconfirm $mess .workdir] == "ok"} {
    foreach file $filelist {
      append commandline " \"$file\""
    }
  }

  set co_cmd [viewer::new "SVN Update"]
  $co_cmd\::do $commandline 0 status_colortags
    
  if {$cvscfg(auto_status)} {
    $co_cmd\::wait
    setup_dir
  }
  gen_log:log T "LEAVE"
}

# dialog for svn commit - called from workdir browser
proc svn_commit_dialog {} {
  global cvsglb
  global cvscfg

  # If marked files, commit these.  If no marked files, then
  # commit any files selected via listbox selection mechanism.
  # The cvsglb(commit_list) list remembers the list of files
  # to be committed.
  set cvsglb(commit_list) [workdir_list_files]
  # If we want to use an external editor, just do it
  if {$cvscfg(use_cvseditor)} {
    svn_commit "" "" $cvsglb(commit_list)
    return
  }

  if {[winfo exists .commit]} {
    destroy .commit
  }

  toplevel .commit
  grab set .commit

  frame .commit.top -border 8
  frame .commit.down -relief groove -border 2

  pack .commit.top -side top -fill x
  pack .commit.down -side bottom -fill x
  frame .commit.comment
  pack .commit.comment -side top -fill both -expand 1
  label .commit.lcomment
  text .commit.tcomment -relief sunken -width 70 -height 10 \
    -exportselection 1 \
    -wrap word -border 2 -setgrid yes


  # Explain what it means to "commit" files
  message .commit.message -justify left -aspect 800 \
    -text "This will commit changes from your \
           local, working directory into the repository, recursively."

  pack .commit.message -in .commit.top -padx 2 -pady 5


  button .commit.ok -text "OK" \
    -command {
      grab release .commit
      wm withdraw .commit
      set cvsglb(commit_comment) [.commit.tcomment get 1.0 end]
      svn_commit $cvsglb(commit_comment) $cvsglb(commit_list)
    }
  button .commit.apply -text "Apply" \
    -command {
      set cvsglb(commit_comment) [.commit.tcomment get 1.0 end]
      svn_commit $cvsglb(commit_comment) $cvsglb(commit_list)
    }
  button .commit.clear -text "ClearAll" \
    -command {
      set version ""
      .commit.tcomment delete 1.0 end
    }
  button .commit.quit \
    -command {
      grab release .commit
      wm withdraw .commit
    }
 
  .commit.lcomment configure -text "Your log message" \
    -anchor w
  .commit.ok configure -text "OK"
  .commit.quit configure -text "Close"
  pack .commit.lcomment -in .commit.comment \
    -side left -fill x -pady 3
  pack .commit.tcomment -in .commit.comment \
    -side left -fill both -expand 1 -pady 3

  pack .commit.ok .commit.apply .commit.clear .commit.quit -in .commit.down \
    -side left -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1

  # Fill in the most recent commit message
  .commit.tcomment insert end $cvsglb(commit_comment)

  wm title .commit "Commit Changes"
  wm minsize .commit 1 1

  gen_log:log T "LEAVE"
}

# svn commit - called from commit dialog
proc svn_commit {comment args} {
  global cvscfg

  gen_log:log T "ENTER ($comment $args)"

  set filelist [lindex $args 0]

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
    set commandline \
      "$cvscfg(terminal) svn commit $filelist"
    gen_log:log C "$commandline"
    set ret [catch {eval "exec $commandline"} view_this]
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
    $v\::do "svn commit -m \"$comment\" $filelist" 1
    $v\::wait
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"

}

# Called from module browser filebrowse button
proc svn_list {module} {
  global env
  global cvscfg

  gen_log:log T "ENTER ($module)"
  set v [viewer::new "SVN list -R"]
  $v\::do "svn list -Rv $cvscfg(svnroot)/$module"
  gen_log:log T "LEAVE"
}

# Called from workdir browser annotate button
proc svn_annotate {revision args} {
  global cvscfg

  gen_log:log T "ENTER ($revision $args)"

  if {$revision != ""} {
    # We were given a revision
    set revflag "-r$revision"
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
    annotate::new $revflag $file "svn"
  }
  gen_log:log T "LEAVE"
}

# called from module browser - list branches & tags
proc parse_svnmodules {svnroot} {
  global modval

  gen_log:log T "Enter ($svnroot)"

  set command "svn list $svnroot"
  set cmd(svnlist) [exec::new "$command"]
  if {[info exists cmd(svnlist)]} {
    set contents [$cmd(svnlist)\::output]
  }
  foreach item $contents {
    gen_log:log D "$item"
    switch -exact -- $item {
      "trunk/" {
          set modval(trunk) "trunk"
       }
      "branches/" {
        set command "svn list $svnroot/branches"
        set cmd(svnlist) [exec::new "$command"]
        if {[info exists cmd(svnlist)]} {
          set branches [$cmd(svnlist)\::output]
        }
        foreach branch $branches {
          gen_log:log D "  $branch"
          set modval($branch) "branches/$branch"
        }
      }
      "tags/" {
        set command "svn list $svnroot/tags"
        set cmd(svnlist) [exec::new "$command"]
        if {[info exists cmd(svnlist)]} {
          set tags [$cmd(svnlist)\::output]
        }
        foreach tag $tags {
          gen_log:log D "  $tag"
          set modval($tag) "tags/$tag"
        }
      }
      default {
        set modval($item) $item
      }
    }
  }
  set modval(branches) "[llength $branches] branches"
  set modval(tags) "[llength $tags] tags"
  gen_log:log D "BRANCHES $modval(branches)"
  gen_log:log D "TAGS $modval(tags)"
  gen_log:log T "LEAVE"
}

proc svn_branches {files} {
  global cvscfg
  global cvsglb
  
  gen_log:log T "ENTER ($files)"
  set filelist [join $files]

  if {$files == {}} {
    cvsfail "Please select one or more files!" .workdir
    return
  }

  gen_log:log D "Relative Path: $cvsglb(relpath)"

  foreach file $files {
    ::branch_canvas::new $cvsglb(relpath) $file
  }

  gen_log:log T "LEAVE"
}

proc svn_cat {rev file} {
  gen_log:log T "ENTER ($rev $file)"

  set cat_cmd [viewer::new "SVN cat $rev $file"]
  set commandline "svn -r $rev cat $file"
  $cat_cmd\::do $commandline 0

  gen_log:log T "LEAVE"
}
 
# called from workdir Reports menu
proc svn_log {args} {
  global cvscfg
  gen_log:log T "ENTER ($args)"

  set filelist [join $args]
  set commandline "svn log "
  if {$cvscfg(ldetail) == "latest"} {
    append commandline "-r COMMITTED "
  }
  if {$cvscfg(ldetail) == "summary"} {
    append commandline "-q "
  }

  set logcmd [viewer::new "SVN Log ($cvscfg(ldetail))"]
  $logcmd\::do "$commandline"
  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

proc cvs_merge_conflict {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"

  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select some files to merge first!"
    return
  }

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
      cvsfail "This file does not appear to have a conflict." .workdir
      return
    }
    # Invoke tkdiff with the proper option for a conflict file
    # and have it write to the original file
    set commandline "$cvscfg(tkdiff) -conflict -o \"$filename\" \"$filename\""
    gen_log:log C "$commandline"
    set ret [catch {eval "exec $commandline"} view_this]
    if {$ret == 0} {
      set mess "Mark $filename resolved?"
      if {[cvsconfirm $mess .workdir] != "ok"} {
        continue
      }
      set commandline "svn resolved $filename"
      exec::new $commandline
    } else {
      cvsfail "$view_this" .workdir
    }
  }
  
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

