#
# Tcl Library for TkRev
# 

#
# Contains procedures used in interaction with CVS.
#

proc cvs_notincvs {} {
  cvsfail "This directory is not in CVS." .workdir
}

# Create a temporary directory
# cd to that directory
# run the CVS command in that directory
# 
# returns: the current wd (ERROR) or the sandbox directory (OK)
proc cvs_sandbox_runcmd {command output_var} {
  global cvscfg
  global cwd
  
  upvar $output_var view_this
  
  # Big note: the temp directory fed to a remote servers's command line
  # needs to be seen by the server.  It can't cd to an absolute path.
  # In addition it's fussy about where you are when you do a checkout -d.
  # Best avoid that altogether.
  # gen_log:log T "ENTER ($command $output_var)"
  set pid [pid]
   
  if {! [file isdirectory $cvscfg(tmpdir)]} {
    gen_log:log F "MKDIR $cvscfg(tmpdir)"
    file mkdir $cvscfg(tmpdir)
  }
  cd $cvscfg(tmpdir)
  gen_log:log F "CD [pwd]"
  if {! [file isdirectory cvstmpdir.$pid]} {
    gen_log:log F "MKDIR cvstmpdir.$pid"
    file mkdir cvstmpdir.$pid
  } 
  cd cvstmpdir.$pid
  gen_log:log F "CD [pwd]"
  
  gen_log:log C "$command"
  set ret [catch {exec {*} $command} view_this]
  # gen_log:log T "RETURN $cvscfg(tmpdir)/cvstmpdir.$pid"
  return $cvscfg(tmpdir)/cvstmpdir.$pid
}

# cvs_sandbox_filetags
#   assume that the sandbox contains the checked out files
#   return a list of all the tags in the files
proc cvs_sandbox_filetags {mcode args} {
  global cvscfg
  global cvs
  
  set pid [pid]
  set cwd [pwd]
  # gen_log:log T "ENTER ($mcode $args)"
  
  set filenames [join $args]
  set command "$cvs log"
  cd [file join $cvscfg(tmpdir) cvstmpdir.$pid $mcode]
  foreach f $filenames {
    append command " \"$f\""
  }
  gen_log:log C "$command"
  set ret [catch {exec {*} $command} view_this]
  if {$ret} {
    cd $cwd
    cvsfail $view_this .merge
    # gen_log:log T "LEAVE ERROR"
    return $keepers
  }
  set view_lines [split $view_this "\n"]
  foreach line $view_lines {
    if {[string index $line 0] == "\t" } {
      regsub -all {[\t ]*} $line "" tag
      append keepers "$tag "
    }
  }
  cd $cwd
  # gen_log:log T "LEAVE"
  return $keepers
}

proc cvs_workdir_status {} {
  global cvscfg
  global cvsglb
  global cvs
  global Filelist
  
  # gen_log:log T "ENTER"
  
  # We mostly get the information we need from cvs -n -q status. But for
  # lockers, we need cvs log.  For editors, we need the separate cvs editors
  # command. If the server isn't local, we need the log to get the author, too.
  set cmd(cvs_status) [exec::new "$cvs -n -q status -l"]
  set status_lines [split [$cmd(cvs_status)\::output] "\n"]
  if {$cvscfg(showeditcol)} {
    set cmd(cvs_get_log) [exec::new "$cvs log -N -l"]
    set cvslog_lines [split [$cmd(cvs_get_log)\::output] "\n"]
  }
  if {$cvscfg(showdatecol) && ! [string match {:local:*} $cvscfg(cvsroot)] } {
    if {! [info exists cmd(cvs_get_log)]} {
      set cmd(cvs_get_log) [exec::new "$cvs log -N -l"]
      set cvslog_lines [split [$cmd(cvs_get_log)\::output] "\n"]
    }
  }
  if {$cvscfg(econtrol) && $cvscfg(showeditcol)} {
    set cmd(cvs_editors) [exec::new "$cvs -n -q editors -l"]
    set editors_lines [split [$cmd(cvs_editors)\::output] "\n"]
  }
  
  if {[info exists cmd(cvs_status)]} {
    $cmd(cvs_status)\::destroy
    catch {unset cmd(cvs_status)}
  }
  
  # get cvs status in current directory only, reading lines that include
  # Status: or Sticky Tag:, putting each file's info (name, status, and tag)
  # into an array.
  foreach logline $status_lines {
    if {[string match "File:*" $logline]} {
      regsub -all {\t+} $logline "\t" logline
      set line [split [string trim $logline] "\t"]
      gen_log:log D "$line"
      # Clean up the file name
      regsub {File:\s+} [lindex $line 0] "" filename
      regsub {^no file } $filename {} filename
      regsub {\s*$} $filename "" filename
      regsub {Status: } [lindex $line 1] "" status
      set Filelist($filename:status) $status
      # Don't set editors to null because we'll use its presence
      # or absence to see if we need to re-read the repository when
      # we ask to map the editors column
    } elseif {[string match "*Working revision:*" $logline]} {
      regsub -all {\t+} $logline "\t" logline
      set line [split [string trim $logline] "\t"]
      gen_log:log D "$line"
      set revision [lindex $line 1]
      regsub {New .*} $revision "New" revision
      set date [lindex $line 2]
      
      # The date field is not supplied to remote clients.
      set Filelist($filename:date) $date
      set Filelist($filename:wrev) $revision
      set Filelist($filename:status) $status
    } elseif {[string match "*Sticky Tag:*" $logline]} {
      regsub -all {\t+} $logline "\t" logline
      set line [split [string trim $logline] "\t"]
      gen_log:log D "$line"
      set tagline [lindex $line 1]
      set t0 [lindex $tagline 0]
      set t1 [lrange $tagline 1 end]
      set stickytag ""
      if { $t0 == "(none)" } {
        set stickytag " on trunk"
      } elseif {[string match "(branch:*" $t1 ]} {
        regsub {\(branch: (.*)\)} $t1 {\1} t1
        set stickytag " on $t0"
      } elseif {[string match "(revision:*" $t1 ]} {
        set stickytag " $t0"
      }
      set Filelist($filename:stickytag) "$revision $stickytag"
    } elseif {[string match "*Sticky Options:*" $logline]} {
      regsub -all {\t+} $logline "\t" logline
      set line [split [string trim $logline] "\t"]
      gen_log:log D "$line"
      set option [lindex $line 1]
      set Filelist($filename:option) $option
    }
  }
  
  if {[info exists cmd(cvs_editors)]} {
    set filename {}
    set editors {}
    $cmd(cvs_editors)\::destroy
    catch {unset cmd(cvs_editors)}
    foreach logline $editors_lines {
      set line [split $logline "\t"]
      gen_log:log D "$line"
      set ell [llength $line]
      # ? files will show up in cvs editors output under certain conditions
      if {$ell < 5} {
        continue
      }
      #if there is no filename, then this is a continuation line
      set f [lindex $line 0]
      if {$f == {}} {
        append editors ",[lindex $line 1]"
      } else {
        if {$filename != {}} {
          #set Filelist($filename:editors) $editors
          set file_editors($filename) $editorsregsub {:status$} $i "" j
        }
        set filename $f
        set editors [lindex $line 1]
      }
      gen_log:log D " $filename   $editors"
    }
    if {$filename != {}} {
      set file_editors($filename) $editors
    }
  }
  
  if {[info exists cmd(cvs_get_log)]} {
    set filename {}
    set date {}
    $cmd(cvs_get_log)\::destroy
    catch {unset cmd(cvs_get_log)}
    foreach line $cvslog_lines {
      if {[string match "Working file: *" $line]} {
        gen_log:log D "$line"
        regsub "Working file: " $line "" filename
      } elseif {[string match "*locked by:*" $line]} {
        gen_log:log D "$line"
        if {$filename != {}} {
          set p [lindex $line 4]
          set r [lindex $line 1]
          set p [string trimright $p {;}]
          gen_log:log D " $filename   $p\($r\)"
          append file_lockers($filename) "$p\($r\)"
        }
      } elseif {[string match "date:*" $line]} {
        #The date line also has the name of the author
        set parts [split $line ";"]
        foreach p $parts {
          set eqn [split $p ":"];
          set eqname [string trim [lindex $eqn 0]]
          set eqval  [string trim [join [lrange $eqn 1 end] ":"]]
          switch -exact -- $eqname {
            {date} {
              # Sometimes the date has a timezone and sometimes not.
              # In that case it's the 3rd field
              set date [lrange $eqval 0 1]
              # Sometimes it's separated by slashes and sometimes by hyphens
              regsub -all {/} $date {-} Filelist($filename:date)
              set Filelist($filename:date)
            }
            {author} {
              set file_authors($filename) $eqval
            }
          }
        }
      }
    }
  }
  foreach a [array names Filelist *:status] {
    regsub {:status$} $a "" f
    set Filelist($f:editors) ""
    # Format the date
    if [info exists Filelist($f:date)] {
      #gen_log:log D "Filelist($f:date) \"$Filelist($f:date)\""
      if {! [catch {set newdate [clock scan "$Filelist($f:date)" -format "%Y-%m-%d %H:%M:%S"]}] } {
        set Filelist($f:date) [clock format $newdate -format $cvscfg(dateformat)]
      }
    }
    #gen_log:log D " Filelist($f:date) $Filelist($f:date)"
    # String the authors, editors, and lockers into one field
    if [info exists file_authors($f)] {
      set Filelist($f:editors) $file_authors($f)
    }
    if [info exists file_lockers($f)] {
      append Filelist($f:editors) " lock:$file_lockers($f)"
    }
    if [info exists file_editors($f)] {
      append Filelist($f:editors) " editors:$file_editors($f)"
    }
  }
  # gen_log:log T "LEAVE"
}

# This deletes a file from the directory and the repository,
# asking for confirmation first.
proc cvs_remove_file {args} {
  global cvs
  global incvs
  global cvscfg
  
  # gen_log:log T "ENTER ($args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  set filelist [join $args]
  
  # Unix-remove the files
  set success 1
  set faillist ""
  foreach file $filelist {
    file delete -force -- $file
    gen_log:log F "DELETE $file"
    if {[file exists $file]} {
      set success 0
      append faillist $file
    }
  }
  if {$success == 0} {
    cvsfail "Remove $file failed" .workdir
    return
  }
  
  # cvs-remove them
  set command "$cvs remove"
  foreach f $filelist {
    append command " \"$f\""
  }
  set cmd(cvscmd) [exec::new "$command"]
  auto_setup_dir $cmd(cvscmd)
  
  # gen_log:log T "LEAVE"
}

