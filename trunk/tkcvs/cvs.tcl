#
# Tcl Library for TkCVS
#

# 
# Contains procedures used in interaction with CVS.
#

proc cvs_notincvs {} {
  cvsfail "This directory is not in CVS." .workdir
}

proc cvs_incvs {} {
  cvsfail "You can\'t do that here because this directory is already in CVS." .workdir
}

#
#  Create a temporary directory
#  cd to that directory
#  run the CVS command in that directory
#
#  returns: the current wd (ERROR) or the sandbox directory (OK)
#
proc cvs_sandbox_runcmd {cmd output_var} {
  global cvscfg
  global cwd

  upvar $output_var view_this

  # Big note: the temp directory fed to a remote servers's command line
  # needs to be seen by the server.  It can't cd to an absolute path.
  # In addition it's fussy about where you are when you do a checkout -d.
  # Best avoid that altogether.
  gen_log:log T "ENTER ($cmd $output_var)"
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

  gen_log:log C "$cmd"
  set ret [catch {eval "exec $cmd"} view_this]
  gen_log:log T "RETURN $cvscfg(tmpdir)/cvstmpdir.$pid"
  return $cvscfg(tmpdir)/cvstmpdir.$pid
}

#
#  cvs_sandbox_filetags
#   assume that the sandbox contains the checked out files
#   return a list of all the tags in the files
#
proc cvs_sandbox_filetags {mcode filenames} {
  global cvscfg
  global cvs

  set pid [pid]
  set cwd [pwd]
  gen_log:log T "ENTER ($mcode $filenames)"
  
  cd [file join $cvscfg(tmpdir) cvstmpdir.$pid $mcode]
  set commandline "$cvs log $filenames"
  gen_log:log C "$commandline"
  set ret [catch {eval "exec $commandline"} view_this]
  if {$ret} {
    cd $cwd
    cvsfail $view_this .merge
    gen_log:log T "LEAVE ERROR"
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
  gen_log:log T "LEAVE"
  return $keepers
}

proc cvs_workdir_status {} {
  global cvscfg
  global cvs
  global Filelist

  gen_log:log T "ENTER"

  set cmd(cvs_status) [exec::new "$cvs -n -q status -l"]
  set status_lines [split [$cmd(cvs_status)\::output] "\n"]
  if {$cvscfg(econtrol)} {
    set cmd(cvs_editors) [exec::new "$cvs -n -q editors -l"]
    set editors_lines [split [$cmd(cvs_editors)\::output] "\n"]
  }
  if {$cvscfg(cvslock)} {
    set cmd(cvs_lockers) [exec::new "$cvs log"]
    set lockers_lines [split [$cmd(cvs_lockers)\::output] "\n"]
  }
  if {[info exists cmd(cvs_status)]} {
    # gets cvs status in current directory only, pulling out lines that include
    # Status: or Sticky Tag:, putting each file's info (name, status, and tag)
    # into an array.

    catch {unset cmd(cvs_status)}
    foreach logline $status_lines {
      if {[string match "File:*" $logline]} {
        regsub -all {\t+} $logline "\t" logline
        set line [split [string trim $logline] "\t"]
        gen_log:log D "$line"
        # Should be able to do these regsubs in one expression
        regsub {File: } [lindex $line 0] "" filename
        regsub {\s*$} $filename "" filename
        #if {[string match "no file *" $filename]} {
          #regsub {^no file } $filename "" filename
        #}
        regsub {Status: } [lindex $line 1] "" status
        set Filelist($filename:status) $status
        # Don't set editors to null because we'll use its presence
        # or absence to see if we need to re-read the repository when
        # we ask to map the editors column
        #set Filelist($filename:editors) ""
      } elseif {[string match "*Working revision:*" $logline]} {
        regsub -all {\t+} $logline "\t" logline
        set line [split [string trim $logline] "\t"]
        gen_log:log D "$line"
        set revision [lindex $line 1]
        regsub {New .*} $revision "New" revision
        set date [lindex $line 2]
        # The date field is not supplied to remote clients.
        if {$date == "" || [string match "New *" $date ] || \
            [string match "Result *" $date]} {
          ; # Leave as is
        } else {
          set juliandate [clock scan $date -gmt yes]
          set date [clock format $juliandate -format $cvscfg(dateformat)]
          set Filelist($filename:date) $date
        }
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
          set stickytag " on $t0  branch"
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
  }

  if {[info exists cmd(cvs_editors)]} {
    set filename {}
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
          set Filelist($filename:editors) $editors
        }
        set filename $f
        set editors [lindex $line 1]
      }
      gen_log:log D " $filename   $editors"
    }
    if {$filename != {}} {
      set Filelist($filename:editors) $editors
    }
  }

  if {[info exists cmd(cvs_lockers)]} {
    set filename {}
    set lockers {}
    catch {unset cmd(cvs_lockers)}
    foreach line $lockers_lines {
      if {[string match "Working file: *" $line]} {
        gen_log:log D "$line"
        regsub "Working file: " $line "" filename
      }
      if {[string match "*locked by:*" $line]} {
        gen_log:log D "$line"
        if {$filename != {}} {
          set p [lindex $line 4]
          set r [lindex $line 1]
          set p [string trimright $p {;}]
          gen_log:log D " $filename   $p\($r\)"
          append Filelist($filename:editors) $p\($r\)
        }
      }
    }
  }
  gen_log:log T "LEAVE"
}

