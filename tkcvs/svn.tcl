proc svn_version {} {
  global cvsglb

  gen_log:log T "ENTER"

  if {$cvsglb(svn_mergeinfo_works) == ""} {
    set commandline "svn log -g"
    set ret [catch {eval "exec $commandline"} output]
    if {$ret == 0} {
      set cvsglb(svn_mergeinfo_works) 1
    } else {
      set cvsglb(svn_mergeinfo_works) 0
    }
  }

  set commandline "svn --version"
  gen_log:log C "$commandline"
  set ret [catch {eval "exec $commandline"} output]
  if {$ret} {
    cvsfail $output
    return
  }
  foreach infoline [split $output "\n"] {
    if {[string match "svn,*" $infoline]} {
      set lr [split $infoline]
      set version [lindex $lr 2]
      gen_log:log D "version $version"
    }
  }
  set cvsglb(svn_version) $version

  gen_log:log T "LEAVE"
}

# Find SVN URL
proc read_svn_dir {dirname} {
  global cvscfg
  global cvsglb
  global current_tagname
  global module_dir
  global cmd

  gen_log:log T "ENTER ($dirname)"
  if {$cvsglb(svn_version) == ""} {
    svn_version
  }
  # svn info gets the URL
  # Have to do eval exec because we need the error output
  set command "svn info"
  gen_log:log C "$command"
  set ret [catch {eval "exec $command"} output]
  if {$ret} {
    cvsfail $output
    return 0
  }
  foreach infoline [split $output "\n"] {
    if {[string match "URL*" $infoline]} {
      gen_log:log D "$infoline"
      set cvscfg(url) [lrange $infoline 1 end]
    }
  }

  if {! [info exists cvscfg(url)]} {
    set cvscfg(url) ""
  }
  if {$cvscfg(url) == ""} {
    cvsfail "Can't get the SVN URL"
    return 0
  }

  set root ""
  foreach s [list $cvscfg(svn_trunkdir) $cvscfg(svn_branchdir) $cvscfg(svn_tagdir)] {
    if {[regexp "/$s/" $cvscfg(url)] || [regexp "/$s" $cvscfg(url)]} {
      set spl [split $cvscfg(url) "/"]
      set root ""
      set relp ""
      set current_tagname ""
      set state P
      for {set j 0} {$j < [llength $spl]} {incr j} {
        set word [lindex $spl $j]
        switch -- $state {
          P {
            if {$word eq $cvscfg(svn_trunkdir)} {
                gen_log:log D "Matched $word for trunk"
                set type "trunk"
                set current_tagname $word
                set state E
            } elseif { $word eq $cvscfg(svn_branchdir)} {
                gen_log:log D "Matched $word for branches"
                set type "branches"
                set state W
            } elseif { $word eq $cvscfg(svn_tagdir)} {
                gen_log:log D "Matched $word for tags"
                set type "tags"
                set state W
            } else {
                append root "$word/"
                #gen_log:log D "No match for $word"
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
      set cvscfg(svnroot) [string trimright $root "/"]
      gen_log:log D "SVN URL: $cvscfg(url)"
      gen_log:log D "svnroot: $cvscfg(svnroot)"
      set cvsglb(relpath) [join $relp {/}]
      gen_log:log D "relpath: $cvsglb(relpath)"
      regsub -all {%20} $cvsglb(relpath) { } module_dir
      gen_log:log D "tagname: $current_tagname"
    }
  }
  if {$root == ""} {
    gen_log:log D "Nonconforming repository"
    gen_log:log D "SVN URL: $cvscfg(url)"
    set cvscfg(svnroot) $cvscfg(url)
    gen_log:log D "svnroot: $cvscfg(svnroot)"
    set cvsglb(relpath) ""
    gen_log:log T "LEAVE (-1)"
    return -1
  }
  gen_log:log T "LEAVE (0)"
  return 1
}

# Get stuff for main workdir browser
proc svn_workdir_status {} {
  global cmd
  global Filelist

  gen_log:log T "ENTER"
  set cmd(svn_status) [exec::new "svn status -uvN"]
  set status_lines [split [$cmd(svn_status)\::output] "\n"]
  if [info exists cmd(svn_status)] {
    $cmd(svn_status)\::destroy
    catch {unset cmd(svn_status)}
  }
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
      #012345678
      # M           965       938 kfogel       wc/bar.c
      #       *     965       922 sussman      wc/foo.c
      #A  +         965       687 joe          wc/qax.c
      #             965       687 joe          wc/zig.c
      set wrev [lindex $varcols 0]
      set crev [lindex $varcols 1]
      set nb [string first "/emailAddress=" [lrange $varcols 3 end] ]
      if {$nb == "-1"} {
        set cauthor [lindex $varcols 2]
        set filename [lrange $varcols 3 end]
      } else {
        set cauthor [lrange $varcols 2 3]
        set filename [lrange $varcols 4 end]
      }
    } else {
      #?                                       newfile
      set filename [lrange $logline 1 end]
    }
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
      ! { append displaymod "Missing or Incomplete" }
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
  set addcmd [exec::new "svn add $filelist"]
  auto_setup_dir $addcmd

  gen_log:log T "LEAVE"
}

# does svn remove from workdir browser
proc svn_remove {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"
  set filelist [join $args]

  set command [exec::new "svn remove $filelist"]
  auto_setup_dir $command

  gen_log:log T "LEAVE"
}

# called from the workdir browser checkmark button
proc svn_check {directory} {
  global cvscfg

  gen_log:log T "ENTER ($directory)"

  busy_start .workdir.main

  # Always show updates
  set flags "-u"
  # Only recurse if flag is set
  if {! $cvscfg(recurse)} {
    append flags "N"
  }
  # unknown files are removed by the filter but we might as well minimize
  # the work the filter has to do
  if {$cvscfg(status_filter)} {
    append flags "q"
  }
  set command "svn status $flags $directory"
  set check_cmd [viewer::new "SVN Status Check"]
  $check_cmd\::do "$command" 0 status_colortags

  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

# svn update - called from workdir browser
proc svn_update {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"

  set filelist [join $args]

  if {$filelist == ""} {
    append mess "\nThis will download from"
    append mess " the repository to your local"
    append mess " filespace ** ALL ** files which"
    append mess " have changed in it."
  } else {
    append mess "\nThis will download from"
    append mess " the repository to your local"
    append mess " filespace these files which"
    append mess " have changed:\n"
  }
  foreach file $filelist {
    append mess "\n\t$file"
  }
  append mess "\n\nAre you sure?"

  set command "svn update"

  if {[cvsconfirm $mess .workdir] == "ok"} {
    foreach file $filelist {
      append command " \"$file\""
    }
  } else {
    return;
  }

  set co_cmd [viewer::new "SVN Update"]
  $co_cmd\::do "$command" 0 status_colortags
  auto_setup_dir $co_cmd

  gen_log:log T "LEAVE"
}

# Called from "update with options" dialog of workdir browser
proc svn_opt_update {} {
  global cvscfg
  global cvsglb

  switch -exact -- $cvsglb(tagmode_selection) {
    "Keep" {
       set command "svn update"
     }
    "Trunk" {
       set command "svn switch $cvscfg(svnroot)/$cvscfg(svn_trunkdir)"
     }
    "Branch" {
       set command "svn switch $cvscfg(svnroot)/$cvscfg(svn_branchdir)/$cvsglb(branchname)"
     }
    "Revision" {
       # Let them get away with saying r3 instead of 3
       set rev [string trimleft $cvsglb(revnumber) {r}]
       set command "svn update -r $rev"
     }
  }
  set upd_cmd [viewer::new "SVN Update/Switch"]
  $upd_cmd\::do "$command" 0 status_colortags

  auto_setup_dir $upd_cmd
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
    -bg $cvsglb(textbg) -exportselection 1 \
    -wrap word -border 2 -setgrid yes


  # Explain what it means to "commit" files
  message .commit.message -justify left -aspect 800 \
    -text "This will commit changes from your \
           local, working directory into the repository, recursively."

  pack .commit.message -in .commit.top -padx 2 -pady 5


  button .commit.ok -text "OK" -highlightbackground $cvsglb(bg) \
    -command {
      grab release .commit
      wm withdraw .commit
      set cvsglb(commit_comment) [.commit.tcomment get 1.0 end]
      svn_commit $cvsglb(commit_comment) $cvsglb(commit_list)
    }
  button .commit.apply -text "Apply" -highlightbackground $cvsglb(bg) \
    -command {
      set cvsglb(commit_comment) [.commit.tcomment get 1.0 end]
      svn_commit $cvsglb(commit_comment) $cvsglb(commit_list)
    }
  button .commit.clear -text "ClearAll" -highlightbackground $cvsglb(bg) \
    -command {
      set version ""
      .commit.tcomment delete 1.0 end
    }
  button .commit.quit -highlightbackground $cvsglb(bg) \
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

  set filelist [join $args]

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
    set command \
      "$cvscfg(terminal) svn commit $filelist"
    gen_log:log C "$command"
    set ret [catch {eval "exec $command"} view_this]
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

# Called from branch browser annotate button
proc svn_annotate_r {revision filepath} {
  global cvscfg

  gen_log:log T "ENTER ($revision $filepath)"
  if {$revision != ""} {
    # We were given a revision
    set revflag "-r$revision"
  } else {
    set revflag ""
  }

  annotate::new $revflag $filepath "svn_r"
  gen_log:log T "LEAVE"
}

proc svn_patch { pathA pathB revA dateA revB dateB outmode outfile } {
#
# This creates a patch file between two revisions of a module.  If the
# second revision is null, it creates a patch to the head revision.
# If both are null the top two revisions of the file are diffed.
#
  global cvscfg
 
  gen_log:log T "ENTER ($pathA $pathB $revA $dateA $revB $dateB $outmode $outfile)"
  global cvs

  foreach {rev1 rev2} {{} {}} { break }
  if {$revA != {}} {
    set rev1 $revA
  } elseif {$dateA != {}} {
    set rev1 "\{\"$dateA\"\}"
  }
  if {$revB != {}} {
    set rev2 "$revB"
  } elseif {$dateA != {}} {
    set rev2 "\{\"$dateB\"\}"
  }
  set pathA [safe_url $pathA]
  set pathB [safe_url $pathB]
  if {$pathA != {} && $pathB != {}} {
    set command "svn diff $pathA $pathB"
  } elseif {$rev1 != {} && $rev2 != {}} {
    set command "svn diff $pathA@$rev1 $pathA@$rev2"
  } else {
    cvsfail "Specify either two paths OR one path and two revisions"
    return
  }

  if {$outmode == 0} {
    set v [viewer::new "SVN Diff"]
    $v\::do "$command"
  } else {
    set e [exec::new "$command"]
    set patch [$e\::output]
    gen_log:log F "OPEN $outfile"
    if {[catch {set fo [open $outfile w]}]} {
      cvsfail "Cannot open $outfile for writing" .modbrowse
      return
    }
    puts $fo $patch
    close $fo
    $e\::destroy
    gen_log:log F "CLOSE $outfile"
  }
  gen_log:log T "LEAVE"
  return
}

# Called from module browser filebrowse button
proc svn_list {module} {
  global cvscfg

  gen_log:log T "ENTER ($module)"
  set v [viewer::new "SVN list -R"]
  $v\::do "svn list -Rv \"$cvscfg(svnroot)/$module\""
  gen_log:log T "LEAVE"
}

# Called from the module browser
proc svn_delete {root path} {

  gen_log:log T "ENTER ($root $path)"

  set mess "Really delete $path from the SVN repository?"
  if {[cvsconfirm $mess .modbrowse] != "ok"} {
    return
  }
  set url [safe_url $root/$path]
  set v [viewer::new "SVN delete"]
  set command "svn delete \"$url\" -m\"Removed_using_TkSVN\""
  $v\::do "$command"
  modbrowse_run
  gen_log:log T "LEAVE"
}

# This is the callback for the folder-opener in ModTree
proc svn_jit_listdir { tf into } {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($tf $into)"
  set cvscfg(svnroot) $cvsglb(root)
  #puts "\nEntering svn_jit_listdir ($into)"
  set dir [string trimleft $into / ]
  set command "svn list -v \"$cvscfg(svnroot)/$dir\""
  #puts "$command"
  set cmd(svnlist) [exec::new "$command"]
  if {[info exists cmd(svnlist)]} {
    set contents [split [$cmd(svnlist)\::output] "\n"]
    $cmd(svnlist)\::destroy
    catch {unset cmd(svnlist)}
  }
  set dirs {}
  set fils {}
  foreach logline $contents {
    if {$logline == "" } continue
    gen_log:log D "$logline"
    if [string match {*/} $logline] {
      set item [lrange $logline 5 end]
      set item [string trimright $item "/"]
      lappend dirs "$item"
      set info($item) [lrange $logline 0 4]
    } else {
      set item [lrange $logline 6 end]
      lappend fils "$item"
      set info($item) [lrange $logline 0 5]
    }
  }

  busy_start $tf
  ModTree:close $tf /$dir
  ModTree:delitem $tf /$dir/_jit_placeholder
  foreach f $fils {
    set command "ModTree:newitem $tf \"/$dir/$f\" \"$f\" \"$info($f)\" -image Fileview"
    set r [catch "$command" err]
  }
  foreach d $dirs {
    svn_jit_dircmd $tf $dir/$d
  }
  gen_log:log D "ModTree:open $tf /$dir"
  ModTree:open $tf /$dir

  #puts "\nLeaving svn_jit_listdir"
  busy_done $tf
  gen_log:log T "LEAVE"
}

proc svn_jit_dircmd { tf dir } {
  global cvscfg
  global Tree

  #gen_log:log T "ENTER ($tf $dir)"

  # Here we are just figuring out if the top level directory is empty or not.
  # We don't have to collect any other information, so no -v flag
  set command "svn list \"$cvscfg(svnroot)/$dir\""
  #puts "$command"
  set cmd(svnlist) [exec::new "$command"]
  if {[info exists cmd(svnlist)]} {
    set contents [$cmd(svnlist)\::output]
    $cmd(svnlist)\::destroy
    catch {unset cmd(svnlist)}
  }
  set lbl "[file tail $dir]/"
  set exp "([llength $contents] items)"
  set parent "[file root $dir]"

  set dirs {}
  set fils {}
  foreach logline [split $contents "\n"] {
    if {$logline == ""} continue
    #gen_log:log D "$logline"
    if [string match {*/} $logline] {
      set item [string trimright $logline "/"]
      lappend dirs $item
    } else {
      lappend fils $logline
    }
  }

  # To avoid having to look ahead and build the whole tree at once, we put
  # a "marker" item in non-empty directories so it will look non-empty
  # and be openable
  if {$dirs == {} && $fils == {}} {
    catch "ModTree:newitem $tf \"/$dir\" \"$lbl\" \"$exp\" -image Folder"
  } else {
    # Newitem returns nothing if the item already exists, or an "after" from
    # buildwhenidle if the item had to be inserted
    set r [catch "ModTree:newitem $tf \"/$dir\" \"$lbl\" \"$exp\" -image Folder" err]
    if {! $r} {
      if {! $Tree($tf:/$dir:open)} {
        # If the node is already open, we don't need a placeholder
        catch "ModTree:newitem $tf \"/$dir/_jit_placeholder\" \"\" \"\" -image {}"
      }
    }
  }

  #gen_log:log T "LEAVE"
}

# called from module browser - list branches & tags
proc parse_svnmodules {tf svnroot} {
  global cvscfg
  global modval

  gen_log:log T "ENTER ($tf $svnroot)"

  if {[catch "image type fileview"]} {
    workdir_images
  }

  set cvscfg(svnroot) $svnroot
  set command "svn list -v $svnroot"
  #puts "$command"
  set cmd(svnlist) [exec::new "$command"]
  if {[info exists cmd(svnlist)]} {
    set contents [$cmd(svnlist)\::output]
    $cmd(svnlist)\::destroy
    catch {unset cmd(svnlist)}
  }
  set dirs {}
  set fils {}

  foreach logline [split $contents "\n"] {
    if {$logline == "" } continue
    gen_log:log D "$logline"
    if [string match {*/} $logline] {
      set item [lrange $logline 5 end]
      lappend dirs [string trimright $item "/"]
    } else {
      set item [lrange $logline 6 end]
      lappend fils $item
      set info($item) [lrange $logline 0 5]
    }
  }

  foreach f $fils {
    catch "ModTree:newitem $tf \"/$f\" \"$f\" \"$info($f)\" -image Fileview"
  }
  foreach d $dirs {
    svn_jit_dircmd $tf $d
  }

  gen_log:log T "LEAVE"
}

# called from workdir Reports menu
proc svn_log {args} {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($args)"

  set svncommand "svn log "
  # svn -g (mergeinfo) appeared in 1.5.  It depends on the server
  # as well as the client, so we can't go by version number.  we
  # just have to see if it works.
  # Do we want to do -g for all detail levels?  Probably not for summary.
  if {$cvsglb(svn_mergeinfo_works)} {
    if {$cvscfg(ldetail) ne "summary"} {
      append svncommand "-g "
    }
  }
  set filelist [join $args]
  foreach file $filelist {
    set command $svncommand
    if {$cvscfg(ldetail) == "latest"} {
      append command "-r COMMITTED "
    }
    if {$cvscfg(ldetail) == "summary"} {
      append command "-q "
    }
    append command "\"$file\""

    set logcmd [viewer::new "SVN Log $file ($cvscfg(ldetail))"]
    $logcmd\::do "$command"
  }
  gen_log:log T "LEAVE"
}

proc svn_merge_conflict {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"

  if {[llength $args] != 1} {
    cvsfail "Please select one file."
    return
  }
  set filelist [join $args]

  # See if it's really a conflict file
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
      cvsfail "$file does not appear to have a conflict." .workdir
      continue
    }
  # FIXME: we don't want to tie up the whole UI with tkdiff, but
  # if we don't wait, we have no way to know if we can mark resolved
    # Invoke tkdiff with the proper option for a conflict file
    # and have it write to the original file
    set command "$cvscfg(tkdiff) -conflict -o \"$file\" \"$file\""
    gen_log:log C "$command"
    set ret [catch {eval "exec $command"} view_this]
    if {$ret == 0} {
      set mess "Mark $file resolved?"
      if {[cvsconfirm $mess .workdir] != "ok"} {
        continue
      }
      set command "svn resolved \"$file\""
      exec::new $command
    } else {
      cvsfail "$view_this" .workdir
    }
  }
  
  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc svn_resolve {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"
  set filelist [join $args]

  # See if it still has a conflict
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

    if {$match} {
      set mess "$file still contains \"<<<<<<< \" - \nUnmark anyway?"
      if {[cvsalwaysconfirm $mess .workdir] != "ok"} {
        continue
      }
    }
    gen_log:log D "Marking $file as resolved"
    set command [exec::new "svn resolved $file"]
  }
  if {$cvscfg(auto_status)} {
    setup_dir
  }

  gen_log:log T "LEAVE"
}

proc svn_revert {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"
  set filelist [join $args]
  if {$filelist == ""} {
    set filelist "-R ."
  }
  gen_log:log D "Reverting $filelist"
  set command [exec::new "svn revert $filelist"]
  auto_setup_dir $command

  gen_log:log T "LEAVE"
}

proc svn_tag {tagname b_or_t update args} {
#
# This tags a file or directory in the current sandbox.
#
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($tagname $b_or_t $update $args)"
  
  if {$tagname == ""} {
    cvsfail "You must enter a tag name!" .workdir
    return 1
  }
  set filelist [join $args]
  gen_log:log D "relpath: $cvsglb(relpath)  filelist \"$filelist\""

  if {$b_or_t == "tag" || $b_or_t == "tags"} {set pathelem "$cvscfg(svn_tagdir)"}
  if {$b_or_t == "branch"} {set pathelem "$cvscfg(svn_branchdir)"}

  set comment "${b_or_t}_copy_by_TkSVN"
  set v [viewer::new "SVN Copy $tagname"]
  set to_url "$cvscfg(svnroot)/$pathelem/$tagname/$cvsglb(relpath)"
  if { $filelist == {} } {
    set command "svn copy -m\"$comment\" $cvscfg(url) $to_url"
    $v\::log "$command"
    $v\::do "$command"
  } else {
    foreach f $filelist {
      if {$f == "."} {
        set command "svn copy -m\"comment\" $cvscfg(url) $to_url"
      } else {
        svn_pathforcopy $tagname $pathelem $v
        set from_url [safe_url $cvscfg(url)/$f]
        set command "svn copy -m\"$comment\" $from_url $to_url"
      }
      $v\::log "$command"
      $v\::do "$command"
    }
  }

  if {$update == "yes"} {
    # update so we're on the branch
    set command "svn switch $to_path"
    $v\::do "$command" 0 status_colortags
    $v\::wait
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

proc svn_rcopy {from_path b_or_t newtag} {
#
# makes a tag or branch.  Called from the module browser
#
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($from_path $b_or_t $newtag)"

  # We're going to do some dangerous second-guessing here.  If "trunk", or
  # something just below the "branches" or "tags" path, is selected, we guess
  # they want to copy its contents.
  # Otherwise, we'll copy exactly what they have selected.
  set need_list 0
  set idx [string length $cvscfg(svnroot)]
  incr idx ;# advance past /
  set from_path_remainder [string range $from_path $idx end]
  set pathelements [file split $from_path_remainder]
  if {$from_path_remainder == "$cvscfg(svn_trunkdir)"} {
    set need_list 1
  } elseif {[llength $pathelements] == 2} {
    set from_type [lindex $pathelements 0]
    switch -- $from_type {
      "$cvscfg(svn_tagdir)" -
      "$cvscfg(svn_branchdir)" {
        set need_list 1
      }
    }
  }
  set comment "${b_or_t}_copy_by_TkSVN"

  set v [viewer::new "SVN Copy $newtag"]
  set comment "Copied_using_TkSVN"
  set to_path [svn_pathforcopy $newtag $b_or_t $v]

  if {! $need_list } {
    # Copy the selected path
    set command "svn copy -m\"$comment\" [safe_url $from_path] $to_path"
    $v\::do "$command"
    $v\::wait
  } else {
    # Copy the contents of the selected path
    set command "svn list [safe_url $from_path]"
    set cmd(svnlist) [exec::new "$command"]
    if {[info exists cmd(svnlist)]} {
      set contents [split [$cmd(svnlist)\::output] "\n"]
      $cmd(svnlist)\::destroy
      catch {unset cmd(svnlist)}
    }
    foreach f $contents {
      if {$f == ""} {continue}
      set file_from_path [safe_url "$from_path/$f"]
      set command "svn copy -m\"$comment\" $file_from_path $to_path"
      $v\::log "$command\n"
      $v\::do "$command"
      $v\::wait
    }
  }
  # Update with what we've done
  modbrowse_run svn
  gen_log:log T "LEAVE"
}

proc svn_pathforcopy {tagname b_or_t viewer} {
# For svn copy, the destination path in the repository must already
# exist. If we're tagging somewhere other than the top level, it may
# not exist yet.  This proc creates the path if necessary and returns
# it to the calling proc, which will do the copy.
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER (\"$tagname\" \"$b_or_t\" \"$viewer\")"
  # Can't use file join or it will mess up the URL
  set to_path [safe_url "$cvscfg(svnroot)/$b_or_t/$tagname"]
  set comment "${b_or_t}_directory_path_by_TkSVN"

  # If no file yet has this tag/branch name, create it
  set ret [catch "eval exec svn list $to_path" err]
  if {$ret} {
    set command "svn mkdir -m\"$comment\" $to_path"
    $viewer\::log "$command\n"
    $viewer\::do "$command"
    $viewer\::wait
  }
  # We may need to construct a path to copy the file to
  set cum_path ""
  set pathelements [file split $cvsglb(relpath)]
  set depth [llength $pathelements]
  for {set i 0} {$i < $depth} {incr i} {
    set cum_path [file join $cum_path [lindex $pathelements $i]]
    gen_log:log D "  $i $cum_path"
    set ret [catch "eval exec svn list $to_path/$cum_path" err]
    if {$ret} {
      set command "svn mkdir -m\"$comment\" $to_path/$cum_path"
      $viewer\::do "$command"
      $viewer\::wait
    }
  }
  if {$cum_path != ""} {
    set to_path "$to_path/$cum_path"
  }
  gen_log:log T "LEAVE (\"$to_path\")"
  return $to_path
}

proc svn_merge {parent frompath since currentpath frombranch args} {
#
# This does a join (merge) of a chosen revision of localfile to the
# current revision.
#
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER( \"$frompath\" \"$since\" \"$currentpath\" \"$frombranch\" $args)"

  set mergetags [assemble_mergetags $frombranch]
  set curr_tag [lindex $mergetags 0]
  set fromtag [lindex $mergetags 1]
  set totag [lindex $mergetags 2]

  regsub {^.*@} $frompath {r} from
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

  # Do the update here, and defer the tagging until later
  set commandline "svn merge \"$currentpath\" \"$frompath\""
  set v [viewer::new "SVN Merge"]
  $v\::do "$commandline" 1 status_colortags
  $v\::wait

  if [winfo exists .workdir] {
    if {$cvscfg(auto_status)} {
      setup_dir
    }
  } else {
    workdir_setup
  }

  dialog_merge_notice svn $from $frombranch $fromtag $totag $args

  gen_log:log T "LEAVE"
}

proc svn_merge_tag_seq {from frombranch totag fromtag args} {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER (\"$from\" \"$totag\" \"$fromtag\" $args)"

  set filelist ""
  foreach f $args {
    append filelist "\"$f\" "
  }

  # It's muy importante to make sure everything is OK at this point
  set commandline "svn status -uq $filelist"
  gen_log:log C "$commandline"
  set ret [catch {eval "exec $commandline"} view_this]
  set logmode [expr {$ret ? {E} : {D}}]
  view_output::new "SVN Check" $view_this
  gen_log:log $logmode $view_this
  if {$ret} {
    set mess "SVN Check shows errors which would prevent a successful\
    commit. Please resolve them before continuing."
    if {[cvsalwaysconfirm $mess .workdir] != "ok"} {
      return
    }
  }

  # Do the commit
  set v [viewer::new "SVN Commit a Merge"]
  $v\::log "svn commit -m \"Merge from $from\" $filelist\n"
  $v\::do "svn commit -m \"Merge from $from\" $filelist" 1
  $v\::wait

  # Tag if desired (no means not a branch
  if {$cvscfg(auto_tag) && $fromtag != ""} {
    if {$frombranch == "trunk"} {
      set from_path "$cvscfg(svnroot)/$cvscfg(svn_trunkdir)/$cvsglb(relpath)"
    } else {
      set from_path "$cvscfg(svnroot)/$cvscfg(svn_branchdir)/$frombranch/$cvsglb(relpath)"
    }
    # tag the current (mergedto) branch
    svn_tag $fromtag tags false $args ;# opens its own viewer
    # Tag the mergedfrom branch
    set filelist [join $args]
    foreach file $filelist {
      if {$file == "."} {
        svn_rcopy [safe_url $from_path] "tags" $totag ;# opens its own viewer
      } else {
        svn_rcopy [safe_url $from_path/$f] "tags" $totag ;# opens its own viewer
      }
    }
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

# SVN Checkout or Export.  Called from Repository Browser
proc svn_checkout {dir url path rev target cmd} {
  gen_log:log T "ENTER ($dir $url $path $rev $target $cmd)"

  foreach {incvs insvn inrcs} [cvsroot_check $dir] { break }
  if {$insvn} { 
    set mess "This is already a SVN controlled directory.  Are you\
              sure that you want to export into this directory?"
    if {[cvsconfirm $mess .modbrowse] != "ok"} {
      return
    }
  }

  set command "svn $cmd"
  if {$rev != {} } {
    # Let them get away with saying r3 instead of 3
    set rev [string trimleft $rev {r}] 
    append command " -r$rev"
  }
  set path [safe_url $path]
  append command " $url/$path"
  if {$target != {} } {
    append command " $target"
  }
  gen_log:log C "$command"

  set v [viewer::new "SVN $cmd"]
  $v\::do "$command"
  $v\::wait
  gen_log:log T "LEAVE"
}

# SVN cat or ls.  Called from module browser
proc svn_filecat {root path title} {
  gen_log:log T "ENTER ($root $path $title)"

  set url [safe_url $root/$path]
  # Should do cat if it's a file and ls if it's a path
  if {[string match {*/} $title]} {
    set command "svn ls \"$url\""
    set wintitle "SVN ls"
  } else {
    set command "svn cat \"$url\""
    set wintitle "SVN cat"
  }

  set v [viewer::new "$wintitle $url"]
  $v\::do "$command"
}

# SVN log.  Called from module browser
proc svn_filelog {root path title} {
  global cvsglb

  gen_log:log T "ENTER ($root $path $title)"

  set command "svn log "
  # svn -g (mergeinfo) appeared in 1.5.  It depends on the server
  # as well as the client, so we can't go by version number.  we
  # just have to see if it works.
  if {$cvsglb(svn_mergeinfo_works)} {
    append command "-g "
  }

  set url [safe_url $root/$path]
  append command "\"$url\""
  set wintitle "SVN Log"

  set v [viewer::new "$wintitle $url"]
  $v\::do "$command"
}

proc svn_fileview {revision filename kind} {
# This views a specific revision of a file in the repository.
# For files checked out in the current sandbox.
  global cvscfg

  gen_log:log T "ENTER ($revision $filename $kind)"
  set command "cat"
  if {$kind == "directory"} {
     set command "ls"
  }
  if {$revision == {}} {
    set command "svn $command \"$filename\""
    set v [viewer::new "$filename"]
    $v\::do "$command"
  } else {
    set command "svn $command -$revision \"$filename\""
    set v [viewer::new "$filename Revision $revision"]
    $v\::do "$command"
  }
  gen_log:log T "LEAVE"
}

# Sends directory "." to the directory-merge tool
proc svn_directory_merge {} {
  global cvscfg
  global cvsglb
  
  gen_log:log T "ENTER"

  gen_log:log D "Relative Path: $cvsglb(relpath)"
  ::svn_branchlog::new $cvsglb(relpath) . 1

  gen_log:log T "LEAVE"
}

# Sends files to the SVN branch browser one at a time
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
    ::svn_branchlog::new $cvsglb(relpath) $file
  }

  gen_log:log T "LEAVE"
}

proc safe_url { url } {
  # Replacement is done in an ordered manner, so the  key  appearing
  # first  in  the list will be checked first, and so on.  string is
  # only iterated over once.
  set url [string map {
    "%20" "%20"
    "%25" "%25"
    "%26" "%26"
    "%" "%25"
    "&" "%26"
    " " "%20"
  } $url]
  #regsub -all {%} $url {%25} url
  #regsub -all {&} $url {%26} url
  #regsub -all { } $url {%20} url
  # These don't seem to be necessary
  #regsub -all {\+} $url {%2B} url
  #regsub -all {\-} $url {%2D} url
  return $url
}

namespace eval ::svn_branchlog {
  variable instance 0

  proc new {relpath filename {directory_merge {0}} } {
    variable instance
    set my_idx $instance
    incr instance

    namespace eval $my_idx {
      set my_idx [uplevel {concat $my_idx}]
      set filename [uplevel {concat $filename}]
      set relpath [uplevel {concat $relpath}]
      set directory_merge [uplevel {concat $directory_merge}]
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

      gen_log:log T "ENTER [namespace current]"
      if {$directory_merge} {
        set newlc [logcanvas::new . "SVN,loc" [namespace current]]
        set ln [lindex $newlc 0]
        set lc [lindex $newlc 1]
        set show_tags 0
      } else {
        set newlc [logcanvas::new $filename "SVN,loc" [namespace current]]
        set ln [lindex $newlc 0]
        set lc [lindex $newlc 1]
        set show_tags [set $ln\::opt(show_tags)]
      }

      # Implementation of Perl-like "grep {/re/} in_list"
      proc grep_filter { re in_list } {
        set res ""
        foreach x $in_list {
          if {[regexp $re $x]} {
            lappend res $x
          }
        }
        return $res
      }

      proc abortLog { } {
        global cvscfg
        variable cmd_log
        variable lc

        gen_log:log D "  $cmd_log\::abort"
        catch {$cmd_log\::abort}
        busy_done $lc
        pack forget $lc.stop
        pack $lc.close -in $lc.down.closefm -side right
        $lc.close configure -state normal
      }

      proc reloadLog { } {
        global cvscfg
        global cvsglb
        variable filename
        variable cmd_log
        variable lc
        variable ln
        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable revkind
        variable revpath
        variable revname
        variable revtags
        variable revbtags
        variable revmergefrom
        variable branchrevs
        variable allrevs
        variable revbranches
        variable logstate
        variable relpath
        variable filename
        variable show_tags

        gen_log:log T "ENTER"
        catch { $lc.canvas delete all }
        catch { unset revwho }
        catch { unset revdate }
        catch { unset revtime }
        catch { unset revcomment }
        catch { unset revtags }
        catch { unset revbtags }
        catch { unset revmergefrom }
        catch { unset branchrevs }
        catch { unset revbranches }
        catch { unset revkind }
        catch { unset revpath }
        catch { unset revname }

        pack forget $lc.close
        pack $lc.stop -in $lc.down.closefm -side right
        $lc.stop configure -state normal

        # Can't use file join or it will mess up the URL
        set safe_filename [safe_url $filename]
        set path "$cvscfg(url)/$safe_filename"
        $ln\::ConfigureButtons $filename

        # Find out where to put the working revision icon (if anywhere)
        set revnum_current [set $ln\::revnum_current]
        set revnum_current r$revnum_current
        #set command "svn info \"$filename\""
        #set cmd_log [exec::new $command]
        #set log_output [$cmd_log\::output]
        #$cmd_log\::destroy
        #set loglines [split $log_output "\n"]
        #foreach line $loglines {
          #if {[string match {Revision:*} $line]} {
            #set revnum_current [lindex $line 1]
            #set revnum_current r$revnum_current
          #}
        #}

        if { $relpath == {} } {
          set path "$cvscfg(svnroot)/$cvscfg(svn_trunkdir)/$safe_filename"
        } else {
          set path "$cvscfg(svnroot)/$cvscfg(svn_trunkdir)/$relpath/$safe_filename"
        }
        if {[read_svn_dir .] == -1} {
          set path "$cvscfg(svnroot)/$safe_filename"
          if {! [info exists cvscfg(svnconform_seen)]} {
            set msg "Your repository does not seem to be arranged in $cvscfg(svn_trunkdir), $cvscfg(svn_branchdir), and $cvscfg(svn_tagdir) directories.  The Branch Browser can't detect branches and tags."
            cvsok "$msg" $lc
            set cvscfg(svnconform_seen) 1
          }
        }
        # The trunk
        set branchrevs(trunk) {}
        # if the file was added on a branch, this will error out.
        # Come to think of it, there's nothing especially privileged
        # about the trunk except that one branch must not stop-on-copy
        set command "svn log $path"
        set cmd_log [exec::new $command {} 0 {} 1]
        set log_output [$cmd_log\::output]
        $cmd_log\::destroy
        if {$log_output == ""} {
          # Maybe the file isn't on the trunk anymore but it once was.
          # We'll have to use a range from r1 that case, to find it
          set j [string trimleft $revnum_current "r"]
          set range "${j}:1"
          set command "svn log -r $range $path"
          set cmd_log [exec::new $command {} 0 {} 1]
          set log_output [$cmd_log\::output]
          $cmd_log\::destroy
        }
        set trunk_lines [split $log_output "\n"]
        set rr [parse_svnlog $trunk_lines trunk]
        # See if the current revision is on the trunk
        set curr 0
        set brevs $branchrevs(trunk)
        set tip [lindex $brevs 0]
        set revpath($tip) $path
        set revkind($tip) "revision"
        set brevs [lreplace $brevs 0 0]
        if {$tip == $revnum_current} {
          # If current is at end of trunk do this.
          set branchrevs(trunk) [linsert $branchrevs(trunk) 0 {current}]
          set curr 1
        }
        foreach r $brevs {
          if {$r == $revnum_current} {
            # We need to make a new artificial branch off of $r
            lappend revbranches($r) {current}
          }
          gen_log:log D " $r $revdate($r) ($revcomment($r))"
          set revkind($r) "revision"
          set revpath($r) $path
        }
        set branchrevs($rr) $branchrevs(trunk)
        set revkind($rr) "root"
        set revname($rr) "trunk"
        set revbtags($rr) "trunk"
        set revpath($rr) $path

        # Branches
        set command "svn list $cvscfg(svnroot)/$cvscfg(svn_branchdir)"
        set cmd_log [exec::new $command {} 0 {} 1]
        set branches [$cmd_log\::output]
        $cmd_log\::destroy

        # There can be files such as "README" here that aren't branches
        set branches [grep_filter {/$} $branches]

        foreach branch $branches {
          gen_log:log D "$branch"
          set branch [string trimright $branch "/"]
          # Can't use file join or it will mess up the URL
          gen_log:log D "BRANCHES: RELPATH \"$relpath\""
          if { $relpath == {} } {
            set path "$cvscfg(svnroot)/$cvscfg(svn_branchdir)/$branch/$safe_filename"
          } else {
            set path "$cvscfg(svnroot)/$cvscfg(svn_branchdir)/$branch/$relpath/$safe_filename"
          }
          set command "svn log --stop-on-copy $path"
          set cmd_log [exec::new $command {} 0 {} 1]
          set log_output [$cmd_log\::output]
          $cmd_log\::destroy
          if {$log_output == ""} {
            continue
          }
          set loglines [split $log_output "\n"]
          set rb [parse_svnlog $loglines $branch]
          #puts "parse_svnlog returned base revision $rb for $branch"
          # See if the current revision is on this branch
          set curr 0
          set brevs $branchrevs($branch)
          set tip [lindex $brevs 0]
          set revpath($tip) $path
          set revkind($tip) "revision"
          set brevs [lreplace $brevs 0 0]
          if {$tip == $revnum_current} {
            # If current is at end of the branch do this.
            set branchrevs($branch) [linsert $branchrevs($branch) 0 {current}]
            set curr 1
          }
          foreach r $brevs {
            if {$r == $revnum_current} {
              # We need to make a new artificial branch off of $r
              lappend revbranches($r) {current}
            }
            gen_log:log D "  $r $revdate($r) ($revcomment($r))"
            set revkind($r) "revision"
            set revpath($r) $path
          }
          set branchrevs($rb) $branchrevs($branch)
          set revkind($rb) "branch"
          set revname($rb) $branch
          lappend revbtags($rb) $branch
          set revpath($rb) $path

          set command "svn log -q $path"
          set cmd_log [exec::new $command {} 0 {} 1]
          set log_output [$cmd_log\::output]
          $cmd_log\::destroy
          if {$log_output == ""} {
            cvsfail "$command returned no output"
            return
          }
          set loglines [split $log_output "\n"]
          parse_q $loglines $branch

          # If current is HEAD of branch, move the branchpoint
          # back one, before You are Here
          set idx [llength $branchrevs($branch)]
          if {$curr} {
            #puts "Currently at Top: decrementing branchpoint"
            gen_log:log E "Currently at Top: decrementing branchpoint"
            incr idx -1
          }
          set bp [lindex $allrevs($branch) $idx]
          if {$bp == ""} {
            #puts "Allrevs same as branchrevs: decrementing branchpoint"
            gen_log:log E "Allrevs same as branchrevs: decrementing branchpoint"
            set bp [lindex $branchrevs($branch) end]
            set bpn [string trimleft $bp "r"]
            incr bpn -1
            set bp "r${bpn}"
          }
          lappend revbranches($bp) $rb
        }
        # Tags
        if {$show_tags} {
          set command "svn list $cvscfg(svnroot)/$cvscfg(svn_tagdir)"
          set cmd_log [exec::new $command {} 0 {} 1]
          set tags [$cmd_log\::output]
          $cmd_log\::destroy
          set n_tags [llength $tags]
          if {$n_tags > $cvscfg(toomany_tags)} {
            # If confirm is on, give them a chance to say yes or no to tags
            if {$cvscfg(confirm_prompt)} {
              set mess    "There are $n_tags tags.  It could take a long time "
              append mess "to process them. If you're willing to wait, "
              append mess " press OK and get a cup of coffee.\n"
              append mess "Otherwise, press Cancel and I will draw the "
              append mess "diagram now without showing tags.  "
              append mess "You may wish to turn off\n"
              append mess "View -> Revision Layout -> Show Tags\n"
              append mess " and\n"
              append mess "View -> Save Options"
              if {[cvsconfirm $mess $lc] != "ok"} {
                set tags ""
              }
            } else {
              # Otherwise, just don't process tags
              set tags ""
              gen_log:log E "Skipping tags: $n_tags > cvscfg(toomany_tags) ($cvscfg(toomany_tags))"
            }
          }
          foreach tag $tags {
            gen_log:log D "$tag"
            # There can be files such as "README" here that aren't tags
            if {![string match {*/} $tag]} {continue}
            set tag [string trimright $tag "/"]
            # Can't use file join or it will mess up the URL
            gen_log:log D "TAGS: RELPATH \"$relpath\""
            if { $relpath == {} } {
              set path "$cvscfg(svnroot)/$cvscfg(svn_tagdir)/$tag/$safe_filename"
            } else {
              set path "$cvscfg(svnroot)/$cvscfg(svn_tagdir)/$tag/$relpath/$safe_filename"
            }
            set command "svn log --stop-on-copy $path"
            set cmd_log [exec::new $command {} 0 {} 1]
            set log_output [$cmd_log\::output]
            $cmd_log\::destroy
            #update idletasks
            if {$log_output == ""} {
              continue
            }
            set loglines [split $log_output "\n"]
            set rb [parse_svnlog $loglines $tag]
            foreach r $branchrevs($tag) {
              gen_log:log D "  $r $revdate($r) ($revcomment($r))"
              set revkind($r) "revision"
              set revpath($r) $path
            }
            set revkind($rb) "tag"
            set revname($rb) "$tag"
            set revpath($rb) $path
  
            set command "svn log -q $path"
            set cmd_log [exec::new $command {} 0 {} 1]
            set log_output [$cmd_log\::output]
            $cmd_log\::destroy
            if {$log_output == ""} {
              cvsfail "$command returned no output"
              return
            }
            set loglines [split $log_output "\n"]
            parse_q $loglines $tag
            set bp [lindex $allrevs($tag) [llength $branchrevs($tag)]]
            lappend revtags($bp) $tag
            update idletasks
          }
        }

        pack forget $lc.stop
        pack $lc.close -in $lc.down.closefm -side right
        $lc.close configure -state normal

        set branchrevs(current) {}
        [namespace current]::svn_sort_it_all_out
        gen_log:log T "LEAVE"
        return
      }

      proc parse_svnlog {lines r} {
        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable revmergefrom
        variable branchrevs

        gen_log:log T "ENTER (<...> $r)"
        set revnum ""
        set i 0
        set l [llength $lines]
        while {$i < $l} {
	  if { $i > 0 } { incr i -1 }
	  set last [lindex $lines $i]
	  incr i 1
          set line [lindex $lines $i]
          gen_log:log D "$i of $l:  $line"
          if { [ regexp {^[-]+$} $last ] && [ regexp {^r[0-9]+ \| .*line[s]?$} $line] } {
            if {[expr {$l - $i}] <= 1} {break}
            set line [lindex $lines $i]
            set splitline [split $line "|"]
            set revnum [string trim [lindex $splitline 0]]
            lappend branchrevs($r) $revnum
            set revwho($revnum) [string trim [lindex $splitline 1]]
            set date_and_time [string trim [lindex $splitline 2]]
            set revdate($revnum) [lindex $date_and_time 0]
            set revtime($revnum) [lindex $date_and_time 1]
            set notelen [lindex [string trim [lindex $splitline 3]] 0]
            gen_log:log D "revnum $revnum"
            gen_log:log D "revwho($revnum) $revwho($revnum)"
            gen_log:log D "revdate($revnum) $revdate($revnum)"
            gen_log:log D "revtime($revnum) $revtime($revnum)"
            gen_log:log D "notelen $notelen"
            
            incr i 2
            set revcomment($revnum) ""
            set c 0
            while {$c < $notelen} {
              append revcomment($revnum) "[lindex $lines [expr {$c + $i}]]\n"
              incr c
            }
            set revcomment($revnum) [string trimright $revcomment($revnum)]
            gen_log:log D "revcomment($revnum) $revcomment($revnum)"
          }
          incr i
        }
        gen_log:log T "LEAVE \"$revnum\""
        return $revnum
      }

      proc parse_q {lines r} {
        variable allrevs

        set allrevs($r) ""
        foreach line $lines {
          if [regexp {^r} $line] {
            gen_log:log D "$line"
            set splitline [split $line "|"]
            set revnum [string trim [lindex $splitline 0]]
            lappend allrevs($r) $revnum
          }
        }
      }

      proc svn_sort_it_all_out {} {
        global cvscfg
        global current_tagname
        variable filename
        variable lc
        variable ln
        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable revkind
        variable revpath
        variable revname
        variable revtags
        variable revbtags
        variable branchrevs
        variable revbranches
        variable logstate
        variable revnum
        variable rootbranch
        variable revbranch
  
        gen_log:log T "ENTER"

        # Sort the revision and branch lists and remove duplicates
        foreach r [lsort -dictionary [array names revkind]] {
           gen_log:log D "revkind($r) $revkind($r)"
           #if {![info exists revbranches($r)]} {set revbranches($r) {} }
        }
        foreach r [lsort -dictionary [array names revpath]] {
           gen_log:log D "revpath($r) $revpath($r)"
           #if {![info exists revbranches($r)]} {set revbranches($r) {} }
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names branchrevs]] {
           gen_log:log D "branchrevs($a) $branchrevs($a)"
        }
        gen_log:log D ""
           foreach a [lsort -dictionary [array names revbranches]] {
           gen_log:log D "revbranches($a) $revbranches($a)"
        }
        gen_log:log D ""
           foreach a [lsort -dictionary [array names revbtags]] {
           gen_log:log D "revbtags($a) $revbtags($a)"
        }
        gen_log:log D ""
           foreach a [lsort -dictionary [array names revtags]] {
           gen_log:log D "revtags($a) $revtags($a)"
        }
        # We only needed these to place the you-are-here box.
        catch {unset rootbranch revbranch}
        $ln\::DrawTree now
        gen_log:log T "LEAVE"
      }

      [namespace current]::reloadLog
      return [namespace current]
    }
  }
}
