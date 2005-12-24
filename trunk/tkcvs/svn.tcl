# Find SVN URL
proc read_svn_dir {dirname} {
  global cvscfg
  global cvsglb
  global current_tagname
  global module_dir
  global cmd

  gen_log:log T "ENTER ($dirname)"
  # svn info gets the URL
  set cmd(info) [exec::new "svn info"]
  set info_lines [$cmd(info)\::output]
  foreach infoline [split $info_lines "\n"] {
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
      set state P
      for {set j 0} {$j < [llength $spl]} {incr j} {
        set word [lindex $spl $j]
        switch -- $state {
          P {
            switch -- $word {
              "trunk" {
                set type $word
                set current_tagname $word
                set state E
              } 
              "branches" {
                set type $word
                set state W
              }
              "tags" {
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
      set cvscfg(svnroot) [string trimright $root "/"]
      gen_log:log D "SVN URL: $cvscfg(url)"
      gen_log:log D "svnroot: $cvscfg(svnroot)"
      set cvsglb(relpath) [join $relp {/}]
      gen_log:log D "relpath: $cvsglb(relpath)"
      set module_dir $cvsglb(relpath)
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
  set cmd(svn_status) [exec::new "svn status -uvN"]
  set status_lines [split [$cmd(svn_status)\::output] "\n"]
  catch {unset cmd(svn_status)}
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
      set cauthor [lindex $varcols 2]
      set filename [lrange $varcols 3 end]
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
proc svn_check {directory {v {0}} } {
  global cvscfg

  gen_log:log T "ENTER ($directory $v)"

  busy_start .workdir.main

  set flags ""
  if {$v} {
    append flags "uv"
  }
  if {! $cvscfg(recurse)} {
    append flags "N"
  }
  if {$flags != ""} {
    set flags "-$flags"
  }
  set commandline "svn status $flags $directory"
  set check_cmd [viewer::new "SVN Status Check"]
  $check_cmd\::do $commandline 0 status_colortags

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

# Called from "update with options" dialog of workdir browser
proc svn_opt_update {} {
  global cvscfg
  global cvsglb

  switch -exact -- $cvsglb(tagmode_selection) {
    "Keep" {
       set command "svn update"
     }
    "Trunk" {
       set command "svn switch $cvscfg(svnroot)/trunk"
     }
    "Branch" {
       set command "svn switch $cvscfg(svnroot)/branches/$cvsglb(branchname)"
     }
    "Revision" {
       # Let them get away with saying r3 instead of 3
       set rev [string trimleft $cvsglb(revnumber) {r}]
       set command "svn update -r $rev"
     }
  }
  set upd_cmd [viewer::new "SVN Update/Switch"]
  $upd_cmd\::do $command 0 status_colortags

  if {$cvscfg(auto_status)} {
    $upd_cmd\::wait
    setup_dir
  }
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

# Called from workdir browser annotate button and from the log browser
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
  if {$pathA != {} && $pathB != {}} {
    set commandline "svn diff $pathA $pathB"
  } elseif {$rev1 != {} && $rev2 != {}} {
    set commandline "svn diff $pathA@$rev1 $pathA@$rev2"
  } else {
    cvsfail "Specify either two paths OR one path and two revisions"
    return
  }

  if {$outmode == 0} {
    set v [viewer::new "SVN Diff"]
    $v\::do "$commandline"
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
  set command "svn delete \"$url\" -m \"Removed using TkSVN\""
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
  #puts "<- delitem /$dir/d"
  ModTree:delitem $tf /$dir/d
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

  gen_log:log T "ENTER ($tf $dir)"
  #puts "\nEntering svn_jit_dircmd ($dir)"

  # Here we are just figuring out if the top level directory is empty or not.
  # We don't have to collect any other information, so no -v flag
  set command "svn list \"$cvscfg(svnroot)/$dir\""
  #puts "$command"
  set cmd(svnlist) [exec::new "$command"]
  if {[info exists cmd(svnlist)]} {
    set contents [$cmd(svnlist)\::output]
  }
  set lbl "[file tail $dir]/"
  set exp "([llength $contents] items)"

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

  if {$dirs == {} && $fils == {}} {
    #puts "  $dir is empty"
    catch "ModTree:newitem $tf \"/$dir\" \"$lbl\" \"$exp\" -image Folder"
  } else {
    #puts "  $dir has contents"
    set r [catch "ModTree:newitem $tf \"/$dir\" \"$lbl\" \"$exp\" -image Folder" err]
    if {! $r} {
      #puts "-> newitem /$dir/d"
      catch "ModTree:newitem $tf \"/$dir/d\" d d -image {}"
    }
  }

  gen_log:log T "LEAVE"
  #puts "Leaving svn_jit_dircmd\n"
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
  append commandline $filelist

  set logcmd [viewer::new "SVN Log ($cvscfg(ldetail))"]
  $logcmd\::do "$commandline"
  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

proc svn_merge_conflict {args} {
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
    set commandline "$cvscfg(tkdiff) -conflict -o \"$file\" \"$file\""
    gen_log:log C "$commandline"
    set ret [catch {eval "exec $commandline"} view_this]
    if {$ret == 0} {
      set mess "Mark $file resolved?"
      if {[cvsconfirm $mess .workdir] != "ok"} {
        continue
      }
      set commandline "svn resolved \"$file\""
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

proc svn_revert {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"
  set filelist [join $args]
  if {$filelist == ""} {
    set filelist "-R ."
  }
  gen_log:log D "Reverting $filelist"
  set cmd [exec::new "svn revert $filelist"]

  if {$cvscfg(auto_status)} {
    $cmd\::wait
    setup_dir
  }

  gen_log:log T "LEAVE"
}

proc svn_tag {tagname force branch update args} {
#
# This tags a file or directory.
#
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($tagname $force $branch $update)"

  if {$tagname == ""} {
    cvsfail "You must enter a tag name!" .workdir
    return 1
  }

  set v [viewer::new "SVN Tag (Copy)"]
  set command "svn copy ."
  # Can't use file join or it will mess up the URL
  if {$branch == "yes"} {
    set to_path "$cvscfg(svnroot)/branches/$tagname/$cvsglb(relpath)"
    set comment "Branched using TkSVN"
  } else {
    set to_path "$cvscfg(svnroot)/tags/$tagname/$cvsglb(relpath)"
    set comment "Tagged using TkSVN"
  }
  append command " $to_path -m \"$comment\""
  $v\::do "$command"
  $v\::wait

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

proc svn_rcopy {from_path to_path} {
#
# makes a tag or branch.  Called from the module browser
#
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($from_path $to_path)"

  set v [viewer::new "SVN Copy"]
  set command "svn copy $from_path"
  # Can't use file join or it will mess up the URL
  set comment "Copied using TkSVN"
  append command " $to_path -m \"$comment\""
  $v\::do "$command"
  $v\::wait

  modbrowse_run svn
  gen_log:log T "LEAVE"
}

proc svn_merge {fromrev sincerev frombranch file} {
#
# This does a join (merge) of a chosen revision of localfile to the
# current revision.
#
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($fromrev $sincerev $frombranch $file)"

  set v [viewer::new "SVN Merge"]

  # Way too many problems with auto-tagging.  I don't think it will work well with
  # Subversion - dar

  # Tagging involves commits, so we have to tag before we change files
  #if {$cvscfg(auto_tag)} {
    #set ret [catch "eval exec svn list $cvscfg(svnroot)/tags/$fromtag" err]
    #if {$ret} {
#puts $err
      #set commandline "svn mkdir -m\"TkSVN_Mergefrom\" $cvscfg(svnroot)/tags/$fromtag"
#puts $commandline
      #$v\::do $commandline
      #$v\::wait
    #}
## svn mkdir -m"Tagged from TkSVN Merge"  $cvscfg(svnroot)/tags/$fromtag
    #set commandline "svn copy -m\"Tag_Mergefrom\" $file"
    #if {$file == "."} {
      ## Not right.  Makes an extra directory under tag
      #append commandline " $cvscfg(svnroot)/tags/$fromtag"
    #} else {
      #append commandline " $cvscfg(svnroot)/tags/$fromtag/$file"
    #}
#puts "$commandline"
    #$v\::do "$commandline"
    #toplevel .reminder
    #message .reminder.m1 -aspect 600 -text \
      #"When you are finished checking in your merges, \
      #you should apply the tag"
    #entry .reminder.ent -width 32 -relief groove \
       #-font $cvscfg(guifont) -readonlybackground $cvsglb(readonlybg)
    #.reminder.ent insert end $totag 
    #.reminder.ent configure -state readonly
    #message .reminder.m2 -aspect 600 -text \
      #"using the \"Tag the selected files\" button"
    #frame .reminder.bottom -relief raised -bd 2
    #button .reminder.bottom.close -text "Dismiss" \
      #-command {destroy .reminder}
    #pack .reminder.bottom -side bottom -fill x
    #pack .reminder.bottom.close -side bottom -expand yes
    #pack .reminder.m1 -side top
    #pack .reminder.ent -side top -padx 2
    #pack .reminder.m2 -side top
  #}

  set fromrev [string trimleft $fromrev {r}]
  set sincerev [string trimleft $sincerev {r}]
  # for a file
  set commandline "svn merge -r$sincerev\:$fromrev $frombranch $file"
  # for cwd
  set commandline "svn merge -r$sincerev\:$fromrev $frombranch"
    
  $v\::do "$commandline" 0 status_colortags
  $v\::wait

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
    set commandline "svn ls \"$url\""
    set wintitle "SVN ls"
  } else {
    set commandline "svn cat \"$url\""
    set wintitle "SVN cat"
  }

  set v [viewer::new "$wintitle $url"]
  $v\::do "$commandline"
}

# SVN log.  Called from module browser
proc svn_filelog {root path title} {
  gen_log:log T "ENTER ($root $path $title)"

  set url [safe_url $root/$path]
  set commandline "svn log \"$url\""
  set wintitle "SVN Log"

  set v [viewer::new "$wintitle $url"]
  $v\::do "$commandline"
}

proc svn_fileview {revision filename kind} {
# This views a specific revision of a file in the repository.
# For files checked out in the current sandbox.
  global cvscfg

  gen_log:log T "ENTER ($revision $filename $kind)"
  set cmd "cat"
  if {$kind == "directory"} {
     set cmd "ls"
  }
  if {$revision == {}} {
    set commandline "svn $cmd \"$filename\""
    set v [viewer::new "$filename"]
    $v\::do "$commandline"
  } else {
    set commandline "svn $cmd -$revision \"$filename\""
    set v [viewer::new "$filename Revision $revision"]
    $v\::do "$commandline"
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
    set file [safe_url $file]
    ::svn_branchlog::new $cvsglb(relpath) $file
  }

  gen_log:log T "LEAVE"
}

proc safe_url { url } {
  regsub -all { } $url {%20} url
  regsub -all {%} $url {%25} url
  regsub -all {&} $url {%26} url
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

      proc reloadLog { } {
        global cvscfg
        global cvsglb
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
        catch { unset branchrevs }
        catch { unset revbranches }
        catch { unset revkind }
        catch { unset revpath }
        catch { unset revname }

        # Can't use file join or it will mess up the URL
        if { $relpath == {} } {
          set path "$cvscfg(url)/$filename"
        } else {
          set path "$cvscfg(url)/$relpath/$filename"
        }
        $ln\::ConfigureButtons $path

        # Find out where to put the working revision icon (if anywhere)
        set command "svn log -q --stop-on-copy $filename"
        set cmd [exec::new $command]
        set log_output [$cmd\::output]
        set loglines [split $log_output "\n"]
        set svnstat [lindex $loglines 1]
        set revnum_current [lindex $svnstat 0]
        gen_log:log D "revnum_current $revnum_current"
#puts "revnum_current $revnum_current"

        busy_start $lc
        if { $relpath == {} } {
          set path "$cvscfg(svnroot)/trunk/$filename"
        } else {
          set path "$cvscfg(svnroot)/trunk/$relpath/$filename"
        }
        # The trunk
#puts "\nTrunk"
        set branchrevs(trunk) {}
        # if the file was added on a branch, this will error out.
        # Come to think of it, there's nothing especially privileged
        #  about the trunk
        set command "svn log $path"
        gen_log:log C "$command"
        set ret [catch {eval exec $command} log_output]
        update idletasks
        if {$ret == 0} {
          set trunk_lines [split $log_output "\n"]
          set rr [parse_svnlog $trunk_lines trunk]
          # See if the current revision is on the trunk
          set curr 0
          set brevs $branchrevs(trunk)
          set tip [lindex $brevs 0]
          set brevs [lreplace $brevs 0 0]
          if {$tip == $revnum_current} {
            # If current is at end of trunk do this.
            set branchrevs(trunk) [linsert $branchrevs(trunk) 0 {current}]
            set curr 1
          }
          foreach r $brevs {
            if {$r == $revnum_current} {
              # We need to make a new artificial branch off of $r
              set revbranches($r) {current}
            }
            gen_log:log D " $r $revdate($r) ($revcomment($r))"
            set revkind($r) "revision"
            set revpath($r) $path
          }
          set branchrevs($rr) [lrange $branchrevs(trunk) 0 end-1]
          set revkind($rr) "root"
          set revname($rr) "trunk"
          set revtags($rr) "trunk"
          set revpath($rr) $path
        }

        # Branches
#puts "Branches"
        set command "svn list $cvscfg(svnroot)/branches"
        gen_log:log C "$command"
        set ret [catch {eval "exec $command"} branches]
        if {$ret != 0} {
            gen_log:log E "$branches"
#puts "$branches"
            set branches ""
        }
        foreach branch $branches {
          gen_log:log D "$branch"
          # There can be files such as "README" here that aren't branches
          if {![string match {*/} $branch]} {continue}
          set branch [string trimright $branch "/"]
#puts " $branch"
          # Can't use file join or it will mess up the URL
          if { $relpath == {} } {
            set path "$cvscfg(svnroot)/branches/$branch/$filename"
          } else {
            set path "$cvscfg(svnroot)/branches/$branch/$relpath/$filename"
          }
          set command "svn log --stop-on-copy $path"
          gen_log:log C "$command"
          set ret [catch {eval exec $command} log_output]
          update idletasks
          if {$ret != 0} {
            # This can happen a lot -let's not let it stop us
            gen_log:log E "$log_output"
            continue
          }
          set loglines [split $log_output "\n"]
          set rb [parse_svnlog $loglines $branch]
          # See if the current revision is on this branch
          set curr 0
          set brevs $branchrevs($branch)
          set tip [lindex $brevs 0]
          set brevs [lreplace $brevs 0 0]
          if {$tip == $revnum_current} {
            # If current is at end of the branch do this.
            set branchrevs($branch) [linsert $branchrevs($branch) 0 {current}]
            set curr 1
          }
          foreach r $brevs {
            if {$r == $revnum_current} {
              # We need to make a new artificial branch off of $r
              set revbranches($r) {current}
            }
            gen_log:log D "  $r $revdate($r) ($revcomment($r))"
            set revkind($r) "revision"
            set revpath($r) $path
          }
          set branchrevs($rb) [lrange $branchrevs($branch) 0 end-1]
          set revkind($rb) "branch"
          set revname($rb) $branch
          set revtags($rb) $branch
          set revpath($rb) $path

          set command "svn log -q $path"
          gen_log:log C "$command"
          set ret [catch {eval exec $command} log_output]
          update idletasks
          if {$ret != 0} {
            cvsfail "$log_output"
            return
          }
          set loglines [split $log_output "\n"]
          parse_q $loglines $branch

          # If current is HEAD of branch, move the branchpoint
          # back one, before You are Here
          set idx [llength $branchrevs($branch)]
          if {$curr} {
            incr idx -1
          }
          set bp [lindex $allrevs($branch) $idx]
#puts " allrevs($branch) $allrevs($branch)"
          set revbranches($bp) $branch

#puts " revbranches($bp) $branch = $rb"
          set revbranches($bp) $rb
#puts " revbranches($bp) $revbranches($bp)"
          update idletasks
        }
        # Tags
        if {$show_tags} {
#puts "Tags"
          set command "svn list $cvscfg(svnroot)/tags"
          gen_log:log C "$command"
          set ret [catch {eval "exec $command"} tags]
          if {$ret != 0} {
              gen_log:log E "$tags"
#puts "$tags"
              set tags ""
          }
          set n_tags [llength $tags]
          if {$n_tags > 10} {
            set mess "There are $n_tags tags.  This may take a long time."
            append mess "  If you're willing to wait, press OK."
            append mess "  Otherwise, press Cancel and I will draw the"
            append mess " diagram without showing tags. You may wish to turn off\n"
            append mess " View -> Revision Layout -> Show tags"
            if {[cvsconfirm $mess $lc] != "ok"} {
              set tags ""
       
            }
          }
          foreach tag $tags {
            gen_log:log D "$tag"
            # There can be files such as "README" here that aren't tags
            if {![string match {*/} $tag]} {continue}
            set tag [string trimright $tag "/"]
#puts " $tag"
            # Can't use file join or it will mess up the URL
            if { $relpath == {} } {
              set path "$cvscfg(svnroot)/tags/$tag/$filename"
            } else {
              set path "$cvscfg(svnroot)/tags/$tag/$relpath/$filename"
            }
            set command "svn log --stop-on-copy $path"
            gen_log:log C "$command"
            set ret [catch {eval exec $command} log_output]
            update idletasks
            if {$ret != 0} {
              # This can happen a lot -let's not let it stop us
              gen_log:log E "$log_output"
#puts "$log_output"
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
            gen_log:log C "$command"
            set ret [catch {eval exec $command} log_output]
            update idletasks
            if {$ret != 0} {
              cvsfail "$log_output"
              return
            }
            set loglines [split $log_output "\n"]
            parse_q $loglines $tag
            set bp [lindex $allrevs($tag) [llength $branchrevs($tag)]]
            lappend revtags($bp) $tag
            update idletasks
          }
        }

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
        variable branchrevs

        set i 0
        set l [llength $lines]
        while {$i < $l} {
          set line [lindex $lines $i]
          gen_log:log D "$i of $l:  $line"
          if [regexp {^--*$} $line] {
            # Next line is new revision
            incr i
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
        variable branchrevs
        variable revbranches
        variable logstate
        variable revnum
        variable rootbranch
        variable revbranch
  
        gen_log:log T "ENTER"

        # Sort the revision and branch lists and remove duplicates
        gen_log:log D "\nsvn_sort_it_all_out"
        foreach r [lsort -dictionary [array names revkind]] {
           gen_log:log D "revkind($r) $revkind($r)"
           if {![info exists revbranches($r)]} {set revbranches($r) {} }
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