# This removes files recursively.
proc cvs_remove_dir {args} {
  global cvs
  global incvs
  global cvscfg
  
  # gen_log:log T "ENTER ($args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select a directory!" .workdir
    return
  } else {
    set mess "This will remove the contents of these directories:\n\n"
    foreach file $filelist {
      append mess "   $file\n"
    }
  }
  
  set v [viewer::new "CVS Remove directory"]
  
  set awd [pwd]
  foreach file $filelist {
    if {[file isdirectory $file]} {
      set awd [pwd]
      cd $file
      gen_log:log F "CD [pwd]"
      rem_subdirs $v
      cd $awd
      gen_log:log F "CD [pwd]"
       
      set commandline "$cvs remove \"$file\""
      $v\::do "$commandline" 1 status_colortags
      $v\::wait
      $v\::clean_exec
    }
  }
  
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  # gen_log:log T "LEAVE"
}

# This sets the edit flag for a file, asking for confirmation first.
proc cvs_edit {args} {
  global cvs
  global incvs
  global cvscfg
  
  # gen_log:log T "ENTER ($args)"
  
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  
  set filelist [join $args]
  
  foreach file $filelist {
    regsub -all {\$} $file {\$} file
    set commandline "$cvs edit \"$file\""
    gen_log:log C "$commandline"
    set ret [catch {exec {*} $commandline} view_this]
    if {$ret != 0} {
      view_output::new "CVS Edit" $view_this
    }
  }
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  # gen_log:log T "LEAVE"
}

# Needs stdin as there is sometimes a dialog if file is modified
# (defaults to no)
proc cvs_unedit {args} {
  global cvs
  global incvs
  global cvscfg
  
  # gen_log:log T "ENTER ($args)"
  
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  set filelist [join $args]
  
  foreach file $filelist {
    # Unedit may hang asking for confirmation if file is not up-to-date
    regsub -all {\$} $file {\$} file
    set commandline "$cvs -n update \"$file\""
    gen_log:log C "$commandline"
    catch {exec {*} $commandline} view_this
    # Its OK if its locally added
    if {([llength $view_this] > 0) && ![string match "A*" $view_this] } {
      gen_log:log D "$view_this"
      cvsfail "File $file is not up-to-date" .workdir
      # gen_log:log T "LEAVE -- cvs unedit failed"
      return
    }
    
    set commandline "$cvs unedit \"$file\""
    gen_log:log C "$commandline"
    set ret [catch {exec {*}  $commandline} view_this]
    if {$ret != 0} {
      view_output::new "CVS Edit" $view_this
    }
  }
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  # gen_log:log T "LEAVE"
}

proc cvs_history {allflag mcode} {
  global cvs
  global cvscfg
  
  set all ""
  # gen_log:log T "ENTER ($allflag $mcode)"
  if {$allflag == "all"} {
    set all "-a"
  }
  if {$mcode == ""} {
    set commandline "$cvs -d $cvscfg(cvsroot) history $all"
  } else {
    set commandline "$cvs -d $cvscfg(cvsroot) history $all -n $mcode"
  }
  # FIXME: If $all, it would be nice to process the output
  set v [viewer::new "CVS History"]
  $v\::do "$commandline"
  # gen_log:log T "LEAVE"
}

# This adds a file to the repository.
proc cvs_add {binflag args} {
  global cvs
  global cvscfg
  global incvs
  
  # gen_log:log T "ENTER ($binflag $args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  set filelist [join $args]
  
  if {$filelist == ""} {
    set mess "This will add all new files"
  } else {
    set mess "This will add these files:\n\n"
    foreach file $filelist {
      append mess "   $file\n"
    }
  }
  
  set command "$cvs add $binflag"
  
  if {$filelist == ""} {
    append filelist [glob -nocomplain $cvscfg(aster) .??*]
  } else {
    foreach f $filelist {
      append command " \"$f\""
    }
  }
  set cmd(cvscmd) [exec::new "$command"]
  auto_setup_dir $cmd(cvscmd)
  
  # gen_log:log T "LEAVE"
}

# This starts adding recursively at the directory level
proc cvs_add_dir {binflag args} {
  global cvs
  global cvscfg
  global incvs
  
  # gen_log:log T "ENTER ($binflag $args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  set filelist [join $args]
  
  if {$filelist == ""} {
    cvsfail "Please select a directory!" .workdir
    return 1
  } else {
    set mess "This will recursively add these directories:\n\n"
    foreach file $filelist {
      append mess "   $file\n"
    }
  }
  
  set v [viewer::new "CVS Add directory"]
  
  set awd [pwd]
  foreach file $filelist {
    if {[file isdirectory $file]} {
      set commandline "$cvs add \"$file\""
      $v\::do "$commandline"
      $v\::wait
      $v\::clean_exec
      
      cd $file
      gen_log:log F "CD [pwd]"
      add_subdirs $binflag $v
    }
  }
  
  cd $awd
  gen_log:log F "[pwd]"
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  # gen_log:log T "LEAVE"
}

proc add_subdirs {binflag v} {
  global cvs
  global cvsglb
  global cvscfg
  
  # gen_log:log T "ENTER ($binflag $v)"
  set plainfiles {}
  foreach child  [glob -nocomplain $cvscfg(aster) .??*] {
    if [file isdirectory $child] {
      if {[regexp -nocase {^CVS$} [file tail $child]]} {
        gen_log:log D "Skipping $child"
        continue
      }
      set commandline "$cvs add \"$child\""
      $v\::do "$commandline"
      $v\::wait
      $v\::clean_exec
      
      set awd [pwd]
      cd $child
      gen_log:log F "CD [pwd]"
      add_subdirs $binflag $v
      cd $awd
      gen_log:log F "CD [pwd]"
    } else {
      lappend plainfiles $child
    }
  }
  if {[llength $plainfiles] > 0} {
    # LJZ: get local ignore file filter list
    set ignore_file_filter $cvscfg(ignore_file_filter)
    if { [ file exists ".cvsignore" ] } {
      set fileId [ open ".cvsignore" "r" ]
      while { [ eof $fileId ] == 0 } {
        gets $fileId line
        append ignore_file_filter " $line"
      }
      close $fileId
    }
    
    # LJZ: ignore files if requested in recursive add
    if { $ignore_file_filter != "" } {
      foreach item $ignore_file_filter {
        # for each pattern
        if { $item != "*" } {
          # if not "*"
          while { [set idx [lsearch $plainfiles $item]] != -1 } {
            # for each occurence, delete
            catch { set plainfiles [ lreplace $plainfiles $idx $idx ] }
          }
        }
      }
    }
    
    # LJZ: any files left after filtering?
    if {[llength $plainfiles] > 0} {
      set commandline "$cvs add $binflag $plainfiles"
      $v\::do "$commandline"
      $v\::wait
    }
  }
  
  # gen_log:log T "LEAVE"
}

proc rem_subdirs { v } {
  global cvs
  global incvs
  global cvscfg
  
  # gen_log:log T "ENTER ($v)"
  set plainfiles {}
  foreach child  [glob -nocomplain $cvscfg(aster) .??*] {
    if [file isdirectory $child] {
      if {[regexp -nocase {^CVS$} [file tail $child]]} {
        gen_log:log D "Skipping $child"
        continue
      }
      set awd [pwd]
      cd $child
      gen_log:log F "CD [pwd]"
      rem_subdirs $v
      cd $awd
      gen_log:log F "CD [pwd]"
    } else {
      lappend plainfiles $child
    }
  }
  if {[llength $plainfiles] > 0} {
    foreach file $plainfiles {
      gen_log:log F "DELETE $file"
      file delete -force -- $file
      if {[file exists $file]} {cvsfail "Remove $file failed" .workdir}
    }
  }
  
  # gen_log:log T "LEAVE"
}

# This views a specific revision of a file in the repository.
# For files checked out in the current sandbox.
proc cvs_fileview_update {revision filename} {
  global cvs
  global cvscfg
  
  # gen_log:log T "ENTER ($revision $filename)"
  if {$revision == {}} {
    set commandline "$cvs -d $cvscfg(cvsroot) update -p \"$filename\""
    set v [viewer::new "$filename"]
    $v\::do "$commandline" 0
  } else {
    set commandline "$cvs -d $cvscfg(cvsroot) update -p -r $revision \"$filename\""
    set v [viewer::new "$filename Revision $revision"]
    $v\::do "$commandline" 0
  }
  # gen_log:log T "LEAVE"
}

# This looks at a revision of a file from the repository.
# Called from Repository Browser -> File Browse -> View
# For files not currently checked out
proc cvs_fileview_checkout {revision filename} {
  global cvs
  global cvscfg
  
  # gen_log:log T "ENTER ($revision)"
  if {$revision == {}} {
    set commandline "$cvs -d $cvscfg(cvsroot) checkout -p \"$filename\""
    set v [viewer::new "$filename"]
    $v\::do "$commandline"
  } else {
    set commandline "$cvs -d $cvscfg(cvsroot) checkout -p -r $revision \"$filename\""
    set v [viewer::new "$filename Revision $revision"]
    $v\::do "$commandline"
  }
  # gen_log:log T "LEAVE"
}

