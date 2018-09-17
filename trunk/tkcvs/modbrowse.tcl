#
# Set up a check out dialog.
#

proc modbrowse_setup {} {
  global cwd
  global cvsroot
  global modbrowse_module
  global modbrowse_path
  global modbrowse_title
  global env
  global cvsglb
  global cvscfg
  global tcl_platform

  gen_log:log T "ENTER"
  set cwd [pwd]

  # Window manager stuff.
  toplevel .modbrowse
  wm title .modbrowse "TkCVS $cvscfg(version) Repository Browser"
  wm iconname .modbrowse "TkCVS Repository Browser"
  if {$tcl_platform(platform) != "windows"} {
    wm iconbitmap .modbrowse @$cvscfg(bitmapdir)/tkcvs48.xbm
  }
  wm protocol .modbrowse WM_DELETE_WINDOW {
    .modbrowse.bottom.buttons.close invoke 
  }
  if {[info exists cvscfg(modgeom)]} {
    wm geometry .modbrowse $cvscfg(modgeom)
  } else {
    wm geometry .modbrowse 510x470
  }

  if {[catch "image type Who"]} {
    modbrowse_images
  }

  modbrowse_menus

  #
  # Top section - module, tags, root
  #
  frame .modbrowse.top -relief groove -border 2
  pack .modbrowse.top -side top -fill x

  label .modbrowse.top.lmcode -text "Module"
  entry .modbrowse.top.tmcode -textvariable modbrowse_module \
    -font $cvscfg(listboxfont) -border 2

  # We have these possibilities
  foreach VCS {cvs svn} {
    if [info exists env(${VCS}ROOT)] {
      gen_log:log D "env(${VCS}ROOT) $env(${VCS}ROOT) $VCS"
      ::picklist::used cvsroot "$env(${VCS}ROOT) $VCS"
    }
  }
  foreach VCS {cvs svn git} {
    if [info exists cvscfg(${VCS}root)] {
      gen_log:log D "cvscfg(${VCS}root) $cvscfg(${VCS}root) $VCS"
      ::picklist::used cvsroot $cvscfg(${VCS}root)
    }
  }
  # Where do we think we are?
  gen_log:log D "cvsglb(root) $cvsglb(root) cvsglb(vcs) $cvsglb(vcs)"

  label .modbrowse.top.lroot -text "Repository"
  ::picklist::entry .modbrowse.top.troot cvsglb(root) cvsroot
  # We can't really do this because we can't necessarily guess
  # the VCS from a path name
  #::picklist::bind .modbrowse.top.troot <Return> \
     { modbrowse_run }

  button .modbrowse.top.bworkdir -image Workdir \
    -command {workdir_setup}

  label .modbrowse.top.lcwd -text "Current Directory"
  ::picklist::entry .modbrowse.top.tcwd cwd directory
  ::picklist::bind .modbrowse.top.tcwd <Return> \
     {if {[pwd] != $cwd} {module_changedir "$cwd"}}

  grid columnconf .modbrowse.top 1 -weight 1
  grid rowconf .modbrowse.top 3 -weight 1
  grid .modbrowse.top.lroot -column 0 -row 0 -sticky w
  grid .modbrowse.top.troot -column 1 -row 0 -columnspan 2 -padx 4 -sticky ew
  grid .modbrowse.top.lmcode -column 0 -row 1 -sticky w
  grid .modbrowse.top.tmcode -column 1 -row 1 -padx 3 -sticky ew
  grid .modbrowse.top.lcwd -column 0 -row 2 -sticky w
  grid .modbrowse.top.tcwd -column 1 -row 2 -padx 4 -sticky ew
  grid .modbrowse.top.bworkdir -column 2 -row 1 -rowspan 2 -sticky w

  # Pack the bottom before the middle so it doesnt disappear if
  # the window is resized smaller
  frame .modbrowse.bottom -relief groove -border 2 -height 128
  frame .modbrowse.bottom.buttons
  frame .modbrowse.bottom.buttons.cvsfuncs -relief groove -bd 2
  frame .modbrowse.bottom.buttons.svnfuncs -relief groove -bd 2
  frame .modbrowse.bottom.buttons.modfuncs -relief groove -bd 2
  frame .modbrowse.bottom.buttons.closefm

  pack .modbrowse.bottom -side bottom -fill x
  pack .modbrowse.bottom.buttons -side top -fill x -expand yes
  pack .modbrowse.bottom.buttons.closefm -side right -expand yes
  pack .modbrowse.bottom.buttons.cvsfuncs -side left
  pack .modbrowse.bottom.buttons.svnfuncs -side left -expand yes
  pack .modbrowse.bottom.buttons.modfuncs -side left -expand yes

  #
  # Create buttons
  #
  button .modbrowse.bottom.buttons.modfuncs.filebrowse -image Files \
    -command { browse_files $modbrowse_module }
  button .modbrowse.bottom.buttons.modfuncs.patchsummary -image Patches \
    -command { dialog_cvs_patch $cvscfg(cvsroot) $modbrowse_module 1 }
  button .modbrowse.bottom.buttons.modfuncs.patchfile -image Patchfile \
    -command { dialog_cvs_patch $cvscfg(cvsroot) $modbrowse_module 0 }
  button .modbrowse.bottom.buttons.modfuncs.checkout -image Checkout \
    -command { dialog_cvs_checkout $cvscfg(cvsroot) $modbrowse_module }
  button .modbrowse.bottom.buttons.modfuncs.export -image Export \
    -command { dialog_cvs_export $cvscfg(cvsroot) $modbrowse_module }
  button .modbrowse.bottom.buttons.modfuncs.tag -image Tag \
    -command { rtag_dialog $cvscfg(cvsroot) $modbrowse_module "tag" }
  button .modbrowse.bottom.buttons.modfuncs.branchtag -image Branchtag \
    -command { rtag_dialog $cvscfg(cvsroot) $modbrowse_module "branch" }

  button .modbrowse.bottom.buttons.svnfuncs.filecat -image Fileview \
    -command { svn_filecat $cvscfg(svnroot) $modbrowse_path $modbrowse_title}
  button .modbrowse.bottom.buttons.svnfuncs.filelog -image Log \
    -command { svn_filelog $cvscfg(svnroot) $modbrowse_path $modbrowse_title}
  button .modbrowse.bottom.buttons.svnfuncs.remove -image SvnRemove \
    -command { svn_delete $cvscfg(svnroot) $modbrowse_path }

  button .modbrowse.bottom.buttons.cvsfuncs.import -image Import \
     -command { import_run }
  button .modbrowse.bottom.buttons.cvsfuncs.who -image Who \
     -command {cvs_history all $modbrowse_module}
  button .modbrowse.bottom.buttons.cvsfuncs.brefresh  -image Refresh \
     -command { modbrowse_run }

  button .modbrowse.bottom.buttons.close -text "Close" \
    -command { module_exit; exit_cleanup 0 }

  grid .modbrowse.bottom.buttons.cvsfuncs.brefresh -column 0 -row 0 \
     -ipadx 4 -ipady 4
  grid .modbrowse.bottom.buttons.cvsfuncs.who -column 1 -row 0 \
     -ipadx 4 -ipady 4
  grid .modbrowse.bottom.buttons.cvsfuncs.import -column 2 -row 0 \
     -ipadx 4 -ipady 4

  grid .modbrowse.bottom.buttons.modfuncs.filebrowse -column 0 -row 0 \
     -ipadx 4 -ipady 4
  grid .modbrowse.bottom.buttons.modfuncs.checkout -column 1 -row 0 \
     -ipadx 4 -ipady 4
  grid .modbrowse.bottom.buttons.modfuncs.export -column 2 -row 0 \
     -ipadx 4 -ipady 4
  grid .modbrowse.bottom.buttons.modfuncs.tag -column 3 -row 0 \
     -ipadx 4 -ipady 4
  grid .modbrowse.bottom.buttons.modfuncs.branchtag -column 4 -row 0 \
     -ipadx 4 -ipady 4
  grid .modbrowse.bottom.buttons.modfuncs.patchsummary -column 5 -row 0 \
     -ipadx 4 -ipady 4
  grid .modbrowse.bottom.buttons.modfuncs.patchfile -column 6 -row 0 \
     -ipadx 4 -ipady 4

  grid .modbrowse.bottom.buttons.svnfuncs.filecat -column 0 -row 0 \
     -ipadx 4 -ipady 4
  grid .modbrowse.bottom.buttons.svnfuncs.filelog -column 1 -row 0 \
     -ipadx 4 -ipady 4
  grid .modbrowse.bottom.buttons.svnfuncs.remove -column 2 -row 0 \
     -ipadx 4 -ipady 4

  pack .modbrowse.bottom.buttons.close \
     -in .modbrowse.bottom.buttons.closefm -side right \
     -fill both -expand yes

  set_tooltips .modbrowse.bottom.buttons.modfuncs.checkout \
     {"Check out selection from the repository"}
  set_tooltips .modbrowse.bottom.buttons.modfuncs.export \
     {"Export selection from the repository"}
  set_tooltips .modbrowse.bottom.buttons.modfuncs.tag \
     {"Tag all files in a module"}
  set_tooltips .modbrowse.bottom.buttons.modfuncs.branchtag \
     {"Branch all files in a module"}
  set_tooltips .modbrowse.bottom.buttons.modfuncs.filebrowse \
     {"Browse the files in a CVS module"}
  set_tooltips .modbrowse.bottom.buttons.svnfuncs.filecat \
     {"Show a file in the SVN repository"}
  set_tooltips .modbrowse.bottom.buttons.svnfuncs.filelog \
     {"Show the history log of a file in the SVN repository"}
  set_tooltips .modbrowse.bottom.buttons.svnfuncs.remove \
     {"Remove something from the SVN repository"}
  set_tooltips .modbrowse.bottom.buttons.modfuncs.patchsummary \
     {"Show a summary of differences between versions"}
  set_tooltips .modbrowse.bottom.buttons.modfuncs.patchfile \
     {"Create a patch file"}
  set_tooltips .modbrowse.bottom.buttons.cvsfuncs.import \
     {"Import the current directory into the repository"}
  set_tooltips .modbrowse.bottom.buttons.cvsfuncs.who \
     {"Show who has modules checked out"}
  set_tooltips .modbrowse.bottom.buttons.cvsfuncs.brefresh \
     {"Re-read the modules"}
  set_tooltips .modbrowse.bottom.buttons.close \
     {"Close the repository browser"}

  set_tooltips .modbrowse.top.bworkdir \
    {"Open the Working Directory Browser"}

  frame .modbrowse.treeframe
  pack .modbrowse.treeframe -side bottom -fill both -expand yes -pady 0

  set screenWidth [winfo vrootwidth .]
  set screenHeight [winfo vrootheight .]

  wm maxsize .modbrowse $screenWidth $screenHeight
  wm minsize .modbrowse 430 300

  gen_log:log T "LEAVE"
}

