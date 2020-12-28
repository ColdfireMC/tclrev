#
# Tcl Library for TkRev
#

# Help procedures and help data.
#
#########################################
#
# Developers: Please don't majorly change the formatting of this
# file unless you know what you're doing.
# The script "mkmanpage.pl" builds a manpage out of it, and the
# thing is the product of an unbelievable number of hours spent
# tweaking this file and the script so that both the help and
# the manpage look sort of OK.
#
# If you do add something to this, do "mkmanpage.pl > tkrev.n"
# to keep the manpage in sync, then look at it to make sure
# it worked.
#
# - dorothy
#########################################

proc aboutbox {} {
  global cvscfg
  global cvsglb

  toplevel .about
  wm title .about "About TkRev"

  frame .about.top
  frame .about.top.g1

  message .about.top.msg1 -width 400 -justify c \
      -text "\nTkRev Version $cvscfg(version)\n" -font $cvscfg(guifont)
  pack .about.top -side top -expand 1 -fill both

  image create photo Tclfish -format gif -file [file join $cvscfg(bitmapdir) TkCVS_128.gif]
  label .about.top.g1.gif1 -image Tclfish
  image create photo Toothyfish -format gif -file [file join $cvscfg(bitmapdir) TkSVN_128.gif]
  label .about.top.g1.gif2 -image Toothyfish
  image create photo Squid -format gif -file [file join $cvscfg(bitmapdir) TkRev_128.gif]
  label .about.top.gif3 -image Squid

  append string2 "A friendly graphical interface\n"
  append string2 "for CVS, Subversion and Git\n"
  append string2 "\nConsult the Help menu to\n"
  append string2 "learn about its features.\n\n"
  append string2 "TkCVS was written by Del.\n"
  append string2 "Later, Subversion functionality\n"
  append string2 "was added by Dorothy.\n"
  append string2 "Later still, Git functionality\n"
  append string2 "was added by Dorothy with some\n"
  append string2 "assistance from Mentor Graphics.\n"
  append string2 "Finally, the name was changed to TkRev.\n"

  message .about.top.msg3 -width 400 -justify c \
      -text $string2

  append about_string "Download: https://sourceforge.net/projects/tkcvs\n"

  message .about.top.msg4 -width 365 -justify c \
      -text $about_string -font $cvscfg(listboxfont)

  pack .about.top -side top -expand 1 -fill both
  pack .about.top.msg1 -expand 1 -fill x
  pack .about.top.g1 -side top -expand 1 -fill both
  pack .about.top.g1.gif1 -side left -pady 2
  pack .about.top.gif3 -side top
  pack .about.top.g1.gif2 -side right -pady 2
  pack .about.top.msg3 -expand 1 -fill x
  pack .about.top.msg4 -expand 1 -fill x

  frame .about.down
  button .about.down.ok -text "OK" -command {destroy .about}

  pack .about.down -side bottom -expand 1 -fill x -pady 2
  pack .about.down.ok
}

proc help_cvs_version {visual} {
  #
  # This shows the banners of the available revision control systems.
  #
  global cvs
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER"

  set cvsglb(have_cvs) 0
  set cvsglb(have_svn) 0
  set cvsglb(have_rcs) 0
  set cvsglb(have_git) 0

  set whichcvs [auto_execok $cvs]
  if {[llength $whichcvs]} {
    set whichcvs [join $whichcvs]
    set commandline "$cvs -v"
    gen_log:log C "$commandline"
    catch {exec {*}$commandline} cvs_output
    set cvsglb(have_cvs) 1
  }
  set whichsvn [auto_execok svn]
  if {[llength $whichsvn]} {
    set whichsvn [join $whichsvn]
    set commandline "svn --version"
    gen_log:log C "$commandline"
    set ret [catch {exec {*}$commandline} svn_output]
    set cvsglb(have_svn) 1
  }
  set whichrcs [auto_execok rcs]
  if {[llength $whichrcs]} {
    set whichrcs [join $whichrcs]
    set commandline "rcs --version"
    gen_log:log C "$commandline"
    set ret [catch {exec {*}$commandline} rcs_output]
    set cvsglb(have_rcs) 1
  }
  set whichgit  [auto_execok git]
  if {[llength $whichgit]} {
    set whichgit [join $whichgit]
    set commandline "git --version"
    gen_log:log C "$commandline"
    set ret [catch {exec {*}$commandline} git_output]
    set cvsglb(have_git) 1
  }

  if {$visual} {
    set v [viewer::new "Versions"]
    $v\::log "-----------------------------------------\n" blue
    if {$cvsglb(have_cvs)} {
      $v\::log "$whichcvs\n$cvs_output"
    } else {
      $v\::log "$cvs was not found in your path."
    }
    $v\::log "\n-----------------------------------------\n" blue
    if {$cvsglb(have_svn)} {
      $v\::log "$whichsvn\n$svn_output"
    } else {
      $v\::log "svn was not found in your path."
    }
    $v\::log "\n-----------------------------------------\n" blue
    if {$cvsglb(have_rcs)} {
      $v\::log "$whichrcs\n$rcs_output"
    } else {
      $v\::log "rcs was not found in your path."
    }
    $v\::log "\n-----------------------------------------\n" blue
    if {$cvsglb(have_git)} {
      $v\::log "$whichgit\n$git_output"
    } else {
      $v\::log "git was not found in your path."
    }
  }
  gen_log:log T "LEAVE"
}

proc wish_version {{parent {.}}} {
  global tk_patchLevel

  set version $tk_patchLevel
  set whichwish [info nameofexecutable]

  set about_string "$whichwish\n\n"
  append about_string "Tk version  $version"

  tk_messageBox -title "About Wish" \
      -message $about_string \
      -parent $parent \
      -type ok
}

######################################################################
#
# text formatting routines derived from Klondike
# Reproduced here with permission from their author.
#
# Copyright (C) 1993,1994 by John Heidemann <johnh@ficus.cs.ucla.edu>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of John Heidemann may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY JOHN HEIDEMANN ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL JOHN HEIDEMANN BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
######################################################################

# This posts the tagged text to the text widget
proc post_text {tw t} {
  gen_log:log T "ENTER ($tw ...)"

  set t <pgph>$t</pgph>
  while {[regexp -indices {<([^@>]*)>} $t match inds] == 1} {

    set start [lindex $inds 0]
    set end [lindex $inds 1]
    set keyword [string range $t $start $end]

    #set oldend [$tw index end]
    $tw insert end [string range $t 0 [expr {$start - 2}]]

    if {[string range $keyword 0 0] == "/"} {
      set keyword [string trimleft $keyword "/"]
      if {[info exists tags($keyword)] == 0} {
        error "end tag $keyword without beginning"
      }
      $tw tag add $keyword $tags($keyword) insert
      unset tags($keyword)
    } else {
      if {[info exists tags($keyword)] == 1} {
        error "nesting of begin tag $keyword"
      }
      set tags($keyword) [$tw index insert]
    }

    set t [string range $t [expr {$end + 2}] end]
  }

  #set oldend [$tw index end]
  $tw insert end $t
  gen_log:log T "LEAVE"
}