# cvs log. Called from "Log" in the Reports menu.
# Uses cvscfg(recurse)
proc cvs_log {detail args} {
  global cvs
  global cvscfg
  
  # gen_log:log T "ENTER ($detail $args)"
  
  if {$args == "."} {
    set args ""
  }
  set filelist [join $args]
  
  set command "$cvs log -N"
  set flags ""
  if {! $cvscfg(recurse)} {
    set flags "-l"
  }
  
  # If verbose, output it as is
  if {$detail eq "verbose"} {
    foreach f $filelist {
      append command " \"$f\""
    }
    if {[llength $filelist] <= 1} {
      set title "CVS log $filelist ($detail)"
    } else {
      set title "CVS log ($detail)"
    }
    set v [viewer::new "$title"]
    $v\::do "$command" 0 rcslog_colortags
    return
  }
  
  # Otherwise, we still do a verbose log but we only print some things
  if {$detail eq "summary"} {
    foreach f $filelist {
      append command " \"$f\""
    }
    set v [viewer::new "CVS log ($detail)"]
    set logcmd [exec::new "$command"]
    set log_lines [split [$logcmd\::output] "\n"]
    foreach logline $log_lines {
      # Beginning of a file's record
      if {[string match "Working file:*" $logline]} {
        $v\::log "==============================================================================\n" patched
        $v\::log "$logline\n" patched
      } elseif {[string match "----------------------------" $logline]} {
        $v\::log "$logline\n" patched
      } elseif {[string match "revision *"  $logline]} {
        $v\::log "$logline"
      } elseif {[string match "date:*"  $logline]} {
        regsub {;\s+state.*$} $logline {} info
        $v\::log "  $info\n"
      }
    }
  } elseif {$detail eq "latest"} {
    foreach f $filelist {
      append command " \"$f\""
    }
    set v [viewer::new "CVS log ($detail)"]
    set logcmd [exec::new "$command"]
    set log_lines [split [$logcmd\::output] "\n"]
    set br 0
    while {[llength $log_lines] > 0} {
      set logline [join [lrange $log_lines 0 0]]
      set log_lines [lrange $log_lines 1 end]
      
      # Beginning of a file's record
      if {[string match "Working file:*" $logline]} {
        $v\::log "$logline\n" patched
        while {[llength $log_lines] > 0} {
          set log_lines [lrange $log_lines 1 end]
          set logline [join [lrange $log_lines 0 0]]
          #gen_log:log D " ! $logline !"
          
          # Reason to skip
          if {[string match "*selected revisions: 0" $logline]} {
            $v\::log "No revisions on branch\n"
            $v\::log "==============================================================================\n" patched
            #set br 0
            break
          }
          # Beginning of a revision
          if {[string match "----------------------------" $logline]} {
            #gen_log:log D "  !! $logline !!"
            #$v\::log "$logline\n"
            while {[llength $log_lines] > 0} {
              set log_lines [lrange $log_lines 1 end]
              set logline [join [lrange $log_lines 0 0]]
              #gen_log:log D "        $logline"
              if { [string match "========================*" $logline] ||
                [string match "--------------*" $logline]} {
                $v\::log "==============================================================================\n" patched
                set br 1
                break
              } else {
                $v\::log "$logline\n"
              }
            }
          }
          # If we broke out of the inside loop, break out of this one too
          if {$br == 1} {set br 0; break}
        }
      }
    }
  }
  
  # gen_log:log T "LEAVE"
}

# called from the branch browser
proc cvs_log_rev {rev filename} {
  global cvs
  
  # gen_log:log T "ENTER ($rev $filename)"
  
  set title "CVS log"
  set commandline "$cvs log -N"
  if {$rev ne ""} {
    append commandline " -r:$rev"
    append title " -r:$rev"
  }
  append commandline " \"$filename\""
  append title " $filename"
  
  set logcmd [viewer::new "$title"]
  $logcmd\::do "$commandline" 0 rcslog_colortags
  
  # gen_log:log T "LEAVE"
}

# annotate/blame. Called from workdir
proc cvs_annotate {revision args} {
  global cvs
  global cvscfg
  
  # gen_log:log T "ENTER ($revision $args)"
  
  set filelist [join $args]
  
  if {$revision == "trunk"} {
    set revision ""
  }
  if {$revision != ""} {
    set revflag "-r$revision"
  } else {
    set revflag ""
  }
  
  if {$filelist == ""} {
    cvsfail "Annotate:\nPlease select one or more files !" .workdir
    # gen_log:log T "LEAVE (Unselected files)"
    return
  }
  foreach f $filelist {
    annotate::new $revflag "$f" "cvs"
  }
  # gen_log:log T "LEAVE"
}

# annotate/blame. Called from logcanvas
proc cvs_annotate_r {revision filename} {
  global cvs
  global cvscfg
  
  # gen_log:log T "ENTER ($revision $filename)"
  
  if {$revision != ""} {
    # We were given a revision
    set revflag "-r$revision"
  } else {
    set revflag ""
  }
  
  annotate::new $revflag "$filename" "cvs_r"
  # gen_log:log T "LEAVE"
}

# Commit changes to the repository.
#  The parameters work differently here -- args is a list. The first
#  element of args is a list of file names.  This is because I can't
#  use eval on the parameters, because comment contains spaces.
proc cvs_commit {revision comment args} {
  global cvs
  global cvscfg
  global incvs
  
  # gen_log:log T "ENTER ($revision $comment $args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  
  set filelist [join $args]
  
  # changed the message to be a little more explicit.  -sj
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
  
  set revflag ""
  if {$revision != ""} {
    set revflag "-r $revision"
  }
  
  if {$cvscfg(use_cvseditor)} {
    # Starts text editor of your choice to enter the log message.
    # This way a template in CVSROOT can be used.
    update idletasks
    set commandline "$cvscfg(terminal) $cvs commit -R $revflag"
    foreach f $filelist {
      append commandline " \"$f\""
    }
    gen_log:log C "$commandline"
    set ret [catch {exec {*} $commandline} view_this]
    if {$ret} {
      cvsfail $view_this .workdir
      # gen_log:log T "LEAVE ERROR ($view_this)"
      return
    }
  } else {
    if {$comment == ""} {
      cvsfail "You must enter a comment!" .commit
      return 1
    }
    set v [viewer::new "CVS Commit"]
    regsub -all "\"" $comment "\\\"" comment
    set commandline "$cvs commit -R $revflag -m \"$comment\""
    foreach f $filelist {
      append commandline " \"$f\""
    }
    # Lets not show stderr as it does a lot of "examining"
    $v\::do "$commandline" 0
    $v\::wait
  }
  
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  # gen_log:log T "LEAVE"
}

# This tags a file in a directory.
proc cvs_tag {tagname force b_or_t updflag args} {
  global cvs
  global cvscfg
  global cvsglb
  global incvs
  
  # gen_log:log T "ENTER ($tagname $force $b_or_t $updflag $args)"
  
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  
  if {$tagname == ""} {
    cvsfail "Please enter a tag name!" .workdir
    return 1
  }
  
  set filelist [join $args]
  
  set command "$cvs tag"
  if {$b_or_t == "branch"} {
    append command " -b"
  }
  if {$force == "yes"} {
    append command " -F"
  }
  append command " $tagname"
  foreach f $filelist {
    append command " \"$f\""
  }
  # In new dialog, this isn't supposed to happen, but let's check anyway
  if {$b_or_t == "branch" && $force == "yes"} {
    cvsfail "Moving a branch tag isn't allowed" .workdir
    return
  }
  
  # If it refuses to tag, it can exit with 0 but still put out some stderr
  set v [viewer::new "CVS Tag"]
  $v\::do "$command" 1
  $v\::wait
  
  if {$updflag == "yes"} {
    # update so we're on the branch
    set command "$cvs update -r $tagname"
    foreach f $filelist {
      append command " \"$f\""
    }
    $v\::do "$command" 0 status_colortags
    $v\::wait
  }
  
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  # gen_log:log T "LEAVE"
}

# This updates the files in the current directory.
proc cvs_update {tagname k no_tag recurse prune d dir args} {
  global cvs
  global cvscfg
  global incvs
  
  # gen_log:log T "ENTER (tagname=$tagname k=$k no_tag=$no_tag recurse=$recurse prune=$prune d=$d dir=$dir args=$args)"
  
  # Because this is called from an eval, the args aren't a list
  foreach a $args {
    append filelist $a
  }
  #
  # cvs update [-APCdflRp] [-k kopt] [-r rev] [-D date] [-j rev]
  #
  set commandline "$cvs update"
  
  if { $k == "Normal" } {
    set kmsg "\nUsing normal (text) mode."
  } elseif { $k == "Binary" } {
    set kmsg "\nUsing binary mode (-kb)."
    append commandline " -kb"
  }
  if { $tagname == "HEAD" } {
    append mess "\nYour local files will be updated to the"
    append mess " latest main trunk (head) revision (-A)."
    append commandline " -A"
  }
  
  if {$recurse == "local"} {
    append commandline " -l"
  } else {
    append mess "\nIf there is a local sub-directory which has"
    append mess " become empty through deletion of its contents,"
    if { $prune == "prune" } {
      append mess " it will be deleted (-P).\n"
      append commandline " -P"
    } else {
      append mess " it will remain.\n"
    }
    append mess "\nIf there is a sub-directory in the repository"
    append mess " that is not here in your local directory,"
    if { $d == "Yes" } {
      append mess " it will be checked out at this time (-d).\n"
      if {$dir ne " "} {
        append mess "($dir only)\n"
      }
      append commandline " -d \"$dir\""
    } else {
      append mess " it will not be checked out.\n"
    }
  }
  
  if { $tagname ne "BASE" && $tagname ne "HEAD" } {
    append mess "\nYour local files will be updated to the"
    append mess " tagged revision (-r $tagname)."
    append mess "  If a file does not have the tag,"
    if { $no_tag eq "Remove" } {
      append mess " it will be removed from your local directory.\n"
      append commandline " -r $tagname"
    } elseif { $no_tag == "Get_head" } {
      append mess " the head revision will be retrieved.\n"
      append commandline " -f -r $tagname"
    }
  }
  
  if {$filelist eq ""} {
    set filemsg    "\nYou are about to download from"
    append filemsg " the repository to your local"
    append filemsg " filespace the files which"
    append filemsg " are different in the repository,"
    if {$recurse == "local"} {
      append filemsg " in this directory only.\n"
    } else {
      append filemsg " recursing the sub-directories.\n"
    }
  } else {
    append filemsg "\nYou are about to download from"
    append filemsg " the repository to your local"
    append filemsg " filespace these files if they"
    append filemsg " have changed:\n"
    foreach f $filelist {
      append commandline " \"$f\""
      #regsub -all {\s+} $f {\ } ftext
      append filemsg "\n\t$f"
    }
  }
  append filemsg "\nIf you have made local changes, they will"
  append filemsg " be merged into the new local copy.\n"
  set mess "$filemsg $mess $kmsg"
  append mess "\n\nAre you sure?"
  
  if {[cvsconfirm $mess .workdir] eq "ok"} {
    set co_cmd [viewer::new "CVS Update"]
    $co_cmd\::do "$commandline" 0 status_colortags
    auto_setup_dir $co_cmd
  }
  # gen_log:log T "LEAVE"
}

# Do what was setup in the "Update with Options" dialog
proc cvs_opt_update {} {
  global cvsglb
  
  # gen_log:log T "ENTER"
  
  set command "cvs_update"
  if { $cvsglb(updatename) == "" } {
    set tagname "BASE"
  } else {
    set tagname $cvsglb(updatename)
  }
  
  if { $cvsglb(get_all_dirs) == "No" } { set cvsglb(getdirname) "" }
  if { $cvsglb(getdirname) == "" } {
    set dirname " "
  } else {
    set dirname $cvsglb(getdirname)
  }
  
  if { $cvsglb(tagmode_selection) == "Keep" } {
    set tagname "BASE"
  } elseif { $cvsglb(tagmode_selection) == "Trunk" } {
    set tagname "HEAD"
  }
  append command " $tagname"
  append command " {$cvsglb(norm_bin)} {$cvsglb(action_notag)} {$cvsglb(update_recurse)} {$cvsglb(update_prune)} {$cvsglb(get_all_dirs)}"
  append command " \"$dirname\""
  
  set filenames [workdir_list_files]
  foreach f $filenames {
    append command " \"$f\""
  }
  gen_log:log C "$command"
  eval "$command"
  
  # gen_log:log T "LEAVE"
}