proc modbrowse_images {} {
  global cvscfg

  image create photo Workdir \
    -format gif -file [file join $cvscfg(bitmapdir) folderopen.gif]
  image create photo Files \
    -format gif -file [file join $cvscfg(bitmapdir) files.gif]
  image create photo Patches \
    -format gif -file [file join $cvscfg(bitmapdir) rdiff.gif]
  image create photo Patchfile \
    -format gif -file [file join $cvscfg(bitmapdir) patchfile.gif]
  image create photo Who \
    -format gif -file [file join $cvscfg(bitmapdir) who.gif]
  image create photo SvnRemove \
    -format gif -file [file join $cvscfg(bitmapdir) delete_red.gif]
  if {[catch "image type arr_dn"]} {
    workdir_images
  }
}

proc modbrowse_menus {} {
  global cvscfg
  global cvsglb
  global cvs
  global logclass

  #gen_log:log T "ENTER"

  menu .modbrowse.menubar

  #
  # Create the Menu bar
  if {[tk windowingsystem] == "aqua"} {
    # There's an extra menu in the first postion on apple, whether you like it or not.
    # So you have to configure it.
    .modbrowse.menubar add cascade -label "TkCVS" -menu [menu .modbrowse.menubar.apple]
  }
  .modbrowse.menubar add cascade -menu [menu .modbrowse.menubar.file] -label "File" -underline 0
  .modbrowse.menubar add cascade -menu [menu .modbrowse.menubar.cvs] -label "CVS" -underline 0
  .modbrowse.menubar add cascade -menu [menu .modbrowse.menubar.svn] -label "SVN" -underline 0
  .modbrowse.menubar add cascade -menu [menu .modbrowse.menubar.options] -label "Options" -underline 0

  # Have to do this after the .apple menu
  .modbrowse configure -menu .modbrowse.menubar

  #
  # Create the menus
  #
  .modbrowse.menubar.file add command -label "Browse Working Directory" -underline 0 \
     -command workdir_setup
  .modbrowse.menubar.file add separator
  .modbrowse.menubar.file add command -label "Close" -underline 1 \
     -command {.modbrowse.bottom.buttons.close invoke}
  .modbrowse.menubar.file add command -label "Exit" -underline 1 \
     -command { module_exit; exit_cleanup 1 }

  .modbrowse.menubar.cvs add command -label "CVS Checkout" \
      -command { dialog_cvs_checkout $cvscfg(cvsroot) $modbrowse_module}
  .modbrowse.menubar.cvs add command -label "CVS Export" \
      -command { dialog_cvs_export $cvscfg(cvsroot) $modbrowse_module}
  .modbrowse.menubar.cvs add command -label "Tag Module" -underline 0 \
     -command { rtag_dialog $cvscfg(cvsroot) $modbrowse_module "tag" }
  .modbrowse.menubar.cvs add command -label "Branch Tag Module" -underline 0 \
     -command { rtag_dialog $cvscfg(cvsroot) $modbrowse_module "branch" }
  .modbrowse.menubar.cvs add command -label "Make Patch File" -underline 0 \
     -command { dialog_cvs_patch $cvscfg(cvsroot) $modbrowse_module 0 }
  .modbrowse.menubar.cvs add command -label "View Patch Summary" -underline 0 \
     -command { dialog_cvs_patch $cvscfg(cvsroot) $modbrowse_module 1 }
  .modbrowse.menubar.cvs add separator
  .modbrowse.menubar.cvs add command -label "Import CWD to A New Module" -underline 0 \
     -command { import_run }
  .modbrowse.menubar.cvs add command -label "Import CWD to An Existing Module" -underline 0 \
     -command { import2_run }
  .modbrowse.menubar.cvs add command -label "Vendor Merge" -underline 0 \
     -command {merge_run $modbrowse_module}
  .modbrowse.menubar.cvs add separator
  .modbrowse.menubar.cvs add command -label "Show My Checkouts" -underline 0 \
     -command {cvs_history me ""}
  .modbrowse.menubar.cvs add command -label "Show Checkouts of Selected Module" -underline 0 \
     -command {cvs_history all $modbrowse_module}
  .modbrowse.menubar.cvs add command -label "Show All Checkouts" -underline 0 \
     -command {cvs_history all ""}

  .modbrowse.menubar.svn add command -label "SVN Checkout" \
      -command { dialog_svn_checkout $cvscfg(svnroot) $modbrowse_path checkout}
  .modbrowse.menubar.svn add command -label "SVN Export" \
      -command { dialog_svn_checkout $cvscfg(svnroot) $modbrowse_path export}
  .modbrowse.menubar.svn add command -label "Tag Module" -underline 0 \
     -command { dialog_svn_tag $cvscfg(svnroot) $modbrowse_path "tags" }
  .modbrowse.menubar.svn add command -label "Branch Module" -underline 0 \
     -command { dialog_svn_tag $cvscfg(svnroot) $modbrowse_path "branches" }
  .modbrowse.menubar.svn add command -label "Make Patch File" -underline 0 \
     -command { dialog_svn_patch $cvscfg(cvsroot) $modbrowse_path $selB_path 0 }
  .modbrowse.menubar.svn add command -label "View Patch Summary" -underline 0 \
     -command { dialog_svn_patch $cvscfg(cvsroot) $modbrowse_path $selB_path 1 }
  .modbrowse.menubar.svn add separator
  .modbrowse.menubar.svn add command -label "Import CWD into Repository" \
     -command svn_import_run

  .modbrowse.menubar.options add checkbutton -label "Group Aliases in a Folder (CVS)" \
     -variable cvscfg(aliasfolder) -onvalue true -offvalue false \
     -command {
        ModTree:delitem .modbrowse.treeframe /
        ModTree:destroy .modbrowse.treeframe
        busy_start .modbrowse
        ModTree:create .modbrowse.treeframe
        pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
        cvs_modbrowse_tree [lsort [array names modval]] "/"
     }
  .modbrowse.menubar.options add separator
  .modbrowse.menubar.options add checkbutton -label "Tracing On/Off" \
     -variable cvscfg(logging) -onvalue true -offvalue false \
     -command log_toggle

  menu_std_help .modbrowse.menubar

  #gen_log:log T "LEAVE"
}

