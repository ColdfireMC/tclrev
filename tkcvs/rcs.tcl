
# Get the revision log of an RCS file and send it to the
# branch-diagram browser.
# Disable merge buttons.
proc rcs_filelog {files} {
  global cvscfg
  global cwd
  
  gen_log:log T "ENTER ($files)"

  if {$files == {}} {
    cvsfail "Please select one or more files!" .workdir
    return
  }

  foreach filename $files {
    set pid [pid]
    set filetail [file tail $filename]
    set commandline "rlog \"$filename\""

    # Log canvas viewer
    logcanvas::new $cwd $filename "no file" $commandline
  }
  gen_log:log T "LEAVE"
}

# check out (co) a file.  Called from the "update" button
proc rcs_checkout {files} {
  global cvscfg

  gen_log:log T "ENTER ($files)"

  if {$files == {}} {
    cvsfail "Please select one or more files!" .workdir
    return
  }

  set commandline "co -l $files"
  set v [::viewer::new "RCS Checkout"]
  $v\::do "$commandline" 1
  
  if {$cvscfg(auto_status)} {
    $v\::wait
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc rcs_checkin {comment args} {
  global cvscfg

  gen_log:log T "ENTER ($comment $args)"
  set filelist [lindex $args 0]
  
  if {$cvscfg(use_cvseditor)} {
    # Starts text editor of your choice to enter the log message.
    update idletasks
    set commandline "$cvscfg(terminal) ci -u $filelist"
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
    set v [viewer::new "RCS Checkin"]
    regsub -all "\"" $comment "\\\"" comment
    $v\::do "ci -u -m\"$comment\" $filelist" 1
    $v\::wait
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

# dialog for rcs checkin - called from workdir browser
proc rcs_commit_dialog {} {
  global cvsglb
  global cvscfg

  # If marked files, commit these.  If no marked files, then
  # commit any files selected via listbox selection mechanism.
  # The cvsglb(commit_list) list remembers the list of files
  # to be committed.
  set cvsglb(commit_list) [workdir_list_files]
  # If we want to use an external editor, just do it
  if {$cvscfg(use_cvseditor)} {
    rcs_checkin "" $cvsglb(commit_list)
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
    -text "This will check in changes from your \
           local copy of these files: \
           $cvsglb(commit_list)"

  pack .commit.message -in .commit.top -padx 2 -pady 5


  button .commit.ok -text "OK" \
    -command {
      grab release .commit
      wm withdraw .commit
      set cvsglb(commit_comment) [.commit.tcomment get 1.0 end]
      rcs_checkin $cvsglb(commit_comment) $cvsglb(commit_list)
    }
  button .commit.apply -text "Apply" \
    -command {
      set cvsglb(commit_comment) [.commit.tcomment get 1.0 end]
      rcs_checkin $cvsglb(commit_comment) $cvsglb(commit_list)
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

# Get an rcs status for files in working directory, for the dircanvas
proc rcs_workdir_status {} {
  global cvscfg
  global Filelist

  gen_log:log T "ENTER"

  set rcsfiles [glob -nocomplain -- RCS/* RCS/.??* *,v .??*,v]
  set command "rlog -h $rcsfiles"
  gen_log:log C "$command"
  set ret [catch {eval "exec $command"} raw_rcs_log]
  #gen_log:log D "$raw_rcs_log"

  set rlog_lines [split $raw_rcs_log "\n"]
  set logstate "working"
  set lockers ""
  foreach rlogline $rlog_lines {
    gen_log:log D "$rlogline"
    gen_log:log D "  logstate $logstate"
    # Found one!
    switch -exact -- $logstate {
      "working" {
        if {[string match "Working file:*" $rlogline]} {
          regsub {Working file: } $rlogline "" filename
          regsub {\s*$} $filename "" filename
          gen_log:log D "RCS file $filename"
          set Filelist($filename:wrev) ""
          set Filelist($filename:stickytag) ""
          set Filelist($filename:option) ""
          if {[file exists $filename]} {
            set Filelist($filename:status) "RCS Up-to-date"
            # Do rcsdiff to see if it's changed
            set command "rcsdiff -q \"$filename\" > $cvscfg(null)"
            gen_log:log C "$command"
            set ret [catch {eval "exec $command"}]
            if {$ret == 1} {
              set Filelist($filename:status) "RCS Modified"
            }
          } else {
            set Filelist($filename:status) "RCS Needs Checkout"
          }
          set who ""
          set lockers ""
          set logstate "head"
          continue
        }
      }
      "head" {
        if {[string match "head:*" $rlogline]} {
          regsub {head: } $rlogline "" revnum
          set Filelist($filename:wrev) "$revnum"
          set Filelist($filename:stickytag) "$revnum on trunk"
          #gen_log:log D "  Rev \"$revnum\""
          set logstate "branch"
          continue
        }
      }
      "branch" {
        if {[string match "branch:*" $rlogline]} {
          regsub {branch: *} $rlogline "" revnum
          if {[string length $revnum] > 0} {
            set Filelist($filename:wrev) "$revnum"
            set Filelist($filename:stickytag) "$revnum on branch"
            #gen_log:log D "  Branch rev \"$revnum\""
          }
          set logstate "locks"
          continue
        }
      }
      "locks" {
        if { [string index $rlogline 0] == "\t" } {
           set splitline [split $rlogline]
           #gen_log:log D "\"[lindex $splitline 1]\""
           #gen_log:log D "\"[lindex $splitline 2]\""
           set who [lindex $splitline 1]
           set who [string trimright $who ":"]
           #gen_log:log D " who $who"
           append lockers ",$who"
           #gen_log:log D " lockers $lockers"
        } else {
          if {[string match "access list:*" $rlogline]} {
            set lockers [string trimleft $lockers ","]
            set Filelist($filename:editors) $lockers
            # No more tags after this point
            set logstate "working"
            continue
          }
        }
      }  
    }
  }
  gen_log:log T "LEAVE"
}

# for Directory Status Check
proc rcs_check {} {
  global cvscfg

  gen_log:log T "ENTER"

  set v [::viewer::new "Directory Status Check"]
  set rcsfiles [glob -nocomplain -- RCS/* RCS/.??* *,v .??*,v]
  set command "rlog -h $rcsfiles"
  gen_log:log C "$command"
  set ret [catch {eval "exec $command"} raw_rcs_log]
  #gen_log:log D "$raw_rcs_log"

  set rlog_lines [split $raw_rcs_log "\n"]
  foreach rlogline $rlog_lines {
    if {[string match "Working file:*" $rlogline]} {
      regsub {Working file: } $rlogline "" filename
      regsub {\s*$} $filename "" filename
      gen_log:log D "RCS file $filename"
      if {[file exists $filename]} {
        # Do rcsdiff to see if it's changed
        set command "rcsdiff -q \"$filename\" > $cvscfg(null)"
        gen_log:log C "$command"
        set ret [catch {eval "exec $command"}]
        if {$ret == 1} {
          $v\::log "\nM $filename"
        }
      } else {
        $v\::log "\nU $filename"
      }
    }
  }
  gen_log:log T "LEAVE"
}

# for Log in Reports Menu
proc rcs_log {args} {
  global cvscfg
  gen_log:log T "ENTER"

  set filelist [join $args]
  if {$filelist == ""} {
    set filelist [glob -nocomplain -dir RCS *,v]
  }
  gen_log:log D "detail $cvscfg(ldetail)"
  gen_log:log D "$filelist"

  switch -- $cvscfg(ldetail) {
   "verbose" { set commandline "rlog $filelist"}
   "summary" { set commandline "rlog -R $filelist"}
   "latest"  { set commandline "rlog -r $filelist"}
  }

  set v [viewer::new "RCS Log"]
  $v\::do "$commandline"

  gen_log:log T "LEAVE"
}