# join (merge) a chosen revision of local file to the current revision.
proc cvs_merge {parent from since frombranch args} {
  global cvs
  global cvscfg
  global cvsglb
  
  # gen_log:log T "ENTER (\"$from\" \"$since\" \"$frombranch\" \"$args\")"
  gen_log:log D "mergetrunkname $cvscfg(mergetrunkname)"
  
  # Bug # 3434817
  # there's an annoying bug in merging: the ending revision is ignored.
  # Example: there are revisions 1.1, 1.2, 1.3, 1.4 and 1.5 (HEAD). You are on
  # a branch made from rev 1.1 and want to merge revisions 1.2 to 1.4. When you
  # click in the merge diagram left mouse on 1.4, right mouse on 1.2 and click
  # Diff it will correctly use the following command:
  #  /usr/bin/tkdiff -r "1.4" -r "1.2" "Filename.ext"
  # However, when you leave the revision selection as-is and click the Merge
  # the following command is used:
  #  cvs update -d -j1.2 -jHEAD Filename.ext
  # Obviously the second "-j" parameter is wrong, there should have been "-j1.4".
  
  #set realfrom "$frombranch"
  #if {$frombranch eq $cvscfg(mergetrunkname)} {
  #set realfrom "HEAD"
  #}
  
  set filelist [join $args]
  
  set mergetags [assemble_mergetags $frombranch]
  set curr_tag [lindex $mergetags 0]
  set fromtag [lindex $mergetags 1]
  set totag [lindex $mergetags 2]
  
  if {$since == {}} {
    set mess "Merge revision $from\n"
  } else {
    set mess "Merge the changes between revision\n $since and $from"
    append mess " (if $since > $from the changes are removed)\n"
  }
  append mess " to the current revision ($curr_tag)"
  if {[cvsalwaysconfirm $mess $parent] != "ok"} {
    return
  }
  
  set commandline "$cvs update -d"
  # Do the update here, and defer the tagging until later
  if {$since == {}} {
    append commandline " -j$from"
  } else {
    append commandline " -j$since -j$from"
  }
  foreach f $filelist {
    append commandline " \"$f\""
  }
  set v [viewer::new "CVS Join"]
  $v\::do "$commandline" 1 status_colortags
  $v\::wait
  
  if [winfo exists .workdir] {
    if {$cvscfg(auto_status)} {
      setup_dir
    }
  } else {
    workdir_setup
  }
  
  dialog_merge_notice cvs $from $frombranch $fromtag $totag $filelist
  
  # gen_log:log T "LEAVE"
}

# Commit and tag a merge
proc cvs_merge_tag_seq {from frombranch totag fromtag args} {
  global cvs
  global cvscfg
  
  # gen_log:log T "ENTER (\"$from\" \"$totag\" \"$fromtag\" $args)"
  
  set filelist [join $args]
  set realfrom "$frombranch"
  if {$frombranch eq $cvscfg(mergetrunkname)} {
    set realfrom "HEAD"
  }
  
  # Do an update first, to make sure everything is OK at this point
  set commandline "$cvs -n -q update"
  foreach f $filelist {
    append commandline " \"$f\""
  }
  gen_log:log C "$commandline"
  set ret [catch {exec {*} $commandline} view_this]
  set logmode [expr {$ret ? {E} : {D}}]
  view_output::new "CVS Check" $view_this
  gen_log:log $logmode $view_this
  if {$ret} {
    set mess "CVS Check shows errors which would prevent a successful\
        commit. Please resolve them before continuing."
    if {[cvsalwaysconfirm $mess .workdir] != "ok"} {
      return
    }
  }
  # Do the commit
  set commandline "$cvs commit -m \"Merge from $from\""
  foreach f $filelist {
    append commandline " \"$f\""
  }
  set v [viewer::new "CVS Commit and Tag a Merge"]
  $v\::log "$commandline\n"
  $v\::do "$commandline" 1
  $v\::wait
  # Tag if desired
  if {$cvscfg(auto_tag) && $totag != ""} {
    # First, the "from" file that's not in this branch (needs -r)
    set commandline "$cvs tag -F -r$realfrom $totag"
    foreach f $filelist {
      append commandline " \"$f\""
    }
    $v\::log "$commandline\n"
    $v\::do "$commandline" 1
    $v\::wait
  }
  if {$cvscfg(auto_tag) && $fromtag != ""} {
    # Now, the version that's in the current branch
    set commandline "$cvs tag -F $fromtag"
    foreach f $filelist {
      append commandline " \"$f\""
    }
    $v\::log "$commandline\n"
    $v\::do "$commandline" 1
    $v\::wait
  }
  catch {destroy .reminder}
  
  if {$cvscfg(auto_status)} {
    setup_dir
  }
}

# cvs status. Called from "Status" in the Reports menu.
# Uses cvscfg(recurse)
proc cvs_status {detail args} {
  global cvs
  global cvscfg
  
  # gen_log:log T "ENTER ($detail $args)"
  
  if {$args == "."} {
    set args ""
  }
  
  set filelist [join $args]
  
  set flags ""
  if {! $cvscfg(recurse)} {
    set flags "-l"
  }
  
  # support verious levels of verboseness.
  set command  "$cvs -Q status $flags"
  foreach f $filelist {
    append command " \"$f\""
  }
  set statcmd [exec::new "$command"]
  set raw_status [$statcmd\::output]
  $statcmd\::destroy
  
  if {$detail == "verbose"} {
    view_output::new "CVS Status ($detail)" $raw_status
  } else {
    set cooked_status ""
    set stat_lines [split $raw_status "\n"]
    foreach statline $stat_lines {
      if {[string match "*Status:*" $statline]} {
        gen_log:log D "$statline"
        if {$detail == "terse" && \
              [string match "*Up-to-date*" $statline]} {
          continue
        } else {
          regsub {\s+no file } $statline { } statline
          regsub {^File:\s+} $statline {} statline
          regsub {Status:\s+} $statline " " statline
          regsub {Locally Removed} $statline "  Locally Removed" statline
          # FIXME why do the tabs disappear?
          #regsub {\s+} $statline "\t" statline
          append cooked_status "$statline\n"
        }
      }
    }
    view_output::new "CVS Status ($detail)" $cooked_status
  }
  
  busy_done .workdir.main
  # gen_log:log T "LEAVE"
}

# called from the "Check Directory" button in the workdir and Reports menu
proc cvs_check {} {
  global cvs
  global cvscfg
  
  # gen_log:log T "ENTER ()"
  
  busy_start .workdir.main
  set title "CVS Directory Check"
  set flags ""
  if {$cvscfg(recurse)} {
    append title " (recursive)"
  } else {
    append flags "-l"
    append title " (toplevel)"
  }
  set commandline "$cvs -n -q update $flags"
  set check_cmd [viewer::new $title]
  $check_cmd\::do $commandline 1 status_colortags
  
  busy_done .workdir.main
  # gen_log:log T "LEAVE"
}

# Check out a cvs module from the module browser
proc cvs_checkout { cvsroot prune kflag revtag date target mtag1 mtag2 module } {
  global cvs
  global cvscfg
  global incvs insvn inrcs ingit
  
  # gen_log:log T "ENTER ($cvsroot $prune $kflag $revtag $date $target $mtag1 $mtag2 $module)"
  
  set dir [pwd]
  if {[file pathtype $target] eq "absolute"} {
    set tgt $target
  } else {
    set tgt "$dir/$target"
  }
  set mess "This will checkout\n\
     $cvsroot/$module\n\
     to directory\n\
     $tgt\n\
      Are you sure?"
  if {[cvsconfirm $mess .modbrowse] == "ok"} {
    if {$revtag != {}} {
      set revtag "-r \"$revtag\""
    }
    if {$date != {}} {
      set date "-D \"$date\""
    }
    if {$target != {}} {
      set target "-d \"$target\""
    }
    if {$mtag1 != {}} {
      set mtag1 "-j \"$mtag1\""
    }
    if {$mtag2 != {}} {
      set mtag2 "-j \"$mtag2\""
    }
    set v [viewer::new "CVS Checkout"]
    $v\::do "$cvs -d \"$cvsroot\" checkout $prune\
             $revtag $date $target\
             $mtag1 $mtag2\
        $kflag \"$module\""
  }
  # gen_log:log T "LEAVE"
  return
}

# This looks at the revision log of a file.  It's called from filebrowse.tcl,
# so we can't do operations such as merges.
proc cvs_filelog {filename parent {graphic {0}} } {
  global cvs
  global cvsglb
  global cwd
  
  # gen_log:log T "ENTER ($filename $parent $graphic)"
  set pid [pid]
  set filetail [file tail $filename]
  
  set commandline "$cvs -d $cvsglb(root) checkout \"$filename\""
  gen_log:log C "$commandline"
  set ret [cvs_sandbox_runcmd "$commandline" cmd_output]
  if {$ret == $cwd} {
    cvsfail $cmd_output $parent
    cd $cwd
    # gen_log:log T "LEAVE -- cvs checkout failed"
    return
  }
  
  if {$graphic} {
    # Log canvas viewer
    ::cvs_branchlog::new "CVS,rep" $filename
  } else {
    set commandline "$cvs -d $cvsglb(root) log \"$filename\""
    set logcmd [viewer::new "CVS log $filename"]
    $logcmd\::do "$commandline" 0 rcslog_colortags
    $logcmd\::wait
  }
  cd $cwd
  # gen_log:log T "LEAVE"
}

