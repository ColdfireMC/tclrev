
# Get the revision log of an RCS file and send it to the
# branch-diagram browser.
# Disable merge buttons.
proc rcs_branches {files} {
  global cvscfg
  global cwd
  
  gen_log:log T "ENTER ($files)"

  if {$files == {}} {
    cvsfail "Please select one or more files!" .workdir
    return
  }

  foreach filename $files {
    ::cvs_branchlog::new RCS "$filename"
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

proc rcs_lock {do files} {
  global cvscfg

  if {$files == {}} {
    cvsfail "Please select one or more files!" .workdir
    return
  }
  switch -- $do {
    lock { set commandline "rcs -l $files"}
    unlock { set commandline "rcs -u $files"}
  }
  set cmd [::exec::new "$commandline"]
  
  if {$cvscfg(auto_status)} {
    $cmd\::wait
    setup_dir
  }
}

# RCS checkin.  Have to use terminal, because ci -m won't take
# a message with a newline
proc rcs_checkin {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"
  set filelist [lindex $args 0]
  
  update idletasks
  set commandline "$cvscfg(terminal) ci -u $filelist"
  gen_log:log C "$commandline"

  set ret [catch {eval "exec $commandline"} view_this]
  if {$ret} {
    cvsfail $view_this .workdir
    gen_log:log T "LEAVE ERROR ($view_this)"
    return
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc rcs_commit_dialog {} {
# RCS checkin.  Have to use terminal, because ci -m won't take
# a message with a newline
# But some day, investigate this:

# % set ms "this has a \
# CR"
# % puts $ms
# this has a
# CR
#
# % regsub -all {\n} $ms {\n} msg
# % puts $msg
# this has a\nCR
#
# puts "this has a\nCR"
# this has a
# CR
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

  # The older version (pre-5.x or something) of RCS is a lot different from
  # the newer versions, explaining some of the ugliness here
  set rlog_lines [split $raw_rcs_log "\n"]
  set lockers ""
  foreach rlogline $rlog_lines {
    gen_log:log D "$rlogline"
    # Found one!
    if {[string match "*Working file:*" $rlogline]} {
      regsub {^.*Working file:\s+} $rlogline "" filename
      regsub {\s*$} $filename "" filename
      gen_log:log D "RCS file $filename"
      set Filelist($filename:wrev) ""
      set Filelist($filename:stickytag) ""
      set Filelist($filename:option) ""
      if {[file exists $filename]} {
        set Filelist($filename:status) "RCS Up-to-date"
        # Do rcsdiff to see if it's changed
        #set command "rcsdiff -q \"$filename\" > $cvscfg(null)"
        set command "rcsdiff \"$filename\""
        gen_log:log C "$command"
        set ret [catch {eval "exec $command"} output]
        gen_log:log D "$output"
        set splitline [split $output "\n"]
        if [string match {====*} [lindex $splitline 0]] {
           set splitline [lrange $splitline 1 end]
        }
        if {[llength $splitline] > 3} {
          set Filelist($filename:status) "RCS Modified"
          gen_log:log D "$filename MODIFIED"
        }
      } else {
        set Filelist($filename:status) "RCS Needs Checkout"
      }
      set who ""
      set lockers ""
      continue
    }
    if {[string match "head:*" $rlogline]} {
      regsub {head: } $rlogline "" revnum
      set Filelist($filename:wrev) "$revnum"
      set Filelist($filename:stickytag) "$revnum on trunk"
      #gen_log:log D "  Rev \"$revnum\""
      continue
    } 
    if {[string match "branch:*" $rlogline]} {
      regsub {branch: *} $rlogline "" revnum
      if {[string length $revnum] > 0} {
        set Filelist($filename:wrev) "$revnum"
        set Filelist($filename:stickytag) "$revnum on branch"
        #gen_log:log D "  Branch rev \"$revnum\""
      }
      continue
    }
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
        continue
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

  set commandline "rlog "
  switch -- $cvscfg(ldetail) {
    latest {
      append commandline "-r "
    }
    summary {
      append commandline "-t "
    }
  }
  append commandline "$filelist"

  set logcmd [viewer::new "RCS log ($cvscfg(ldetail))"]
  $logcmd\::do "$commandline" 0 hilight_rcslog
  busy_done .workdir.main

  gen_log:log T "LEAVE"
}

# Revert a file to checked-in version by removing the local
# copy and updating it
proc rcs_revert {args} {
  global cvscfg
        
  gen_log:log T "ENTER ($args)"
  set filelist [join $args]

  gen_log:log D "Reverting $filelist"
  file delete $filelist
  set cmd [exec::new "co $filelist"]
        
  if {$cvscfg(auto_status)} {
    $cmd\::wait
    setup_dir 
  }     
        
  gen_log:log T "LEAVE"
}     

