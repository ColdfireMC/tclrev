
# Find SVN URL and where we are in path
proc read_svn_dir {dirname} {
  global cvscfg
  global cvsglb
  global current_tagname
  global module_dir
  global cmd

  gen_log:log T "ENTER ($dirname)"
  set cvsglb(vcs) svn
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
      set cvscfg(url) [lrange $infoline 1 end]
      gen_log:log D "$cvscfg(url)"
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
      #set cvsglb(root) $cvscfg(svnroot)
      gen_log:log D "SVN URL: $cvscfg(url)"
      gen_log:log D "svnroot: $cvscfg(svnroot)"
      set cvsglb(relpath) [join $relp {/}]
      gen_log:log D "relpath: $cvsglb(relpath)"
      regsub -all {%20} $cvsglb(relpath) { } module_dir
      gen_log:log D "tagname: $current_tagname"
    }
  }
  if {$root == ""} {
    gen_log:log F "Nonconforming repository"
    puts "No conforming $cvscfg(svn_trunkdir)/$cvscfg(svn_branchdir)/$cvscfg(svn_tagdir) structure detected in the repository"
    puts " I won't be able to detect any branches or tags."
    gen_log:log D "SVN URL: $cvscfg(url)"
    set cvscfg(svnroot) $cvscfg(url)
    set cvsglb(root) $cvscfg(svnroot)
    gen_log:log D "svnroot: $cvscfg(svnroot)"
    set cvsglb(relpath) ""
    set cvsglb(svnconform) 0
    gen_log:log T "LEAVE (-1)"
    return -1
  }
  set cvsglb(svnconform) 1
  gen_log:log T "LEAVE (0)"
  return 1
}

proc svn_lock {do files} {
  global cvscfg

  if {$files == {}} {
    cvsfail "Please select one or more files!" .workdir
    return
  }
  switch -- $do {
    lock { set commandline "svn lock $files"}
    unlock { set commandline "svn unlock $files"}
  }
  set cmd [::exec::new "$commandline"]

  if {$cvscfg(auto_status)} {
    $cmd\::wait
    setup_dir
  }
}