# This exports a new module (see man cvs and read about export) into
# the target directory.
proc cvs_export { cvsroot kflag revtag date target module } {
  global cvs
  global cvscfg
  global incvs insvn inrcs ingit
  
  # gen_log:log T "ENTER ($cvsroot $kflag $revtag $date $target $module)"
  
  set dir [pwd]
  if {[file pathtype $target] eq "absolute"} {
    set tgt $target
  } else {
    set tgt "$dir/$target"
  }
  set mess "This will export\n\
     $cvsroot/$module\n\
     to directory\n\
     $tgt\n\
      Are you sure?"
  if {[cvsconfirm $mess .modbrowse] == "ok"} {
    if {$revtag != {}} {
      set revtag "-r \"$revtag\""
    }
    if {$date != {}} {
      set date "-D \"$date\""
    }
    if {$target != {}} {
      set target "-d \"$target\""
    }
    
    set v [::viewer::new "CVS Export"]
    set cwd [pwd]
    $v\::do "$cvs -d \"$cvsroot\" export\
        $revtag $date $target $kflag \"$module\""
  }
  # gen_log:log T "LEAVE"
  return
}

# This creates a patch file between two revisions of a module.  If the
# second revision is null, it creates a patch to the head revision.
# If both are null the top two revisions of the file are diffed.
proc cvs_patch { cvsroot module difffmt revtagA dateA revtagB dateB outmode outfile } {
  global cvs
  global cvscfg
  
  # gen_log:log T "ENTER ($cvsroot $module $difffmt \"$revtagA\" \"$dateA\" \"$revtagB\" \"$dateB\" $outmode $outfile)"
  
  lassign {{} {}} rev1 rev2
  if {$revtagA != {}} {
    set rev1 "-r \"$revtagA\""
  } elseif {$dateA != {}} {
    set rev1 "-D \"$dateA\""
  }
  if {$revtagB != {}} {
    set rev2 "-r \"$revtagB\""
  } elseif {$dateA != {}} {
    set rev2 "-D \"$dateB\""
  }
  if {$rev1 == {} && $rev2 == {}} {
    set rev1 "-t"
  }
  
  set commandline "$cvs -d \"$cvsroot\" patch $difffmt $rev1 $rev2 \"$module\""
  
  if {$outmode == 0} {
    set v [viewer::new "CVS Patch"]
    $v\::do "$commandline" 0 patch_colortags
  } else {
    set e [exec::new "$commandline"]
    set patch [$e\::output]
    gen_log:log F "OPEN $outfile"
    if {[catch {set fo [open $outfile w]}]} {
      cvsfail "Cannot open $outfile for writing" .modbrowse
      return
    }
    puts $fo $patch
    close $fo
    gen_log:log F "CLOSE $outfile"
  }
  # gen_log:log T "LEAVE"
  return
}

# This finds the current CVS version number.
proc cvs_version {} {
  global cvs
  global cvscfg
  global cvsglb
  
  # gen_log:log T "ENTER"
  set cvsglb(cvs_version) ""
  
  set commandline "$cvs -v"
  gen_log:log C "$commandline"
  set ret [catch {exec {*} $commandline} output]
  if {$ret} {
    cvsfail $output
    return
  }
  foreach infoline [split $output "\n"] {
    if {[string match "Concurrent*" $infoline]} {
      set lr [split $infoline]
      set species [lindex $lr 3]
      regsub -all {[()]} $species {} species
      set version [lindex $lr 4]
      gen_log:log D "species $species   version $version"
    }
  }
  gen_log:log D "Split: $species $version"
  regsub -all {\s*} $version {} version
  gen_log:log D "De-whitespaced: $species $version"
  set cvsglb(cvs_type) $species
  set cvsglb(cvs_version) $version
  
  # gen_log:log T "LEAVE"
}

proc cvs_reconcile_conflict {args} {
  global cvscfg
  global cvs
  
  # gen_log:log T "ENTER ($args)"
  
  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select some files to merge first!"
    return
  }
  
  foreach file $filelist {
    # Make sure its really a conflict - tkdiff will bomb otherwise
    regsub -all {\$} $file {\$} filename
    set commandline "$cvs -n -q update \"$filename\""
    gen_log:log C "$commandline"
    set ret [catch {exec {*} $commandline} status]
    set logmode [expr {$ret ? {E} : {D}}]
    gen_log:log $logmode "$status"
    
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
    
    if { [string match "C *" $status] } {
      # If its marked "Needs Merge", we have to update before
      # we can resolve the conflict
      gen_log:log C "$commandline"
      set commandline "$cvs update \"$file\""
      set ret [catch {exec {*} $commandline} status]
      set logmode [expr {$ret ? {E} : {D}}]
      gen_log:log $logmode "$status"
    } elseif { $match == 1 } {
      # There are conflict markers already, dont update
      ;
    } else {
      cvsfail "$file does not appear to have a conflict." .workdir
      continue
    }
    # Invoke tkdiff with the proper option for a conflict file
    set tkdiff_command "$cvscfg(tkdiff) -conflict -o \"$filename\" \"$filename\""
    gen_log:log C "$tkdiff_command"
    catch {exec {*} $tkdiff_command &} view_this
  }
  
  # gen_log:log T "LEAVE"
}

proc cvs_gettaglist {filename parent} {
  global cvs
  global cvscfg
  global cwd
  
  set keepers ""
  set pid [pid]
  # gen_log:log T "ENTER ($filename)"
  set filetail [file tail $filename]
  
  set commandline "$cvs -d $cvscfg(cvsroot) checkout \"$filename\""
  # run a command, possibly creating the sandbox to play in
  set ret [cvs_sandbox_runcmd $commandline cmd_output]
  if {$cwd == $ret} {
    cvsfail $cmd_output $parent
    cd $cwd
    # gen_log:log T "LEAVE ERROR ($cmd_output)"
    return $keepers
  }
  
  set commandline "$cvs -d $cvscfg(cvsroot) log \"$filename\""
  gen_log:log C "$commandline"
  set ret [catch {exec {*} $commandline} view_this]
  if {$ret} {
    cvsfail $view_this $parent
    cd $cwd
    # gen_log:log T "LEAVE ERROR"
    return $keepers
  }
  set view_lines [split $view_this "\n"]
  set c 0
  set l [llength $view_lines]
  foreach line $view_lines {
    if {[string match "symbolic names:" $line]} {
      gen_log:log D "line $c $line"
      for {set b [expr {$c + 1}]} {$b <= $l} {incr b} {
        set nextline [lindex $view_lines $b]
        if {[string index $nextline 0] == "\t" } {
          set nextline [string trimleft $nextline]
          gen_log:log D "$nextline"
          append keepers "$nextline\n"
        } else {
          gen_log:log D "$nextline - quitting"
          break
        }
      }
    }
    incr c
  }
  if {$keepers == ""} {
    set keepers "No Tags"
  }
  
  cd $cwd
  # gen_log:log T "LEAVE"
  return "$keepers"
}

proc cvs_release {delflag args} {
  global cvs
  global cvscfg
  
  # gen_log:log T "ENTER ($args)"
  set filelist [join $args]
  
  foreach directory $filelist {
    if {! [file isdirectory $directory]} {
      cvsfail "$directory is not a directory" .workdir
      return
    }
    # We're in the level above the directory to be released, so we don't necessarily
    # know its root
    read_cvs_dir "$directory/CVS"
    gen_log:log D "$directory: CVSROOT=$cvscfg(cvsroot)"
    
    set commandline "$cvs -d $cvscfg(cvsroot) -n -q update \"$directory\""
    gen_log:log C "$commandline"
    set ret [catch {exec {*} $commandline} view_this]
    if {$view_this != ""} {
      view_output::new "CVS Check" $view_this
      set mess "\"$directory\" is not up-to-date."
      append mess "\nRelease anyway?"
      if {[cvsconfirm $mess .workdir] != "ok"} {
        return
      }
    }
    set commandline "$cvs -d $cvscfg(cvsroot) -Q release $delflag \"$directory\""
    set ret [catch {exec {*} $commandline} view_this]
    gen_log:log C "$commandline"
    if {$ret != 0} {
      view_output::new "CVS Release" $view_this
    }
  }
  
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  # gen_log:log T "LEAVE"
}

proc cvs_rtag { cvsroot mcode b_or_t force oldtag newtag } {
  #
  # This tags a module in the repository.
  # Called by the tag commands in the Repository Browser
  #
  global cvs
  global cvscfg
  
  # gen_log:log T "ENTER ($cvsroot $mcode $b_or_t $force $oldtag $newtag)"
  
  set command "$cvs -d \"$cvsroot\" rtag"
  if {$force == "remove"} {
    if {$oldtag == ""} {
      cvsfail "Please enter an Old tag name!" .modbrowse
      return 1
    }
    append command " -d \"$oldtag\" \"$mcode\""
  } else {
    if {$newtag == ""} {
      cvsfail "Please enter a New tag name!" .modbrowse
      return 1
    }
    if {$b_or_t == "branch"} {
      append command " -b"
    }
    if {$force == "yes"} {
      append command " -F"
    }
    if {$oldtag != ""} {
      append command " -r \"$oldtag\""
    }
    append command " \"$newtag\" \"$mcode\""
  }
  
  set v [::viewer::new "CVS Rtag"]
  $v\::do "$command"
  
  # gen_log:log T "LEAVE"
}