# This outputs the text in nroff format for the manpage
proc put_text {t fo} {
  gen_log:log T "ENTER ( ...)"

  # Strip the first newline
  set t [string trimleft $t "\n"]
  # and trailing space
  set t [string trimright $t " \n"]
  # That should have left only internal newlines
  #regsub -all {\n} $t "\n.br\n" t

  # Bold
  regsub -all {<bld>} $t {\\fB} t
  regsub -all {</bld>} $t {\\fP} t
  # Italic (underline)
  regsub -all {<itl>} $t {\\fI} t
  regsub -all {</itl>} $t {\\fP} t
  # Section Head (SYNOPSIS, OPTIONS, etc)
  regsub -all {<h1>} $t {.SH } t
  regsub -all {</h1>} $t {} t
  # Subsection heading
  regsub -all {<h2>} $t {.SS } t
  regsub -all {</h2>} $t {} t
  # .TP "term paragraph" - Term is idented, paragraphs are indented more
  regsub -all {<h3>} $t ".TP\n.B " t
  regsub -all {</h3>} $t {} t
  # No alternate fonts in nroff
  regsub -all {<cmp>} $t {} t
  regsub -all {</cmp>} $t {} t
  # No hyperlinks but embolden
  regsub -all {<hyp>} $t {\\fB} t
  regsub -all {</hyp>} $t {\\fP} t
  # Regular paragraph
  regsub -all {<pgph>} $t {} t
  regsub -all {</pgph>} $t {} t
  # Double indent
  regsub -all {<indt>} $t {} t
  regsub -all {</indt>} $t {} t

  puts $fo ".PP"
  #foreach m [split $t "\n"] {
    #puts $fo "$m"
  #}
  puts $fo $t
  gen_log:log T "LEAVE"
}

proc clear_text {tw} {
  $tw delete 1.0 end
}

proc hyperlink { hviewer xpos ypos} {
  gen_log:log T "ENTER ($hviewer $xpos $ypos)"
  upvar 1 toc_dict toc_dict

  set i [$hviewer index @$xpos,$ypos]
  set range [$hviewer tag prevrange hyp $i]
  set linktext [eval $hviewer get $range]
  gen_log:log D "$linktext"
  dict for {section title} $toc_dict {
    gen_log:log D "$title: $section"
    if {$linktext eq $title} {
      gen_log:log D "$section $hviewer $title"
      $section $hviewer $title
      break
    }
  }
  gen_log:log T "LEAVE"
}

######################################################################
#
# End of text formatting routines.
#
######################################################################

proc do_help {parent title helptext} {
  global cvscfg
  global cvsglb
  global tcl_platform

  gen_log:log T "ENTER $title <helptext suppressed>)"

  if {! [info exists cvsglb(last_searchstr)]} {set cvsglb(last_searchstr) ""}
  set tw .cvshelpview.top.text

  if {[winfo exists .cvshelpview]} {
    clear_text $tw
    wm deiconify .cvshelpview
    raise .cvshelpview
  } else {
    toplevel .cvshelpview
    frame .cvshelpview.top
    text $tw -setgrid yes -wrap word \
        -exportselection 1 \
        -width 80 -height 28 -relief sunken -border 2 \
        -yscroll ".cvshelpview.top.scroll set"
    scrollbar .cvshelpview.top.scroll -relief sunken \
        -command "$tw yview"
    frame .cvshelpview.bot
    button .cvshelpview.bot.toc -text "Back to Table of Contents" \
        -command "table_of_contents $parent"
    button .cvshelpview.bot.close -text "Close" \
        -command "destroy .cvshelpview; exit_cleanup 0"
    button .cvshelpview.bot.searchbtn  -text Search \
        -command "search_textwidget .cvshelpview.top.text"
    entry .cvshelpview.bot.entry -width 20 -textvariable cvsglb(searchstr)
    bind .cvshelpview.bot.entry <Return> \
        "search_textwidget .cvshelpview.top.text"

    pack .cvshelpview.bot -side bottom -fill x
    pack .cvshelpview.bot.searchbtn -side left
    pack .cvshelpview.bot.entry -side left
    pack .cvshelpview.bot.toc -side left
    pack .cvshelpview.bot.close -side right
    pack .cvshelpview.top -side top -fill both -expand y
    pack .cvshelpview.top.scroll -side right -fill y
    pack $tw -fill both -expand y

    wm title .cvshelpview "TkRev Help"
    dialog_position .cvshelpview $parent

    if { [tk windowingsystem] eq "x11" } {
      wm iconphoto .cvshelpview Help
    }
    wm minsize .cvshelpview 1 1

    $tw configure -font -*-Helvetica-Medium-R-Normal-*-14-*
    set tabwidth [font measure -*-Helvetica-Medium-R-Normal-*-14-* -displayof $tw "\t"]
    set doubletab [expr {$tabwidth * 2}]

    # Indented paragraph, normal for text
    $tw tag configure pgph -lmargin1 $tabwidth -lmargin2 $tabwidth
    # Double-indened, fo hang under a h3 heading
    $tw tag configure indt -lmargin1 $doubletab -lmargin2 $doubletab
    # Bold
    $tw tag configure bld -font -*-Helvetica-Bold-R-Normal-*-14-*
    # Italic
    $tw tag configure itl -font -*-Helvetica-Medium-I-Normal-*-14-*
    # Section Head (SYNOPSIS, OPTIONS, etc)
    #$tw tag configure h1 -font -*-Helvetica-Bold-R-Normal-*-18-* -underline 1 -lmargin1 0 -lmargin2 0
    $tw tag configure h1 -font -*-Helvetica-Bold-R-Normal-*-18-* -lmargin1 0 -lmargin2 0
    # Subsection heading
    $tw tag configure h2 -font -*-Helvetica-Bold-R-Normal-*-16
    # term for "term paragraph"
    $tw tag configure h3 -font -*-Helvetica-Bold-R-Normal-*-14-* -lmargin1 $tabwidth -lmargin2 $tabwidth
    # Code block in monospace font
    $tw tag configure cmp -font -*-Courier-Medium-R-Normal-*-14-*
    # Hyperlink
    $tw tag configure hyp -font -*-Helvetica-Medium-R-Normal-*-14-* -underline 1 -foreground blue

    $tw mark set insert 0.0

    $tw tag bind hyp <Button-1> "hyperlink $tw %x %y"
    $tw tag bind hyp <Enter> "$tw config -cursor hand2"
    $tw tag bind hyp <Leave> "$tw config -cursor {}"

    ro_textbindings $tw
  }
  post_text $tw "<h1>$title</h1>\n\n$helptext"
  gen_log:log T "LEAVE ($tw)"
}

proc define_sections {} {
  # Make it available above
  upvar 1 toc_dict toc_dict

  set toc_dict [dict create \
    man_description "Overview" \
    man_cli_options "Command Line Options" \
    man_current_directory "Current Directory Browser" \
    man_module_browser "Repository Browser" \
    man_branch_diagram_browser "Branch Diagram Browser" \
    man_directory_branch_viewer "Directory Merge Tool for CVS" \
    man_importing_new_modules "Importing New Modules" \
    man_importing_to_existing_module "Importing to an Existing Module" \
    man_vendor_merge "Vendor Merge for CVS" \
    man_configuration_files "TkRev Configuration Files" \
    man_user_defined_menu "User Defined Menu" \
    man_cvs_modules_file "CVS Modules File" \
    man_environment_variables "Environment Variables" \
  ]
}

