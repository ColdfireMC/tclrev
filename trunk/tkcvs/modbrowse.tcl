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

  if {[winfo exists .modbrowse]} {
    wm deiconify .modbrowse
    raise .modbrowse
    return
  }

  # Window manager stuff.
  toplevel .modbrowse
  wm title .modbrowse "TkCVS $cvscfg(version) -- Repository Browser"
  wm iconname .modbrowse "TkCVS Repository Browser"
  if {$tcl_platform(platform) ne "windows"} {
    wm iconbitmap .modbrowse @$cvscfg(bitmapdir)/tkcvs48.xbm
    wm iconphoto .modbrowse -default Tclfish64
  }
  wm minsize .modbrowse 430 300
  wm protocol .modbrowse WM_DELETE_WINDOW {.modbrowse.bottom.buttons.close invoke}
  wm withdraw .modbrowse

  if {[info exists cvscfg(modgeom)]} {
    update
    wm geometry .modbrowse $cvscfg(modgeom)
  }

  menubar_menus .modbrowse
  modbrowse_menus .modbrowse
  help_menu .modbrowse

  #
  # Top section - module, tags, root
  #
  frame .modbrowse.top -relief groove -border 2
  pack .modbrowse.top -side top -fill x

  label .modbrowse.top.lmcode -text "Module"
  entry .modbrowse.top.tmcode -textvariable modbrowse_module \
    -font $cvscfg(listboxfont) -border 2
  bind .modbrowse.top.tmcode <Return> {modbrowse_run}

  # We have these possibilities
  foreach VCS {cvs svn git} {
    if [info exists env(${VCS}ROOT)] {
      gen_log:log D "env(${VCS}ROOT) $env(${VCS}ROOT)"
      picklist_used cvsroot "$env(${VCS}ROOT)"
    }
  }
  foreach VCS {cvs svn git} {
    if [info exists cvscfg(${VCS}root)] {
      gen_log:log D "cvscfg(${VCS}root) $cvscfg(${VCS}root)"
      picklist_used cvsroot "$cvscfg(${VCS}root)"
    }
  }
  # Where do we think we are?
  gen_log:log D "cvsglb(root) $cvsglb(root) cvsglb(vcs) $cvsglb(vcs)"

  label .modbrowse.top.lroot -text "Repository"
  ttk::combobox .modbrowse.top.troot -textvariable cvsglb(root)
  .modbrowse.top.troot configure -values $cvsglb(cvsroot)
  bind .modbrowse.top.troot <Return> { modbrowse_run }
  bind .modbrowse.top.troot <<ComboboxSelected>> { modbrowse_run }

  button .modbrowse.top.bworkdir -image Workdir \
    -command {workdir_setup}

  label .modbrowse.top.lcwd -text "Current Directory"
  ttk::combobox .modbrowse.top.tcwd -textvariable cwd
  .modbrowse.top.tcwd configure -values $cvsglb(directory)
  bind .modbrowse.top.tcwd <Return>             {if {[pwd] != $cwd} {change_dir "$cwd"}}
  bind .modbrowse.top.tcwd <<ComboboxSelected>> {if {[pwd] != $cwd} {change_dir "$cwd"}}

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

  frame .modbrowse.treeframe -bg $cvsglb(canvbg)
  pack .modbrowse.treeframe -side bottom -fill both -expand yes -pady 0

  set screenWidth [winfo vrootwidth .]
  set screenHeight [winfo vrootheight .]

  wm maxsize .modbrowse $screenWidth $screenHeight
  wm minsize .modbrowse 430 300

  gen_log:log T "LEAVE"
}

# Try to contact the repository somehow to guess what kind it is
proc modbrowse_guess_vcs {} {
  global cvsglb
  global cvscfg
  global modbrowse_module

  gen_log:log T "ENTER"

  # If there's no root at all, don't waste our time
  if {$cvsglb(root) eq ""} {
    gen_log:log T "LEAVE ($cvsglb(vcs))"
    return $cvsglb(vcs)
  }

  set vcs ""

  set cvs_cmd "cvs -d $cvsglb(root) rdiff -l -s -D 01/01/1971 \"$modbrowse_module\""
  gen_log:log C $cvs_cmd
  set cvsret [catch {eval "exec $cvs_cmd > $cvscfg(null)"} cvsout]
  if {[string match {*Diffing*} $cvsout]} {
    gen_log:log T "LEAVE (cvs)"
    return "cvs"
  } else {
    gen_log:log E $cvsout
  }

  set svn_cmd "svn list $cvsglb(root)"
  gen_log:log C $svn_cmd
  set svnret [catch {eval "exec $svn_cmd"} svnout]
  if {$svnret} {
    gen_log:log E $svnout
  } else {
    gen_log:log T "LEAVE (svn)"
    return "svn"
  }

  set git_cmd "git ls-remote $cvsglb(root)"
  gen_log:log C $git_cmd
  set gitret [catch {eval "exec $git_cmd"} gitout]
  if {$gitret} {
    gen_log:log E $gitout
  } else {
    set cvscfg(gitroot) $cvsglb(root)
    gen_log:log T "LEAVE (git)"
    return "git"
  }

  gen_log:log T "LEAVE ($cvsglb(vcs))"
  return $cvsglb(vcs)
}

