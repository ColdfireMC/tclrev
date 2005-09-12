
# Get the revision log of an RCS file and send it to the
# branch-diagram browser.
# Disable merge buttons.
proc rcs_filelog {filename} {
  global cvscfg
  global cwd
  
  gen_log:log T "ENTER ($filename)"
  set pid [pid]
  set filetail [file tail $filename]
  
  set commandline "rlog \"$filename\""

  # Log canvas viewer
  logcanvas::new $cwd $filename "no file" $commandline
  gen_log:log T "LEAVE"
}

# check out (co) a file.  Called from the "update" button
proc rcs_checkout {filename} {
  global cvscfg

  gen_log:log T "ENTER ($filename)"
  set commandline "co -l $filename"
  set v [::viewer::new "RCS Checkout"]
  $v\::do "$commandline" 1

  if {$cvscfg(auto_status)} {
    $v\::wait
    setup_dir
  }
  gen_log:log T "LEAVE"
}

# Get an rcs status for files in working directory
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