proc table_of_contents {parent} {
  gen_log:log T "ENTER ($parent)"
  upvar 1 toc_dict toc_dict

  # Run the proc where the list is defined
  define_sections

  # Generate the text for the ToC
  dict for {procname title} $toc_dict {
    #gen_log:log D "procname <hyp>$title</hyp>"
    append toc_list "<hyp>$title</hyp>\n"
    append toc_list "\n"
  }

  # Post the ToC
  if {[winfo exists .cvshelpview]} {
    clear_text .cvshelpview.top.text
    post_text .cvshelpview.top.text "<h1>$title</h1>\n\n$toc_list"
  } else {
    do_help $parent "Table of Contents" $toc_list
  }
  gen_log:log T "LEAVE"
}

#
# Help procedures for the TkRev users guide.
#

proc man_description {wn title {manpage {}} } {
  gen_log:log T "ENTER ($wn $title)"

  set help_body_1 {
<bld>tkrev</bld> [<bld>-dir</bld> <itl>directory</itl>] [<bld>-root</bld> <itl>cvsroot</itl>] [<bld>-win workdir</bld>|<bld>module</bld>|<bld>merge</bld>]

<bld>tkrev</bld> [<bld>-log</bld>|<bld>blame</bld> <itl>file</itl>]

<bld>tkrev</bld> <bld>file</bld> - same as <bld>tkrev -log</bld> <itl>file</itl>
}

  set help_body_2 {
TkRev is a Tcl/Tk-based graphical interface to the CVS, Subversion and Git configuration management systems. It displays the status of the files in the current working directory, and provides buttons and menus to execute configuration-management commands on the selected files. Limited RCS functionality is also present. Git functionality is new in version 9.
TkDiff is bundled in for browsing and merging your changes.
TkRev also aids in browsing the repository. For Subversion, the repository tree looks like an ordinary file tree. For CVS, the CVSROOT/modules file is read. TkRev extends CVS with a method to produce a browsable, "user friendly" listing of modules. This requires special comments in the CVSROOT/modules file. See the <hyp>CVS Modules File</hyp> section for more guidance.
  }

  # In the manpage, this is two sections, but in the help, it's one
  if {$manpage ne ""} {
    puts $manpage ".SH SYNOPSIS"
    put_text $help_body_1 $manpage
    puts $manpage ".SH DESCRIPTION"
    put_text $help_body_2 $manpage
  } else {
    clear_text $wn
    post_text $wn "<h1>$title</h1>\n"
    post_text $wn $help_body_1
    post_text $wn $help_body_2
  }
}
# End man_description

proc man_cli_options {wn title {manpage {}} } {
  gen_log:log T "ENTER ($wn $title)"

  set help_body_1 {
TkRev accepts the following options

<h3>-dir</h3> <itl>directory</itl>
<indt>Start TkRev in the specified directory</indt>

<h3>-help</h3>
<indt>Print a usage message</indt>

<h3>-log</h3> <itl>file</itl>
<indt>Invoke a log browser for the specified file</indt>

<h3>-blame</h3> <itl>file</itl>
<indt>Invoke a blame (annotation) browser for the specified file</indt>

<h3>-root</h3> <itl>cvsroot</itl>
<indt>Set $CVSROOT to the specified repository.</indt>

<h3>-win</h3>  <bld>workdir</bld>|<bld>module</bld>|<bld>merge</bld>
<indt>Start by displaying the directory browser (the default), the module browser, or the directory-merge tool. -win and -log are mutually exclusive.</indt>
  }

  set help_body_2 {
<h2>Examples</h2>
Browse the modules located in CVSROOT /jaz/repository:

<cmp>% tkrev -win module -root /jaz/repository</cmp>

View the log of the file tstheap.c:

<cmp>% tkrev -log tstheap.c</cmp>
  }

  if {$manpage ne ""} {
    puts $manpage ".SH OPTIONS"
    put_text $help_body_1 $manpage
    put_text $help_body_2 $manpage
  } else {
    clear_text $wn
    post_text $wn "<h1>$title</h1>\n"
    post_text $wn $help_body_1
    post_text $wn $help_body_2
  }
}
# End man_cli_options

