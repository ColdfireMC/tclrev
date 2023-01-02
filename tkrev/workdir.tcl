
# Tcl Library for TkRev
#

#
# Current working directory display.  Handles all of the functions
# concerned with navigating about the current directory on the main
# window.
#

proc workdir_setup {} {
  global cwd
  global module_dir
  global cvscfg
  global cvsglb
  global current_tagname
  global logclass  
  global tcl_platform
  global incvs insvn inrcs ingit
  set vrbl 1  
  global dot_workdir
  #gen_log:log T "ENTER"
  set cwd [pwd]  
  set pid [pid]  
  if {[exists dot_workdir]} {
    return
  } 
 change_dir "[pwd]"
 setup_dir
}

# Returns a list of the selected file names. This is where the arg-list comes
# from for mostttons and menus.
proc workdir_list_files {} {
  global DirList
  global cvsglb
    
  set wt .workdir.main.tree
  set cvsglb(current_selection) {}
  set DirList($wt:selection) {}
  set selected_items [$wt selection]
  foreach s $selected_items {
    set f [$wt set $s filecol]
    lappend DirList($wt:selection) "$f"
  }
  set cvsglb(current_selection) $DirList($wt:selection)
    
  #gen_log:log T "LEAVE -- ($cvsglb(current_selection))"
  return $cvsglb(current_selection)
}

proc workdir_edit_command {file} {
  global cvscfg
    
  #gen_log:log T "ENTER ($file)"
  if {[info exists cvscfg(editors)]} {
    foreach {editor pattern} $cvscfg(editors) {
      if {[string match $pattern $file]} {
        return "$editor \"$file\""
      }
    }
  }
  return "$cvscfg(editor) \"$file\""
}
proc auto_setup_dir {command} {
  global cvscfg
    
  if {$cvscfg(auto_status)} {
    $command\::wait
    setup_dir
  } else {
    after 0 "$command\::wait; $command\::destroy"
  }
}


proc workdir_delete_file {args} {  
  global cvscfg 
    
  #gen_log:log T "ENTER ($args)"
     
  set filelist [join $args]
  if {$filelist == ""} { 
    cvsfail "Please select some files to delete first!" .workdir
    return
  }
    
  if { [ are_you_sure "This will delete these files from your local, working directory:\n" $filelist ] == 1 } {
    #gen_log:log F "DELETE $filelist"
    eval file delete -force -- $filelist
    setup_dir
  }
  #gen_log:log T "LEAVE"
}  

proc are_you_sure {mess args} {
  # 
  # General posting message
  # 
  global cvscfg
    
  #gen_log:log T "ENTER ($mess $args)"
    
  set filelist [join $args]
  if {$cvscfg(confirm_prompt)} {
    append mess "\n"
    set indent "      "
        
    foreach item $filelist {
      if { $item != {} } {
        append mess " $indent"
        append mess " $item\n"
      }
    } 
    append mess "\nAre you sure?"
    if {[cvsconfirm $mess .workdir] != "ok"} {
      #gen_log:log T "LEAVE 0"
      return 0
    }
  }
  #gen_log:log T "LEAVE 1"
  return 1
 }