# Get stuff for main workdir browser
proc svn_workdir_status {} {
  global cmd
  global Filelist

  gen_log:log T "ENTER"
  set cmd(svn_status) [exec::new "svn status -uvN --xml"]
  set xmloutput [$cmd(svn_status)\::output]
  set entrylist [regexp -all -inline {<entry.*?</entry>} $xmloutput]

  if [info exists cmd(svn_status)] {
    $cmd(svn_status)\::destroy
    catch {unset cmd(svn_status)}
  }
  # do very simple xml parsing
  foreach entry $entrylist {
    set filename ""
    set cauthor ""
    set lockstatus ""
    set wrev ""
    set crev ""

    regexp  {<entry\s+path=\"([^\"]*?)\"\s*>} $entry tmp filename
    regexp  {<wc\-status.*</wc\-status>} $entry wcstatusent
    if { [ regexp  {<repos\-status.*</repos\-status>} $entry repstatusent ] } {
      regexp  {<repos\-status\s+([^>]*)>} $repstatusent tmp repstatusheader
      regexp  {item=\"(\w+)\"} $repstatusheader tmp repstatus
      if { [ regexp  {<lock>.*</lock>} $repstatusent replock ] } {
        set lockstatus "locked"
      }
    } else {
      set repstatus ""
    }
    regexp  {<author>(.*)</author>} $wcstatusent tmp cauthor
    regexp  {<commit\s+revision=\"(\d+)\"} $wcstatusent tmp crev
    regexp  {<wc\-status\s+([^>]*)>} $wcstatusent tmp wcstatusheader
    regexp  {item=\"(\w+)\"} $wcstatusheader tmp wcstatus
    regexp  {revision=\"(\w+)\"} $wcstatusheader tmp wrev
    # FIXME?: an item can have item="normal" but props="modified"
    # In a short status, that's the same as ' M'  'C' for conflicted is also possible
    # After a merge, "." has that status. "svn diff" shows "Modified:svn:mergeinfo"
    # We aren't using that info though we could get it this way:
    regexp  {props=\"(\w+)\"} $wcstatusheader tmp props
    # It may be relevant to merging, ie. to show that we have done a merge but not
    # committed it.
    if { [ regexp  {<lock>.*</lock>} $wcstatusent wclock ] } {
      set lockstatus "havelock"
    }

    # wcstatus="added|normal|deleted|missing|unversioned|modified|none
    # repstatus="modified|none"
    set status ""

    set displaymod ""
    if { [file exists $filename] && [file type $filename] == "link" } {
        set displaymod "<link> "
    }
    if [file isdirectory $filename] {
      set displaymod "<dir> "
    }


    set mayhavelock false
    switch -exact -- $wcstatus {
      "normal" {
        if { $repstatus == "modified"} {
          append displaymod "Out-of-date"
        } else {
          if {$props eq "modified"} {
            append displaymod "Property Modified"
          } else {
            append displaymod "Up-to-date"
          }
          set mayhavelock true
        }
      }
      "missing" { append displaymod "Missing" }
      "modified" {
        if  { $repstatus == "modified"} {
          append displaymod "Needs Merge"
        } else {
          append displaymod "Locally Modified"
           set mayhavelock true
        }
      }
      "added" { append displaymod "Locally Added" }
      "deleted" { append displaymod "Locally Removed" }
      "unversioned" { append displaymod "Not managed by SVN" }
      "conflicted" { append displaymod "Conflict" }
      L { append displaymod "Locked" }
      S { append displaymod "Switched to Branch" }
      "none" { append displaymod "Missing/Needs Update" }
      ~ { append displaymod "Dir/File Mismatch" }
    }
    #in some cases there might be locks: check now
    if { $mayhavelock } {
        switch -exact -- $lockstatus {
            "" { }
            "havelock" { append displaymod "/HaveLock" }
            "locked" { append displaymod "/Locked" }
        }
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
    #gen_log:log D " \
       \"$Filelist($filename:status)\" \
       \"$wrev (committed:$crev)\" \
       \"$Filelist($filename:editors)\" \
       \"$filename\" \
       "
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

  gen_log:log T "ENTER ($args)"
  set filelist [join $args]

  set command [exec::new "svn remove $filelist"]
  auto_setup_dir $command

  gen_log:log T "LEAVE"
}

# does a status report on the files in the current directory. Called from
# "Status" in the Reports menu. Uses the recurse and status_filter settings.
proc svn_status {detail args} {
  global cvscfg
 
  gen_log:log T "ENTER ($args)"

  busy_start .workdir.main
  set filelist [join $args]
  set flags ""
  set title "SVN Status ($detail)"

  if {$cvscfg(status_filter)} {
    append flags " -q"
  }
  if {! $cvscfg(recurse)} {
    append flags " --depth=files"
  }
  switch -- $detail {
    summary {
      append flags " -u"
    }
    verbose {
      append flags " -v"
    }
  }
  set command "svn status $flags $filelist"
  set check_cmd [viewer::new "$title"]
  $check_cmd\::do "$command" 0 status_colortags

  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

# called from the "Check Directory" button in the workdir and the Reports menu
proc svn_check {} {
  global cvscfg

  gen_log:log T "ENTER ()"

  busy_start .workdir.main
  set title "SVN Directory Check"
  set flags ""
  if {$cvscfg(recurse)} {
    append title " (recursive)"
  } else {
    append flags " --depth=files"
    append title " (toplevel)"
  }
  set command "svn status $flags"
  set check_cmd [viewer::new "$title"]
  $check_cmd\::do "$command" 0 status_colortags

  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

# svn update - called from workdir browser
proc svn_update {args} {

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

  #set command "svn update --accept postpone"
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
  global module_dir

  switch -exact -- $cvsglb(tagmode_selection) {
    "Keep" {
       set command "svn update"
     }
    "Trunk" {
       set command "svn switch --ignore-ancestry ^/$cvscfg(svn_trunkdir)/$module_dir"
     }
    "Branch" {
       set command "svn switch --ignore-ancestry ^/$cvscfg(svn_branchdir)/$cvsglb(branchname)/$module_dir"
     }
    "Tag" {
       set command "svn switch --ignore-ancestry ^/$cvscfg(svn_tagdir)/$cvsglb(tagname)/$module_dir"
     }
    "Revision" {
       # Let them get away with saying r3 instead of 3
       set rev [string trimleft $cvsglb(revnumber) {r}]
       # FIXME: This doesn't work if you're not on the trunk
       set command "svn switch --ignore-ancestry ^/trunk/$module_dir -r $rev"
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
  #grab set .commit

  frame .commit.top -border 8
  frame .commit.down -relief groove -border 2

  pack .commit.top -side top -fill x
  pack .commit.down -side bottom -fill x
  frame .commit.comment
  pack .commit.comment -side top -fill both -expand 1
  label .commit.comment.lcomment -text "Your log message" -anchor w
  button .commit.comment.history -text "Log History" \
    -command history_browser
  text .commit.comment.tcomment -relief sunken -width 70 -height 10 \
    -bg $cvsglb(textbg) -exportselection 1 \
    -wrap word -border 2 -setgrid yes


  # Explain what it means to "commit" files
  message .commit.message -justify left -aspect 800 \
    -text "This will commit changes from your \
           local, working directory into the repository, recursively."

  pack .commit.message -in .commit.top -padx 2 -pady 5

  button .commit.ok -text "OK" \
    -command {
      #grab release .commit
      wm withdraw .commit
      set cvsglb(commit_comment) [.commit.comment.tcomment get 1.0 end]
      svn_commit $cvsglb(commit_comment) $cvsglb(commit_list)
      commit_history $cvsglb(commit_comment)
    }
  button .commit.apply -text "Apply" \
    -command {
      set cvsglb(commit_comment) [.commit.comment.tcomment get 1.0 end]
      svn_commit $cvsglb(commit_comment) $cvsglb(commit_list)
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
  .commit.comment.tcomment insert end $cvsglb(commit_comment)

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

# Called from workdir browser popup
proc svn_rename_ask {args} {

  gen_log:log T "ENTER ($args)"
  set file [lindex $args 0]
  if {$file eq ""} {
    cvsfail "Rename:\nPlease select a file !" .workdir
    return
  }

  # Send it to the dialog to ask for the filename
  file_input_and_do "SVN Rename" "svn_rename \"$file\""

  gen_log:log T "LEAVE"
}

# The callback for svn_rename_ask and file_input_and_do
proc svn_rename {args} {
  global cvscfg

  gen_log:log T "ENTER ($args)"

  set v [viewer::new "SVN rename"]
  set command "svn rename [lindex $args 0] [lindex $args 1]"
  $v\::do "$command"

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

# Called from workdir browser annotate button
proc svn_annotate {revision args} {

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

# This creates a patch file between two revisions of a module.  If the
# second revision is null, it creates a patch to the head revision.
# If both are null the top two revisions of the file are diffed.
proc svn_patch { pathA pathB revA dateA revB dateB outmode outfile } {

  gen_log:log T "ENTER ($pathA $pathB $revA $dateA $revB $dateB $outmode $outfile)"

  lassign {{} {}} rev1 rev2
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

# Called from the module browser
proc svn_delete {root path} {

  gen_log:log T "ENTER ($root $path)"

  set mess "Really delete $path from the SVN repository?"
  if {[cvsconfirm $mess .modbrowse] != "ok"} {
    return
  }
  set url [safe_url $root/$path]
  set v [viewer::new "SVN delete"]
  set command "svn delete -m\"Removed\\ using\\ TkCVS\" \"$url\""
  $v\::do "$command"
  modbrowse_run
  gen_log:log T "LEAVE"
}

# This is the callback for the folder-opener in ModTree
proc svn_jit_listdir {} {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER"
  gen_log:log D "svnroot: $cvscfg(svnroot)"
  set tv .modbrowse.treeframe.pw
  set opendir [$tv selection]
  # It might be a string like {/trunk/Dir 2}
  set opendir [join $opendir]
  gen_log:log D "selection: $opendir"
  set dir [string trimleft $opendir / ]
  set command "svn list -v \"$cvscfg(svnroot)/$dir\""
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
      if {$item ne "."} {
        lappend dirs "$item"
        set info($item) [lrange $logline 0 4]
      }
    } else {
      set item [lrange $logline 6 end]
      lappend fils "$item"
      set info($item) [lrange $logline 0 5]
    }
  }

  busy_start $tv
  # Remove the placeholder
  if {[$tv exists "/$dir/placeholder"]} {
    gen_log:log D "$tv delete /$dir/placeholder"
    $tv delete \"/$dir/placeholder\"
  }
  foreach f $fils {
    gen_log:log D "$tv insert /$dir end -id /$dir/$f -image paper -values [list $f]"
    $tv insert "/$dir" end -id "/$dir/$f" -image paper -values [list "$f"]
  }
  foreach d $dirs {
    svn_jit_dircmd "$dir" $d
  }

  busy_done $tv
  gen_log:log T "LEAVE"
}

proc svn_jit_dircmd { parent dir } {
  global cvscfg
  global Tree

  gen_log:log T "ENTER ($parent $dir)"

  set tv .modbrowse.treeframe.pw
  # Here we are just figuring out if the top level directory is empty or not.
  # We don't have to collect any other information, so no -v flag
  set command "svn list \"$cvscfg(svnroot)/$parent/$dir\""
  set cmd(svnlist) [exec::new "$command"]
  if {[info exists cmd(svnlist)]} {
    set contents [$cmd(svnlist)\::output]
    $cmd(svnlist)\::destroy
    catch {unset cmd(svnlist)}
  }
  set lbl "[file tail $dir]/"

  set dirs {}
  set fils {}
  set nl 0
  foreach logline [split $contents "\n"] {
    if {$logline == ""} continue
    incr nl
    #gen_log:log D "$logline"
    if [string match {*/} $logline] {
      set item [string trimright $logline "/"]
      lappend dirs $item
    } else {
      lappend fils $logline
    }
  }
  set exp "($nl items)"

  if {$parent ne {}} {
    set parent "/$parent"
  }

  # To avoid having to look ahead and build the whole tree at once, we put
  # a "marker" item in non-empty directories so it will look non-empty
  # and be openable
  if {$dirs == {} && $fils == {}} {
    # Empty, so no placeholder
    gen_log:log D "$tv insert $parent end -id $parent/$dir -image dir -values {$lbl $exp}"
    $tv insert "$parent" end -id "$parent/$dir" -image dir -values [list "$lbl" "$exp"]
  } else {
    gen_log:log D "$tv insert $parent end -id $parent/$dir -image dir -values {$lbl $exp}"
    $tv insert "$parent" end -id "$parent/$dir" -image dir -values [list "$lbl" "$exp"]
    # Placeholder so that folder is openable
    gen_log:log D "$tv insert $parent/$dir end -id $parent/$dir/placeholder -values {placeholder \"\"}"
    $tv insert "$parent/$dir" end -id "$parent/$dir/placeholder" -values [list "placeholder" ""]
  }
  set depth [llength [file split "$parent/$dir"]]
  set col0_width [expr {$depth * $cvscfg(mod_iconwidth)}]
  $tv column #0 -width $col0_width

  #gen_log:log T "LEAVE"
}

# called from module browser - list branches & tags
proc parse_svnmodules {svnroot} {
  global cvscfg

  gen_log:log T "ENTER ($svnroot)"

  set tv .modbrowse.treeframe.pw
  set command "svn list -v $svnroot"
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
        if {$item ne "./"} {
      lappend dirs [string trimright $item "/"]
      }
    } else {
      set item [lrange $logline 6 end]
      lappend fils $item
      set info($item) [lrange $logline 0 5]
    }
  }

  foreach f $fils {
    gen_log:log D "$tv insert {} end -id $f -image Fileview -values {$f \"\"}"
    $tv insert {} end -id $f -image paper -values [list "$f" ""]
  }
  foreach d $dirs {
    svn_jit_dircmd {} $d
  }
  gen_log:log T "LEAVE"
}

# Called when a directory in the module browser is closed
proc svn_closedir {} {
  set tv .modbrowse.treeframe.pw
  set closedir [$tv selection]
  # It might be a list like {/trunk/Dir 2}
  set closedir [join $closedir]
  gen_log:log D "selection: $closedir"
  # Clear the contents
  set contents [$tv children $closedir]
  gen_log:log D "$tv delete $contents"
  $tv delete $contents
  # Put the placeholder back
  gen_log:log D "$tv insert $closedir end -id $closedir/placeholder -text placeholder"
  $tv insert "$closedir" end -id "$closedir/placeholder" -text placeholder
}

# called from workdir Reports menu. Uses recurse setting
proc svn_log {detail args} {
  global cvsglb

  gen_log:log T "ENTER ($detail $args)"

  busy_start .workdir.main
  set filelist [join $args]
  set flags ""
  # svn log is always recursive

  if {[llength $filelist] == 0} {
    set filelist {{}}
  }
  if {[llength $filelist] > 1} {
    set title "SVN Log ($detail)"
  } else {
    set title "SVN Log $filelist ($detail)"
  }
  
  switch -- $detail {
     latest {
       append flags "-r COMMITTED "
     }
     summary {
       append flags "-q "
     }
  }
  if {$detail ne "summary"} {
    append flags "-g "
  }

  set v [viewer::new "$title"]
  foreach file $filelist {
    $v\::log "$file\n"
    set command "svn log $flags \"$file\""
    $v\::do "$command" 0
    $v\::wait
  }

  busy_done .workdir.main
  gen_log:log T "LEAVE"
}

# called from branch browser
proc svn_log_rev {filepath} {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($filepath)"

  set svncommand "svn log -g "
  if {[regexp {/} $filepath]} {
    append svncommand "--stop-on-copy "
  }
  append svncommand "\"$filepath\""
  set logcmd [viewer::new "SVN log $filepath"]
  $logcmd\::do "$svncommand"
  gen_log:log T "LEAVE"
}

proc svn_info {args} {
  global cvscfg
  gen_log:log T "ENTER ($args)"

  set filelist [join $args]
  set urllist ""
  foreach file $filelist {
      append urllist $cvscfg(url)/$file
      append urllist " "
  }
  set command "svn info "
  append command $urllist

  set logcmd [viewer::new "SVN Info"]
  $logcmd\::do "$command"
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
    # We don't want to tie up the whole UI with tkdiff, but if we don't wait,
    # we don't know if we can mark it resolved.  The context popup for a
    # conflict file in SVN has a "resolve" pick which calls svn_resolve. That
    # function checks whether there are still conflict markers in the file and
    # won't let you resolve it if so.
    set tkdiff_command "$cvscfg(tkdiff) -conflict -o \"$file\" \"$file\""
    gen_log:log C "$tkdiff_command"
    set ret [catch {eval "exec $tkdiff_command &"} view_this]
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

# svn tag or branch - called from tag and branch dialogs
proc svn_tag {tagname b_or_t updflag comment args} {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($tagname $b_or_t $updflag comment $args)"

  if {$tagname == ""} {
    cvsfail "You must enter a tag name!" .workdir
    return 1
  }
  set filelist [join $args]
  gen_log:log D "relpath: $cvsglb(relpath)  filelist \"$filelist\""

  if {$b_or_t == "tag"} {
    set pathelem "$cvscfg(svn_tagdir)"
    set typearg "tags"
  }
  if {$b_or_t == "branch"} {
    set pathelem "$cvscfg(svn_branchdir)"
    set typearg "branches"
  }

  set v [viewer::new "SVN Copy $tagname"]
  set to_url "$cvscfg(svnroot)/$pathelem/$tagname/$cvsglb(relpath)"

  # When delivered scriptically, there can't be any spaces in the comments. This is a
  # known thing with Subversion. So we escape them.
  regsub -all { } $comment {\\ } comment
  if { $filelist == {} } {
    set command "svn copy -m\"$comment\" \"$cvscfg(url)\" \"$to_url\""
    $v\::log "$command"
    $v\::do "$command"
  } else {
    foreach f $filelist {
      set from_path [safe_url $cvscfg(url)/$f]
      set to_path [svn_pathforcopy $tagname $typearg]
      if {[file isdirectory $f]} {
        set command "svn copy -m\"$comment\" $from_path $to_path"
      } else {
        set command "svn copy --parents -m\"$comment\" \"$from_path\" \"$to_path/$f\""
      }
      $v\::log "$command"
      $v\::do "$command"
    }
  }

  if {$updflag == "yes"} {
    # update so we're on the branch
    set to_path [svn_pathforcopy $tagname $typearg]
    set command "svn switch $to_path"
    $v\::log "$command"
    $v\::do "$command" 0 status_colortags
    $v\::wait
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

# makes a tag or branch.  Called from the workdir, module or branch
# browser
proc svn_rcopy {from_path b_or_t newtag {from {}}} {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($from_path $b_or_t $newtag)"

  if {[string match {bran*} $b_or_t]} {
    set comment "branch\\ rcopy\\ by\\ TkCVS"
  } else {
    set comment "tag\\ rcopy\\ by\\ TkCVS"
  }

  set v [viewer::new "SVN Copy $newtag"]
  set to_path [svn_pathforcopy $newtag $b_or_t]
  set from_path [string trimright $from_path "/"]

  # Copy the selected path
  if { $from != {} } {
    set command "svn copy -$from -m\"$comment\" [safe_url $from_path] $to_path"
  } else {
    set command "svn copy -m\"$comment\" [safe_url $from_path] $to_path"
  }
  $v\::do "$command"
  $v\::wait
  gen_log:log T "LEAVE"
}

# If a file to be copied isn't at the top level, we need to construct the
# destination path. It's no longer necessary to do svn mkdir, since svn copy
# has a --parent option.
proc svn_pathforcopy {tagname b_or_t} {
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER (\"$tagname\" \"$b_or_t\")"
  # Can't use file join or it will mess up the URL
  set to_path [safe_url "$cvscfg(svnroot)/$b_or_t/$tagname"]

  # We may need to construct a path to copy the file to
  set cum_path ""
  set pathelements [file split $cvsglb(relpath)]
  set depth [llength $pathelements]
  for {set i 0} {$i < $depth} {incr i} {
    set cum_path [file join $cum_path [lindex $pathelements $i]]
    gen_log:log D "  $i $cum_path"
  }
  if {$cum_path != ""} {
    set to_path "$to_path/$cum_path"
  }

  gen_log:log T "LEAVE (\"$to_path\")"
  return $to_path
}

# join (merge) a chosen revision of local file to the current revision.
proc svn_merge {parent frompath since currentpath frombranch args} {
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
  #set commandline "svn merge --accept postpone \"$currentpath\" \"$frompath\""
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

  # Tag if desired (no means not a branch)
  if {$cvscfg(auto_tag) && $fromtag != ""} {
    if {$frombranch == "trunk"} {
      set from_path "$cvscfg(svnroot)/$cvscfg(svn_trunkdir)/$cvsglb(relpath)"
    } else {
      set from_path "$cvscfg(svnroot)/$cvscfg(svn_branchdir)/$frombranch/$cvsglb(relpath)"
    }
    set from_path [string trimright $from_path "/"]
    # tag the current (mergedto) branch
    svn_tag $fromtag "tag" no "tag\ after\ merge\ by\ TkCVS" $args
    # Tag the mergedfrom branch
    set filelist [join $args]
    foreach f $filelist {
      if {$f == "."} {
        svn_rcopy [safe_url $from_path] "tags" $totag $from
      } else {
        svn_rcopy [safe_url $from_path/$f] "tags" $totag/$f $from
      }
    }
  }

  if {$cvscfg(auto_status)} {
    setup_dir
  }
  gen_log:log T "LEAVE"
}

# SVN Checkout or Export.  Called from Repository Browser
proc svn_checkout {url path rev target cmd} {
  global incvs insvn inrcs ingit

  gen_log:log T "ENTER ($url $path $rev $target $cmd)"

  set command "svn $cmd"
  if {$rev != {} } {
    # Let them get away with saying r3 instead of 3
    set rev [string trimleft $rev {r}]
    append command " -r$rev"
  }

  set dir [pwd]
  if {[file pathtype $target] eq "absolute"} {
    set tgt $target
  } else {
    set tgt "$dir/$target"
  }
  set mess "This will $cmd\n\
     $url/$path\n\
     to directory\n\
     $tgt\n\
     Are you sure?"
  if {[cvsconfirm $mess .modbrowse] == "ok"} {
    set path [safe_url $path]
    append command " $url/$path"
    if {$target != {} } {
      append command " $target"
    }
  
    set v [viewer::new "SVN $cmd"]
    $v\::do "$command"
    $v\::wait
  }
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

  set command "svn log -g "

  set url [safe_url $root/$path]
  append command "\"$url\""
  set wintitle "SVN Log"

  set v [viewer::new "$wintitle $url"]
  $v\::do "$command"
}

# This views a specific revision of a file in the repository.
# For files checked out in the current sandbox.
proc svn_fileview {revision filename kind} {

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
  # Replacement is done in an ordered manner, so the key appearing
  # first in the list will be checked first, and so on. The string is
  # only iterated over once.
  set url [string map {
    "%20" "%20"
    "%25" "%25"
    "%26" "%26"
    "%" "%25"
    "&" "%26"
    " " "%20"
  } $url]
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
      variable show_tags
      variable show_merges

      gen_log:log T "ENTER [namespace current]"
      if {$directory_merge} {
        set newlc [logcanvas::new . "SVN,loc" [namespace current]]
      } else {
        set newlc [logcanvas::new $filename "SVN,loc" [namespace current]]
      }
      set ln [lindex $newlc 0]
      set lc [lindex $newlc 1]
      set show_tags [set $ln\::opt(show_tags)]

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
        variable show_merges

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
        set branchlist ""

        pack forget $lc.close
        pack $lc.stop -in $lc.down.closefm -side right
        $lc.stop configure -state normal
        busy_start $lc

        # Can't use file join or it will mess up the URL
        set safe_filename [safe_url $filename]
        set path "$cvscfg(url)/$safe_filename"
        $ln\::ConfigureButtons $filename

        set show_merges [set $ln\::opt(show_merges)]
        set show_tags [set $ln\::opt(show_tags)]

        # Find out where to put the working revision icon (if anywhere)
        set revnum_current [set $ln\::revnum_current]
        set revnum_current r$revnum_current

        if { $relpath == {} } {
          set path "$cvscfg(svnroot)/$cvscfg(svn_trunkdir)/$safe_filename"
        } else {
          set path "$cvscfg(svnroot)/$cvscfg(svn_trunkdir)/$relpath/$safe_filename"
        }
        if {! $cvsglb(svnconform)} {
          set path "$cvscfg(svnroot)/$safe_filename"
        }
        # We need to go to the repository to find the highest revision.  Doing
        # info on local files may not have it.  Let's start with what we've got
        # though in case it fails.
        set highest_revision [string trimleft $revnum_current "r"]
        set command "svn info $path"
        gen_log:log C "$command"
        set ret [catch {eval "exec $command"} output]
        if {$ret} {
          gen_log:log D "This file $path must not be in the trunk"
          ## cvsfail $output
        }
        foreach infoline [split $output "\n"] {
          if {[string match "Revision*" $infoline]} {
            set highest_revision [lrange $infoline 1 end]
            gen_log:log D "$highest_revision"
          }
        } 
        # The trunk
        set branchrevs(trunk) {}
        # There's nothing especially privileged about the trunk except that one
        # branch must not stop-on-copy.  Maybe the file was added on a branch,
        # or maybe it isn't on the trunk anymore but it once was.  We'll have
        # to use a range from r1 that case, to find it
        set range "${highest_revision}:1"
        set command "svn log "
        append command "-g "
        append command "-r $range $path"
        set cmd_log [exec::new $command {} 0 {} 1]
        set log_output [$cmd_log\::output]
        $cmd_log\::destroy
        set trunk_lines [split $log_output "\n"]
        set rootrev [parse_svnlog $trunk_lines trunk]
        gen_log:log D "BASE/ROOT: $rootrev"

        # We do a stop-on-copy too, to see where the trunk started, since the
        # file may have been merged in from a branch
        set command "svn log -g -q"
        append command " --stop-on-copy $path"
        set cmd_log [exec::new $command {} 0 {} 1]
        set log_output [$cmd_log\::output]
        $cmd_log\::destroy
        if {$log_output == ""} {
          continue
        }
        set loglines [split $log_output "\n"]
        parse_q $loglines trunk
        set rt [lindex $allrevs(trunk) end]
        gen_log:log D "trunk: BASE $rt"
        set branchroot(trunk) $rt
        if {$rt ne $rootrev} {
          set drawing_root $rt
          lappend branchlist $rt
          set branchrevs($rt) $allrevs(trunk)
        } else {
          set drawing_root $rootrev
          set branchrevs($rootrev) $branchrevs(trunk)
        }
        set revbtags($drawing_root) "trunk"
        set revpath($drawing_root) $path
        set revkind($drawing_root) "root"

        # See if the current revision is on the trunk
        set curr 0
        set brevs $branchrevs($drawing_root)
        set tip [lindex $brevs 0]
        set revpath($tip) $path
        set revkind($tip) "revision"
        if {$tip == $revnum_current} {
          # If current is at end of trunk do this.
          set branchrevs($drawing_root) [linsert $branchrevs($drawing_root) 0 {current}]
          set curr 1
        }
        # We checked the tip, now check the rest while we assign revkind etc
        set brevs [lrange $brevs 1 end-1]
        foreach r $brevs {
          if {($curr == 0) && ($r == $revnum_current)} {
            # We need to make a new artificial branch off of $r
            lappend revbranches($r) {current}
          }
          gen_log:log D " $r $revdate($r) ($revcomment($r))"
          set revkind($r) "revision"
          set revpath($r) $path
        }
        # We may have added a "current" branch. We have to set all its
        # stuff or we'll get errors
        foreach {revwho(current) revdate(current) revtime(current)
           revlines(current) revcomment(current)
           branchrevs(current) revbtags(current)}\
           {{} {} {} {} {} {} {}} \
           { break }


        # if root is not empty added it to the branchlist
        if { $rootrev ne "" } {
          lappend branchlist $rootrev
        }
        # Prepare to draw something on the canvas so user knows we're working
        set cnv_y 20
        set yspc  15
        set cnv_h [winfo height $lc.canvas]
        set cnv_w [winfo width $lc.canvas]
        # subtract scrollbars etc
        incr cnv_h -20
        incr cnv_w -20
        # This is necessary to reset the view after clearing the canvas
        $lc.canvas configure -scrollregion [list 0 0 $cnv_w $cnv_h]
        set cnv_x [expr {$cnv_w / 2 - 8}]
        # Branche
        # Get a list of the branches from the repository
        # Draw something on the canvas so the user knows we're working
        $lc.canvas create text $cnv_x $cnv_y -text "Getting BRANCHES" -tags {temporary}
        set cnv_y [expr {$cnv_y + $yspc}]

        set command "svn list $cvscfg(svnroot)/$cvscfg(svn_branchdir)"
        set cmd_log [exec::new $command {} 0 {} 1]
        set branches [$cmd_log\::output]
        $cmd_log\::destroy
        # There can be files such as "README" here that aren't branches
        # so we look for a trailing slash
        set branches [grep_filter {/$} $branches]

        foreach branch $branches {
          set branch [string trimright $branch "/"]
          gen_log:log D "========= $branch =========="
          # Draw something on the canvas so the user knows we're working
          $lc.canvas create text $cnv_x $cnv_y -text $branch -tags {temporary} -fill $cvscfg(colourB)
          set cnv_y [expr {$cnv_y + $yspc}]
          update
          # Can't use file join or it will mess up the URL
          gen_log:log D "BRANCHES: RELPATH \"$relpath\""
          if { $relpath == {} } {
            set path "$cvscfg(svnroot)/$cvscfg(svn_branchdir)/$branch/$safe_filename"
          } else {
            set path "$cvscfg(svnroot)/$cvscfg(svn_branchdir)/$branch/$relpath/$safe_filename"
          }
          # Do stop-on-copy to find the base of the branch
          set command "svn log -g"
          append command " --stop-on-copy $path"
          set cmd_log [exec::new $command {} 0 {} 1]
          set log_output [$cmd_log\::output]
          $cmd_log\::destroy
          if {$log_output == ""} {
            continue
          }
          set loglines [split $log_output "\n"]
          set rb [parse_svnlog $loglines $branch]
          gen_log:log D "$branch: BASE $rb"
          set branchroot($branch) $rb
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
          # build a list of all branches so we can make sure each branch is on
          # a revbranch list so there will be a full set of branches on diagram
          lappend branchlist $rb
          lappend revbtags($rb) $branch
          set revpath($rb) $path

          set command "svn log -q -g $path"
          set cmd_log [exec::new $command {} 0 {} 1]
          set log_output [$cmd_log\::output]
          $cmd_log\::destroy
          if {$log_output == ""} {
            cvsfail "$command returned no output"
            return
          }
          set loglines [split $log_output "\n"]
          parse_q $loglines $branch

          # If current is HEAD of branch, the count is one too high because of the
          # You Are Here box, so the branchpoint would be too low
          set idx [llength $branchrevs($branch)]
          if {$curr} {
            gen_log:log D "Currently at Top"
            incr idx -1
          }
          set bp [lindex $allrevs($branch) $idx]
          gen_log:log D "$allrevs($branch)"
          gen_log:log D " PARENT for $branch: $bp"
          if {$bp == ""} {
            gen_log:log D "allrevs same as branchrevs: decrementing branchpoint"
            set bp [lindex $branchrevs($branch) end]
            set bpn [string trimleft $bp "r"]
            incr bpn -1
            set bp "r${bpn}"
            gen_log:log D " NEW PARENT for $branch: $bp"
          }
          set revparent($rb) $bp
          lappend revbranches($bp) $rb
          gen_log:log D "===== finished $branch ======"
        } ;# Finished branches

        # Tags
        # Get a list of the tags from the repository
        if {$show_tags} {
          # Draw something on the canvas so the user knows we're working
          set cnv_y [expr {$cnv_y + $yspc}]
          $lc.canvas create text $cnv_x $cnv_y -text "Getting TAGS" -tags {temporary}
          set cnv_y [expr {$cnv_y + $yspc}]

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
              append mess " press OK.\n"
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
            # Draw something on the canvas so the user knows we're working
            set tag [string trimright $tag "/"]
            # Draw something on the canvas so the user knows we're working
            $lc.canvas create text $cnv_x $cnv_y -text $tag -tags {temporary} -fill $cvscfg(colourA)
            set cnv_y [expr {$cnv_y + $yspc}]
            update
            # Can't use file join or it will mess up the URL
            gen_log:log D "TAGS: RELPATH \"$relpath\""
            if { $relpath == {} } {
              set path "$cvscfg(svnroot)/$cvscfg(svn_tagdir)/$tag/$safe_filename"
            } else {
              set path "$cvscfg(svnroot)/$cvscfg(svn_tagdir)/$tag/$relpath/$safe_filename"
            }
            # Do log with stop-on-copy to find the actual revision that was tagged.
            # The tag itself created a rev which may be much higher.
            set command "svn log -g --stop-on-copy $path"
            set cmd_log [exec::new $command {} 0 {} 1]
            set log_output [$cmd_log\::output]
            $cmd_log\::destroy
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
            set revpath($rb) $path

            # Now do log -q to find the previous rev, which is down
            # the list.  For tags, it's only one down, so we can limit
            # the log to 2.  It only speeds it up a little though.
            set command "svn log -q --limit 2 $path"
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
            gen_log:log D "   revtags($bp) $revtags($bp)"
            update idletasks
          }
        }

        # sort the list in rev number order
        set brlist [lsort -unique -dictionary $branchlist]
        gen_log:log D "init branches $brlist"
        gen_log:log D "OLDEST ROOT $rootrev"
        gen_log:log D "DRAWING ROOT $drawing_root"
        # rebuild the list
        set branchlist {}
        foreach br $brlist {
          set btag $revbtags($br)
          gen_log:log D "$br $btag"
          if {[info exists branchroot($btag)]} {
            gen_log:log D " base of $br is $branchroot($btag)"
          } else {
            gen_log:log D " base of $br is MISSING"
          }
          if {[info exists revparent($br)]} {
            gen_log:log D " parent of $br is $revparent($br)"
          } else {
            gen_log:log D " parent of $br is MISSING"
          }
        }
        set branchlist $brlist
        gen_log:log D "branches $branchlist"

        pack forget $lc.stop
        pack $lc.close -in $lc.down.closefm -side right
        $lc.close configure -state normal

        set branchrevs(current) {}
        # In SVN, sort_it_all_out is mostly a report
        [namespace current]::svn_sort_it_all_out
        $ln\::DrawTree now

        # We chose a branch other than the oldest one for this file, as the root.
        # Let's draw the branch that has the oldest rev for this file, too.
        if {$rootrev ne $drawing_root} {
          gen_log:log D "Adding UNROOTED branch: $rootrev"
          $ln\::DrawSideTree 40 0 $rootrev
        }
        gen_log:log T "LEAVE"
        return
      }

      # Parses a --stop-on-copy log, getting information for each revision
      proc parse_svnlog {lines r} {
        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable branchrevs
        variable revmergefrom

        gen_log:log T "ENTER (<...> $r)"
        set revnum ""
        set i 0
        set l [llength $lines]
        # in svn_log output, line zero is a separator and can be ignored
        while {$i < $l} {
	  if { $i > 0 } { incr i -1 }
	  set last [lindex $lines $i]
	  incr i 1
          set line [lindex $lines $i]
          gen_log:log D "$i of $l:  $line"
          if { [ regexp {^[-]+$} $last ] && [ regexp {^r[0-9]+ \| .*line[s]?$} $line] } {
            # ^ The last line was dashes and this one starts with a revnum
            if {[expr {$l - $i}] <= 1} {break}
            # ^ we came to the last line!
            # else deal with the line. We know it's formatted like this:
            # r4 | dorothyr | 2018-08-18 18:45:36 -0700 (Sat, 18 Aug 2018) | 1 line
            set line [lindex $lines $i]
            set splitline [split $line "|"]
            set revnum [string trim [lindex $splitline 0]]
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

            # See if there's merge info
            incr i 1
            set line [lindex $lines $i]
            if { [string match "Merged via:*" $line] } {
              set splitline [split $line " "]
              set mergedvia [string trim [lindex $splitline end]]
              lappend revmergefrom($mergedvia) $revnum
            } else {
              lappend branchrevs($r) $revnum
            }
            incr i 1
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
        # Return the base revnum of the branch
        return $revnum
      }

      # Parses a summary (-q) log to find what revisions are on it
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
        variable revtags
        variable revbtags
        variable branchrevs
        variable revbranches
        variable revmergefrom
        variable logstate
        variable revnum
        variable rootbranch
        variable revbranch

        gen_log:log T "ENTER"

        # Sort the revision and branch lists and remove duplicates
        foreach r [lsort -dictionary [array names revkind]] {
           gen_log:log D "revkind($r) $revkind($r)"
        }
        #foreach r [lsort -dictionary [array names revpath]] {
           #gen_log:log D "revpath($r) $revpath($r)"
        #}
        gen_log:log D ""
        foreach a [lsort -dictionary [array names branchrevs]] {
           gen_log:log D "branchrevs($a) $branchrevs($a)"
        }
        gen_log:log D ""
        foreach a [lsort -dictionary [array names revbranches]] {
           # sort the rev branches to they will be displayed in increasing order
           set revbranches($a) [lsort -dictionary $revbranches($a)]
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
        gen_log:log D ""
           foreach a [lsort -dictionary [array names revmergefrom]] {
           # Only take the highest rev of the messsy list that you might have here
           set revmergefrom($a) [lindex [lsort -dictionary $revmergefrom($a)] end]
           gen_log:log D "revmergefrom($a) $revmergefrom($a)"
        }
        # We only needed these to place the you-are-here box.
        catch {unset rootbranch revbranch}
        gen_log:log T "LEAVE"
      }

      [namespace current]::reloadLog
      return [namespace current]
    }
  }
}