proc man_current_directory {wn title {manpage {}} } {
  gen_log:log T "ENTER ($wn $title)"

  set help_body_1 {
The working directory browser shows the files in your local working copy, or "sandbox."  It shows the status of the files at a glance and provides tools to help with most of the common version control operations you might do.

At the top of the browser you will find:

<bld>*</bld> The name of the current directory. You can change directories by typing in this field. Recently visited directories are saved in the picklist.

<bld>*</bld> The relative path of the current directory in the repository. If it is not contained in the repository you may import it using the menu or toolbar button.

<bld>*</bld> A Directory Tag name, if the directory is contained in the repository and it has been checked out against a particular branch or tag. In Subversion, the branch or tag is inferred from the URL based on the conventional trunk-branches-tags repository organization.

<bld>*</bld> The repository location of the current directory - CVSROOT if it's under CVS control, the URL of the Subversion repository if it's under Subversion control, or the origin if it's controlled by Git. If not a version-controlled directory, it may default to the value of the $CVSROOT environment variable.

The main part of the working directory browser is a list of the files in the current directory with an icon next to each showing its status. You select a file by clicking on its name or icon once with the left mouse button. Holding the Control key while clicking will add the file to the group of those already selected. You can select a contiguous group of files by holding the Shift key while clicking. You can also select a group of files by dragging the mouse with the middle or right button pressed to select an area. Selecting an item that's already selected de-selects that item. To unselect all files, click the left mouse button in an empty area of the file list.

<bld>*</bld> The Date column (can be hidden) shows the modification time of the file is shown. The format of the date column may be specified with cvscfg(dateformat). The default format was chosen because it sorts the same way alphabetically as chronologically.

If the directory belongs to a revision system, other columns are present.

<bld>*</bld> The revision column shows which revision of the file is checked out, and whether it's on the trunk or on a branch.

<bld>*</bld> The status column (can be hidden) shows the revision of the file spelled out in text. This information is mostly redundant to the icon in the file column.

<bld>*</bld> The Editor/Author/Locker column (can be hidden) varies according to revision system. In Subversion, the author of the most recent checkin is shown. In CVS, it shows a list of people editing the files if your site uses "cvs watch" and/or "cvs edit". Otherwise, it will be empty. In RCS, it shows who, if anyone, has the file locked.

The optional columns can be displayed or hidden using the Options menu.

You can move into a directory by double-clicking on it.

Double clicking on a file will load the file into a suitable editor so you can change it. A different editor can be used for different file types (see Configuration Files).
  }

  set help_body_2 {
<h2>File Status</h2>

When you are in a directory that is under CVS, Subversion, or Git control, the file status will be shown by an icon next to each file. Checking the "Status Column" option causes the status to be displayed in text in its own column. Some possible statuses are:

<h3>Up-to-date</h3>
<indt>The file is up to date with respect to the repository.</indt>

<h3>Locally Modified</h3>
<indt>The file has been modified in the current directory since being checked out of the repository.</indt>

<h3>Locally Added</h3>
<indt>The file has been added to the repository. This file will become permanent in the repository once a commit is made.</indt>

<h3>Locally Removed</h3>
<indt>You have removed the file with remove, and not yet committed your changes.</indt>

<h3>Needs Checkout</h3>
<indt>Someone else has committed a newer revision to the repository. The name is slightly misleading; you will ordinarily use update rather than checkout to get that newer revision.</indt>

<h3>Needs Patch</h3>
<indt>Like Needs Checkout, but the CVS server will send a patch rather than the entire file. Sending a patch or sending an entire file accomplishes the same thing.</indt>

<h3>Needs Merge</h3>
<indt>Someone else has committed a newer revision to the repository, and you have also made modifications to the file.</indt>

<h3>Unresolved Conflict</h3>
<indt>This is like Locally Modified, except that a previous update command gave a conflict. You need to resolve the conflict before checking in.</indt>

<h3>?</h3>
<indt>The file is not contained in the repository. You may need to add the file to the repository by pressing the "Add" button.</indt>

<h3>[directory:CVS]</h3>
<indt>A directory which has been checked out from a CVS repository.</indt>

<h3>[directory:SVN]</h3>
<indt>A directory which has been checked out from a Subversion repository. In Subversion, directories are themselves versioned objects.</indt>

<h3>[directory:RCS]</h3>
<indt>A directory which contains an RCS sub-directory or some files with the ,v suffix, presumably containing some files that are under RCS revision control.</indt>

<h3>[directory:GIT]</h3>
<indt>A directory which has been cloned from a Git repository.</indt>

<h3>[directory]</h3>
<indt>A directory not controlled by one of the supported revision control systems</indt>
  }

  set help_body_3 {
<h2>File Filters</h2>

<h3>Clean</h3>
<indt>You can specify file matching patterns to instruct TkRev which files you wish to see. You can also specify patterns telling it which files to remove when you press the "Clean" button or select the <bld>File -> Cleanup</bld> menu item.</indt>

<h3>Hide</h3>
<indt>"Hide" works exactly the way a .cvsignore file works. That is, it causes non-CVS files with the pattern to be ignored. It's meant for hiding .o files and such. Any file under CVS control will be listed anyway.</indt>

<h3>Show</h3>
<indt>"Show" is the inverse. It hides non-CVS files except for those with the pattern.</indt>

<h2>Buttons</h2>

<h3>Module Browser:</h3>
<indt>The big button at the upper right opens the module browser opens a module browser window which will enable you to explore items in the repository even if they're not checked out. In CVS, this requires that there be entries in the CVSROOT/modules file. Browsing can be improved by using TkRev-specific comments in CVSROOT/modules.</indt>

<h3>Go Up:</h3>
<indt>The button to the left of the entry that shows the current directory. Press it and you go up one level.</indt>
  }

  set help_body_4 {
There are a number of buttons at the bottom of the window. Pressing on one of these causes the following actions:

<h3>Delete:</h3>
<indt>Press this button to delete the selected files. The files will not be removed from the repository. To remove the files from the repository as well as delete them, press the "Remove" button instead.</indt>

<h3>Edit:</h3>
<indt>Press this button to load the selected files in to an appropriate editor.</indt>

<h3>View:</h3>
<indt>Press this button to view the selected files in a Tk text window. This can be a lot faster then Edit, in case your preferred editor is xemacs or something of that magnitude.</indt>

<h3>Refresh:</h3>
<indt>Press this button to re-read the current directory, in case the status of some files may have changed.</indt>

<h3>Status Check:</h3>
<indt>Shows, in a searchable text window, the status of all the files. By default, it is recursive and lists unknown (?) files. These can be changed in the Options menu.</indt>


<h3>Directory Branch Browser:</h3>
<indt>For merging the entire directory. In Subversion, it opens the Branch Browser for "."  In CVS, it chooses a "representative" file in the current directory and opens a graphical tool for directory merges.</indt>

<h3>Log (Branch) Browse:</h3>
<indt>This button will bring up the log browser window for each of the selected files in the window. See the <hyp>Branch Diagram Browser</hyp> section.</indt>

<h3>Annotate:</h3>
<indt>This displays a window in which the selected file is shown with the lines highlighted according to when and by whom they were last revised. In Subversion, it's also called "blame."</indt>

<h3>Diff:</h3>
<indt>This compares the selected files with the equivalent files in the repository. A separate program called "TkDiff" (also supplied with TkRev) is used to do this. For more information on TkDiff, see TkDiff's help menu.</indt>

<h3>Merge Conflict:</h3>
<indt>If a file's status says "Needs Merge", "Conflict", or is marked with a "C" in CVS Check, there was a difference which CVS needs help to reconcile. This button invokes TkDiff with the -conflict option, opening a merge window to help you merge the differences.</indt>

<h3>Check In:</h3>
<indt>This button commits your changes to the repository. This includes adding new files and removing deleted files. When you press this button, a dialog will appear asking you for the version number of the files you want to commit, and a comment. You need only enter a version number if you want to bring the files in the repository up to the next major version number. For example, if a file is version 1.10, and you do not enter a version number, it will be checked in as version 1.11. If you enter the version number 3, then it will be checked in as version 3.0 instead. It is usually better to use symbolic tags for that purpose.  If you use rcsinfo to supply a template for the comment, you must use an external editor. Set cvscfg(use_cvseditor) to do this. For checking in to RCS, an externel editor is always used.</indt>

<h3>Update:</h3>
<indt>This updates your sandbox directory with any changes committed to the repository by other developers.</indt>

<h3>Update with Options:</h3>
<indt>Allows you to update from a different branch, with a tag, with empty directories, and so on.</indt>

<h3>Add Files:</h3>
<indt>Press this button when you want to add new files to the repository. You must create the file before adding it to the repository. To add some files, select them and press the Add Files button. The files that you have added to the repository will be committed next time you press the Check In button. It is not recursive. Use the menu <bld>CVS -> Add Recursively</bld> for that.</indt>

<h3>Remove Files:</h3>
<indt>This button will remove files. To remove files, select them and press the Remove button. The files will disappear from the directory, and will be removed from the repository next time you press the Check In button. It is not recursive. Use the menu <bld>CVS -> Remove Recursively</bld> for that.</indt>

<h3>Tag:</h3>
<indt>This button will tag the selected files. In CVS, the <bld>-F (force)</bld> option will move the tag if it already exists on the file.</indt>

<h3>Branch Tag:</h3>
<indt>This button will tag the selected files, creating a branch. In CVS, the <bld>-F (force)</bld> option will move the tag if it already exists on the file.</indt>

<h3>Lock (CVS and RCS):</h3>
<indt>Lock an RCS file for editing. If cvscfg(cvslock) is set, lock a CVS file. Use of locking is philosophically discouraged in CVS since it's against the "concurrent" part of Concurrent Versioning System, but locking policy is nevertheless used at some sites. One size doesn't fit all.</indt>

<h3>Unlock (CVS and RCS):</h3>
<indt>Unlock an RCS file. If cvscfg(cvslock) is set, unlock a CVS file.</indt>

<h3>Set Edit Flag (CVS):</h3>
<indt>This button sets the edit flag on the selected files, enabling other developers to see that you are currently editing those files (See "cvs edit" in the CVS documentation).</indt>

<h3>Reset Edit Flag (CVS):</h3>
<indt>This button resets the edit flag on the selected files, enabling other developers to see that you are no longer editing those files (See "cvs edit" in the CVS documentation). As the current version of cvs waits on a prompt for "cvs unedit" if changes have been made to the file in question (to ask if you want to revert the changes to the current revision), the current action of tkrev is to abort the unedit (by piping in nothing to stdin). Therefore, to lose the changes and revert to the current revision, it is necessary to delete the file and do an update (this will also clear the edit flag). To keep the changes, make a copy of the file, delete the original, update, and then move the saved copy back to the original filename.</indt>

<h3>Close:</h3>
<indt>Press this button to close the Working Directory Browser. If no other windows are open, TkRev exits.</indt>
  }

  if {$manpage ne ""} {
    puts $manpage ".SH $title"
    put_text $help_body_1 $manpage
    put_text $help_body_2 $manpage
    put_text $help_body_3 $manpage
    put_text $help_body_4 $manpage
  } else {
    clear_text $wn
    post_text $wn "<h1>$title</h1>\n"
    post_text $wn $help_body_1
    post_text $wn $help_body_2
    post_text $wn $help_body_3
    post_text $wn $help_body_4
  }
}
# #nd man_current_directory