proc cvs_remove {args} {
#
# This deletes a file from the directory and the repository,
# asking for confirmation first.
#
  global cvs
  global incvs
  global cvscfg

  gen_log:log T "ENTER ($args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  set filelist [join $args]

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

  set cmd [exec::new "$cvs remove $filelist"]
  if {$cvscfg(auto_status)} {
    $cmd\::wait
    setup_dir
  }

  gen_log:log T "LEAVE"
}

proc cvs_remove_dir {args} {
# This removes files recursively.
  global cvs
  global incvs
  global cvscfg

  gen_log:log T "ENTER ($args)"
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
    }
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc cvs_edit {args} {
#
# This sets the edit flag for a file
# asking for confirmation first.
#
  global cvs
  global incvs
  global cvscfg

  gen_log:log T "ENTER ($args)"

  if {! $incvs} {
    cvs_notincvs
    return 1
  }

  foreach file [join $args] {
    regsub -all {\$} $file {\$} file
    set commandline "$cvs edit \"$file\""
    gen_log:log C "$commandline"
    set ret [catch {eval "exec $commandline"} view_this]
    if {$ret != 0} {
      view_output::new "CVS Edit" $view_this
    }
  }
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc cvs_unedit {args} {
#
# This resets the edit flag for a file.
# Needs stdin as there is sometimes a dialog if file is modified
# (defaults to no)
#
  global cvs
  global incvs
  global cvscfg

  gen_log:log T "ENTER ($args)"

  if {! $incvs} {
    cvs_notincvs
    return 1
  }

  foreach file [join $args] {
    # Unedit may hang asking for confirmation if file is not up-to-date
    regsub -all {\$} $file {\$} file
    set commandline "cvs -n update \"$file\""
    gen_log:log C "$commandline"
    catch {eval "exec $commandline"} view_this
    # Its OK if its locally added
    if {([llength $view_this] > 0) && ![string match "A*" $view_this] } {
      gen_log:log D "$view_this"
      cvsfail "File $file is not up-to-date" .workdir
      gen_log:log T "LEAVE -- cvs unedit failed"
      return
    }

    set commandline "$cvs unedit \"$file\""
    gen_log:log C "$commandline"
    set ret [catch {eval "exec $commandline"} view_this]
    if {$ret != 0} {
      view_output::new "CVS Edit" $view_this
    }
  }
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc cvs_history {allflag mcode} {
  global cvs
  global cvscfg

  set all ""
  gen_log:log T "ENTER ($allflag $mcode)"
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
  gen_log:log T "LEAVE"
}

proc cvs_add {binflag args} {
#
# This adds a file to the repository.
#
  global cvs
  global cvscfg
  global incvs

  gen_log:log T "ENTER ($binflag $args)"
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

  if {$filelist == ""} {
    append filelist [glob -nocomplain $cvscfg(aster) .??*]
  }
  set cmd [exec::new "$cvs add $binflag $filelist"]
  if {$cvscfg(auto_status)} {
    $cmd\::wait
    setup_dir
  }

  gen_log:log T "LEAVE"
}

proc cvs_add_dir {binflag args} {
# This starts adding recursively at the directory level
  global cvs
  global cvscfg
  global incvs

  gen_log:log T "ENTER ($binflag $args)"
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
  gen_log:log T "LEAVE"
}

proc add_subdirs {binflag v} {
  global cvs
  global cvsglb
  global cvscfg

  gen_log:log T "ENTER ($binflag $v)"
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
    set ignore_file_filter $cvsglb(default_ignore_filter)
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

  gen_log:log T "LEAVE"
}

proc rem_subdirs { v } {
  global cvs
  global incvs
  global cvscfg

  gen_log:log T "ENTER ($v)"
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
    #set commandline "$cvs remove $plainfiles"
    #$v\::do "$commandline" 1
    #$v\::wait
  }

  gen_log:log T "LEAVE"
}

proc cvs_fileview_update {revision filename} {
#
# This views a specific revision of a file in the repository.
# For files checked out in the current sandbox.
#
  global cvs
  global cvscfg

  gen_log:log T "ENTER ($revision $filename)"
  if {$revision == {}} {
    set commandline "$cvs -d $cvscfg(cvsroot) update -p \"$filename\""
    set v [viewer::new "$filename"]
    $v\::do "$commandline" 0
  } else {
    set commandline "$cvs -d $cvscfg(cvsroot) update -p -r $revision \"$filename\""
    set v [viewer::new "$filename Revision $revision"]
    $v\::do "$commandline" 0
  }
  gen_log:log T "LEAVE"
}

proc cvs_fileview_checkout {revision filename} {
#
# This looks at a revision of a file from the repository.
# Called from Repository Browser -> File Browse -> View
# For files not currently checked out
#
  global cvs
  global cvscfg

  gen_log:log T "ENTER ($revision)"
  if {$revision == {}} {
    set commandline "$cvs -d $cvscfg(cvsroot) checkout -p \"$filename\""
    set v [viewer::new "$filename"]
    $v\::do "$commandline"
  } else {
    set commandline "$cvs -d $cvscfg(cvsroot) checkout -p -r $revision \"$filename\""
    set v [viewer::new "$filename Revision $revision"]
    $v\::do "$commandline"
  }
  gen_log:log T "LEAVE"
}

proc cvs_log {args} {
#
# This looks at a log from the repository.
# Called by Workdir menu Reports->"CVS log ..."
#
  global cvs
  global cvscfg

  set filelist [join $args]

  # Don't recurse
  set commandline "$cvs log -l "
  switch -- $cvscfg(ldetail) {
    latest {
      # -N means don't list tags
      append commandline "-Nr "
    }
    summary {
      append commandline "-Nt "
    }
  }
  append commandline "$filelist"

  set logcmd [viewer::new "CVS log ($cvscfg(ldetail))"]
  $logcmd\::do "$commandline" 0 hilight_rcslog
  busy_done .workdir.main

  gen_log:log T "LEAVE"
}

proc cvs_annotate {revision args} {
#
# This looks at a log from the repository.
# Called by Workdir menu Reports->"CVS log ..."
#
  global cvs
  global cvscfg

  gen_log:log T "ENTER ($revision $args)"

  if {$revision == "trunk"} {
    set revision ""
  }
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
    annotate::new $revflag $file "cvs"
  }
  gen_log:log T "LEAVE"
}

