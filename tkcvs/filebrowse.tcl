#
# Tcl library for TkCVS
#

#
# Sets up a dialog to browse the contents of a module.
#

proc browse_files {module} {
  global filenames
  global modval
  global checkout_version
  global cvscfg

  gen_log:log T "ENTER ($module)"
  static {browser 0}

  if {$module == ""} {
    cvsfail "Please select a module!" .modbrowse
    return
  }
  #gen_log:log D "[array names modval]"
  if {[lsearch -exact [array names modval] $module] < 0} {
    cvsfail "$module is not a CVS module" .modbrowse
    return
  }

  # Find the list of file names.
  find_filenames $module

  if {! [info exists filenames($module)]} {
    cvsfail "There are no files in this module!" .modbrowse
    return
  }

  #
  # Create the browser window.
  #
  incr browser
  set filebrowse ".filebrowse$browser"
  toplevel $filebrowse
  frame $filebrowse.up   -relief groove -border 2
  frame $filebrowse.up.left
  frame $filebrowse.up.right
  frame $filebrowse.down -relief groove -border 2

  pack $filebrowse.up -side top -fill x
  pack $filebrowse.up.left -side left -fill both
  pack $filebrowse.up.right -side left -fill both -expand 1
  pack $filebrowse.down -side bottom -fill x

  label $filebrowse.lver1 -text "Version / Tag " -anchor w
  # label $filebrowse.lver2 -anchor w -text "Version / Tag 2 (diff)"

  entry $filebrowse.tver1 -relief sunken -textvariable checkout_version

  pack $filebrowse.lver1 \
    -in $filebrowse.up.left -side top -fill x
  pack $filebrowse.tver1 \
    -in $filebrowse.up.right -side top -fill x

  #
  # Create buttons
  #
  if {[catch "image type Fileview"]} {
    workdir_images
  }

  button $filebrowse.view -image Fileview \
    -command "module_fileview $filebrowse $module"
  button $filebrowse.log -image Branches \
    -command "module_filelog $filebrowse $module"
  button $filebrowse.tag -image Tags \
    -command "module_tagview $filebrowse $module"
  button $filebrowse.quit -text "Close" \
    -padx 0 -pady 0 \
    -command "destroy $filebrowse; exit_cleanup 0"

  pack $filebrowse.view \
       $filebrowse.log \
       $filebrowse.tag \
    -in $filebrowse.down -side left -ipadx 1 -ipady 1 -fill x -expand 1
  pack $filebrowse.quit \
    -in $filebrowse.down -side left -ipadx 0 -ipady 0 -fill both -expand 1

  set_tooltips $filebrowse.view \
    {"View the selected file"}
  set_tooltips $filebrowse.log \
    {"See the revision log and branches of the selected file"}
  set_tooltips $filebrowse.tag \
    {"List the tags of the selected file"}

  #
  # Create a scrollbar and a list box.
  #
  scrollbar $filebrowse.scroll -relief sunken \
    -command "$filebrowse.list yview"
  listbox $filebrowse.list \
    -yscroll "$filebrowse.scroll set" -relief sunken \
    -font $cvscfg(listboxfont) \
    -width 40 -height 25 -setgrid yes
  pack $filebrowse.scroll -side right -fill y
  pack $filebrowse.list -side left -fill both -expand 1

  #
  # Window manager stuff.
  #
  wm title $filebrowse "Files in $module"
  wm minsize $filebrowse 5 5

  #
  # Fill the list.
  #
  foreach file $filenames($module) {
    if {[info exists modval($module)]} {
      set module $modval($module)
    }
    regsub "^$module/" $file "" file
    $filebrowse.list insert end $file
  }
  gen_log:log T "LEAVE"
}

proc filepath {module filename} {
  # Prepend a path to the filename if needed
  global modval
  global module_dir
  global cvscfg
  global cvs

  gen_log:log T "ENTER ($filename $module)"
  regsub -all {\$} $filename {\$} file
 
  # set global module variable - logcanvas may need it

  set commandline \
     "$cvs -d $cvscfg(cvsroot) rdiff -s -D 01/01/1971 \"$file\""
  gen_log:log C  $commandline
  set ret [catch {eval "exec $commandline"} view_this]
  gen_log:log D "\"$view_this\""
  if {! $ret} {
    gen_log:log T "LEAVE (fine the way we are) ($file)"
    return $file
  }

  if {[info exists modval($module)]} {
    gen_log:log D "modval $module \"$modval($module)\""
    set module_dir $modval($module)
    #set file "$module_dir/[file tail $file]"
    set file "$module_dir/$file"
    gen_log:log T "LEAVE (prepend modval) ($file)"
    return $file
  }
  set file "$module/$file"
  gen_log:log T "LEAVE (default) ($file)"
  return $file
}

proc module_filelog {toplevelname module} {
  # Open the logbrowser from the file list
  gen_log:log T "ENTER ($toplevelname $module)"
  set listname $toplevelname.list
  foreach item [$listname curselection] {
    set v [$listname get $item]
    set f [filepath $module $v]
    cvs_filelog "$f" $toplevelname
  }
  gen_log:log T "LEAVE"
}

proc module_fileview {toplevelname module} {
  # View a file from the file list
  gen_log:log T "ENTER ($toplevelname $module)"
  set listname $toplevelname.list
  foreach item [$listname curselection] {
    set v [$listname get $item]
    set f [filepath $module $v]
    cvs_fileview_checkout [$toplevelname.tver1 get] "$f"
  }
  gen_log:log T "LEAVE"
}

proc module_tagview {toplevelname module} {
  # List the tags of a file from the filelist
  gen_log:log T "ENTER ($toplevelname $module)"
  set listname $toplevelname.list
  foreach item [$listname curselection] {
    set v [$listname get $item]
    set f [filepath $module $v]
    view_output::new "$f Tags" [cvs_gettaglist "$f" $toplevelname]
  }
  gen_log:log T "LEAVE"
}


