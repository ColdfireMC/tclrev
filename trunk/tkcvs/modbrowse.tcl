#
# Set up a check out dialog.
#

proc modbrowse_setup {} {
  global cwd
  global repository_root
  global modbrowse_module
  global modbrowse_path
  global modbrowse_title
  global cvsglb
  global cvscfg
  global tcl_platform

  #gen_log:log T "ENTER"
  set cwd [pwd]

  # Window manager stuff.
  toplevel .modbrowse
  wm title .modbrowse "TkCVS $cvscfg(version) Repository Browser"
  wm iconname .modbrowse "TkCVS Repository Browser"
  if {$tcl_platform(platform) != "windows"} {
    wm iconbitmap .modbrowse @$cvscfg(bitmapdir)/tkcvs48.xbm
  }
  wm protocol .modbrowse WM_DELETE_WINDOW {
    .modbrowse.bottom.buttons.closefm.close invoke 
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

  label .modbrowse.top.lroot -text "CVSROOT"
  ::picklist::entry .modbrowse.top.troot cvsglb(root) cvsroot
  ::picklist::bind .modbrowse.top.troot <Return> \
    {if {$repository_root != $cvsglb(root)} {modbrowse_run}}

  button .modbrowse.top.bworkdir -image Workdir -command {workdir_setup}

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
  frame .modbrowse.bottom.buttons.closefm -relief groove -bd 2

  pack .modbrowse.bottom -side bottom -fill x
  pack .modbrowse.bottom.buttons -side top -fill x -expand yes
  pack .modbrowse.bottom.buttons.closefm -side right -padx 10
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

  button .modbrowse.bottom.buttons.closefm.close -text "Close" \
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

  pack .modbrowse.bottom.buttons.closefm.close \
     -side right -fill both -expand yes

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
  set_tooltips .modbrowse.bottom.buttons.closefm.close \
     {"Close the repository browser"}

  set_tooltips .modbrowse.top.bworkdir \
    {"Open the Working Directory Browser"}

  frame .modbrowse.treeframe
  pack .modbrowse.treeframe -side bottom -fill both -expand yes -pady 0

  set screenWidth [winfo vrootwidth .]
  set screenHeight [winfo vrootheight .]

  wm maxsize .modbrowse $screenWidth $screenHeight
  wm minsize .modbrowse 430 300

  #gen_log:log T "LEAVE"
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
  global cvs
  global logclass

  #gen_log:log T "ENTER"

  menu .modbrowse.modmenu
  .modbrowse configure -menu .modbrowse.modmenu

  #
  # Create the Menu bar
  #
  .modbrowse.modmenu add cascade -menu .modbrowse.modmenu.file -label "File" -underline 0
  menu .modbrowse.modmenu.file -tearoff 0
  .modbrowse.modmenu add cascade -menu .modbrowse.modmenu.cvs -label "CVS" -underline 0
  menu .modbrowse.modmenu.cvs -tearoff 0
  .modbrowse.modmenu add cascade -menu .modbrowse.modmenu.svn -label "SVN" -underline 0
  menu .modbrowse.modmenu.svn -tearoff 0
  .modbrowse.modmenu add cascade -menu .modbrowse.modmenu.options -label "Options" -underline 0
  menu .modbrowse.modmenu.options -tearoff 0

  #
  # Create the menus
  #
  set selcolor [option get .modbrowse selectColor selectColor]
  .modbrowse.modmenu.file add command -label "Browse Working Directory" -underline 0 \
     -command workdir_setup
  .modbrowse.modmenu.file add separator
  .modbrowse.modmenu.file add command -label "Close" -underline 1 \
     -command {.modbrowse.bottom.buttons.closefm.close invoke}
  .modbrowse.modmenu.file add command -label "Exit" -underline 1 \
     -command { module_exit; exit_cleanup 1 }

  .modbrowse.modmenu.cvs add command -label "CVS Checkout" \
      -command { dialog_cvs_checkout $cvscfg(cvsroot) $modbrowse_module}
  .modbrowse.modmenu.cvs add command -label "CVS Export" \
      -command { dialog_cvs_export $cvscfg(cvsroot) $modbrowse_module}
  .modbrowse.modmenu.cvs add command -label "Tag Module" -underline 0 \
     -command { rtag_dialog $cvscfg(cvsroot) $modbrowse_module "tag" }
  .modbrowse.modmenu.cvs add command -label "Branch Tag Module" -underline 0 \
     -command { rtag_dialog $cvscfg(cvsroot) $modbrowse_module "branch" }
  .modbrowse.modmenu.cvs add command -label "Make Patch File" -underline 0 \
     -command { dialog_cvs_patch $cvscfg(cvsroot) $modbrowse_module 0 }
  .modbrowse.modmenu.cvs add command -label "View Patch Summary" -underline 0 \
     -command { dialog_cvs_patch $cvscfg(cvsroot) $modbrowse_module 1 }
  .modbrowse.modmenu.cvs add separator
  .modbrowse.modmenu.cvs add command -label "Import CWD to A New Module" -underline 0 \
     -command { import_run }
  .modbrowse.modmenu.cvs add command -label "Import CWD to An Existing Module" -underline 0 \
     -command { import2_run }
  .modbrowse.modmenu.cvs add command -label "Vendor Merge" -underline 0 \
     -command {merge_run $modbrowse_module}
  .modbrowse.modmenu.cvs add separator
  .modbrowse.modmenu.cvs add command -label "Show My Checkouts" -underline 0 \
     -command {cvs_history me ""}
  .modbrowse.modmenu.cvs add command -label "Show Checkouts of Selected Module" -underline 0 \
     -command {cvs_history all $modbrowse_module}
  .modbrowse.modmenu.cvs add command -label "Show All Checkouts" -underline 0 \
     -command {cvs_history all ""}

  .modbrowse.modmenu.svn add command -label "SVN Checkout" \
      -command { dialog_svn_checkout $cvscfg(svnroot) $modbrowse_path checkout}
  .modbrowse.modmenu.svn add command -label "SVN Export" \
      -command { dialog_svn_checkout $cvscfg(svnroot) $modbrowse_path export}
  .modbrowse.modmenu.svn add command -label "Tag Module" -underline 0 \
     -command { dialog_svn_tag $cvscfg(svnroot) $modbrowse_path "tags" }
  .modbrowse.modmenu.svn add command -label "Branch Module" -underline 0 \
     -command { dialog_svn_tag $cvscfg(svnroot) $modbrowse_path "branches" }
  .modbrowse.modmenu.svn add command -label "Make Patch File" -underline 0 \
     -command { dialog_svn_patch $cvscfg(cvsroot) $modbrowse_path $selB_path 0 }
  .modbrowse.modmenu.svn add command -label "View Patch Summary" -underline 0 \
     -command { dialog_svn_patch $cvscfg(cvsroot) $modbrowse_path $selB_path 1 }
  .modbrowse.modmenu.svn add separator
  .modbrowse.modmenu.svn add command -label "Import CWD into Repository" \
     -command svn_import_run

  .modbrowse.modmenu.options add checkbutton -label "Group Aliases in a Folder (CVS)" \
     -variable cvscfg(aliasfolder) -onvalue true -offvalue false \
     -selectcolor $selcolor -command {
        ModTree:delitem .modbrowse.treeframe /
        ModTree:destroy .modbrowse.treeframe
        busy_start .modbrowse
        ModTree:create .modbrowse.treeframe
        pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
        modbrowse_tree [lsort [array names modval]] "/"
     }
  .modbrowse.modmenu.options add separator
  .modbrowse.modmenu.options add checkbutton -label "Tracing On/Off" \
     -variable cvscfg(logging) -onvalue true -offvalue false \
     -selectcolor $selcolor -command log_toggle
  .modbrowse.modmenu.options add cascade -label "Trace Level" \
     -menu .modbrowse.modmenu.options.loglevel
  menu .modbrowse.modmenu.options.loglevel
  .modbrowse.modmenu.options.loglevel add checkbutton -label "CVS commands (C)" \
     -variable logclass(C) -onvalue "C" -offvalue "" \
     -selectcolor $selcolor -command gen_log:changeclass
  .modbrowse.modmenu.options.loglevel add checkbutton -label "CVS stderr (E)" \
     -variable logclass(E) -onvalue "E" -offvalue "" \
     -selectcolor $selcolor -command gen_log:changeclass
  .modbrowse.modmenu.options.loglevel add checkbutton -label "File creation/deletion (F)"\
     -variable logclass(F) -onvalue "F" -offvalue "" \
     -selectcolor $selcolor -command gen_log:changeclass
  .modbrowse.modmenu.options.loglevel add checkbutton -label "Function entry/exit (T)" \
     -variable logclass(T) -onvalue "T" -offvalue "" \
     -selectcolor $selcolor -command gen_log:changeclass
  .modbrowse.modmenu.options.loglevel add checkbutton -label "Debugging (D)" \
     -variable logclass(D) -onvalue "D" -offvalue "" \
     -selectcolor $selcolor -command gen_log:changeclass


  menu_std_help .modbrowse.modmenu

  #gen_log:log T "LEAVE"
}

proc modbrowse_run { {CVSorSVN {}} } {
  global env
  global svnurl
  global insvn incvs inrcs
  global modval
  global cvscfg
  global cvsglb
  global cvs
  global cmd
  global repository_root

  gen_log:log T "ENTER ($CVSorSVN)"
  # If a checkout is already running, abort it
  if {[info exists cmd(cvs_co)]} {
    catch {$cmd(cvs_co)\::abort}
    catch {unset cmd(cvs_co)}
  }

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
  switch $CVSorSVN {
    svn {
      set svnurl 1
      gen_log:log D "svn"

      set cvsglb(root) $cvscfg(svnroot) 
      if {! [info exists cvscfg(svnroot)] } {
        read_svn_dir .
      }
      .modbrowse.top.lroot configure -text "SVN URL"
      .modbrowse.top.lmcode configure -text "Selection"
      # Call ModTree with the just-in-time level maker
      ModTree:create .modbrowse.treeframe svn_jit_listdir
      pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
      parse_svnmodules .modbrowse.treeframe $cvscfg(svnroot)
    }
    cvs {
      set svnurl 0
      gen_log:log D "cvs"
      #gen_log:log D "cvsglb(root) $cvsglb(root)"
      #gen_log:log D "cvscfg(cvsroot) $cvscfg(cvsroot)"
      #gen_log:log D "cvscfg(svnroot) $cvscfg(svnroot)"

      set cvsglb(root) $cvscfg(cvsroot)
      set cmd(cvs_co) \
          [exec::new "$cvs -d $cvscfg(cvsroot) checkout -p CVSROOT/modules"]
      .modbrowse.top.lroot configure -text "CVSROOT"
      .modbrowse.top.lmcode configure -text "Module"
      ModTree:create .modbrowse.treeframe
      pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
      if {[info exists cmd(cvs_co)]} {
        parse_cvsmodules [$cmd(cvs_co)\::output]
      }
      catch {unset cmd(cvs_co)}
    }
    default {
      set svnurl 0
      # Detect a SVN URL
      if {[regexp {://} $cvsglb(root)]} {
        set svnurl 1
      }
      if {$svnurl} {
        gen_log:log D "default,detected svn url"
        set cvscfg(svnroot) $cvsglb(root)

        .modbrowse.top.lroot configure -text "SVN URL"
        .modbrowse.top.lmcode configure -text "Selection"
        # Call ModTree with the just-in-time level maker
        ModTree:create .modbrowse.treeframe svn_jit_listdir
        pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
        parse_svnmodules .modbrowse.treeframe $cvscfg(svnroot)
      } else {
        gen_log:log D "default"
        set cvscfg(cvsroot) $cvsglb(root)
        #gen_log:log D "cvsglb(root) $cvsglb(root)"
        #gen_log:log D "cvscfg(cvsroot) $cvscfg(cvsroot)"
        #gen_log:log D "cvscfg(svnroot) $cvscfg(svnroot)"

        #set cvsglb(root) $cvscfg(cvsroot)
        set cmd(cvs_co) \
            [exec::new "$cvs -d $cvscfg(cvsroot) checkout -p CVSROOT/modules"]
        .modbrowse.top.lroot configure -text "CVSROOT"
        .modbrowse.top.lmcode configure -text "Module"
        ModTree:create .modbrowse.treeframe
        pack .modbrowse.treeframe.pw -side bottom -fill both -expand yes
        if {[info exists cmd(cvs_co)]} {
            parse_cvsmodules [$cmd(cvs_co)\::output]
        }
        catch {unset cmd(cvs_co)}
      }
    }
  }
  set repository_root $cvsglb(root)
  ::picklist::used cvsroot $cvsglb(root)

  set bstate [expr {$svnurl ? {disabled} : {normal}}]
  .modbrowse.bottom.buttons.cvsfuncs.import configure -state $bstate
  .modbrowse.bottom.buttons.cvsfuncs.who configure -state $bstate
  .modbrowse.bottom.buttons.cvsfuncs.brefresh configure -state normal
  foreach widget [grid slaves .modbrowse.bottom.buttons.modfuncs ] {
    $widget configure -state $bstate
  }
  if {$svnurl} {
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
    .modbrowse.bottom.buttons.svnfuncs.filecat configure -state normal
    .modbrowse.bottom.buttons.svnfuncs.filelog configure -state normal
    .modbrowse.bottom.buttons.svnfuncs.remove configure -state normal
  } else {
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
    .modbrowse.bottom.buttons.svnfuncs.filecat configure -state disabled
    .modbrowse.bottom.buttons.svnfuncs.filelog configure -state disabled
    .modbrowse.bottom.buttons.svnfuncs.remove configure -state disabled
  }
  if {$insvn || $incvs || $inrcs} {
    .modbrowse.bottom.buttons.cvsfuncs.import configure -state disabled
  }

  # Populate the tree
  if {$svnurl} {
    # Make sure branches and tags names come first, before any of their
    # contents, so we get the "# tags" and "# branches" labels
    set newlist ""
    foreach item [array names modval] {
      if {! ($item == "branches" || $item == "tags")} {
        lappend newlist $item
      }
    }
    set newlist [lsort $newlist]
    set newlist [concat {"branches"} {"tags"} $newlist]
  } else {
    modbrowse_tree [lsort [array names modval]] "/"
  }

  busy_done .modbrowse
  gen_log:log T "LEAVE"
}

proc modbrowse_tree { mnames node } {
#
# Do this to update the display of the listbox (body proc).
#
  global cvscfg
  global modval
  global modtitle
  global dcontents
  global Tree

  gen_log:log T "ENTER (... $node)"

  if {! [info exists cvscfg(aliasfolder)]} {
    set cvscfg(aliasfolder) false
  }

  set tf ".modbrowse.treeframe"
  foreach mname $mnames {
    #gen_log:log D "{$mname} {$modval($mname)}"
    set dimage "dir"
    # The descriptive title of the module.  If not specified, modval is used.
    set title $modval($mname)
    if {[info exists modtitle($mname)]} {
      set title $modtitle($mname)
      #gen_log:log D "* modtitle($mname) {$title}"
    }
    if {[string match "-a *" $modval($mname)]} {
      # Its an alias module
      regsub {\-a } $modtitle($mname) "Alias for " title
      if {$cvscfg(aliasfolder)} {
        #gen_log:log D "path=Aliases/$mname pathtop=Aliases pathroot=/Aliases"
        if {! [info exists Tree($tf:/Aliases:children)]} {
          #gen_log:log D "Making Aliases"
          ModTree:newitem $tf /Aliases Aliases "Aliases" -image "adir"
        }
        ModTree:newitem $tf /Aliases/$mname $mname "$title" -image "amod"
        continue
      }
      set dimage amod
    } elseif {[string match "* *" $modval($mname)]} {
      # The value isn't a simple path
      #gen_log:log D "Found spaces in modval($mname) $modval($mname)"
    } elseif {[string match "*/*" $modval($mname)]} {
      #gen_log:log D "Set image to dir because $modval($mname) contains a slash"
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
        #gen_log:log D "* Using pathtop * modtitle($pathtop) {$title}"
      } elseif {[info exists modtitle($path)]} {
        set title $modtitle($path)
        #gen_log:log D "* Using path * modtitle($path) {$title}"
      } else {
        #gen_log:log D "* No modtitle($path)"
      }
      #gen_log:log D "path=$path pathtop=$pathtop pathroot=$pathroot"
      if {! [info exists Tree($tf:$pathroot:children)]} {
        #gen_log:log D "1 Making $pathtop for something with a \"/\" in its module name"
        if {[info exists modval($pathtop)]} { set dimage mdir }
        ModTree:newitem $tf $pathroot $pathtop "$title" -image $dimage
      }
      set pathroot ""
      for {set i 1} {$i < $pathdepth} {incr i} {
        set newnode [lindex $pathitems $i]
        set pathroot [file join $pathroot [lindex $pathitems [expr {$i -1} ]]]
        set newpath [file join "/" $pathroot $newnode]
        set namepath [string range $newpath 1 end]
        #gen_log:log D "* * mname=$mname namepath=$namepath pathroot=$pathroot newpath=$newpath newnode=$newnode"
        if {[info exists modtitle($namepath)]} {
          set title $modtitle($namepath)
          #gen_log:log D "* Using namepath * modtitle($namepath) {$title}"
        } elseif {[info exists modtitle($newnode)]} {
          set title $modtitle($newnode)
          #gen_log:log D "* Using newnode * modtitle($newnode) {$title}"
        } elseif {[info exists modtitle($mname)]} {
          set title $modtitle($mname)
          #gen_log:log D "* Using mname * modtitle($mname) {$title}"
        } else {
          #gen_log:log D "* * No modtitle($namepath)"
        }
        if {! [info exists Tree($tf:$newpath:children)]} {
          set modvalpath [file join "/" $modval($mname)]
          regsub { &\S+} $modvalpath {} modvalpath
          #gen_log:log D "* * mname=$mname modvalpath=$modvalpath newpath=$newpath newnode=$newnode"
          if {$modvalpath == $newpath} {
            set newnode $mname
          }
          set dimage dir
          #gen_log:log D "2 Making $newnode for an intermediate node"
          lappend dcontents($pathroot) $newnode
          if {[info exists modval($newnode)]} {set dimage mdir}
          ModTree:newitem $tf $newpath $newnode "$title" -image $dimage
        }
      }
      # If we got here we just did a leaf, so break out and dont put it
      # at the toplevel too.
      continue
    }
    set treepath [file join $node $mname]
    if {[info exists Tree($tf:$treepath:children)]} {
      #gen_log:log D "  Already handled $treepath"
      continue
    }
    #gen_log:log D "3 Making $mname"
    if {[info exists modval($mname)] && ($dimage != "amod")} { set dimage mdir }
    ModTree:newitem $tf $treepath $mname $title -image $dimage
  }
  update idletasks
  gather_mod_index
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

  gen_log:log T "ENTER ($new_dir)"
  #if {! [winfo exists .modbrowse]} {
    #modbrowse_setup
  #}
  if {[file exists $new_dir]} {
    cd $new_dir
    set cwd $new_dir
    gen_log:log F "CD [pwd]"

    foreach {incvs insvn inrcs} [cvsroot_check [pwd]] { break }

    # If this directory has a different cvsroot, redo the tree
    if {$incvs} {
      if {$cvscfg(cvsroot) != $cvsglb(root)} {
        set cvsglb(root) $cvscfg(cvsroot)
        modbrowse_run cvs
      }
    } elseif {$insvn} {
      if {$cvscfg(svnroot) != $cvsglb(root)} {
        set cvsglb(root) $cvscfg(svnroot)
        modbrowse_run svn
      }
    }
    #if {$insvn || $incvs || $inrcs} {
      #.modbrowse.bottom.buttons.cvsfuncs.import configure -state disabled
    #} else {
      #.modbrowse.bottom.buttons.cvsfuncs.import configure -state normal
    #}

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