proc man_branch_diagram_browser {wn title {manpage {}} } {
  gen_log:log T "ENTER ($wn $title)"

  set help_body_1 {
The TkRev Log Browser window enables you to view a graphical display of the revision log of a file, including all previous versions and any branched versions.

You can get to the log browser window in three ways, either by invoking it directly with <bld>tkrev [-log]</bld> <itl>filename</itl>, by selecting a file in the main window of TkRev and pressing the Log Browse button, or by selecting a file in a list invoked from the module browser and pressing the Log Browse button.

If the Log Browser is examining a checked-out file, the buttons for performing merge operations are enabled.

<h2>Log Browser Window</h2>

The log browser window has three components. These are the file name and version information section at the top, the log display in the middle, and a row of buttons along the bottom.

<h2>Log Display</h2>

The main log display is fairly self explanatory. It shows a group of boxes connected by lines indicating the main trunk of the file development (on the left hand side) and any branches that the file has (which spread out to the right of the main trunk).

Each box contains the version number, author of the version, and other information determined by the menu Diagram -> Revision Layout.

Constructing the branch diagram from Subversion is inefficient, so the Log Browser counts the tags when doing a Subversion diagram and pops up a dialog giving you a chance to skip the tag step if there are too many tags (where "many" arbitrarily equals 10.)

<h2>Version Numbers</h2>

Once a file is loaded into the log browser, one or two version numbers may be selected. The primary version (Selection A) is selected by clicking the left mouse button on a version box in the main log display.

The secondary version (Selection B) is selected by clicking the right mouse button on a version box in the main log display.

Operations such as "View" and "Annotate" operate only on the primary version selected.

Operations such as "Diff" and "Merge Changes to Current" require two versions to be selected.

<h2>Searching the Diagram</h2>

You can search the canvas for tags, revisions, authors, and dates.
The following special characters are used in the search pattern:
    *      Matches any sequence of characters in string, including a null string.
    ?      Matches any single character in string.
    [chars] Matches any character in the set given by chars. If a sequence of the form x-y appears in chars, then any character between x and y, inclusive, will match.
    \\x      Matches the single character x. This provides a way of avoiding interpretation of the spacial characters in a  pattern. If you only enter "foo" (without the quotes) in the entry box, it searches the exact string "foo". If you want to search all strings starting with "foo", you have to put "foo*". For all strings containing "foo", you must put "*foo*".

<h2>Log Browser Buttons</h2>

The log browser contains the following buttons:

<h3>Refresh:</h3>
<indt>Re-reads the revision history of the file</indt>

<h3>View:</h3>
<indt>Pressing this button displays a Tk text window containing the version of the file at Selection A.</indt>

<h3>Annotate:</h3>
<indt>This displays a window in which the file is shown with its lines highlighted according to when and by whom they were last revised. In Subversion, it's also called "blame."</indt>

<h3>Diff:</h3>
<indt>Pressing this button runs the "tkdiff" program to display the differences between version A and version B.</indt>

<h3>Merge:</h3>
<indt>To use this button, select a branch version of the file, other than the branch you are currently on, as the primary version (Selection A). The changes made along the branch up to that version will be merged into the current version, and stored in the current directory. Optionally, select another version (Selection B) and the changes will be from that point rather than from the base of the branch. The version of the file in the current directory will be merged, but no commit will occur. Then you inspect the merged files, correct any conflicts which may occur, and commit when you are satisfied. Optionally, TkRev will tag the version that the merge is from. It suggests a tag of the form "mergefrom_rev_date."  If you use this auto-tagging function, another dialog containing a suggested tag for the merged-to version will appear. It's suggested to leave the dialog up until you are finished, then copy-and-paste the suggested tag into the "Tag" dialog. It is always a good practice to tag when doing merges, and if you use tags of the suggested form, the Branch Browser can diagram them. (Auto-tagging is not implemented in Subversion because, despite the fact that tags are "cheap," it's somewhat impractical to auto-tag single files. You can do the tagging manually, however.)</indt>

<h3>View Tags:</h3>
<indt>This button lists all the tags applied to the file in a searchable text window.</indt>

<h3>Close:</h3>
<indt>This button closes the Log Browser. If no other windows are open, TkRev exits.</indt>
  }

  set help_body_2 {
<h2>The Diagram Menu</h2>
The Diagram Menu allows you to control what you see in the branch diagram. You can choose how much information to show in the boxes, whether to show empty revisions, and whether to show tags. You can even control the size of the boxes. If you are using Subversion, you may wish to turn the display of tags off. If they aren't asked for they won't be read from the repository, which can save a lot of time.
  }

  if {$manpage ne ""} {
    puts $manpage ".SH $title"
    put_text $help_body_1 $manpage
    put_text $help_body_2 $manpage
  } else {
    clear_text $wn
    post_text $wn "<h1>$title</h1>\n"
    post_text $wn $help_body_1
    post_text $wn $help_body_2
  }
}
# End man_branch_diagram_browser

proc man_directory_branch_viewer {wn title {manpage {}} } {
  gen_log:log T "ENTER ($wn $title)"

  set help_body {
The Directory Merge Tool chooses a "representative" file in the current directory and diagrams the branch tags. It tries to pick the "bushiest" file, or failing that, the most-revised file. If you disagree with its choice, you can type the name of another file in the top entry and press Return to diagram that file instead.

The main purpose of this tool is to do merges (cvs update -j rev [-j rev]) on the whole directory. For merging one file at a time, you should use the Log Browser. You can only merge to the line (trunk or branch) that you are currently on. Select a branch to merge from by clicking on it. Then press either the "Merge" or "Merge Changes" button. The version of the file in the current directory will be over-written, but it will not be committed to the repository. You do that after you've reconciled conflicts and decided if it's what you really want.

<h2>Merge Branch to Current:</h2>

The changes made on the branch since its beginning will be merged into the current version.

<h2>Merge Changes to Current:</h2>

Instead of merging from the base of the branch, this button merges the changes that were made since a particular version on the branch. It pops up a dialog in which you fill in the version. It should usually be the version that was last merged.
  }

  if {$manpage ne ""} {
    puts $manpage ".SH $title"
    put_text $help_body $manpage
  } else {
    clear_text $wn
    post_text $wn "<h1>$title</h1>\n"
    post_text $wn $help_body
  }
}
# End man_directory_branch_viewer