proc modbrowse_run {} {
  global env
  global incvs insvn inrcs ingit
  global modval
  global cvscfg
  global cvsglb
  global cvs
  global cmd
  global cvsroot


  gen_log:log T "ENTER ()"
  gen_log:log D "cvsglb(root) $cvsglb(root)"
  gen_log:log D "cvsglb(vcs) $cvsglb(vcs)"
  catch {unset modval}
  catch {unset modtitle}
  set modbrowse_module ""

  if {! [winfo exists .modbrowse]} {
    modbrowse_setup
  }

  wm deiconify .modbrowse
  raise .modbrowse

  ModTree:delitem .modbrowse.treeframe /
  ModTree:destroy .modbrowse.treeframe
  busy_start .modbrowse
  switch $cvsglb(vcs) {
    svn {
      .modbrowse.top.lroot configure -text "SVN URL"
      .modbrowse.top.lmcode configure -text "Selection"
      # Set up ModTree and tell it to use clbk just-in-time-listdir
      ModTree:create .modbrowse.treeframe svn_jit_listdir
      pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
      .modbrowse.treeframe.tree.lbl configure -text "File"
      .modbrowse.treeframe.labl.lbl configure -text "Information"
      # parse_svnmodules will do "svn list" and post the files and directories
      parse_svnmodules .modbrowse.treeframe $cvsglb(root)
    }
    cvs {
      .modbrowse.top.lroot configure -text "CVSROOT"
      .modbrowse.top.lmcode configure -text "Module"
      # Set up ModTree
      ModTree:create .modbrowse.treeframe
      pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
      .modbrowse.treeframe.tree.lbl configure -text "Module"
      .modbrowse.treeframe.labl.lbl configure -text "Information"
      # parse_cvsmodules will check out CVSROOT/modules and post what it finds
      parse_cvsmodules .modbrowse.treeframe $cvsglb(root)
    }
    git {
      .modbrowse.top.lroot configure -text "Origin"
      .modbrowse.top.lmcode configure -text "Selection"
      # Set up ModTree
      ModTree:create .modbrowse.treeframe
      pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
      .modbrowse.treeframe.tree.lbl configure -text "Reference"
      .modbrowse.treeframe.labl.lbl configure -text "Commit ID"
      # parse_gitlist will do git ls-remote and post what it finds
      parse_gitlist .modbrowse.treeframe $cvsglb(root)
    }
    default {
      # Just make an empty frame
      ModTree:create .modbrowse.treeframe
      pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
      busy_done .modbrowse
      return
    }
  }
  # Maybe this root is new to us?
  ::picklist::used cvsroot "$cvsglb(root) $cvsglb(vcs)"

  switch $cvsglb(vcs) {
    cvs {
      .modbrowse.bottom.buttons.modfuncs.filebrowse configure \
        -command { browse_files $modbrowse_module }
      .modbrowse.bottom.buttons.modfuncs.checkout configure -state normal \
        -command { cvs_checkout_dialog $cvscfg(cvsroot) $modbrowse_module }
      .modbrowse.bottom.buttons.cvsfuncs.import configure -state normal \
        -command { import_run }
      .modbrowse.bottom.buttons.modfuncs.checkout configure -state normal \
        -command { dialog_cvs_checkout $cvscfg(cvsroot) $modbrowse_module }
      .modbrowse.bottom.buttons.modfuncs.export configure -state normal \
        -command { dialog_cvs_export $cvscfg(cvsroot) $modbrowse_module }
      .modbrowse.bottom.buttons.modfuncs.tag configure -state normal \
        -command { rtag_dialog $cvscfg(cvsroot) $modbrowse_module "tag" }
      .modbrowse.bottom.buttons.modfuncs.branchtag configure -state normal \
        -command { rtag_dialog $cvscfg(cvsroot) $modbrowse_module "branch" }
      .modbrowse.bottom.buttons.modfuncs.patchsummary configure -state normal \
        -command { dialog_cvs_patch $cvscfg(cvsroot) $modbrowse_module 1 }
      .modbrowse.bottom.buttons.modfuncs.patchfile configure -state normal \
        -command { dialog_cvs_patch $cvscfg(cvsroot) $modbrowse_module 0 }
      .modbrowse.bottom.buttons.cvsfuncs.who configure -state normal
      .modbrowse.bottom.buttons.svnfuncs.filecat configure -state disabled
      .modbrowse.bottom.buttons.svnfuncs.filelog configure -state disabled
      .modbrowse.bottom.buttons.svnfuncs.remove configure -state disabled
      .modbrowse.menubar entryconfigure "CVS" -state normal
      .modbrowse.menubar entryconfigure "SVN" -state disabled
    }
    svn {
      .modbrowse.bottom.buttons.cvsfuncs.import configure -state normal \
        -command { svn_import_run }
      .modbrowse.bottom.buttons.modfuncs.checkout configure -state normal \
        -command { dialog_svn_checkout $cvscfg(svnroot) $modbrowse_path checkout}
      .modbrowse.bottom.buttons.modfuncs.export configure -state normal \
        -command { dialog_svn_checkout $cvscfg(svnroot) $modbrowse_path export}
      .modbrowse.bottom.buttons.modfuncs.tag configure -state normal \
        -command { dialog_svn_tag $cvscfg(svnroot) $modbrowse_path "tags" }
      .modbrowse.bottom.buttons.modfuncs.branchtag configure -state normal \
        -command { dialog_svn_tag $cvscfg(svnroot) $modbrowse_path "branches" }
      .modbrowse.bottom.buttons.modfuncs.patchsummary configure -state normal \
        -command { dialog_svn_patch $cvscfg(svnroot) $modbrowse_path $selB_path 1 }
      .modbrowse.bottom.buttons.modfuncs.patchfile configure -state normal \
        -command { dialog_svn_patch $cvscfg(svnroot) $modbrowse_path $selB_path 0 }
      .modbrowse.bottom.buttons.cvsfuncs.who configure -state disabled
      .modbrowse.bottom.buttons.svnfuncs.filecat configure -state normal
      .modbrowse.bottom.buttons.svnfuncs.filelog configure -state normal
      .modbrowse.bottom.buttons.svnfuncs.remove configure -state normal
      .modbrowse.menubar entryconfigure "CVS" -state disabled
      .modbrowse.menubar entryconfigure "SVN" -state normal
    }
    default {
      # Disable 'em all
      .modbrowse.bottom.buttons.modfuncs.filebrowse configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.checkout configure -state disabled
      .modbrowse.bottom.buttons.cvsfuncs.import configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.checkout configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.export configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.tag configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.branchtag configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.patchsummary configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.patchfile configure -state disabled
      .modbrowse.bottom.buttons.cvsfuncs.who configure -state disabled
      .modbrowse.bottom.buttons.svnfuncs.filecat configure -state disabled
      .modbrowse.bottom.buttons.svnfuncs.filelog configure -state disabled
      .modbrowse.bottom.buttons.svnfuncs.remove configure -state disabled
      .modbrowse.menubar entryconfigure "CVS" -state disabled
      .modbrowse.menubar entryconfigure "SVN" -state disabled
    }
  }

  if {$insvn || $incvs || $inrcs || $ingit} {
    # Don't allow an attempt to import from a version-controlled directory
    .modbrowse.bottom.buttons.cvsfuncs.import configure -state disabled
  }

  # Populate the tree
  switch $cvsglb(vcs) {
    svn {
      # Make sure branches and tags names come first, before any of their
      # contents, so we get the "# tags" and "# branches" labels
      set newlist ""
      foreach item [array names modval] {
        if {! ($item == $cvscfg(svn_branchdir) || $item == $cvscfg(svn_tagdir))} {
          lappend newlist $item
        }
      }
      set newlist [lsort $newlist]
      set newlist [concat {$cvscfg(svn_branchdir} {$cvscfg(svn_tagdir)} $newlist]
    }
    cvs {
      cvs_modbrowse_tree [lsort [array names modval]] "/"
    }
    git {
    }
  }

  busy_done .modbrowse
  gen_log:log T "LEAVE"
}

proc module_exit { } {
  global cvscfg
  global cvs
  global cmd

  gen_log:log T "ENTER"

  if {[info exists cmd(cvs_co)]} {
    catch {$cmd(cvs_co)\::abort}
    catch {unset cmd(cvs_co)}
  }

  set pid [pid]
  set cwd [pwd]
  set sandbox [file join $cvscfg(tmpdir) cvstmpdir.$pid]
  if {[file isdirectory $sandbox]} {
    gen_log:log F "CD $sandbox"
    cd $sandbox
    set dirs {}
    foreach d [glob -nocomplain *] {
      lappend dirs $d
    }
    gen_log:log C "$cvs -Q release $dirs"
    catch {eval "exec $cvs -Q release $dirs"}
    # Doing it this way makes it pop up an error on windoze.
    # Very annoying.
    #set finish [exec::new "$cvs -Q release $dirs"]
    #$finish\::wait
  }
  cd $cwd
  gen_log:log F "CD [pwd]"

  ModTree:delitem .modbrowse.treeframe /
  set cvscfg(modgeom) [wm geometry .modbrowse]
  destroy .modbrowse
  catch {destroy .tooltips_wind}
  exit_cleanup 0

  gen_log:log T "LEAVE"
}

proc module_changedir {new_dir} {
# Make sure a directory exists before trying to cd to it
  global cwd
  global cvscfg
  global cvsglb
  global incvs insvn inrcs ingit

  gen_log:log T "ENTER ($new_dir)"
  if {[file exists $new_dir]} {
    cd $new_dir
    set cwd $new_dir
    gen_log:log F "CD [pwd]"

    lassign [cvsroot_check [pwd]] incvs insvn inrcs ingit

    # If this directory has a different cvsroot, redo the tree
    if {$incvs} {
      set cvsglb(root) $cvscfg(cvsroot)
      set cvsglb(vcs) cvs
      modbrowse_run
    } elseif {$insvn} {
      set cvsglb(root) $cvscfg(svnroot)
      set cvsglb(vcs) svn
      modbrowse_run
    } elseif {$ingit} {
      set cvsglb(root) $cvscfg(url)
      set cvsglb(vcs) git
      modbrowse_run
    }
    # Add to the directory picklist
    if {[winfo exists .workdir]} {
      ::picklist::used directory [pwd]
      setup_dir
    }
  } else {
    set cwd [pwd]
    cvsfail "Directory $new_dir doesn\'t exist!" .modbrowse
  }
  gen_log:log F "$cwd"
  gen_log:log T "LEAVE"
}

