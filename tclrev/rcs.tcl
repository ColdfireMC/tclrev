
# Get the revision log of an RCS file and send it to the
# branch-diagram browser.
# Disable merge buttons.
proc rcs_branches {files} {
  global cvscfg
  global cwd 
  if {$files == {}} {
    cvsfail "Please select one or more files!" 
    return
  }
  
  foreach filename $files {
    ::cvs_branchlog::new RCS "$filename"
  }
}
# check out (co) a file.  Called from the "update" button
proc rcs_checkout {files} {
  global cvscfg
  if {$files == {}} {
    cvsfail "Please select one or more files!" 
    return
  }
  set commandline "co -l $files"
  set v [::viewer::new "RCS Checkout"]
  $v\::do "$commandline" 1
  
  if {$cvscfg(auto_status)} {
    $v\::wait
    setup_dir
  }
}
proc rcs_lock {do files} {
  global cvscfg
  if {$files == {}} {
    cvsfail "Please select one or more files!"
    return
  }
  switch -- $do {
    lock { set commandline "rcs -l $files"}
    unlock { set commandline "rcs -u $files"}
  }
  set rcscmd [exec "$commandline"] 
  if {$cvscfg(auto_status)} {
    setup_dir
  }
}
# RCS checkin.
proc rcs_checkin {revision comment args} {
  global cvscfg 
  global inrcs 
  set filelist [lindex $args 0]
  if {$filelist == "" } {  
    cvsfail "Please select some files!"
    return 1
  }
  set commit_output ""    
  foreach file $filelist {
    append commit_output "\n$file"
  }
  set mess "This will commit your changes to:$commit_output"
  append mess "\n\nAre you sure?"
  set commit_output ""
  set revflag ""
  if {$revision != ""} {
    set revflag "-r $revision"
  }
  if {$cvscfg(use_cvseditor)} {
    # Starts text editor of your choice to enter the log message.
    # This way a template in CVSROOT can be used.
    update idletasks
    set commandline \
        "$cvscfg(terminal) ci $revflag $filelist"
    set ret [catch {exec {*}$commandline} view_this]
    if {$ret} { 
      cvsfail $view_this .workdir
      return
    }
  } else {
    if {$comment == ""} {
      cvsfail "You must enter a comment!"
      return 1
    } 
    set v [viewer::new "RCS Checkin"] 
    regsub -all {\"} $comment {\"} comment
    regsub -all { } $comment {\ } comment
    regsub -all {\n} $comment {\\n} comment
    set now [clock format [clock seconds] -format "$cvscfg(dateformat)"]
    set description "Created $now"
    regsub -all { } $description {_} description
    # The -t is necessary if it's the initial commit (aka "add" in other systems.)
    # It's ignored otherwise, so it does no harm.
    set commandline "ci $revflag -t-$description -m\"$comment\" $filelist"
    exec "$commandline" 1
}

  if {$cvscfg(auto_status)} {
    setup_dir
  }
}      

# Get an rcs status for files in working directory, for the dircanvas
proc rcs_workdir_status { } {
  global cvscfg
  global Filelist
  set rcsfiles [glob -nocomplain -- RCS/* RCS/.??* *,v .??*,v] 
  set command "rlog -h $rcsfiles"
  ##gen_log:log C "$command"
  set ret [catch {exec {*}$command} raw_rcs_log]
    # The older version (pre-5.x or something) of RCS is a lot different from
    # the newer versions, explaining some of the ugliness here
  set rlog_lines [split $raw_rcs_log "\n"]
  set lockers ""
  set filenames ""
  foreach rlogline $rlog_lines {
    # Found one!  
    if {[string match "*Working file:*" $rlogline]} {     
      regsub {^.*Working file:\s+} $rlogline "" filename 
      regsub {\s*$} $filename "" filename
      lappend filenames $filename
      ##gen_log:log D "RCS file $filename"
      set Filelist($filename:wrev) "" 
      set Filelist($filename:stickytag) ""
      set Filelist($filename:option) "" 
      if {[file exists $filename]} {  
        set Filelist($filename:status) "RCS Up-to-date"
    # Do rcsdiff to see if it's changed
        set command "rcsdiff \"$filename\"" 
        ##gen_log:log C "$command"    
        set ret [catch {exec {*}$command} output]
        #gen_log:log F "$output"
        set splitline [split $output "\n"]
        if [string match {====*} [lindex $splitline 0]] {
           set splitline [lrange $splitline 1 end]
        }
        if {[llength $splitline] > 3} {
          set Filelist($filename:status) "RCS Modified"
          #gen_log:log D "$filename MODIFIED"
        }
      } else {
        set Filelist($filename:status) "RCS Needs Checkout"
      }
      set who ""
      set lockers ""
      continue
    }
    if {[string match "head:*" $rlogline]} {
      regsub {head:\s+} $rlogline "" revnum
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
       set who [lindex $splitline 1]
       set who [string trimright $who ":"]
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
  foreach f $filenames {
    set lockers $Filelist($f:editors)
    if { $lockers ne "" } {
      if {$cvscfg(user) in $lockers} {
        append Filelist($f:status) "/HaveLock"
      } else {
        append Filelist($f:status) "/Locked"
      }
    }
  }
}

# for Directory Status Check
proc rcs_check {} {
  global cvscfg
  set v [::viewer::new "RCS Directory Check"]
  set rcsfiles [glob -nocomplain -- RCS/* RCS/.??* *,v .??*,v]
  set command "rlog -h $rcsfiles"
  set ret [catch {exec {*}$command} raw_rcs_log]
  set rlog_lines [split $raw_rcs_log "\n"]
  foreach rlogline $rlog_lines {
    if {[string match "Working file:*" $rlogline]} {
      regsub {Working file: } $rlogline "" filename
      regsub {\s*$} $filename "" filename
      #gen_log:log D "RCS file $filename"
      if {[file exists $filename]} {
    # Do rcsdiff to see if it's changed
        set command "rcsdiff -q \"$filename\" > $cvscfg(null)"
        set ret [catch {exec {*}$command}]
        if {$ret == 1} {
          $v\::log "\nM $filename"
        }
      } else {
        $v\::log "\nU $filename"
      }
    }
  }
}
# for Log in Reports Menu
proc rcs_log {detail args} {
  global cvscfg
  set filelist [join $args]
  if {$filelist == ""} {
    set filelist [glob -nocomplain -- RCS/* RCS/.??* *,v .??*,v]
  }
  set commandline "rlog "
  switch -- $detail {
    latest {
      append commandline "-R "
    }
    summary {
      append commandline "-t "
    }
  }
  append commandline "$filelist"
  set v [viewer::new "RCS log ($detail)"]
  $v\::do "$commandline" 0 rcslog_colortags
}

proc rcs_log_rev {revision filename} {
  set commandline "rlog"
  if {$revision ne ""} {
    append commandline " -r$revision"
  }
  append commandline " \"$filename\""
  set v [viewer::new "RCS log -r$revision $filename "]
  $v\::do "$commandline" 0 rcslog_colortags
}

# This views a specific revision of a file
proc rcs_fileview_checkout {revision filename} {
  global cvscfg
  if {$revision == {}} {
    set commandline "co -p \"$filename\""
    set v [viewer::new "$filename"]
    $v\::do "$commandline" 0
  } else {
    set commandline "co -p -r$revision \"$filename\""
    set v [viewer::new "$filename Revision $revision"]
    $v\::do "$commandline" 0
  }
}
# Revert a file to checked-in version by removing the local
# copy and updating it
proc rcs_revert {args} {
  global cvscfg
  set filelist [join $args]
  file delete $filelist
  set rcscmd [exec::new "co $filelist"]
  if {$cvscfg(auto_status)} {
    $rcscmd\::wait
    setup_dir 
  }     
}     