# dialog for cvs commit - called from workdir browser
proc cvs_commit_dialog {} {
  global incvs
  global cvsglb
  global cvscfg
  
  # gen_log:log T "ENTER"
  
  if {! $incvs} {
    cvs_notincvs
    # gen_log:log T "LEAVE"
    return
  }
  
  # If marked files, commit these.  If no marked files, then
  # commit any files selected via listbox selection mechanism.
  # The cvsglb(commit_list) list remembers the list of files
  # to be committed.
  set cvsglb(commit_list) [workdir_list_files]
  
  # If we want to use an external editor, just do it
  if {$cvscfg(use_cvseditor)} {
    cvs_commit "" "" $cvsglb(commit_list)
    return
  }
  
  if {[winfo exists .commit]} {
    destroy .commit
  }
  
  toplevel .commit
  #grab set .commit
  
  frame .commit.top -border 8
  frame .commit.vers
  frame .commit.down -relief groove -border 2
  
  pack .commit.top -side top -fill x
  pack .commit.down -side bottom -fill x
  pack .commit.vers -side top -fill x
  
  label .commit.lvers -text "Specify Revision (-r) (usually ignore)" \
      -anchor w
  entry .commit.tvers -relief sunken -textvariable version
  
  pack .commit.lvers .commit.tvers -in .commit.vers \
      -side left -fill x -pady 3
  
  frame .commit.comment
  pack .commit.comment -side top -fill both -expand 1
  label .commit.comment.lcomment -text "Your log message" -anchor w
  button .commit.comment.history -text "Log History" \
      -command history_browser
  text .commit.comment.tcomment -relief sunken -width 70 -height 10 \
      -bg $cvsglb(textbg) -exportselection 1 \
      -wrap word -border 2 -setgrid yes
  
  
  # Explain what it means to "commit" files
  message .commit.message -justify left -aspect 500 -relief groove -bd 2 \
    -text "This will commit changes from your \
           local, working directory into the repository, recursively.

\
          For any local (sub)directories or files that are on a branch, \
           your changes will be added to the end of that branch.  \
           This includes new or deleted files as well as modifications.

\
          For any local (sub)directories or files that have \
           a non-branch tag, a branch will be created, and \
           your changes will be placed on that branch.  (CVS bug.) \

\
          For all other (sub)directories, your changes will be \
      added to the end of the main trunk."
  
  pack .commit.message -in .commit.top -padx 2 -pady 5
  
  button .commit.ok -text "OK" \
      -command {
    #grab release .commit
    wm withdraw .commit
    set cvsglb(commit_comment) [string trimright [.commit.comment.tcomment get 1.0 end]]
    cvs_commit $version $cvsglb(commit_comment) $cvsglb(commit_list)
    commit_history $cvsglb(commit_comment)
  }
  button .commit.apply -text "Apply" \
      -command {
    set cvsglb(commit_comment) [string trimright [.commit.comment.tcomment get 1.0 end]]
    cvs_commit $version $cvsglb(commit_comment) $cvsglb(commit_list)
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
  .commit.comment.tcomment insert end [string trimright $cvsglb(commit_comment)]
  
  wm title .commit "Commit Changes"
  wm minsize .commit 1 1
  
  # gen_log:log T "LEAVE"
}

# This changes a binary flag to ASCII
proc cvs_ascii { args } {
  global cvs
  global cvscfg
  global incvs
  global cvsglb
  
  # gen_log:log T "ENTER ($args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  set filelist [join $args]
  
  gen_log:log D "Changing sticky flag"
  set command "$cvs admin -kkv"
  foreach f $filelist {
    append command " \"$f\""
  }
  set cmd(cvscmd) [exec::new "$command"]
  auto_setup_dir $cmd(cvscmd)
  
  # gen_log:log T "LEAVE"
}

# This converts an ASCII file to binary
proc cvs_binary {args} {
  global cvs
  global cvscfg
  global incvs
  global cvsglb
  
  # gen_log:log T "ENTER ($args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  set filelist [join $args]
  
  gen_log:log D "Changing sticky flag"
  set command "$cvs admin -kb"
  foreach f $filelist {
    append command " \"$f\""
  }
  set cmd(cvscmd) [exec::new "$command"]
  auto_setup_dir $cmd(cvscmd)
  
  # gen_log:log T "LEAVE"
}

# Revert a file to checked-in version by removing the local
# copy and updating it
proc cvs_revert {args} {
  global incvs
  global cvscfg
  global cvsglb
  global cvs
  
  # gen_log:log T "ENTER ($args)"
  set filelist [join $args]
  
  if {$filelist == ""} {
    set mess "This will revert (discard) your changes to ** ALL ** files in this directory"
  } else {
    foreach file $filelist {
      append revert_output "\n$file"
    }
    set mess "This will revert (discard) your changes to:$revert_output"
  }
  append mess "\n\nAre you sure?"
  
  if {[cvsconfirm $mess .workdir] != "ok"} {
    return 1
  }
  
  gen_log:log D "Reverting $filelist"
  # update -C option appeared in 1.11
  set versionsplit [split $cvsglb(cvs_version) {.}]
  set major [lindex $versionsplit 1]
  set command "$cvs update"
  if {$major < 11} {
    gen_log:log F "DELETE $filelist"
    file delete $filelist
  } else {
    append command " -C"
  }
  foreach f $filelist {
    append command " \"$f\""
  }
  set cmd(cvscmd) [exec::new "$command"]
  
  
  auto_setup_dir $cmd(cvscmd)
  
  # gen_log:log T "LEAVE"
}

# Reads a CVS "bookkeeping" directory
proc read_cvs_dir {dirname} {
  global module_dir
  global cvscfg
  global cvsglb
  global cvs
  global current_tagname
  
  # gen_log:log T "ENTER ($dirname)"
  if {$cvsglb(cvs_version) == ""} {
    cvs_version
  }
  set current_tagname "trunk"
  if {[file isdirectory $dirname]} {
    if {[file isfile [file join $dirname Repository]]} {
      gen_log:log F "OPEN CVS/Repository"
      set f [open [file join $dirname Repository] r]
      gets $f module_dir
      close $f
      gen_log:log D "  MODULE $module_dir"
      if {[file isfile [file join $dirname Root]]} {
        gen_log:log F "OPEN CVS/Root"
        set f [open [file join $dirname Root] r]
        gets $f cvscfg(cvsroot)
        close $f
        # On a PC, the cvsroot can be like C:\DosRepository.
        # This makes that workable.
        regsub -all {\\} $cvscfg(cvsroot) {\\\\} cvscfg(cvsroot)
        gen_log:log D " cvsroot: $cvscfg(cvsroot)"
      }
      if {[file isfile [file join $dirname Tag]]} {
        gen_log:log F "OPEN CVS/Tag"
        set f [open [file join $dirname Tag] r]
        gets $f current_tagname
        close $f
        # T = branch tag, N = non-branch, D = sticky date
        set current_tagname [string range $current_tagname 1 end]
        gen_log:log D "  BRANCH TAG $current_tagname"
      }
    } else {
      cvsfail "Repository file not found in $dirname" .workdir
      return 0
    }
  } else {
    cvsfail "$dirname is not a directory" .workdir
    return 0
  }
  set cvsglb(vcs) cvs
  set cvsglb(root) $cvscfg(cvsroot)
  
  # gen_log:log T "LEAVE (1)"
  return 1
}

# For the module browser. Reads CVSROOT/modules
proc parse_cvsmodules {cvsroot} {
  global cvs
  global modval
  global modtitle
  global cvscfg
  
  # gen_log:log T "ENTER ($cvsroot)"
  
  # Clear the arrays
  catch {unset modval}
  catch {unset modtitle}
  
  # We have to use cvs to access the modules file
  set cvscfg(cvsroot) $cvsroot
  set command "$cvs -d \"$cvsroot\" checkout -p CVSROOT/modules"
  set cmd(cvs_co) [exec::new $command]
  if {[info exists cmd(cvs_co)]} {
    set cat_modules_file [$cmd(cvs_co)\::output]
    $cmd(cvs_co)\::destroy
    catch {unset cmd(cvs_co)}
  }
  
  # Unescape newlines, compress repeated whitespace, and remove blank lines
  regsub -all {(\\\n|[ \t])+} $cat_modules_file " " cat_modules_file
  regsub -all {\n\s*\n+} $cat_modules_file "\n" cat_modules_file
  
  foreach line [split $cat_modules_file "\n"] {
    if {[string index $line 0] == {#}} {
      #gen_log:log D "Comment: $line"
      if {[string index $line 1] == {D} || [string index $line 1] == {M}} {
        set text [split $line]
        set dname [lindex $text 1]
        set modtitle($dname) [lrange $text 2 end]
        #gen_log:log D "Directory: {$dname} {$modtitle($dname)}"
      }
    } else {
      set text [split $line]
      set modname [lindex $text 0]
      set modstring [string trim [join [lrange $text 1 end]]]
      # A "#D ..." or "#M ..." entry _always_ overrides this default
      if {! [info exists modtitle($modname)]} {
        set modtitle($modname) $modstring
      }
      # Remove flags except for -a.  Luckily alias modules can't have
      # any other options.
      regsub -- {^((-l\s*)|(-[ioestud]\s+((\\\s)|\S)+\s*))+} \
          $modstring {} modstring
      if {$modname != ""} {
        set modval($modname) $modstring
      }
    }
  }
  
  # gen_log:log T "LEAVE"
}

# Organizes cvs modules into parents and children
proc cvs_modbrowse_tree { mnames node } {
  global cvscfg
  global modval
  global modtitle
  global dcontents
  #global Tree
  
  # gen_log:log T "ENTER ($mnames $node)"
  
  if {! [info exists cvscfg(aliasfolder)]} {
    set cvscfg(aliasfolder) false
  }
  
  set tv ".modbrowse.treeframe.pw"
  foreach mname [lsort $mnames] {
    gen_log:log D "{$mname} {$modval($mname)}"
    set dimage "mod"
    # The descriptive title of the module.  If not specified, modval is used.
    set title $modval($mname)
    if {[info exists modtitle($mname)]} {
      set title $modtitle($mname)
      gen_log:log D "* modtitle($mname) {$title}"
    }
    if {[string match "-a *" $modval($mname)]} {
      # Its an alias module
      regsub {\-a } $modtitle($mname) "Alias for " title
      # If we want all the aliases in a folder, do this
      if {$cvscfg(aliasfolder)} {
        gen_log:log D "path=Aliases/$mname pathtop=Aliases pathroot=/Aliases"
        if {! [$tv exists "AliasTop"]} {
          gen_log:log D "Making Aliases"
          gen_log:log D "$tv insert {} end -id AliasTop -image adir -values {Aliases Aliases}"
          $tv insert {} end -id AliasTop -image "adir" -values [list Aliases Aliases]
        }
        gen_log:log D "$tv insert AliasTop end -id $mname -image amod -values {$mname $title}"
        $tv insert AliasTop end -id $mname -image "amod" -values [list "$mname" "$title"]
      } else {
        # Otherwise, it just goes in the list
        gen_log:log D "$tv insert {} end -id $mname $mname -image amod -values {$mname $title}"
        $tv insert {} end -id $mname $mname -image "amod" -values [list "$mname" "$title"]
      }
      continue
    } elseif {[string match "* *" $modval($mname)]} {
      # The value isn't a simple path
      gen_log:log D "Found spaces in modval($mname) $modval($mname)"
    } elseif {[string match "*/*" $modval($mname)]} {
      gen_log:log D "Set image to dir because $modval($mname) contains a slash"
      set dimage dir
      set path $modval($mname)
      if {[llength $modval($mname)] > 1} {
        regsub { &\S+} $path {} path
      }
      set pathitems [file split $path]
      set pathdepth [llength $pathitems]
      set pathtop [lindex [file split $path] 0]
      set pathroot [file join $node $pathtop]
      set pathroot "$pathroot"
      if {[info exists modtitle($pathtop)]} {
        set title $modtitle($pathtop)
        gen_log:log D "* Using pathtop * modtitle($pathtop) {$title}"
      } elseif {[info exists modtitle($path)]} {
        set title $modtitle($path)
        gen_log:log D "* Using path * modtitle($path) {$title}"
      } else {
        gen_log:log D "* No modtitle($path)"
      }
      gen_log:log D "path=$path pathtop=$pathtop pathroot=$pathroot"
      if {! [$tv exists $pathroot]} {
        gen_log:log D "1 Making $pathtop for something with a \"/\" in its module name"
        if {[info exists modval($pathtop)]} { set dimage mdir }
        gen_log:log D "$tv insert {} end -id $pathroot -image dir -values {$pathtop $title}"
        $tv insert {} end -id "$pathroot" -image dir -values [list "$pathtop" "$title"]
      }
      set col0_width [expr {($pathdepth + 1) * ($cvscfg(mod_iconwidth) * 2)}]
      # FIXME: we want to trigger this when a folder is opened
      #$tv column #0 -width $col0_width
      set pathroot ""
      for {set i 1} {$i < $pathdepth} {incr i} {
        set newnode [lindex $pathitems $i]
        set pathroot [file join $pathroot [lindex $pathitems [expr {$i -1} ]]]
        set newpath [file join "/" $pathroot $newnode]
        set namepath [string range $newpath 1 end]
        if {[info exists modtitle($namepath)]} {
          set title $modtitle($namepath)
        } elseif {[info exists modtitle($newnode)]} {
          set title $modtitle($newnode)
        } elseif {[info exists modtitle($mname)]} {
          set title $modtitle($mname)
        }
        if {! [info exists dcontants($pathroot)]} {
          set modvalpath [file join "/" $modval($mname)]
          regsub { &\S+} $modvalpath {} modvalpath
          if {$modvalpath == $newpath} {
            set newnode $mname
          }
          lappend dcontents($pathroot) $newnode
          if {[info exists modval($newnode)]} {
            gen_log:log D "3 Making $newnode as a leaf"
            set dimage mod
          } else {
            gen_log:log D "2 Making $newnode as an intermediate node"
            set dimage dir
          }
          if {! [$tv exists $newpath]} {
            gen_log:log D "$tv insert /$pathroot end -id $newpath -image $dimage -values {$newnode $title}"
            $tv insert "/$pathroot" end -id $newpath -image $dimage -values [list "$newnode" "$title"]
          }
        }
      }
      # If we got here we just did a leaf, so break out and dont put it
      # at the toplevel too.
      continue
    }
    set treepath [file join $node $mname]
    if {[info exists dcontents($treepath)]} {
      gen_log:log D "  Already handled $treepath"
      continue
    }
    if {[info exists modval($mname)] && ($dimage != "amod")} { set dimage mdir }
    gen_log:log D "$tv insert {} end -id $mname -image mod -values {$mname $title}"
    $tv insert {} end -id $mname -image mod -values [list "$mname" "$title"]
  }
  # Move the Aliases to the top
  if {[$tv exists AliasTop]} {
    gen_log:log D "$tv detach AliasTop"
    $tv detach AliasTop
    gen_log:log D "$tv move AliasTop {} 0"
    $tv move AliasTop {} 0
  }
  update idletasks
  gather_mod_index
  # gen_log:log T "LEAVE"
}

proc cvs_lock {do files} {
  global cvs
  global cvscfg
  global cvscfg
  
  if {$files == {}} {
    cvsfail "Please select one or more files!" .workdir
    return
  }
  switch -- $do {
    lock { set commandline "$cvs admin -l $files"}
    unlock { set commandline "$cvs admin -u $files"}
  }
  set lock_cmd [::exec::new "$commandline"]
  auto_setup_dir $lock_cmd
}

# Sends directory "." to the directory-merge tool
# Find the bushiest file in the directory and diagram it.
# Called from the workdir browser
proc cvs_directory_merge {} {
  global cvscfg
  global cvsglb
  global cvs
  global incvs
  
  # gen_log:log T "ENTER"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  set files [glob -nocomplain -types f -- .??* *]
  
  regsub -all {\$} $files {\$} files
  set commandline "$cvs -d $cvscfg(cvsroot) log $files"
  gen_log:log C "$commandline"
  catch {exec {*} $commandline} raw_log
  set log_lines [split $raw_log "\n"]
  
  foreach logline $log_lines {
    if {[string match "Working file:*" $logline]} {
      set filename [lrange [split $logline] 2 end]
      set nbranches($filename) 0
      continue
    }
    if {[string match "total revisions:*" $logline]} {
      set nrevs($filename) [lindex [split $logline] end]
      continue
    }
    if { [regexp {^\t[-\w]+: .*\.0\.\d+$} $logline] } {
      incr nbranches($filename)
    }
  }
  set bushiestfile ""
  set mostrevisedfile ""
  set nbrmax 0
  foreach br [array names nbranches] {
    if {$nbranches($br) > $nbrmax} {
      set bushiestfile $br
      set nbrmax $nbranches($br)
    }
  }
  set nrevmax 0
  foreach br [array names nrevs] {
    if {$nrevs($br) > $nrevmax} {
      set mostrevisedfile $br
      set nrevmax $nrevs($br)
    }
  }
  gen_log:log F "Bushiest file \"$bushiestfile\" has $nbrmax branches"
  gen_log:log F "Most Revised file \"$mostrevisedfile\" has $nrevmax revisions"
  
  # Sometimes we don't find a file with any branches at all, so bushiest
  # is empty.  Fall back to mostrevised.  All files have at least one rev.
  if {[string length $bushiestfile] > 0} {
    set filename $bushiestfile
  } else {
    set filename $mostrevisedfile
  }
  
  ::cvs_branchlog::new "CVS,dir" "$filename"
  
  # gen_log:log T "LEAVE"
}

# Sends files to the CVS branch browser one at a time.  Called from
# workdir browser
proc cvs_branches {args} {
  global cvs
  global cvscfg
  
  # gen_log:log T "ENTER ($args)"
  
  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select one or more args!" .workdir
    return
  }
  
  foreach file $filelist {
    ::cvs_branchlog::new "CVS,loc" "$file"
  }
  # gen_log:log T "LEAVE"
}

namespace eval ::cvs_branchlog {
  variable instance 0
  
  proc new {how filename} {
    variable instance
    set my_idx $instance
    incr instance
    
    namespace eval $my_idx {
      set my_idx [uplevel {concat $my_idx}]
      set filename [uplevel {concat $filename}]
      set how [uplevel {concat $how}]
      variable filename
      variable command
      variable cmd_log
      variable lc
      variable revwho
      variable revdate
      variable revtime
      variable revlines
      variable revstate
      variable revcomment
      variable revmergefrom
      variable tags
      variable revbranches
      variable branchrevs
      variable logstate 
      variable sys
      variable loc
      variable cwd
        
      # gen_log:log T "ENTER [namespace current]"
      set sys_loc [split $how {,}]
      set sys [lindex $sys_loc 0]
      set loc [lindex $sys_loc 1]
      
      switch -- $sys {
        # loc is "loc" (local, i.e. workdir), "rep" (repository), or "dir" (mergecanvas)
        CVS {
          if {$loc eq "dir"} {
            # Invoking the mergecanvas
            set newlc [mergecanvas::new $filename $how [namespace current]]
          } else {
            set newlc [logcanvas::new $filename $how [namespace current]]
          }
        }
        RCS {
          set newlc [logcanvas::new $filename "RCS,loc" [namespace current]]
        }
      }
      # ln is the namespace, lc is the canvas
      set ln [lindex $newlc 0]
      set lc [lindex $newlc 1]
      
      proc abortLog { } {
        global cvscfg
        variable cmd_log
        variable lc
        
        catch {$cmd_log\::abort}
        busy_done $lc
        pack forget $lc.stop
        pack $lc.close -in $lc.down.closefm -side right
        $lc.close configure -state normal
      }
      
      proc reloadLog { } {
        global cvs
        global logcfg
        global cvsglb
        variable filename
        variable command
        variable cmd_log
        variable lc
        variable revwho
        variable revdate
        variable revtime
        variable revlines
        variable revstate
        variable revcomment
        variable revmergefrom
        variable revtags
        variable revbtags
        variable revbranches
        variable branchrevs
        variable logstate
        variable sys
        variable loc
        
        # gen_log:log T "ENTER"
        catch { $lc.canvas delete all }
        catch { unset revwho }
        catch { unset revdate }
        catch { unset revtime }
        catch { unset revlines }
        catch { unset revstate }
        catch { unset revcomment }
        catch { unset revmergefrom }
        catch { unset revtags }
        catch { unset revbtags }
        catch { unset revbranches }
        catch { unset branchrevs }
        set cwd [pwd]
        
        switch -- $sys {
          # loc is "loc" (local, i.e. workdir), "rep" (repository), or "dir" (mergecanvas)
          CVS {
            if {$loc eq "dir"} {
              set command "$cvs log \"$filename\""
            } else {
              set command "$cvs "
              if {$loc eq "rep"} {
                append command " -d $cvsglb(root) "
                # FIXME: Refresh won't work in the temp sandbox so for now
                # disable the button
                $lc.refresh configure -state disabled
              }
              append command " log"
              if {! $logcfg(show_branches)} {
                append command " -b"
              }
            }
            append command " \"$filename\""
          }
          RCS {
            set command "rlog \"$filename\""
          }
        }
        
        pack forget $lc.close
        pack $lc.stop -in $lc.down.closefm -side right
        $lc.stop configure -state normal
        busy_start $lc
        
        set logstate {R}
        
        set cmd_log [::exec::new $command {} 0 [namespace current]::parse_cvslog]
        # wait for it to finish so our arrays are all populated
        $cmd_log\::wait
        $cmd_log\::destroy
        
        pack forget $lc.stop
        pack $lc.close -in $lc.down.closefm -side right
        $lc.close configure -state normal
        
        [namespace current]::cvs_sort_it_all_out
        # gen_log:log T "LEAVE"
        return
      }
      
      proc parse_cvslog { exec logline } {
        #
        # Splits the rcs file up and parses it using a simple state machine.
        #
        global module_dir
        global inrcs
        global cvsglb
        global logcfg
        variable filename
        variable lc
        variable ln
        variable revwho
        variable revdate
        variable revtime
        variable revlines
        variable revstate
        variable revcomment
        variable revmergefrom
        variable revtags
        variable revbtags
        variable revbranches
        variable branchrevs
        variable logstate
        variable revkind
        variable rnum
        variable rootbranch
        variable revbranch
        
        ## gen_log:log T "ENTER ($exec $logline)"
        #gen_log:log D "$logline"
        if {$logline != {}} {
          switch -exact -- $logstate {
            {R} {
              # Look for the first text line which should give the file name.
              if {[string match {RCS file: *} $logline]} {
                # I think the whole path to the "RCS file" from the log isn't
                # really what we want here.  More like module_dir, so we know
                # what to feed to cvs rdiff and rannotate.
                set fname [string range $logline 10 end]
                set fname [file tail $fname]
                if {[string range $fname end-1 end] == {,v}} {
                  set fname [string range $fname 0 end-2]
                }
                set fname [file join $module_dir $fname]
                if {$inrcs && [file isdir RCS]} {
                  set fname [file join RCS $fname]
                }
                $ln\::ConfigureButtons $fname
              } elseif {[string match {Working file: *} $logline]} {
                # If we care about a working copy we need to look
                # at the name of the working file here. It may be
                # different from what we were given if we were invoked
                # on a directory.
                #if {$localfile != "no file"} {
                set localfile [string range $logline 14 end]
                #}
              } elseif {$logline == "symbolic names:"} {
                # FIXME: old RCS can have a tag on this line
                set logstate {T}
              }
            }
            {T} {
              # Any line with a tab leader is a tag
              if { [string index $logline 0] == "\t" } {
                set parts [split $logline {:}]
                set tagstring [string trim [lindex $parts 0]]
                set rnum [string trim [lindex $parts 1]]
                
                set parts [split $rnum {.}]
                if {[expr {[llength $parts] & 1}] == 1} {
                  set parts [linsert $parts end-1 {0}]
                  set rnum [join $parts {.}]
                }
                if {[lindex $parts end-1] == 0} {
                  # Branch tag
                  if {$logcfg(show_branches)} {
                    set rnum [join [lreplace $parts end-1 end-1] {.}]
                    set revkind($rnum) "branch"
                    set revbranch($tagstring) $rnum
                    set rbranch [join [lrange $parts 0 end-2] {.}]
                    set rootbranch($tagstring) $rbranch
                    lappend revbtags($rnum) $tagstring
                    lappend revbranches($rbranch) $rnum
                  }
                } else {
                  # Ordinary symbolic tag
                  lappend revtags($rnum) $tagstring
                  # Is it possible that this tag is the only surviving
                  # record that this revision ever existed?
                  if {[llength $parts] == 2} {
                    # A trunk revision but not necessarily 1.x because CVS allows
                    # the first part of the revision number to be changed. We have
                    # to assume that people always increase it if they change it
                    # at all.
                    lappend branchrevs(trunk) $rnum 
                  } else {
                    if {$logcfg(show_branches)} {
                      set rbranch [join [lrange $parts 0 end-1] {.}]
                      lappend branchrevs($rbranch) $rnum
                    }
                  }
                  # Branches for this revision may have already been created
                  # during tag parsing
                  foreach "revwho($rnum) revdate($rnum) revtime($rnum)
                  revlines($rnum) revstate($rnum) revcomment($rnum)" \
                      {{} {} {} {} {dead} {}} \
                      { break }
                }
              } else {
                if {$logline == "description:"} {
                  set logstate {S}
                }
              }
            }
            {S} {
              # Look for the line that starts a revision message.
              if {$logline == "----------------------------"} {
                set logstate {V}
              }
            }
            {V} {
              if {! [string match "revision *" $logline] } {
                # Did they put just the right number of dashes in the comment
                # to fool us?
                set logstate {L}
              } else {
                # Look for a revision number line
                set rnum [lindex [split $logline] 1]
                set parts [split $rnum {.}]
                set revkind($rnum) "revision"
                if {[llength $parts] == 2} {
                  # A trunk revision but not necessarily 1.x because CVS allows
                  # the first part of the revision number to be changed. We have
                  # to assume that people always increase it if they change it
                  # at all.
                  lappend branchrevs(trunk) $rnum
                } else {
                  lappend branchrevs([join [lrange $parts 0 end-1] {.}]) $rnum
                }
                # Branches for this revision may have already been created
                # during tag parsing
                foreach "revwho($rnum) revdate($rnum) revtime($rnum)
                revlines($rnum) revstate($rnum) revcomment($rnum)" \
                    {{} {} {} {} {} {}} \
                    { break }
                set logstate {D}
              }
            }
            {D} {
              # Look for a date line.  This also has the name of the author.
              set parts [split $logline ";"]
              foreach p $parts {
                set eqn [split $p ":"];
                set eqname [string trim [lindex $eqn 0]]
                set eqval  [string trim [join [lrange $eqn 1 end] ":"]]
                switch -exact -- $eqname {
                  {date} {
                    set revdate($rnum) [lindex $eqval 0]
                    set revtime($rnum) [lindex $eqval 1]
                    gen_log:log D "date $revdate($rnum)"
                    gen_log:log D "time $revtime($rnum)"
                  }
                  {author} {
                    set revwho($rnum) $eqval
                  }
                  {lines} {
                    set revlines($rnum) $eqval
                  }
                  {state} {
                    set revstate($rnum) $eqval
                  }
                  {mergepoint} {
                    set revmergefrom($rnum) $eqval
                    gen_log:log D "mergefrom $revmergefrom($rnum)"
                  }
                }
              }
              set logstate {L}
            }
            {L} {
              # See if there are branches off this revision
              if {[string match "branches:*" $logline]} {
                foreach br [lrange $logline 1 end] {
                  set br [string trimright $br {;}]
                  lappend revbranches($rnum) $br
                }
              } elseif {$logline == {----------------------------}} {
                set logstate {V}
              } elseif {$logline ==\
                    {=============================================================================}} {
                set logstate {X} 
              } else {
                append revcomment($rnum) $logline "\n"
              }
            }
            {X} {
              # ignore any further lines
            }
          }
        }
         
        if {$logstate == {X}} {
          gen_log:log D "********* Done parsing *********"
        }
        return [list {} $logline]
      }
      
      proc cvs_sort_it_all_out {} {
        global cvscfg
        global module_dir
        variable filename
        variable sys
        variable lc
        variable ln
        variable revwho
        variable revdate
        variable revtime
        variable revlines
        variable revstate
        variable revcomment
        variable revmergefrom
        variable revtags
        variable revbtags
        variable revbranches
        variable branchrevs
        variable logstate
        variable rnum
        variable rootbranch
        variable revbranch
        variable revkind
        
        # gen_log:log T "ENTER"
        
        if {[llength [array names revkind]] < 1} {
          cvsfail "Log empty.  Check error status of cvs log command"
          $lc.close invoke
          return
        }
        
        set revkind(1) "root"
        
        foreach r [lsort -dictionary [array names revkind]] {
          gen_log:log D "revkind($r) $revkind($r)"
        }
        # Sort the revision and branch lists and remove duplicates
        foreach r [array names branchrevs] {
          set branchrevs($r) \
              [lsort -unique -decreasing -dictionary $branchrevs($r)]
          #gen_log:log D "branchrevs($r) $branchrevs($r)"
        }
        
        # Create a fake revision to be the trunk branchtag
        set revbtags(1) "trunk"
        set branchrevs(1) $branchrevs(trunk)
        
        foreach r [array names revbranches] {
          set revbranches($r) \
              [lsort -unique -dictionary $revbranches($r)]
          #gen_log:log D "revbranches($r) $revbranches($r)"
        }
        # Find out where to put the working revision icon (if anywhere)
        # FIXME: we don't know that the log parsed was derived from the
        # file in this directory. Maybe we should check CVS/{Root,Repository}?
        # Maybe this check should be done elsewhere?
        if {$sys != "rcs" && $filename != "no file"} {
          gen_log:log F "Reading CVS/Entries"
          set basename [file tail $filename]
          if {![catch {open [file join \
                  [file dirname $filename] {CVS}\
                  {Entries}] \
              {r}} entries]} \
              {
            foreach line [split [read $entries] "\n"] {
              # What does the entry for an added/deleted file look like?
              set parts [split $line {/}]
              if {[lindex $parts 1] == $basename} {
                set rnum [lindex $parts 2]
                if {[string index $rnum 0] == {-}} {
                  # File has been locally removed and cvs removed but not
                  # committed.
                  set revstate(current) {dead}
                  set rnum [string range $rnum 1 end]
                } else {
                  set revstate(current) {Exp}
                }
                
                set root [join [lrange [split $rnum {.}] 0 end-1] {.}]
                gen_log:log D "root $root"
                set tag [string range [lindex $parts 5] 1 end]
                if {$rnum == {0}} {
                  # A locally added file has a revision of 0. Presumably
                  # there is no log and no revisions to show.
                  # FIXME: what if this is a resurrection?
                  lappend branchrevs(trunk) {current}
                } elseif {[info exists rootbranch($tag)] && \
                      $rootbranch($tag) == $rnum} {
                  # The sticky tag specifies a branch and the branch's
                  # root is the same as the source revision. Place the
                  # you-are-here box at the start of the branch.
                  lappend branchrevs($revbranch($tag)) {current}
                } else {
                  if {[catch {info exists $branchrevs($root)}] == 0} {
                    if {$rnum == [lindex $branchrevs($root) 0]} {
                      # The revision we are working on is the latest on its
                      # branch. Place the you-are-here box on the end of the
                      # branch.
                      set branchrevs($root) [linsert $branchrevs($root) 0\
                          {current}]
                    } else {
                      # Otherwise we will place it as a branch off the
                      # revision.
                      if {![info exists revbranches($rnum)]} {
                        set revbranches($rnum) {current}
                      } else {
                        set revbranches($rnum) [linsert $revbranches($rnum)\
                            0 {current}]
                      }
                    }
                  }
                }
                # We may have added a "current" branch. We have to set all its
                # stuff or we'll get errors
                foreach {revwho(current) revdate(current) revtime(current)
                  revlines(current) revcomment(current)
                branchrevs(current) revbtags(current)} \
                    {{} {} {} {} {} {} {}} \
                    { break }
                break
              }
            }
            close $entries
          }
        }
        gen_log:log D ""
        foreach a [array names branchrevs] { 
          gen_log:log D "branchrevs($a) $branchrevs($a)" 
        }
        gen_log:log D ""
        foreach a [array names revbranches] {
          gen_log:log D "revbranches($a) $revbranches($a)"
        }
        gen_log:log D ""
        foreach a [array names revbtags] {
          gen_log:log D "revbtags($a) $revbtags($a)"
        }
        gen_log:log D ""
        foreach a [array names revtags] {
          gen_log:log D "revtags($a) $revtags($a)"
        }
        
        # We only needed these to place the you-are-here box.
        catch {unset rootbranch revbranch}
        $ln\::DrawTree now
      }
      [namespace current]::reloadLog
      return [namespace current]
    }
  }
}