proc man_module_browser {wn title {manpage {}} } {
  gen_log:log T "ENTER ($wn $title)"

  set help_body {
Operations that are performed on the repository instead of in a checked-out working directory are done with the Module Browser. The most common of these operations is checking out or exporting from the repository. The Module Browser can be started from the command line (tkrev -win module) or started from the main window by pressing the big button.

Subversion repositories can be browsed like a file tree, and that is what you will see in the Module Browser. CVS repositories aren't directly browsable, but if the CVSROOT/modules file is maintained appropriately, TkRev can display the modules and infer tree structures if they are present. See the <hyp>CVS Modules File</hyp> section.

Using the module browser window, you can select a module to check out. When you check out a module, a new directory is created in the current working directory with the same name as the module.

<h2>Tagging and Branching (cvs rtag)</h2>

You can tag particular versions of a module or file in the repository, with plain or branch tags, without having the module checked out.

<h2>Exporting</h2>

Once a software release has been tagged, you can use a special type of checkout called an export. This allows you to cleanly check out files from the repository,  without all of the administrivia that CVS needs to have while working on the files. It is useful for delivery of a software release to a customer.

<h2>Importing</h2>

TkRev contains a special dialog to allow users to import new files into the repository. In CVS, new modules can be assigned places within the repository, as well as descriptive names (so that other people know what they are for).

When the Module Browser displays a CVS repository, the first column is a tree showing the module codes and directory names of all of the items in the repository. The icon shows whether the item is a directory (which may contain other directories or modules), or whether it is a module (which may be checked out from TkRev). It is possible for an item to be both a module and a directory. If it has a red ball on it, you can check it out. If it shows a plain folder icon, you have to open the folder to get to the items that you can check out.

To select a module, click on it with the left mouse button. The right mouse button will perform a secondary selection, which is used only for Subversion diff and patch. To clear the selection, click on the item again or click in an empty area of the module column. There can only be one primary and one secondary selection.

<h2>Repository Browser Buttons</h2>

The module browser contains the following buttons:

<h3>Who:</h3>
<indt>CVS only. Shows which modules are checked out by whom.</indt>

<h3>Import:</h3>
<indt>This item will import the contents of the current directory (the one shown in the Working Directory Browser) into the repository as a module. See the section titled Importing for more information.</indt>

<h3>File Browse:</h3>
<indt>Displays a list of the selected module's files. From the file list, you can view the file, browse its revision history, or see a list of its tags.</indt>

<h3>Check Out:</h3>
<indt>Checks out the current version of a module. A dialog allows you to specify a tag, change the destination, and so on.</indt>

<h3>Export:</h3>
<indt>Exports the current version of a module. A dialog allows you to specify a tag, change the destination, and so on. Export is similar to check-out, except exported directories do not contain the CVS or administrative directories, and are therefore cleaner (but cannot be used for checking files back in to the repository). You must supply a tag name when you are exporting a module to make sure you can reproduce the exported files at a later date.</indt>

<h3>Tag:</h3>
<indt>This button tags an entire module.</indt>

<h3>Branch Tag:</h3>
<indt>This creates a branch of a module by giving it a branch tag.</indt>

<h3>Patch Summary:</h3>
<indt>This item displays a short summary of the differences between two versions of a module.</indt>

<h3>Create Patch File:</h3>
<indt>This item creates a Larry Wall format patch(1) file of the module selected.</indt>

<h3>Close:</h3>
<indt>This button closes the Repository Browser. If no other windows are open, TkRev exits.</indt>
  }

  if {$manpage ne ""} {
    puts $manpage ".SH $title"
    put_text $help_body $manpage
  } else {
    clear_text $wn
    post_text $wn "<h1>$title</h1>\n"
    post_text $wn $help_body
  }
}
# End man_module_browser

proc man_importing_new_modules {wn title {manpage {}} } {
  gen_log:log T "ENTER ($wn $title)"

  set help_body_1 {
Before importing a new module, first check to make sure that you have write permission to the repository. Also you'll have to make sure the module name is not already in use.

To import a module you first need a directory where the module is located. Make sure that there is nothing in this directory except the files that you want to import.

Press the big "Repository Browser" button in the top part of the tkrev UI, or use CVS -> Import WD into Repository from the menu bar.

In the module browser, press the Import button on the bottom, the one that shows a folder and an up arrow.

In the dialog that pops up, fill in a descriptive title for the module. This will be what you see in the right side of the module browser.

OK the dialog. Several things happen now. The directory is imported, the CVSROOT/module file is updated, your original directory is saved as directory.orig, and the newly created module is checked out.

When it finishes, you should find the original Working Directory Browser showing the files in the newly created, checked out module.

Here is a more detailed description of the fields in the Import Dialog.

<h3>Module Name:</h3>
<indt>A name for the module. This name must not already exist in the repository. Your organization could settle on a single unambiguous code for modules. One possibility is something like:

<cmp>[project code]-[subsystem code]-[module code]</cmp></indt>

<h3>Module Path:</h3>
<indt>The location in the repository tree where your new module will go.</indt>

<h3>Descriptive Title:</h3>
<indt>A one-line descriptive title for your module. This will be displayed in the right-hand column of the browser.</indt>

<h3>Version Number:</h3>
<indt>The current version number of the module. This should be a number of the form X.Y.Z where .Y and .Z are optional. You can leave this blank, in which case 1 will be used as the first version number.</indt>
  }

  set help_body_2 {
Importing a directory into Subversion is similar but not so complicated. You use the SVN -> Import CWD into Repository menu. You need supply only the path in the repository where you want the directory to go. The repository must be prepared and the path must exist, however.
  }

  if {$manpage ne ""} {
    puts $manpage ".SH $title"
    put_text $help_body_1 $manpage
    put_text $help_body_2 $manpage
  } else {
    clear_text $wn
    post_text $wn "<h1>$title</h1>\n"
    post_text $wn $help_body_1
    post_text $wn $help_body_2
  }
}
# End man_importing_new_modules

proc man_importing_to_existing_module {wn title {manpage {}} } {
  gen_log:log T "ENTER ($wn $title)"

  set help_body {
Before importing to an existing module, first check to make sure that you have write permission to the repository.

To import to an existing module you first need a directory where the code is located. Make sure that there is nothing in this directory (including no CVS directory) except the files that you want to import.

Open up the Repository Browser by selecting <bld>File -> Browse Modules</bld> from the menu bar.

In the Repository Browser, select <bld>File -> Import To An Existing Module</bld> from the menu bar.

In the dialog that pops up, press the Browse button and select the name of an existing module. Press the OK to close this dialog box. Enter the version number of the code to be imported.

OK the dialog. Several things happen now. The directory is imported, your original directory is saved as directory.orig, and the newly created module is checked out.

When it finishes, you will find the original Working Directory Browser showing the original code. If you press the "Re-read the current directory" button you will see the results of the checked out code.

Here is a more detailed description of the fields in the Import Dialog.

<h3>Module Name:</h3>
<indt>A name for the existing module. Filled in by the use of the the Browse button</indt>

<h3>Module Path:</h3>
<indt>The location in the repository tree where the existing module is. Filled in by the use of the Browse button.</indt>

<h3>Version Number:</h3>
<indt>The current version number of the module to be imported. This should be a number of the form X.Y.Z where .Y and .Z are optional. You can leave this blank, in which case 1 will be used as the first version number.</indt>
  }

  if {$manpage ne ""} {
    puts $manpage ".SH $title"
    put_text $help_body $manpage
  } else {
    clear_text $wn
    post_text $wn "<h1>$title</h1>\n"
    post_text $wn $help_body
  }
}
# End man_importing_to_existing_mdoule