proc cvs_annotate_r {revision file} {
#
# This looks at a log from the repository.
# Called by Logcanvas when not in a CVS directory
#
  global cvs
  global cvscfg

  gen_log:log T "ENTER ($revision $file)"

  if {$revision != ""} {
    # We were given a revision
    set revflag "-r$revision"
  } else {
    set revflag ""
  }

  annotate::new $revflag $file "cvs_r"
  gen_log:log T "LEAVE"
}

proc cvs_commit {revision comment args} {
#
# This commits changes to the repository.
#
# The parameters work differently here -- args is a list.  The first
# element of args is a list of file names.  This is because I can't
# use eval on the parameters, because comment contains spaces.
#
  global cvs
  global cvscfg
  global incvs

  gen_log:log T "ENTER ($revision $comment $args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }

  set filelist [lindex $args 0]

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
    set commandline \
      "$cvscfg(terminal) $cvs commit -R $revflag $filelist"
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
    set v [viewer::new "CVS Commit"]
    regsub -all "\"" $comment "\\\"" comment
    # Lets not show stderr as it does a lot of "examining"
    $v\::do "$cvs commit -R $revflag -m \"$comment\" $filelist" 0
    $v\::wait
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc cvs_tag {tagname force branch update args} {
#
# This tags a file in a directory.
#
  global cvs
  global cvscfg
  global incvs

  gen_log:log T "ENTER ($tagname $force $branch $update $args)"

  if {! $incvs} {
    cvs_notincvs
    return 1
  }

  if {$tagname == ""} {
    cvsfail "You must enter a tag name!" .workdir
    return 1
  }

  set filelist [join $args]

  set command "$cvs tag"
  if {$branch == "yes"} {
   append command " -b"
  }
  if {$force == "yes"} {
    append command " -F"
  }
  append command " $tagname $filelist"

  if {$branch == "yes" && $force == "yes"} {
    set too_new 0
    # As of 1.11.2, -F won't move branch tags without the -B option
    set cvsglb(cvs_version) [cvs_version_number]
    set versionsplit [split $cvsglb(cvs_version) {.}]
    set major [lindex $versionsplit 1]
    set minor [lindex $versionsplit 2]
    if {$major > 11} {
      set too_new 1
    } elseif {($major == 11) && ($minor >= 2)} {
      set too_new 1
    }
    if {$too_new} {
      cvsfail "In CVS version >= 1.11.2, you're not allowed to move a branch tag" .workdir
    }
    return
  }

  # If it refuses to tag, it can exit with 0 but still put out some stderr
  set v [viewer::new "CVS Tag"]
  $v\::do "$command" 1
  $v\::wait

  if {$update == "yes"} {
    # update so we're on the branch
    set command "$cvs update -r $tagname $filelist"
    $v\::do "$command" 0 status_colortags
    $v\::wait
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc cvs_update {tagname normal_binary action_if_no_tag get_all_dirs dir args} {
#
# This updates the files in the current directory.
#
  global cvs
  global cvscfg
  global incvs

  gen_log:log T "ENTER ($tagname $normal_binary $action_if_no_tag $get_all_dirs $dir $args)"

  if { $normal_binary == "Normal" } {
      set mess "Using normal (text) mode.\n"
  } elseif { $normal_binary == "Binary" } {
      set mess "Using binary mode.\n"
  } else {
      set mess "Unknown mode:  $normal_binary\n"
  }

  if { $tagname != "BASE"  && $tagname != "HEAD" } {
      append mess "\nIf a file does not have tag $tagname"
      if { $action_if_no_tag == "Remove" } {
          append mess " it will be removed from your local directory.\n"
      } elseif { $action_if_no_tag == "Get_head" } {
          append mess " the head revision will be retrieved.\n"
      } elseif { $action_if_no_tag == "Skip" } {
          append mess " it will be skipped.\n"
      }
  }

  if { $tagname == "HEAD" } {
    append mess "\nYour local files will be updated to the"
    append mess " latest main trunk (head) revision."
    append mess " CVS will try to preserve any local, un-committed changes.\n"
  }

  append mess "\nIf there is a directory in the repository"
  append mess " that is not in your local, working directory,"
  if { $get_all_dirs == "Yes" } {
    append mess " it will be checked out at this time.\n"
  } else {
    append mess " it will not be checked out.\n"
  }

  set filelist [join $args]
  if {$filelist == ""} {
    append mess "\nYou are about to download from"
    append mess " the repository to your local"
    append mess " filespace ** ALL ** files which"
    append mess " have changed in it."
  } else {
    append mess "\nYou are about to download from"
    append mess " the repository to your local"
    append mess " filespace these files which"
    append mess " have changed:\n"
  
    foreach file $filelist {
      append mess "\n\t$file"
    }
  }
  append mess "\n\nAre you sure?"
  if {[cvsconfirm $mess .workdir] == "ok"} {
    # modified by jo to build the commandline incrementally
    set commandline "$cvs update -P"
    if { $normal_binary == "Binary" } {
      append commandline " -kb"
    }
    if { $get_all_dirs == "Yes" } {
      append commandline " -d $dir"
    }
    if { $tagname != "BASE" && $tagname != "HEAD" } {
      if { $action_if_no_tag == "Remove" } {
          append commandline " -r $tagname"
      } elseif { $action_if_no_tag == "Get_head" } {
          append commandline " -f -r $tagname"
      } elseif { $action_if_no_tag == "Skip" } {
          append commandline " -s -r $tagname"
      }
    }
    if { $tagname == "HEAD" } {
      append commandline " -A"
    }
    foreach file $filelist {
      append commandline " \"$file\""
    }

    set co_cmd [viewer::new "CVS Update"]
    $co_cmd\::do $commandline 0 status_colortags
    
    if {$cvscfg(auto_status)} {
      $co_cmd\::wait
      setup_dir
    }
  }
  gen_log:log T "LEAVE"
}

proc cvs_merge {from since fromtag totag args} {
#
# This does a join (merge) of a chosen revision of localfile to the
# current revision.
#
  global cvs
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER (\"$from\" \"$since\" \"$fromtag\" \"$totag\" \"$args\")"

  set filelist $args
  set v [viewer::new "CVS Join"]

  if {$since == ""} {
    set commandline "$cvs update -d -j$from $filelist"
  } else {
    set commandline "$cvs update -d -j$since -j$from $filelist"
  }
    
  $v\::do "$commandline"
  $v\::wait

  if {$cvscfg(auto_tag)} {
    set commandline "$cvs tag -F -r $from $fromtag $filelist"
    $v\::do "$commandline"
    toplevel .reminder
    wm title .reminder "Reminder"
    message .reminder.m1 -aspect 600 -text \
      "When you are finished checking in your merges, \
      you should apply the tag"
    entry .reminder.ent -width 32 -relief groove \
       -readonlybackground $cvsglb(readonlybg)
    .reminder.ent insert end $totag 
    .reminder.ent configure -state readonly
    message .reminder.m2 -aspect 600 -text \
      "using the \"Tag the selected files\" button"
    frame .reminder.bottom -relief raised -bd 2
    button .reminder.bottom.close -text "Dismiss" \
      -command {destroy .reminder}
    pack .reminder.bottom -side bottom -fill x
    pack .reminder.bottom.close -side bottom -expand yes
    pack .reminder.m1 -side top
    pack .reminder.ent -side top -padx 2
    pack .reminder.m2 -side top
  }

  if [winfo exists .workdir] {
    if {$cvscfg(auto_status)} {
      setup_dir
    }
  }
  gen_log:log T "LEAVE"
}

proc cvs_status {args} {
#
# This does a status report on the files in the current directory.
#
  global cvs
  global cvscfg

  gen_log:log T "ENTER ($args)"

  if {$args == "."} {
    set args ""
  }
  # if there are selected files, I want verbose output for those files
  # so I'm going to save the current setting here
  # - added by Jo
  set verbosity_setting ""

  busy_start .workdir.main
  set filelist [join $args]
  # if recurse option is true or there are no selected files, recurse
  set cmd_options ""
  if {! [info exists cvscfg(recurse)]} {
    set cmd_options "-l"
  }

  # if there are selected files, use verbose output
  # but save the current setting so it can be reset
  # - added by Jo
  if {[llength $filelist] > 0 || \
      ([llength $filelist] == 1  && ! [file isdir $filelist])} {
    set verbosity_setting $cvscfg(rdetail)
    set cvscfg(rdetail) "verbose"
  }

  # support verious levels of verboseness. Ideas derived from GIC
  set statcmd [exec::new "$cvs -Q status $cmd_options $filelist"]
  set raw_status [$statcmd\::output]

  if {$cvscfg(rdetail) == "verbose"} {
    view_output::new "CVS Status ($cvscfg(rdetail))" $raw_status
  } else {
    set cooked_status ""
    set stat_lines [split $raw_status "\n"]
    foreach statline $stat_lines {
      if {[string match "*Status:*" $statline]} {
        gen_log:log D "$statline"
        if {$cvscfg(rdetail) == "terse" &&\
            [string match "*Up-to-date*" $statline]} {
          continue
        } else {
          regsub {^File: } $statline {} statline
          regsub {Status:} $statline " " line
          append cooked_status $line
          append cooked_status "\n"
        }
      }
    }
    view_output::new "CVS Status ($cvscfg(rdetail))" $cooked_status
  }

  # reset the verbosity setting if necessary
  if { $verbosity_setting != "" } {
    set cvscfg(rdetail) $verbosity_setting
  }
  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

proc cvs_check {directory} {
#
# This does a cvscheck on the files in the current directory.
#
  global cvs
  global cvscfg

  gen_log:log T "ENTER ($directory)"

  busy_start .workdir.main

  # The current directory doesn't have to be in CVS for cvs update to work.

  # Sometimes, cvs update doesn't work with ".", only with "" or an argument
  if {$directory == "."} {
    set directory ""
  }

  if $cvscfg(recurse) {
    set checkrecursive ""
  } else {
    set checkrecursive "-l"
  }
  set commandline "$cvs -n -q update $checkrecursive $directory"
  set check_cmd [viewer::new "CVS Directory Status Check"]
  $check_cmd\::do $commandline 1 status_colortags

  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

proc cvs_checkout { dir cvsroot prune kflag revtag date target mtag1 mtag2 module } {
  #
  # This checks out a new module into the current directory.
  #
  global cvs
  global cvscfg

  gen_log:log T "ENTER ($dir $cvsroot $prune $kflag $revtag $date $target $mtag1 $mtag2 $module)"

  foreach {incvs insvn inrcs} [cvsroot_check $dir] { break }
  if {$incvs} {
    set mess "This is already a CVS controlled directory.  Are you\
              sure that you want to check out another module in\
              to this directory?"
    if {[cvsconfirm $mess .modbrowse] != "ok"} {
      return
    }
  }

  set mess "This will check out $module from CVS.\nAre you sure?"
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
    set v [::viewer::new "CVS Checkout"]
    set cwd [pwd]
    cd $dir
    $v\::do "$cvs -d \"$cvsroot\" checkout $prune\
             $revtag $date $target\
             $mtag1 $mtag2\
             $kflag \"$module\""
    cd $cwd
  }
  gen_log:log T "LEAVE"
  return
}

proc cvs_filelog {filename parent} {
#
# This looks at the revision log of a file.  It's called from filebrowse.tcl, 
# so we can't do operations such as merges.
#
  global cvs
  global cvscfg
  global cwd
  
  gen_log:log T "ENTER ($filename)"
  set pid [pid]
  set filetail [file tail $filename]
  
  set commandline "$cvs -d $cvscfg(cvsroot) checkout \"$filename\""
  gen_log:log C "$commandline"
  set ret [cvs_sandbox_runcmd "$commandline" cmd_output]
  if {$ret == $cwd} {
    cvsfail $cmd_output $parent
    cd $cwd
    gen_log:log T "LEAVE -- cvs checkout failed"
    return
  }

  set commandline "$cvs -d $cvscfg(cvsroot) log \"$filename\""

  # Log canvas viewer
  ::cvs_branchlog::new "CVS,rep" $filename
  cd $cwd
  gen_log:log T "LEAVE"
}

proc cvs_export { dir cvsroot kflag revtag date target module } {
#
# This exports a new module (see man cvs and read about export) into
# the current directory.
#
  global cvs
  global cvscfg 

  gen_log:log T "ENTER ($dir $cvsroot $kflag $revtag $date $target $module)"
    
  foreach {incvs insvn inrcs} [cvsroot_check $dir] { break }
  if {$incvs} { 
    set mess "This is already a CVS controlled directory.  Are you\
              sure that you want to export a module in to this directory?"
    if {[cvsconfirm $mess .modbrowse] != "ok"} {
      return
    }
  }

  set mess "This will export $module from CVS.\nAre you sure?"
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
    cd $dir
    $v\::do "$cvs -d \"$cvsroot\" export\
             $revtag $date $target $kflag \"$module\""
    cd $cwd
  }
  gen_log:log T "LEAVE"
  return
}

proc cvs_patch { cvsroot module difffmt revtagA dateA revtagB dateB outmode outfile } {
#
# This creates a patch file between two revisions of a module.  If the
# second revision is null, it creates a patch to the head revision.
# If both are null the top two revisions of the file are diffed.
#
  global cvs
  global cvscfg
 
  gen_log:log T "ENTER ($cvsroot $module $difffmt $revtagA $dateA $revtagB $dateB $outmode $outfile)"

  foreach {rev1 rev2} {{} {}} { break }
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
  gen_log:log T "LEAVE"
  return
}

proc cvs_version_number {} {
#
# This finds the current CVS version number.
#
  global cvs
  global cvscfg

  gen_log:log T "ENTER"
  set commandline "$cvs -v"
  set e [exec::new "$commandline" {} 0 parse_version]
  set number [$e\::output]
  regsub -all {\s*} $number {} number
  
  gen_log:log T "LEAVE ($number)"
  return $number
}

proc cvs_merge_conflict {args} {
  global cvscfg
  global cvs

  gen_log:log T "ENTER ($args)"

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
    catch {eval "exec $commandline"} status
    gen_log:log C "$status"

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
      gen_log:log C "$status"
      catch {eval "exec $commandline"} status
    } elseif { $match == 1 } { 
      # There are conflict markers already, dont update
      ;
    } else {
      cvsfail "This file does not appear to have a conflict." .workdir
      return
    }
    # Invoke tkdiff with the proper option for a conflict file
    # and have it write to the original file
    set commandline "$cvscfg(tkdiff) -conflict -o \"$filename\" \"$filename\""
    gen_log:log C "$commandline"
    catch {eval "exec $commandline"} view_this
  }
  
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc cvs_gettaglist {filename parent} {
  global cvs
  global cvscfg
  global cwd

  set keepers ""
  set pid [pid]
  gen_log:log T "ENTER ($filename)"
  set filetail [file tail $filename]
  
  set commandline "$cvs -d $cvscfg(cvsroot) checkout \"$filename\"" 
  # run a command, possibly creating the sandbox to play in
  set ret [cvs_sandbox_runcmd $commandline cmd_output]
  if {$cwd == $ret} {
    cvsfail $cmd_output $parent
    cd $cwd
    gen_log:log T "LEAVE ERROR ($cmd_output)"
    return $keepers
  }

  set commandline "$cvs -d $cvscfg(cvsroot) log \"$filename\""
  gen_log:log C "$commandline"
  set ret [catch {eval "exec $commandline"} view_this]
  if {$ret} {
    cvsfail $view_this $parent
    cd $cwd
    gen_log:log T "LEAVE ERROR"
    return $keepers
  }
  set view_lines [split $view_this "\n"]
  foreach line $view_lines {
    if {[string index $line 0] == "\t" } {
      set line [string trimleft $line]
      gen_log:log D "$line"
      append keepers "$line\n"
    }
  }
  if {$keepers == ""} {
    set keepers "No Tags"
  }

  cd $cwd
  gen_log:log T "LEAVE"
  return "$keepers"
}

proc cvs_release {delflag directory} {
  global cvs
  global cvscfg

  gen_log:log T "ENTER ($directory)"
  if {! [file isdirectory $directory]} {
    cvsfail "$directory is not a directory" .workdir
    return
  }

  set commandline "$cvs -n -q update $directory"
  gen_log:log C "$commandline"
  set ret [catch {eval "exec $commandline"} view_this]
  if {$view_this != ""} {
    view_output::new "CVS Check" $view_this
    set mess "$directory is not up-to-date."
    append mess "\nRelease anyway?"
    if {[cvsconfirm $mess .workdir] != "ok"} {
      return
    }
  }
  set commandline "$cvs -Q release $delflag $directory"
  set ret [catch {eval "exec $commandline"} view_this]
  gen_log:log C "$commandline"
  if {$ret != 0} {
    view_output::new "CVS Release" $view_this
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc cvs_rtag { cvsroot mcode branch force oldtag newtag } {
#
# This tags a module in the repository.
# Called by the tag commands in the Repository Browser
#
  global cvs
  global cvscfg
  
  gen_log:log T "ENTER ($cvsroot $mcode $branch $force $oldtag $newtag)"
  if {$newtag == ""} {
    cvsfail "You must enter a tag name!" .modbrowse
    return 1
  }

  set command "$cvs -d \"$cvsroot\" rtag"
  if {$branch == "yes"} {
    append command " -b"
  } 
  if {$force == "yes"} {
    append command " -F" 
  }   
  if {$oldtag != ""} {
    append command " -r \"$oldtag\""
  }
  append command " \"$newtag\" \"$mcode\""

  set v [::viewer::new "CVS Rtag"]
  $v\::do "$command"

  gen_log:log T "LEAVE"
}

# dialog for cvs commit - called from workdir browser
proc cvs_commit_dialog {} {
  global incvs
  global cvsglb
  global cvscfg

  gen_log:log T "ENTER"

  if {! $incvs} {
    cvs_notincvs
    gen_log:log T "LEAVE"
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
  grab set .commit

  frame .commit.top -border 8
  frame .commit.vers
  frame .commit.down -relief groove -border 2

  pack .commit.top -side top -fill x
  pack .commit.down -side bottom -fill x
  pack .commit.vers -side top -fill y

  label .commit.lvers -text "Specify Revision (-r) (usually ignore)" \
     -anchor w
  entry .commit.tvers -relief sunken -textvariable version

  pack .commit.lvers .commit.tvers -in .commit.vers \
    -side left -fill x -pady 3

  frame .commit.comment
  pack .commit.comment -side top -fill both -expand 1
  label .commit.lcomment
  text .commit.tcomment -relief sunken -width 70 -height 10 \
    -bg $cvsglb(textbg) -exportselection 1 \
    -wrap word -border 2 -setgrid yes


  # Explain what it means to "commit" files
  message .commit.message -justify left -aspect 500 -relief groove \
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
      grab release .commit
      wm withdraw .commit
      set cvsglb(commit_comment) [.commit.tcomment get 1.0 end]
      cvs_commit $version $cvsglb(commit_comment) $cvsglb(commit_list)
    }
  button .commit.apply -text "Apply" \
    -command {
      set cvsglb(commit_comment) [.commit.tcomment get 1.0 end]
      cvs_commit $version $cvsglb(commit_comment) $cvsglb(commit_list)
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

proc cvs_ascii { args } {
# This converts a binary file to ASCII
  global cvs
  global cvscfg
  global incvs
  global cvsglb

  gen_log:log T "ENTER ($args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  set filelist [join $args]

  gen_log:log D "Changing sticky flag"
  gen_log:log D "$cvs admin -kkv $filelist"
  set cmd [exec::new "$cvs admin -kkv $filelist"]
  # gen_log:log D "Updating file list"
  # set cmd [exec::new "$cvs update $filelist"]
  if {$cvscfg(auto_status)} {
    $cmd\::wait
    setup_dir
  }

  gen_log:log T "LEAVE"
}

proc cvs_binary { args } {
# This converts an ASCII file to binary
  global cvs
  global cvscfg
  global incvs
  global cvsglb

  gen_log:log T "ENTER ($args)"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  set filelist [join $args]

  gen_log:log D "Changing sticky flag"
  gen_log:log D "$cvs admin -kb $filelist"
  set cmd [exec::new "$cvs admin -kb $filelist"]
  # gen_log:log D "Updating file list"
  # set cmd [exec::new "$cvs update $filelist"]
  if {$cvscfg(auto_status)} {
    $cmd\::wait
    setup_dir
  }

  gen_log:log T "LEAVE"
}

# Revert a file to checked-in version by removing the local
# copy and updating it
proc cvs_revert {args} {
  global incvs
  global cvscfg
  global cvs

  gen_log:log T "ENTER ($args)"
  set filelist [join $args]

  gen_log:log D "Reverting $filelist"
  # update -C option appeared in 1.11
  set cvsglb(cvs_version) [cvs_version_number]
  set versionsplit [split $cvsglb(cvs_version) {.}]
  if {$major < 11} {
    gen_log:log F "DELETE $filelist"
    file delete $filelist
    set cmd [exec::new "$cvs update $filelist"]
  } else {
    set cmd [exec::new "$cvs update -C $filelist"]
  }
  
  if {$cvscfg(auto_status)} {
    $cmd\::wait
    setup_dir
  }

  gen_log:log T "LEAVE"
}

proc read_cvs_dir {dirname} {
#
# Reads a CVS "bookkeeping" directory
#
  global module_dir
  global cvscfg
  global cvsglb
  global current_tagname

  gen_log:log T "ENTER ($dirname)"
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
    }
  } else {
    cvsfail "$dirname is not a directory" .workdir
  }
  set cvsglb(root) $cvscfg(cvsroot)
  #gen_log:log D "cvsglb(root) $cvsglb(root)"
  #gen_log:log D "cvscfg(cvsroot) $cvscfg(cvsroot)"
  gen_log:log T "LEAVE"
}

proc parse_cvsmodules {modules_file} {
  global cvs
  global modval
  global modtitle
  global cvsglb
  global cvscfg

  gen_log:log T "ENTER"

  # Clear the arrays
  catch {unset modval}
  catch {unset modtitle}

  # Unescape newlines, compress repeated whitespace, and remove blank lines
  regsub -all {(\\\n|[ \t])+} $modules_file " " modules_file
  regsub -all {\n\s*\n+} $modules_file "\n" modules_file

  foreach line [split $modules_file "\n"] {
    if {[string index $line 0] == {#}} {
#     gen_log:log D "Comment: $line"
      if {[string index $line 1] == {D} || [string index $line 1] == {M}} {
        set text [split $line]
        set dname [lindex $text 1]
        set modtitle($dname) [lrange $text 2 end]
#       gen_log:log D "Directory: {$dname} {$modtitle($dname)}"
      }
    } else {
#     gen_log:log D "Data: $line"
      set text [split $line]
      set modname [lindex $text 0]
      set modstring [string trim [join [lrange $text 1 end]]]
      # A "#D ..." or "#M ..." entry _always_ overrides this default
      if {! [info exists modtitle($modname)]} {
        set modtitle($modname) $modstring
      }
      # Remove flags except for -a.  Luckily alias modules can't have
      # any other options.
#     gen_log:log D "{$modname} {$modstring}"
      regsub -- {^((-l\s*)|(-[ioestud]\s+((\\\s)|\S)+\s*))+} \
        $modstring {} modstring
      if {$modname != ""} {
        set modval($modname) $modstring
        gen_log:log D "{$modname} {$modstring}"
      }
    }
  }

  gen_log:log T "LEAVE"
}

proc cvs_lock {do files} {
  global cvscfg
  global cvscfg

  if {$files == {}} {
    cvsfail "Please select one or more files!" .workdir
    return
  }
  switch -- $do {
    lock { set commandline "cvs admin -l $files"}
    unlock { set commandline "cvs admin -u $files"}
  }
  set cmd [::exec::new "$commandline"]
  
  if {$cvscfg(auto_status)} {
    $cmd\::wait
    setup_dir
  }
}

# Sends directory "." to the directory-merge tool
# Find the bushiest file in the directory and diagram it
proc cvs_directory_merge {} {
  global cvscfg
  global cvsglb
  global cvs
  global incvs
  
  gen_log:log T "ENTER"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  set files [glob -nocomplain -types f -- .??* *]

  regsub -all {\$} $files {\$} files
  set commandline "$cvs -d $cvscfg(cvsroot) log $files"
  gen_log:log C "$commandline"
  catch {eval "exec $commandline"} raw_log
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

  gen_log:log T "LEAVE"
}

# Sends files to the CVS branch browser one at a time.  Called from
# workdir browser
proc cvs_branches {files} {
  global cvs
  global cvscfg

  gen_log:log T "ENTER ($files)"

  if {$files == {}} {
    cvsfail "Please select one or more files!" .workdir
    return
  }

  foreach file $files {
    ::cvs_branchlog::new "CVS,loc" "$file"
  }

  gen_log:log T "LEAVE"
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
      variable command
      variable cmd_log
      variable lc
      variable revwho
      variable revdate
      variable revtime
      variable revlines
      variable revstate
      variable revcomment
      variable tags
      variable revbranches
      variable branchrevs
      variable logstate
      variable cwd

      gen_log:log T "ENTER [namespace current]"
      set sys_loc [split $how {,}]
      set sys [lindex $sys_loc 0]
      set loc [lindex $sys_loc 1]

      switch -- $sys {
        CVS {
          set command "cvs log \"$filename\""
          if {$loc == "dir"} {
            set newlc [mergecanvas::new $filename $how [namespace current]]
            # ln is the namespace, lc is the canvas
            set ln [lindex $newlc 0]
            set lc [lindex $newlc 1]
            set show_tags 0
          } else {
            set newlc [logcanvas::new $filename $how [namespace current]]
            set ln [lindex $newlc 0]
            set lc [lindex $newlc 1]
            set show_tags [set $ln\::opt(show_tags)]
          }
        }
        RCS {
          set command "rlog $filename"
          set newlc [logcanvas::new $filename "RCS,loc" [namespace current]]
          set ln [lindex $newlc 0]
          set lc [lindex $newlc 1]
          set show_tags [set $ln\::opt(show_tags)]
        }
      }

      proc reloadLog { } {
        variable command
        variable cmd_log
        variable lc
        variable revwho
        variable revdate
        variable revtime
        variable revlines
        variable revstate
        variable revcomment
        variable revtags
        variable revbtags
        variable revbranches
        variable branchrevs
        variable logstate

        gen_log:log T "ENTER"
        catch { $lc.canvas delete all }
        catch { unset revwho }
        catch { unset revdate }
        catch { unset revtime }
        catch { unset revlines }
        catch { unset revstate }
        catch { unset revcomment }
        catch { unset revtags }
        catch { unset revbtags }
        catch { unset revbranches }
        catch { unset branchrevs }
        set cwd [pwd]

        busy_start $lc
        set logstate {R}

        set cmd_log [::exec::new $command {} 0 [namespace current]::parse_cvslog]
        # wait for it to finish so our arrays are all populated
        $cmd_log\::wait

        [namespace current]::cvs_sort_it_all_out
        gen_log:log T "LEAVE"
        return
      }

      proc parse_cvslog { exec logline } {
        #
        # Splits the rcs file up and parses it using a simple state machine.
        #
        global module_dir
        global inrcs
        global cvsglb
        variable filename
        variable lc
        variable ln
        variable revwho
        variable revdate
        variable revtime
        variable revlines
        variable revstate
        variable revcomment
        variable revtags
        variable revbtags
        variable revbranches
        variable branchrevs
        variable logstate
        variable revkind
        variable rnum
        variable rootbranch
        variable revbranch
        #gen_log:log T "ENTER ($exec $logline)"

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
                  set rnum [join [lreplace $parts end-1 end-1] {.}]
                  set revkind($rnum) "branch"
                  set revbranch($tagstring) $rnum
                  set rbranch [join [lrange $parts 0 end-2] {.}]
                  set rootbranch($tagstring) $rbranch
                  lappend revbtags($rnum) $tagstring
                  lappend revbranches($rbranch) $rnum
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
                    set rbranch [join [lrange $parts 0 end-1] {.}]
                    lappend branchrevs($rbranch) $rnum
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
                } elseif {$logline == "----------------------------"} {
                  # Oops, missed something.
                  set logstate {V}
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
            {D} {
              # Look for a date line.  This also has the name of the author.
              set parts [split $logline]
	      if {[lindex $parts 4] == "author:"} {
                foreach [list \
                    revwho($rnum) revdate($rnum) revtime($rnum) \
                    revlines($rnum) revstate($rnum) \
                  ] \
                  [list \
                    [string trimright [lindex $parts 5] {;}] \
                    [lindex $parts 1] \
                    [string trimright [lindex $parts 2] {;}] \
                    [lrange $parts 11 end] \
                    [string trimright [lindex $parts 8] {;}] \
                  ] \
                  { break }
	      } else {
                foreach [list \
                    revwho($rnum) revdate($rnum) revtime($rnum) \
                    revlines($rnum) revstate($rnum) \
                  ] \
                  [list \
                    [string trimright [lindex $parts 6] {;}] \
                    [lindex $parts 1] \
                    [string trimright [lindex $parts 2] {;}] \
                    [lrange $parts 11 end] \
                    [string trimright [lindex $parts 8] {;}] \
                  ] \
                  { break }
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
        #global current_tagname
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
        variable revtags
        variable revbtags
        variable revbranches
        variable branchrevs
        variable logstate
        variable rnum
        variable rootbranch
        variable revbranch
        variable revkind
  
        gen_log:log T "ENTER"

        if {[llength [array names revkind]] < 1} {
          cvsfail "Log empty.  Check error status of cvs log comand"
          return
        }

        set revkind(1) "root"

        foreach r [lsort -command sortrevs [array names revkind]] {
          gen_log:log D "revkind($r) $revkind($r)"
        }
        # Sort the revision and branch lists and remove duplicates
        foreach r [array names branchrevs] {
          set branchrevs($r) \
            [lsort -unique -decreasing -command sortrevs $branchrevs($r)]
          #gen_log:log D "branchrevs($r) $branchrevs($r)"
        }

        # Create a fake revision to be the trunk branchtag
        set revbtags(1) "trunk"
        set branchrevs(1) $branchrevs(trunk)

        foreach r [array names revbranches] {
          set revbranches($r) \
            [lsort -unique -command sortrevs $revbranches($r)]
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
                  #set revbranches(current) {}
                } elseif {[info exists rootbranch($tag)] && \
                    $rootbranch($tag) == $rnum} {
                  # The sticky tag specifies a branch and the branch's
                  # root is the same as the source revision. Place the
                  # you-are-here box at the start of the branch.
                  lappend branchrevs($revbranch($tag)) {current}
                  #set revbranches(current) {}
                } else {
                  if {[catch {info exists $branchrevs($root)}] == 0} {
                    if {$rnum == [lindex $branchrevs($root) 0]} {
                      # The revision we are working on is the latest on its
                      # branch. Place the you-are-here box on the end of the
                      # branch.
                      set branchrevs($root) [linsert $branchrevs($root) 0\
                        {current}]
                      #set revbranches(current) {}
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
                foreach {revwho(current) revdate(current) revtime(current)
                    revlines(current) revcomment(current)
                    branchrevs(current)} \
                    {{} {} {} {} {} {}} \
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

proc sortrevs {a b} {
    # Proc for lsort -command, to sort revision numbers
    # Return -1 if a<b, 0 if a=b, and 1 if a>b
    foreach ax [split $a {.}] bx [split $b {.}] {
	if {$ax < $bx} {
	    return -1
	}\
	elseif {$ax > $bx} {
	    return 1
	}
    }
    return 0
}