proc modbrowse_run {} {
  global env
  global incvs insvn inrcs ingit
  global cvscfg
  global cvsglb
  global cvs
  global cmd
  global cvsroot
  global modval
  global modtitle
  global modbrowse_module
  global modbrowse_path
  global modbrowse_title


  gen_log:log T "ENTER ()"
  gen_log:log D "incvs=$incvs insvn=$insvn inrcs=$inrcs ingit=$ingit"
  gen_log:log D "cvsglb(root) $cvsglb(root)"
  catch {unset modval}
  catch {unset modtitle}
  set modbrowse_module ""

  if {$incvs} {
    set cvsglb(vcs) cvs
  } elseif {$insvn} {
    set cvsglb(vcs) svn
  } elseif {$ingit} { 
    set cvsglb(vcs) git
  } elseif {$inrcs} { 
    set cvsglb(vcs) ""
  } else {
    set cvsglb(vcs) [modbrowse_guess_vcs]
  }
  gen_log:log D "cvsglb(vcs) $cvsglb(vcs)"


  if {! [winfo exists .modbrowse]} {
    modbrowse_setup
  }

  wm deiconify .modbrowse
  raise .modbrowse

  ModTree:destroy .modbrowse.treeframe
  busy_start .modbrowse

  switch $cvsglb(vcs) {
    svn {
      .modbrowse.top.lroot configure -text "SVN URL"
      .modbrowse.top.lmcode configure -text "Selection"
      # Set up ModTree and tell it to use clbk just-in-time-listdir
      ModTree:create .modbrowse.treeframe
      pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
      .modbrowse.treeframe.pw heading file -text "File"
      .modbrowse.treeframe.pw heading information -text "Information"
      # parse_svnmodules will do "svn list" and post the files and directories
      bind .modbrowse.treeframe.pw <<TreeviewOpen>> svn_jit_listdir
      bind .modbrowse.treeframe.pw <<TreeviewClose>> svn_closedir
      bind .modbrowse.treeframe.pw <<TreeviewSelect>> {
        global modbrowse_module
        global modbrowse_path
        global modbrowse_title
        set selection [.modbrowse.treeframe.pw selection]
        set modbrowse_title [string trimleft $selection "/"]
        set modbrowse_path $modbrowse_title
        set modbrowse_module $modbrowse_path
      }

      # parse_svnmodules does svn list of the repository
      # For SVN. The URL changes depending on what directory we're in, so use
      # svnroot instead of cvsglb(root)
      parse_svnmodules $cvscfg(svnroot)
    }
    cvs {
      .modbrowse.top.lroot configure -text "CVSROOT"
      .modbrowse.top.lmcode configure -text "Module"
      # Set up ModTree
      ModTree:create .modbrowse.treeframe
      pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
      .modbrowse.treeframe.pw heading file -text "Module"
      .modbrowse.treeframe.pw heading information -text "Information"
      .modbrowse.treeframe.pw column #0 -width [expr {$cvscfg(mod_iconwidth) * 2}]
      bind .modbrowse.treeframe.pw <<TreeviewSelect>> {
        global modbrowse_module
        global modbrowse_path
        global modbrowse_title
        set selection [.modbrowse.treeframe.pw selection]
        set modbrowse_title [string trimleft $selection "/"]
        set modbrowse_path $modbrowse_title
        set modbrowse_module $selection
      }

      # parse_cvsmodules will check out CVSROOT/modules and post what it finds
      parse_cvsmodules $cvsglb(root)
    }
    git {
      .modbrowse.top.lroot configure -text "Origin"
      .modbrowse.top.lmcode configure -text "Selection"
      # Set up ModTree for a git ls-remote
      ModTree:create .modbrowse.treeframe
      pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
      .modbrowse.treeframe.pw heading file -text "Reference"
      .modbrowse.treeframe.pw heading information -text "Commit ID"
      .modbrowse.treeframe.pw column #0 -width 0
      bind .modbrowse.treeframe.pw <<TreeviewSelect>> {
        global modbrowse_module
        global modbrowse_path
        global modbrowse_title
        set selection [.modbrowse.treeframe.pw selection]
        set modbrowse_title $selection
        set modbrowse_path $modbrowse_title
        # The hash, not the name
        set modbrowse_module [lindex [.modbrowse.treeframe.pw item $modbrowse_path -values] 1]
      }

      # parse_gitlist will do git ls-remote and post what it finds
      parse_gitlist $cvsglb(root)
    }
    default {
      # Just make an empty frame
      ModTree:create .modbrowse.treeframe
      pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
      return
    }
  }
  busy_done .modbrowse

  # Maybe this root is new to us?
  picklist_used cvsroot "$cvsglb(root)"
  # Have to do this to display the new value in the list
  .modbrowse.top.troot configure -values $cvsglb(cvsroot)

  # Start without revision-control menu
  gen_log:log D "CONFIGURE VCS MENUS"
  foreach label {"CVS" "SVN" "GIT"} {
    if {! [catch {set vcsmenu_idx [.modbrowse.menubar index "$label"]}]} {
      .modbrowse.menubar delete $vcsmenu_idx
    }
  }
  set filemenu_idx [.modbrowse.menubar index "File"]
  
  switch $cvsglb(vcs) {
    cvs {
      .modbrowse.bottom.buttons.modfuncs.filebrowse configure \
        -command { browse_files $modbrowse_module }
      .modbrowse.bottom.buttons.modfuncs.checkout configure -state normal \
        -command { dialog_cvs_checkout $cvscfg(cvsroot) $modbrowse_module }
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
      .modbrowse.menubar insert [expr {$filemenu_idx + 1}] cascade -label "CVS" \
        -menu .modbrowse.menubar.cvs
    }
    svn {
      .modbrowse.bottom.buttons.cvsfuncs.import configure -state normal \
        -command { svn_import_run }
      .modbrowse.bottom.buttons.modfuncs.filebrowse configure -state disabled
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
      .modbrowse.menubar insert [expr {$filemenu_idx + 1}] cascade -label "SVN" \
        -menu .modbrowse.menubar.svn
    }
    git {
      # Disable all except clone
      .modbrowse.bottom.buttons.cvsfuncs.import configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.filebrowse configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.checkout configure -state normal \
        -command { dialog_git_clone $cvscfg(gitroot) $modbrowse_module }
      .modbrowse.bottom.buttons.modfuncs.export configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.tag configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.branchtag configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.patchsummary configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.patchfile configure -state disabled
      .modbrowse.bottom.buttons.cvsfuncs.who configure -state disabled
      .modbrowse.bottom.buttons.svnfuncs.filecat configure -state disabled
      .modbrowse.bottom.buttons.svnfuncs.filelog configure -state disabled
      .modbrowse.bottom.buttons.svnfuncs.remove configure -state disabled
      .modbrowse.menubar insert [expr {$filemenu_idx + 1}] cascade -label "GIT" \
        -menu .modbrowse.menubar.git
    }
    default {
      # Disable all
      .modbrowse.bottom.buttons.cvsfuncs.import configure -state disabled
      .modbrowse.bottom.buttons.modfuncs.filebrowse configure -state disabled
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
      # Nothing to do here
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

  # Stop any checkout that may be in process
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
    # Doing it this way makes it pop up an error on windows.
    # Very annoying.
    #set finish [exec::new "$cvs -Q release $dirs"]
    #$finish\::wait
  }
  cd $cwd
  gen_log:log F "CD [pwd]"

  set cvscfg(modgeom) [wm geometry .modbrowse]
  ModTree:destroy .modbrowse.modtree
  destroy .modbrowse
  catch {destroy .tooltips_wind}
  exit_cleanup 0

  gen_log:log T "LEAVE"
}

proc ModTree:create {w} {
  global cvsglb
  global cvscfg


  ttk::treeview $w.pw -yscroll "$w.yscroll set"
  $w.pw configure -columns "file information"
  $w.pw column #0 -minwidth 0
  $w.pw column #0 -width $cvscfg(mod_iconwidth)
  $w.pw column #0 -stretch no

  scrollbar $w.yscroll -orient vertical \
      -relief sunken -command "$w.pw yview"
  pack $w.yscroll -side right -fill y

  focus $w.pw
}

proc ModTree:destroy {w} {
  destroy $w.pw
  destroy $w.yscroll
}