proc man_vendor_merge {wn title {manpage {}} } {
  gen_log:log T "ENTER ($wn $title)"

  set help_body {
Software development is sometimes based on source distribution from a vendor or third-party distributor. After building a local version of this distribution, merging or tracking the vendor's future release into the local version of the distribution can be done with the vendor merge command.

The vendor merge command assumes that a separate module has already been defined for the vendor or third-party distribution with the use of the "Import To A New Module" and "Import To An Existing Module" commands. It also assumes that a separate module has already been defined for the local code for which the vendor merge operation is to be applied to.

Start from an empty directory and invoke tkrev. Open up the Repository Browser by selecting <bld>File -> Browse Modules</bld> from the menu bar.

Checkout the module of the local code to be merged with changes from the vendor module. (Use the red icon with the down arrow)

In the Repository Browser, after verifying that the Module entry box still has the name the module of the local code to which the vendor code is to be merged into, select File/Vendor Merge from the menu bar.

In the Module Level Merge With Vendor Code window, press the Browse button to select the module to be used as the vendor module.

OK the dialog. All revisions from the vendor module will be shown in the two scroll lists. Fill in the From and To entry boxes by clicking in the appropriate scroll lists.

Ok the dialog. Several things happens now. Several screens will appear showing the output from cvs commands for (1)checking out temp files, (2)cvs merge, and (3)cvs rdiff. Information in these screens will tell you what routines will have merge conflicts and what files are new or deleted. After perusing the files, close each screen. (In the preceding dialog box, there was an option to save outputs from the merge and rdiff operations to files CVSmerge.out and CVSrdiff.out.)

The checked out local code will now contain changes from a merge between two revisions of the vendor modules. This code will not be checked into the repository. You can do that after you've reconciled conflicts and decide if that is what you really want.

A detailed example on how to use the vendor merge operation is provided in the PDF file vendor5readme.pdf.
  }

  if {$manpage ne ""} {
    puts $manpage ".SH $title"
    put_text $help_body $manpage
  } else {
    clear_text $wn
    post_text $wn "<h1>$title</h1>\n"
    post_text $wn $help_body
  }
}
# End man_vendor_merge