proc workdir_print_file {args} {   
  global cvscfg
    
  #gen_log:log T "ENTER ($args)"
    
  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select some files to print first!" .workdir
    return
  }  
  set mess "This will print these files:\n\n"
  foreach file $filelist {
    append mess "   $file\n"
  }
  append mess "\nUsing $cvscfg(print_cmd)\n"
  append mess "\nAre you sure?"
  if {[cvsconfirm $mess .workdir] == "ok"} {
    set final_result ""
    foreach file $filelist {
      set commandline [concat $cvscfg(print_cmd) \"$file\"]
      exec::new $commandline
    }
  }
}  
proc root_check { dir cvscfg_str cvsglb_str} {
  #  global cvscfg 
  #  global cvsglb
  array set cvscfg $cvscfg_str
  array set cvsglb $cvsglb_str 
  set srcdirtype(incvs) 0
  set srcdirtype(insvn) 0
  set srcdirtype(inrcs) 0
  set srcdirtype(ingit) 0
  set cvsrootfile [file join $dir CVS Root] 
  if {[file isfile $cvsrootfile]} {
    set incvs [ read_cvs_dir [file join $dir CVS]]
    # Outta here, don't check for svn or rcs
    if {$srcdirtype(incvs)} {
      return [array get srcdirtype]
    }
  }
  set svnret [catch {exec {*}svn info} svnout]
  if {! $svnret} {
    set srcdirtype(insvn) [ read_svn_dir $dir ]
    if {$srcdirtype(insvn)} {
      return a
    }
  }
  set rcsdir [file join $dir RCS]
  if {[file exists $rcsdir]} {
    set cvscfg(rcsdir) $rcsdir
    set inrcs 1
  } elseif {[llength [glob -nocomplain -dir $dir *,v]] > 0} {
    set inrcs 1
    set cvscfg(rcsdir) $dir
  } else {
    set cvscfg(rcsdir) ""
  }    
  if {$srcdirtype(inrcs)} {
    # Make sure we have rcs, and bag this (silently) if we don't
    set command "rcs --version"
    #gen_log:log C "$command"
    set ret [catch {exec {*}$command} raw_rcs_log]
    #gen_log:log F "$raw_rcs_log"
    if {$ret} {
      if [string match {rcs*} $raw_rcs_log] {
        # An old version of RCS, but it's here
        set srcdirtype(inrcs) 1
      } else {
        set srcdirtype(inrcs) 0
      }
    }
  }
  set gitret [catch {exec {*}git rev-parse --is-inside-work-tree} gitout]
  if {! $gitret} {
    # revparse may return "false"
    if {$gitout} {
      set srcdirtype(ingit) 1
      find_git_remote $dir
    }
  } else {
    set srcdirtype(ingit) 0
  }
  puts [array get srcdirtype]
  return [array get srcdirtype]
}
proc isCmDirectory { file } {
  ##gen_log:log T "ENTER ($file)"
  switch -- $file  { 
    "CVS"  -
    "RCS"  -
    ".svn"  - 
    ".git"  -
    "SCCS" { set value 1 }
    default { set value 0 }
  }
  return $value 
}
# Get the files in the current working directory. Use the file_filter
# values. Add hidden files if desired by the user. Sort them to match
# the ordering that will be returned by cvs commands (this matches the
# default ls ordering.).
proc getFiles { } { 
  global cvscfg
  global cvsglb
  set filelist "" 
  # make sure the file filter is at least set to "*".
  if { $cvscfg(show_file_filter) == "" } {
    set cvscfg(show_file_filter) "*"
  }
  # get the initial file list, including dotfiles if requested, filtered by show_file_filter
  if {$cvscfg(allfiles)} {
    # get hidden as well
    foreach item $cvscfg(show_file_filter) {
      set filelist [ concat [ glob -nocomplain .$item $item ] $filelist ]
    }
  } else {
    foreach item $cvscfg(show_file_filter) {
      set filelist [ concat [ glob -nocomplain $item ] $filelist ]
    }
  }
  # ignore files if requested by ingore_file_filter
  set ignore_file_filter [concat $cvscfg(ignore_file_filter) $cvsglb(vcs_hidden_files)]
  if { $ignore_file_filter != "" } {
    foreach item $ignore_file_filter {
      # for each pattern
      if { $item != "*" } {
        # if not "*"
        set idx [lsearch $filelist $item]
        while { [set idx [lsearch $filelist $item]] != -1 } {
          # for each occurence, delete
          catch { set filelist [ lreplace $filelist $idx $idx ] }
        }
      }
    }
  } 
  # make sure "." is always in the list for 'cd' purposes
  if { "." ni $filelist} {
    set filelist [ concat "." $filelist ] 
  } 
  # make sure ".." is always in the list for 'cd' purposes
  if { ".." ni $filelist} {
    set filelist [ concat ".." $filelist ] 
  }
  # sort it
  set filelist [ lsort $filelist ] 
  # if this directory is under CVS and CVS is not in the list, add it. Its
  # presence is needed for later processing
  if { ( [ file exists "CVS" ] ) && ("CVS" ni $filelist) } {
   catch { set filelist [ concat "CVS" $filelist ] }
  }
  return $filelist
}