proc man_configuration_files {wn title {manpage {}} } {
  gen_log:log T "ENTER ($wn $title)"

  set help_body {
There are two configuration files for TkRev. The first is stored in the directory in which the *.tcl files for TkRev are installed. This is called tkrev_def.tcl. You can put a file called site_def in that directory, too. That's a good place for site-specific things like tagcolours. Unlike tkrev_def.tcl, it will not be overwritten when you install a newer version of TkRev.

Values in the site configuration files can be over-ridden at the user level by placing a .tkrev file in your home directory. Commands in either of these files should use Tcl syntax. In other words, to set a variable name, you should have the following command in your .tkrev file:

<cmp>    set variablename value</cmp>

for example:
<cmp>    set cvscfg(editor) "gvim"</cmp>

The following variables are supported by TkRev:

<h2>Startup</h2>

<h3>cvscfg(startwindow)</h3>
<indt>Which window you want to see on startup. (workdir or module)</indt>

<h2>CVS</h2>
<h3>cvscfg(cvsroot)</h3>
<indt>If set, it overrides the CVSROOT environment variable.</indt>

<h2>Subversion</h2>
If your SVN repository has a structure similar to trunk, branches, and tags but with different names, you can tell TkRev about it by setting variables in tkrev_def.tcl:
    set cvscfg(svn_trunkdir) "elephants"
    set cvscfg(svn_branchdir) "dogs"
    set cvscfg(svn_tagdir) "ducklings"
    The branch browser depends on the convention of having a trunk, branches, and tags structure to draw the diagram. These variables may give you a little more flexibility.

<h2>GIT</h2>
<h3>cvscfg(gitdetail)</h3>
<indt>Set to true or false. If it's false (off) an individual Git log call to each file will be suppressed to save time. You won't see the hashtag or committer in that case.</indt>

<h3>cvscfg(gitmaxhist)</h3>
<indt>For the branch visualizer. Tells how far back into the history to go. Default is 250 commits.</indt>

<h2>GUI</h2>

Most colors and fonts can be customized by using the options database. For example, you can add lines like these to your .tkrev file:
    <cmp>   option add *Canvas.background #c3c3c3 </cmp>
    <cmp>   option add *Menu.background #c3c3c3 </cmp>
    <cmp>   option add *selectColor #ffec8b </cmp>
    <cmp>   option add *Text.background gray92 </cmp>
    <cmp>   option add *Entry.background gray92 </cmp>
    <cmp>   option add *Listbox.background gray92 </cmp>
    <cmp>   option add *ToolTip.background LightGoldenrod1 </cmp>
    <cmp>   option add *ToolTip.foreground black </cmp>

<h3>cvscfg(picklist_items)</h3>
<indt>Maximum number of visited directories and repositories to save in the picklist history</indt>

<h2>Log browser</h2>

<h3>cvscfg(colourA), cvscfg(colourB)</h3>
<indt>Hilight colours for revision-log boxes</indt>

<h3>cvscfg(tagdepth)</h3>
<indt>Number of tags you want to see for each revision on the branching diagram before it says "more..." and offers a pop-up to show the rest</indt>

<h3>cvscfg(toomany_tags)</h3>
<indt>Maximum number of tags in a Subversion repository to process and display</indt>

<h3>cvscfg(tagcolour,tagstring)</h3>
<indt>Colors for marking tags. For example:
<cmp>set cvscfg(tagcolour,tkcvs_r6) Purple</cmp></indt>

<h2>Module browser</h2>

<h3>cvscfg(aliasfolder)</h3>
<indt>In the CVS module browser, if true this will cause the alias modules to be grouped in one folder. Cleans up clutter if there are a lot of aliases.</indt>

<h2>User preferences</h2>

<h3>cvscfg(allfiles)</h3>
<indt>Set this to false to see normal files only in the directory browser. Set it to true to see all files including hidden files.</indt>

<h3>cvscfg(auto_status)</h3>
<indt>Set the default for automatic status-refresh of a CVS controlled directory. Automatic updates are done when a directory is entered and after some operations.</indt>

<h3>cvscfg(auto_tag)</h3>
<indt>Whether to tag the merged-from revision when using TkRev to merge different revisions of files by default. A dialog still lets you change your mind, regardless of the default.</indt>

<h3>cvscfg(confirm_prompt)</h3>
<indt>Ask for confirmation before performing an operation(true or false)</indt>

<h3>cvscfg(dateformat)</h3>
<indt>Format for the date string shown in the "Date" column, for example "%Y/%m/%d %H:%M"</indt>

<h3>cvscfg(cvslock)</h3>
<indt>Set to true to turn on the ability to use cvs-admin locking from the GUI.</indt>

<h3>cvscfg(econtrol)</h3>
<indt>Set this to true to turn on the ability to use CVS Edit and Unedit, if your site is configured to allow the feature.</indt>

<h3>cvscfg(editor)</h3>
<indt>Preferred default editor</indt>

<h3>cvscfg(editors)</h3>
<indt>String pairs giving the editor-command and string-match-pattern, for deciding which editor to use</indt>

<h3>cvscfg(editorargs)</h3>
<indt>Command-line arguments to send to the default editing program.</indt>

<h3>cvscfg(mergetoformat), cvscfg(mergefromformat)</h3>
<indt>Format for mergeto- and mergefrom- tags. The _BRANCH_ part must be left as-is, but you can change the prefix and the date format, for example "mergeto_BRANCH_%d%b%y". The date format must be the same for both. CVS rule: a tag must not contain the characters `$,.:;@'</indt>

<h3>cvscfg(recurse)</h3>
<indt>Whether reports are recursive (true or false)</indt>

<h3>cvscfg(savelines)</h3>
<indt>How many lines to keep in the trace window</indt>

<h3>cvscfg(status_filter)</h3>
<indt>Filter out unknown files (status "?") from CVS Check and CVS Update reports.</indt>

<h3>cvscfg(use_cvseditor)</h3>
<indt>Let CVS invoke an editor for commit log messages rather than having tkrev use its own input box. By doing this, your site's commit template (rcsinfo) can be used.</indt>

<h2>File filters</h2>

<h3>cvscfg(show_file_filter)</h3>
<indt>Pattern for which files to list. Empty string is equivalent to the entire directory (minus hidden files)</indt>

<h3>cvscfg(ignore_file_filter)</h3>
<indt>Pattern used in the workdir filter for files to be ignored</indt>

<h3>cvscfg(clean_these)</h3>
<indt>Pattern to be used for cleaning a directory (removing unwanted files)</indt>

<h2>System</h2>
<h3>cvscfg(print_cmd)</h3>
<indt>System command used for printing. lpr, enscript -Ghr, etc)</indt>

<h3>cvscfg(shell)</h3>
<indt>What you want to happen when you ask for a shell</indt>

<h3>cvscfg(terminal)</h3>
<indt>Command prefix to use to run something in a terminal window</indt>

<h2>Portability</h2>
<h3>cvscfg(aster)</h3>
<indt>File mask for all files (* for Unix, *.* for windows)</indt>

<h3>cvscfg(null)</h3>
<indt>The null device. /dev/null for Unix, nul for windows</indt>

<h3>cvscfg(tkdiff)</h3>
<indt>How to start tkdiff. Example sh /usr/local/bin/tkdiff</indt>

<h3>cvscfg(tmpdir)</h3>
<indt>Directory in which to do behind-the-scenes checkouts. Usually /tmp or /var/tmp)</indt>

<h2>Debugging</h2>

<h3>cvscfg(log_classes)</h3>
<indt>For debugging: C=CVS commands, E=CVS stderr output, F=File creation/deletion, T=Function entry/exit tracing, D=Debugging</indt>

<h3>cvscfg(logging)</h3>
<indt>Logging (debugging) on or off</indt>
  }

  if {$manpage ne ""} {
    puts $manpage ".SH FILES"
    put_text $help_body $manpage
  } else {
    clear_text $wn
    post_text $wn "<h1>$title</h1>\n"
    post_text $wn $help_body
  }
}
# End man_configuration_files

proc man_environment_variables {wn title {manpage {}} } {
  gen_log:log T "ENTER ($wn $title)"

  set help_body {
You should have the CVSROOT environment variable pointing to the location of your CVS repository before you run TkRev. It will still allow you to work with different repositories within the same session.

If you wish TkRev to point to a Subversion repository by default, you can set the environment variable SVNROOT. This has no meaning to Subversion itself, but it will clue TkRev if it's started in an un-versioned directory.
  }

  if {$manpage ne ""} {
    puts $manpage ".SH ENVIRONMENT"
    put_text $help_body $manpage
  } else {
    clear_text $wn
    post_text $wn "<h1>$title</h1>\n"
    post_text $wn $help_body
  }
}
# End man_environment_variables

proc man_user_defined_menu {wn title {manpage {}} } {
  gen_log:log T "ENTER ($wn $title)"

  set help_body_1 {
It is possible to extend the TkRev menu by inserting additional commands into the .tkrev or tkrev_def.tcl files. These extensions appear on an extra menu to the right of the TkRev Options menu.

To create new menu entries on the user-defined menu, set the following variables:

<h3>cvsmenu(command)</h3>
<indt>Setting a variable with this name to a value like "commandname" causes the CVS command "cvs commandname" to be run when this menu option is selected. For example, the following line:
<cmp>set cvsmenu(update_A) "update -A"</cmp>

Causes a new menu option titled "update_A" to be added to the user defined menu that will run the command "cvs update -A" on the selected files when it is activated.

(This example command, for versions of CVS later than 1.3, will force an update to the head version of a file, ignoring any sticky tags or versions attached to the file).</indt>

<h3>usermenu(command)</h3>
<indt>Setting a variable with this name to a value like "commandname" causes the command "commandname" to be run when this menu option is selected. For example, the following line:
<cmp>set usermenu(view) "cat"</cmp>

Causes a new menu option titled "view" to be added to the User defined menu that will run the command "cat" on the selected files when it is activated.</indt>
  }

set help_body_2 {
Any user-defined commands will be passed a list of file names corresponding to the files selected on the directory listing on the main menu as arguments.

The output of the user defined commands will be displayed in a window when the command is finished.
  }

  if {$manpage ne ""} {
    puts $manpage ".SH $title"
    put_text $help_body_1 $manpage
    put_text $help_body_2 $manpage
  } else {
    clear_text $wn
    post_text $wn "<h1>$title</h1>\n"
    post_text $wn $help_body_1
    post_text $wn $help_body_2
  }
}
# End man_user_defined_menu

proc man_cvs_modules_file {wn title {manpage {}} } {
  gen_log:log T "ENTER ($wn $title)"

  set help_body {
If you haven't put anything in your CVSROOT/modules file, please do so. See the "Administrative Files" section of the CVS manual. Then, you can add comments which TkRev can use to title the modules and to display them in a tree structure.

The simplest use of TkRev's "#D" directive is to display a meaningful title for the module:

    <cmp>#D      softproj        Software Development Projects</cmp>
    <cmp>softproj softproj</cmp>

A fancier use is to organize the modules into a tree which will mimic their directory nesting in the repository when they appear in the module browser. For example, suppose we have a directory called "chocolate" which is organized like this:

    <cmp>chocolate/</cmp>
    <cmp>    truffle/</cmp>
    <cmp>        cocoa3/</cmp>
    <cmp>            biter/</cmp>
    <cmp>            sniffer/</cmp>
    <cmp>            snuffler/</cmp>

To display its hierarchy, as well as make the deepest directories more accessible by giving them module names, we could put this in the modules file:

    <cmp>#D	chocolate	Top Chocolate</cmp>
    <cmp>#D	chocolate/truffle	Cocoa Level 2</cmp>
    <cmp>#D	chocolate/truffle/cocoa3	Cocoa Level 3</cmp>
    <cmp>#D	sniffer	Chocolate Sniffer</cmp>
    <cmp>sniffer	chocolate/truffle/cocoa3/sniffer</cmp>
    <cmp>#D	snuff	Chocolate Snuffler</cmp>
    <cmp>snuff	chocolate/truffle/cocoa3/snuffler</cmp>
    <cmp>#D	biter	Chocolate Biter</cmp>
    <cmp>biter	chocolate/truffle/cocoa3/biter</cmp>


When you are installing TkRev, you may like to add these additional lines to the modules file (remember to check out the modules module from the repository, and then commit it again when you have finished the edits).

These extension lines commence with a "#" character, so CVS interprets them as comments. They can be safely left in the file whether you are using TkRev or not.

"#M" is equivalent to "#D". The two had different functions in previous versions of TkRev, but now both are parsed the same way.
  }

  if {$manpage ne ""} {
    puts $manpage ".SH $title"
    put_text $help_body $manpage
  } else {
    clear_text $wn
    post_text $wn "<h1>$title</h1>\n"
    post_text $wn $help_body
  }
}
# End man_cvs_modules

