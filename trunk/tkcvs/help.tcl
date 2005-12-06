#
# Tcl Library for TkCVS
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
# If you do add something to this, do "mkmanpage.pl > tkcvs.n"
# to keep the manpage in sync, then look at it to make sure
# it worked.
#
# - dorothy
#########################################

proc aboutbox {} {
  global cvscfg

  toplevel .about
  wm title .about "About TkCVS!"

  frame .about.top

  message .about.top.msg1 -width 400 -justify c \
    -text "\nTkCVS Version 8.0\n" -font $cvscfg(guifont)
  pack .about.top -side top -expand 1 -fill both

  image create photo Tclfish -format gif -file \
    [file join $cvscfg(bitmapdir) ticklefish_med.gif]
  label .about.top.gif1 -image Tclfish
  image create photo Anglerfish -format gif -file \
    [file join $cvscfg(bitmapdir) anglerfish_med.gif]
  label .about.top.gif2 -image Anglerfish

  append string1 "A friendly interface to CVS\n"
  append string1 "and Subversion.\n"

  message .about.top.msg2 -width 400 -justify c \
    -text $string1

  append string2 "\nConsult the Help menu to\n"
  append string2 "learn about its features.\n\n"
  append string2 "TkCVS was written by Del.\n"

  message .about.top.msg3 -width 400 -justify c \
    -text $string2

  append about_string "Home page: http://www.twobarleycorns.net/tkcvs.html\n"
  append about_string "Source code: http://sourceforge.net/projects/tkcvs/\n"

  message .about.top.msg4 -width 365 -justify c \
    -text $about_string -font $cvscfg(listboxfont)

  pack .about.top -side top -expand 1 -fill both
  pack .about.top.msg1 -expand 1 -fill x
  pack .about.top.gif1
  pack .about.top.msg2 -expand 1 -fill x
  pack .about.top.gif2
  pack .about.top.msg3 -expand 1 -fill x
  pack .about.top.msg4 -expand 1 -fill x

  frame .about.down
  button .about.down.ok -text "OK" -command {destroy .about}

  pack .about.down -side bottom -expand 1 -fill x -pady 2
  pack .about.down.ok
}

proc cvs_version {} {
#
# This shows CVS banner.
#
  global cvs
  global cvscfg

  gen_log:log T "ENTER"
  set v [viewer::new "Versions"]

  $v\::log "\n-----------------------------------------"
  set commandline "$cvs -v"
  set ret [catch {eval "exec $commandline"} output]
  $v\::log $output

  $v\::log "\n-----------------------------------------\n"
  set commandline "svn --version"
  set ret [catch {eval "exec $commandline"} output]
  $v\::log $output

  $v\::log "\n-----------------------------------------\n"
  set commandline "rcs -V"
  set ret [catch {eval "exec $commandline"} output]
  $v\::log $output
  $v\::log "\nIf you see a usage message here, you have"
  $v\::log " an old version of RCS.  It should still work.\n"

  gen_log:log T "LEAVE"
}

proc wish_version {{parent {.}}} {
  global tk_version

  set version $tk_version
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
# ARE DISCLAIMED.  IN NO EVENT SHALL JOHN HEIDEMANN BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
######################################################################

proc put-text {tw txt} {

    gen_log:log T "ENTER ($tw ...)"
    $tw configure -font -*-Times-Medium-R-Normal-*-14-*

    $tw tag configure bld -font -*-Times-Bold-R-Normal-*-14-*
    $tw tag configure cmp -font -*-Courier-Medium-R-Normal-*-12-*
    $tw tag configure h1 -font -*-Helvetica-Bold-R-Normal-*-18-* -underline 1
    $tw tag configure h2 -font -*-Helvetica-Bold-R-Normal-*-18-*
    $tw tag configure h3 -font -*-Helvetica-Bold-R-Normal-*-14-*
    $tw tag configure itl -font -*-Times-Medium-I-Normal-*-14-*
    $tw tag configure rev -foreground white -background black

    $tw tag configure btn \
            -font -*-Courier-Medium-R-Normal-*-12-* \
            -foreground black -background white \
            -relief groove -borderwidth 2

    $tw mark set insert 0.0

    set t $txt

    while {[regexp -indices {<([^@>]*)>} $t match inds] == 1} {

        set start [lindex $inds 0]
        set end [lindex $inds 1]
        set keyword [string range $t $start $end]

        set oldend [$tw index end]

        $tw insert end [string range $t 0 [expr {$start - 2}]]

        purge-all-tags $tw $oldend insert

        if {[string range $keyword 0 0] == "/"} {
            set keyword [string trimleft $keyword "/"]
            if {[info exists tags($keyword)] == 0} {
                error "end tag $keyword without beginning"
            }
            #gen_log:log D "$tw tag add $keyword $tags($keyword) insert"
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

    set oldend [$tw index end]
    $tw insert end $t
    purge-all-tags $tw $oldend insert
    gen_log:log T "LEAVE"
}

proc purge-all-tags {w start end} {
    foreach tag [$w tag names $start] {
        $w tag remove $tag $start $end
    }
}

######################################################################
#
# End of text formatting routines.
#
######################################################################

proc do_help {title helptext} {
  global cvscfg
  global tcl_platform

  gen_log:log T "ENTER $title <helptext suppressed>)"
  static {helpviewer 0}

  incr helpviewer
  set cvshelpview ".cvshelpview$helpviewer"
  toplevel $cvshelpview
  text $cvshelpview.text -setgrid yes -wrap word \
    -width 55 -relief sunken -border 2 \
    -yscroll "$cvshelpview.scroll set"
  scrollbar $cvshelpview.scroll -relief sunken \
    -command "$cvshelpview.text yview"
  button $cvshelpview.close -text "Close" \
    -command "destroy $cvshelpview; exit_cleanup 0"

  pack $cvshelpview.close -side bottom
  pack $cvshelpview.scroll -side right -fill y
  pack $cvshelpview.text -fill both -expand 1

  wm title $cvshelpview "$title Help"
  if {$tcl_platform(platform) != "windows"} {
    wm iconbitmap $cvshelpview @$cvscfg(bitmapdir)/tkcvs-help.xbm
  }
  wm minsize $cvshelpview 1 1

  put-text $cvshelpview.text $helptext
  gen_log:log T "LEAVE"
}

# This is here for the manpage. We don't call it from tkcvs.
proc man_description {} {

  do_help "Description" {

<h1>DESCRIPTION</h1>

TkCVS is a Tcl/Tk-based graphical interface to the CVS and Subversion configuration management systems. It displays the status of the files in the current working directory, and provides buttons and menus to execute configuration-management commands on the selected files. Limited RCS functionality is also present.  TkDiff is bundled in for browsing and merging your changes.

TkCVS also aids in browsing the repository. For Subversion, the repository tree is browsed like an ordinary file tree.  For CVS, the CVSROOT/modules file is read.  TkCVS extends CVS with a method to produce a browsable, "user friendly" listing of modules. This requires special comments in the CVSROOT/modules file. See "CVS Modules File" for more guidance.
  }
}

#
# Help procedures for the TkCVS users guide.
#

proc cli_options {} {

  do_help "Command Line Options" {

<h1>OPTIONS</h1>

TkCVS accepts the following options.

<h3>-dir</h3> <itl>directory</itl>
Start TkCVS in the specified directory.

<h3>-help</h3>
Print a usage message.

<h3>-log</h3> <itl>file</itl>
Invoke a log browser for the specified file. -log and -win are mutually exclusive.

<h3>-root</h3> <itl>cvsroot</itl>
Set $CVSROOT to the specified repository.

<h3>-win</h3>  <itl>workdir|module|merge</itl>
Start by displaying the directory browser (the default), the module browser, or the directory-merge tool. -win and -log are mutually exclusive.

<h1>Examples</h1>
<cmp>% tkcvs -win module -root /jaz/repository</cmp>
Browse the modules located in CVSROOT /jaz/repository 
<cmp>% tkcvs -log tstheap.c</cmp>
View the log of the file tstheap.c
  }
}

proc current_directory {} {

  do_help "Current Directory" {

<h1>Working Directory Browser</h1>

The working directory browser shows the files in your local working copy, or "sandbox."  It shows the status of the files at a glance and provides tools to help with most of the common CVS, SVN, and RCS operations you might do.

At the top of the browser you will find:
*  The name of the current directory. You can change directories by typing in this field. Recently visited directories are saved in the picklist.

*  The relative path of the current directory in the repository. If it is not contained in the repository you may import it using the menu or toolbar button.

*  A Directory Tag name, if the directory is contained in the repository and it has been checked out against a particular branch or tag.  In Subversion, the branch or tag is inferred from the URL based on the conventional trunk-branches-tags repository organization.

*  The CVSROOT of the current directory if it's under CVS control, or the URL of the Subversion repository if it's under Subversion control.  If neither is true, it may default to the value of the $CVSROOT environment variable.

The main part of the working directory browser is a list of the files in the current directory with an icon next to each showing its status. You select a file by clicking on its name or icon once with the left mouse button. Holding the Control key while clicking will add the file to the group of those already selected. You can select a contiguous group of files by holding the Shift key while clicking. You can also select a group of files by dragging the mouse with the middle or right button pressed to select an area. Selecting an item that's already selected de-selects that item. To unselect all files, click the left mouse button in an empty area of the file list.

*  The Date column (can be hidden) shows the modification time of the file is shown. The format of the date column may be specified with cvscfg(dateformat). The default format was chosen because it sorts the same way alphabetically as chronologically.

If the directory belongs to a revision system, other columns are present.

* The revision column shows which revision of the file is checked out, and whether it's on the trunk or on a branch.

*  The status column (can be hidden) shows the revision of the file spelled out in text.  This information is mostly redundant to the icon in the file column.

*  The Editor/Author/Locker column (can be hidden) varies according to revision system. In Subversion, the author of the most recent checkin is shown.  In CVS, it shows a list of people editing the files if your site uses "cvs watch" and/or "cvs edit". Otherwise, it will be empty.  In RCS, it shows who, if anyone, has the file locked.

The optional columns can be displayed or hidden using the Options menu.

You can move into a directory by double-clicking on it.

Double clicking on a file will load the file into a suitable editor so you can change it. A different editor can be used for different file types (see Configuration Files).

<h2>File Status</h2>

When you are in a directory that is under CVS or Subversion control, the file status will be shown by an icon next to each file. Checking the "Status Column" option causes the status to be displayed in text in its own column. Some possible statuses are:

<h3>Up-to-date</h3>
The file is up to date with respect to the repository.

<h3>Locally Modified</h3>
The file has been modified in the current directory since being checked out of the repository.

<h3>Locally Added</h3>
The file has been added to the repository. This file will become permanent in the repository once a commit is made.

<h3>Locally Removed</h3>
You have removed the file with remove, and not yet committed your changes.

<h3>Needs Checkout</h3>
Someone else has committed a newer revision to the repository. The name is slightly misleading; you will ordinarily use update rather than checkout to get that newer revision.

<h3>Needs Patch</h3>
Like Needs Checkout, but the CVS server will send a patch rather than the entire file. Sending a patch or sending an entire file accomplishes the same thing.

<h3>Needs Merge</h3>
Someone else has committed a newer revision to the repository, and you have also made modifications to the file.

<h3>Unresolved Conflict</h3>
This is like Locally Modified, except that a previous update command gave a conflict. You need to resolve the conflict before checking in.

<h3>?</h3>
The file is not contained in the repository. You may need to add the file to the repository by pressing the "Add" button.

<h3>[directory:CVS]</h3>
A directory which has been checked out from a CVS repository.

<h3>[directory:SVN]</h3>
The file is a directory which has been checked out from a Subversion repository.  In Subversion, directories are themselves versioned objects.

<h3>[directory:RCS]</h3>
A directory which contains an RCS sub-directory or some files with the ,v suffix, presumably containing some files that are under RCS revision control.

<h3>[directory]</h3>
The file is a directory.

<h2>File Filters</h2>

You can specify file matching patterns to instruct TkCVS which files you wish to see. You can also specify patterns telling it which files to remove when you press the "Clean" button or select the <bld>File->Cleanup</bld> menu item.

"Hide" works exactly the way a .cvsignore file works. That is, it causes non-CVS files with the pattern to be ignored. It's meant for hiding .o files and such. Any file under CVS control will be listed anyway.

"Show" is the inverse. It hides non-CVS files except for those with the pattern.

<h2>Buttons</h2>

<itl>Module Browser:</itl>
The big button at the upper right opens the module browser.
Opens a module browser window which will enable you to explore items in the repository even if they're not checked out.  In CVS, this requires that there be entries in the CVSROOT/modules file.  Browsing can be improved by using TkCVS-specific comments in CVSROOT/modules.

<itl>Go Up:</itl>
The button to the left of the entry that shows the current directory. Press it and you go up one level.

There are a number of buttons at the bottom of the window. Pressing on one of these causes the following actions:

<itl>Delete:</itl>
Press this button to delete the selected files. The files will not be removed from the repository. To remove the files from the repository as well as delete them, press the "Remove" button instead.


<itl>Edit:</itl>
Press this button to load the selected files in to an appropriate editor.

<itl>View:</itl>
Press this button to view the selected files in a Tk text window. This can be a lot faster then Edit, in case your preferred editor is xemacs or something of that magnitude.

<itl>Refresh:</itl>
Press this button to re-read the current directory, in case the status of some files may have changed.

<itl>Status Check:</itl>
Shows, in a searchable text window, the status of all the files. By default, it is recursive and lists unknown (?) files. These can be changed in the Options menu.


<itl>Directory Branch Browse:</itl>
For merging the entire directory. In Subversion, it opens the Branch Browser for "."  In CVS, it chooses a "representative" file in the current directory and opens a graphical tool for directory merges.

<itl>Log (Branch) Browse:</itl>
This button will bring up the log browser window for each of the selected files in the window. See the Log Browser section

<itl>Annotate:</itl>
This displays a window in which the selected file is shown with the lines highlighted according to when and by whom they were last revised.  In Subversion, it's also called "blame." 

<itl>Diff:</itl>
This compares the selected files with the equivalent files in the repository. A separate program called "TkDiff" (also supplied with TkCVS) is used to do this. For more information on TkDiff, see TkDiff's help menu.

<itl>Merge Conflict:</itl>
If a file's status says "Needs Merge", "Conflict", or is marked with a "C" in CVS Check, there was a difference which CVS needs help to reconcile. This button invokes TkDiff with the -conflict option, opening a merge window to help you merge the differences.

<itl>Check In:</itl>
This button commits your changes to the repository. This includes adding new files and removing deleted files. When you press this button, a dialog will appear asking you for the version number of the files you want to commit, and a comment. You need only enter a version number if you want to bring the files in the repository up to the next major version number. For example, if a file is version 1.10, and you do not enter a version number, it will be checked in as version 1.11. If you enter the version number 3, then it will be checked in as version 3.0 instead.  It is usually better to use symbolic tags for that purpose.
If you use rcsinfo to supply a template for the comment, you must use an external editor.  Set cvscfg(use_cvseditor) to do this. For checking in to RCS, an externel editor is always used.

<itl>Update:</itl>
This updates your sandbox directory with any changes committed to the repository by other developers.

<itl>Update with Options:</itl>
Allows you to update from a different branch, with a tag, with empty directories, and so on.

<itl>Add Files:</itl>
Press this button when you want to add new files to the repository. You must create the file before adding it to the repository. To add some files, select them and press the Add Files button. The files that you have added to the repository will be committed next time you press the Check In button. It is not recursive. Use the menu CVS -> Add Recursively for that.

<itl>Remove Files:</itl>
This button will remove files. To remove files, select them and press the Remove button. The files will disappear from the directory, and will be removed from the repository next time you press the Check In button. It is not recursive. Use the menu CVS -> Remove Recursively for that. 

<itl>Tag:</itl>
This button will tag the selected files. In CVS, the -F (force) option will move the tag if it already exists on the file.

<itl>Branch Tag:</itl>
This button will tag the selected files, creating a branch. In CVS, the -F (force) option will move the tag if it already exists on the file.

<itl>Lock (CVS and RCS):</itl>
Lock an RCS file for editing.  If cvscfg(cvslock) is set, lock a CVS file.  Use of locking is philosophically discouraged in CVS since it's against the "concurrent" part of Concurrent Versioning System, but locking policy is nevertheless used at some sites.  One size doesn't fit all.

<itl>Unlock (CVS and RCS):</itl>
Unlock an RCS file.  If cvscfg(cvslock) is set, unlock a CVS file.

<itl>Set Edit Flag (CVS):</itl>
This button sets the edit flag on the selected files, enabling other developers to see that you are currently editing those files (See "cvs edit" in the CVS documentation).

<itl>Reset Edit Flag (CVS):</itl>
This button resets the edit flag on the selected files, enabling other developers to see that you are no longer editing those files (See "cvs edit" in the CVS documentation). As the current version of cvs waits on a prompt for "cvs unedit" if changes have been made to the file in question (to ask if you want to revert the changes to the current revision), the current action of tkcvs is to abort the unedit (by piping in nothing to stdin). Therefore, to lose the changes and revert to the current revision, it is necessary to delete the file and do an update (this will also clear the edit flag). To keep the changes, make a copy of the file, delete the original, update, and then move the saved copy back to the original filename.

<itl>Close:</itl>
Press this button to close the Current Directory Browser. If no other windows are open, TkCVS exits.
  }
}

proc log_browser {} {

  do_help "Log (Branch) Browser" {

<h1>Log (Branch) Browser</h1>

The TkCVS Log Browser window enables you to view a graphical display of the revision log of a file, including all previous versions and any branched versions.

You can get to the log browser window in three ways, either by invoking it directly with "tkcvs -log <filename>", by selecting a file within the main window of TkCVS and pressing the Log Browse button, or by selecting a file in a list invoked from the module browser and pressing the Log Browse button.

If the Log Browser is examining a checked-out file, the buttons for performing merge operations are enabled.

<h2>Log Browser Window</h2>

The log browser window has three components. These are the file name and version information section at the top, the log display in the middle, and a row of buttons along the bottom.

<h2>Log Display</h2>

The main log display is fairly self explanatory. It shows a group of boxes connected by lines indicating the main trunk of the file development (on the left hand side) and any branches that the file has (which spread out to the right of the main trunk).

Each box contains the version number, author of the version, and other information determined by the menu View -> Revision Layout.

<h2>Version Numbers</h2>

Once a file is loaded into the log browser, one or two version numbers may be selected. The primary version (Selection A) is selected by clicking the left mouse button on a version box in the main log display.

The secondary version (Selection B) is selected by clicking the right mouse button on a version box in the main log display.

Operations such as "View" and "Annotate" operate only on the primary version selected.

Operations such as "Diff" and "Merge Changes to Current" require two versions to be selected.

<h2>Log Browser Buttons</h2>

The log browser contains the following buttons:

<itl>Refresh:</itl>
Re-reads the revision history of the file.

<itl>View:</itl>
Pressing this button displays a Tk text window containing the version of the file at Selection A.

<itl>Annotate:</itl>
This displays a window in which the file is shown with its lines highlighted according to when and by whom they were last revised.  In Subversion, it's also called "blame." 

<itl>Diff:</itl>
Pressing this button runs the "tkdiff" program to display the differences between version A and version B.

<itl>Merge:</itl>
To use this button, select a branch version of the file, other than the branch you are currently on, as the primary version (Selection A). The changes made along the branch up to that version will be merged into the current version, and stored in the current directory. Optionally, select another version (Selection B) and the changes will be from that point rather than from the base of the branch.  The version of the file in the current directory will be merged, but no commit will occur.  Then you inspect the merged files, correct any conflicts which may occur, and commit when you are satisfied.  Optionally, TkCVS will tag the version that the merge is from.  It suggests a tag of the form "mergefrom_<rev>_date."  If you use this auto-tagging function, another dialog containing a suggested tag for the merged-to version will appear.  It's suggested to leave the dialog up until you are finished, then copy-and-paste the suggested tag into the "Tag" dialog.  It is always a good practice to tag when doing merges, and if you use tags of the suggested form, the Branch Browser can diagram them. (Auto-tagging is not implemented in Subversion because, despite the fact that tags are "cheap," it's somewhat impractical to auto-tag single files.  You can do the tagging manually, however.)

<itl>View Tags:</itl>
This button lists all the tags applied to the file in a searchable text window.

<itl>Close:</itl>
This button closes the Log Browser. If no other windows are open, TkCVS exits.

<h2>The View Options Menu</h2>
The View Menu allows you to control what you see in the branch diagram.  You can choose how much information to show in the boxes, whether to show empty revisions, and whether to show tags.  You can even control the size of the boxes.  If you are using Subversion, you may wish to turn the display of tags off.  If they aren't asked for they won't be read from the repository, which can save a lot of time.
  }
}

proc directory_branch_viewer {} {

  do_help "CVS Merge Tool" {

<h1>Merge Tool for CVS</h1>

The Merge Tool chooses a "representative" file in the current directory and diagrams the branch tags. It tries to pick the "bushiest" file, or failing that, the most-revised file. If you disagree with its choice, you can type the name of another file in the top entry and press Return to diagram that file instead.

The main purpose of this tool is to do merges (cvs update -j rev [-j rev]) on the whole directory. For merging one file at a time, you should use the Log Browser. You can only merge to the line (trunk or branch) that you are currently on. Select a branch to merge from by clicking on it. Then press either the "Merge" or "Merge Changes" button. The version of the file in the current directory will be over-written, but it will not be committed to the repository. You do that after you've reconciled conflicts and decided if it's what you really want.

<itl>Merge Branch to Current:</itl>
The changes made on the branch since its beginning will be merged into the current version.

<itl>Merge Changes to Current:</itl>
Instead of merging from the base of the branch, this button merges the changes that were made since a particular version on the branch. It pops up a dialog in which you fill in the version. It should usually be the version that was last merged.
  }
}

proc module_browser {} {

  do_help "Repository Browser" {

<h1>Module Browser</h1>

Most of the file-related actions of TkCVS are performed within the current-directory window. The module-related actions are performed within the module browser. The module browser can be started from the command line (tkcvs -win moduile) or started from the main window by pressing the big button.

TkCVS arranges CVS modules into directories and subdirectories in a tree structure. You can navigate through the module tree using the module browser window.

Using the module browser window, you can select a module to check out. When you check out a module, a new directory is created in the current working directory with the same name as the module.

<h2>Tagging and Branching (cvs rtag)</h2>

You can tag particular versions of a module or file in the repository, with plain or branch tags, without having the module checked out.

<h2>Exporting</h2>

Once a software release has been tagged, you can use a special type of check out called an export. This allows you to more cleanly check out files from the repository,  without all of the administrivia that CVS needs to have while working on the files. It is useful for delivery of a software release to a customer.

<h2>Importing</h2>

TkCVS contains a special dialog to allow users to import new files into the repository. In CVS, new modules can be assigned places within the repository, as well as descriptive names (so that other people know what they are for).

When the Module Browser displays a CVS repository, the first column is a tree showing the module codes and directory names of all of the items in the repository. The icon shows whether the item is a directory (which may contain other directories or modules), or whether it is a module (which may be checked out from TkCVS). It is possible for an item to be both a module and a directory. If it has a red ball on it, you can check it out. If it shows a plain folder icon, you have to open the folder to get to the items that you can check out.

To select a module, click on it with the left mouse button. Only one module can be selected at a time. To clear the selection, click on the item again or click in an empty area of the module column.

The second column shows descriptive titles of the items in the repository, if you have added descriptions to the CVS modules file with the #M syntax.

In Subversion, the repository is browsed directly, like an ordinary file tree, with no extra work about modules.

<h2>Repository Browser Buttons</h2>

The module browser contains the following buttons:

<itl>Who:</itl>
Shows which modules are checked out by whom.

<itl>Import:</itl>
This item will import the contents of the current directory (the one shown in the Current Directory Display) into the repository as a module. See the section titled Importing for more information.

<itl>File Browse:</itl>
Displays a list of the selected module's files. From the file list, you can view the file, browse its revision history, or see a list of its tags.

<itl>Check Out:</itl>
Checks out the current version of a module. A dialog allows you to specify a tag, change the destination, and so on.

<itl>Export:</itl>
Exports the current version of a module. A dialog allows you to specify a tag, change the destination, and so on. Export is similar to check-out, except exported directories do not contain the CVS or administrative directories, and are therefore cleaner (but cannot be used for checking files back in to the repository). You must supply a tag name when you are exporting a module to make sure you can reproduce the exported files at a later date.

<itl>Tag:</itl>
This button tags an entire module.

<itl>Branch Tag:</itl>
This creates a branch of a module by giving it a branch tag.

<itl>Patch Summary:</itl>
This item displays a short summary of the differences between two versions of a module.

<itl>Create Patch File:</itl>
This item creates a Larry Wall format patch(1) file of the module selected.

<itl>Close:</itl>
This button closes the Repository Browser. If no other windows are open, TkCVS exits.
  }
}

proc importing_new_modules {} {

  do_help "Importing" {

<h1>Importing New Modules</h1>

Before importing a new module, first check to make sure that you have write permission to the repository. Also you'll have to make sure the module name is not already in use.

To import a module you first need a directory where the module is located. Make sure that there is nothing in this directory except the files that you want to import.

Press the big "Repository Browser" button in the top part of the tkcvs UI, or use CVS -> Import WD into Repository from the menu bar.

In the module browser, press the Import button on the bottom, the one that shows a folder and an up arrow.

In the dialog that pops up, fill in a descriptive title for the module.  This will be what you see in the right side of the module browser.

OK the dialog.  Several things happen now.  The directory is imported, the CVSROOT/module file is updated, your original directory is saved as directory.orig, and the newly created module is checked out.

When it finishes, you should find the original Working Directory Browser showing the files in the newly created, checked out module.

Here is a more detailed description of the fields in the Import Dialog.

<itl>Module Name:</itl>
A name for the module.  This name must not already exist in the repository. Your organization could settle on a single unambiguous code for modules. One possibility is something like:

<cmp>    [project code]-[subsystem code]-[module code]</cmp>

<itl>Module Path:</itl>
The location in the repository tree where your new module will go.

<itl>Descriptive Title:</itl>
A one-line descriptive title for your module.  This will be displayed in the right-hand column of the browser.

<itl>Version Number:</itl>
The current version number of the module. This should be a number of the form X.Y.Z where .Y and .Z are optional. You can leave this blank, in which case 1 will be used as the first version number.

Importing a directory into Subversion is similar but not so complicated.  You use the SVN -> Import CWD into Repository menu.  You need supply only the path in the repository where you want the directory to go.  The repository must be prepared and the path must exist, however.
  }
}

proc importing_to_existing_module {} {

  do_help "Importing To An Existing Module" {

<h1>Importing to an Existing Module (CVS)</h1>

Before importing to an existing module, first check to make sure that you have write permission to the repository.

To import to an existing module you first need a directory where the code is located. Make sure that there is nothing in this directory (including no CVS directory) except the files that you want to import.

Open up the Repository Browser by selecting File/Browse Modules from the menu bar.

In the Repository Browser, select File/Import To An Existing Module from the menu bar.

In the dialog that pops up, press the Browse button and select the name of an existing module. Press the OK to close this dialog box. Enter the version number of the code to be imported. 

OK the dialog.  Several things happen now.  The directory is imported, your original directory is saved as directory.orig, and the newly created module is checked out.

When it finishes, you will find the original Working Directory Browser showing the original code. If you press the "Re-read the current directory" button you will see the results of the checked out code.

Here is a more detailed description of the fields in the Import Dialog.

<itl>Module Name:</itl>
A name for the existing module. Filled in by the use of the the Browse button

<itl>Module Path:</itl>
The location in the repository tree where the existing module is. Filled in by the use of the Browse button. 

<itl>Version Number:</itl>
The current version number of the module to be imported. This should be a number of the form X.Y.Z where .Y and .Z are optional. You can leave this blank, in which case 1 will be used as the first version number.
  }
}

proc vendor_merge {} {

  do_help "Vendor Merge" {

<h1>Vendor Merge (CVS)</h1>

Software development is sometimes based on source distribution from a vendor or third-party distributor. After building a local version of this distribution, merging or tracking the vendor's future release into the local version of the distribution can be done with the vendor merge command.

The vendor merge command assumes that a separate module has already been defined for the vendor or third-party distribution with the use of the "Import To A New Module" and "Import To An Existing Module" commands. It also assumes that a separate module has already been defined for the local code for which the vendor merge operation is to be applied to.

Start from an empty directory and invoke tkcvs. Open up the Repository Browser by selecting File/Browse Modules from the menu bar.

Checkout the module of the local code to be merged with changes from the vendor module. (Use the red icon with the down arrow)

In the Repository Browser, after verifying that the Module entry box still has the name the module of the local code to which the vendor code is to be merged into, select File/Vendor Merge from the menu bar.

In the Module Level Merge With Vendor Code window, press the Browse button to select the module to be used as the vendor module.

OK the dialog. All revisions from the vendor module will be shown in the two scroll lists. Fill in the From and To entry boxes by clicking in the appropriate scroll lists.

Ok the dialog. Several things happens now. Several screens will appear showing the output from cvs commands for (1)checking out temp files, (2)cvs merge, and (3)cvs rdiff. Information in these screens will tell you what routines will have merge conflicts and what files are new or deleted. After perusing the files, close each screen. <itl>(In the preceeding dialog box, there was an option to save outputs from the merge and rdiff operations to files CVSmerge.out and CVSrdiff.out.)</itl>

The checked out local code will now contain changes from a merge between two revisions of the vendor modules. This code will not be checked into the repository. You can do that after you've reconciled conflicts and decide if that is what you really want. 

A detailed example on how to use the vendor merge operation is provided in the PDF file vendor5readme.pdf. 
  }
}

proc configuration_files {} {

  do_help "Configuration Files" {

<h1>Configuration Files</h1>

There are two configuration files for TkCVS. The first is stored in the directory in which the *.tcl files for TkCVS are installed. This is called tkcvs_def.tcl. You can put a file called site_def in that directory, too. That's a good place for site-specific things like tagcolours. Unlike tkcvs_def.tcl, it will not be overwritten when you install a newer version of TkCVS.

Values in the site configuration files can be over-ridden at the user level by placing a .tkcvs file in your home directory. Commands in either of these files should use Tcl syntax. In other words, to set a variable name, you should have the following command in your .tkcvs file:

<cmp>    set variablename value</cmp>

for example:
<cmp>    set cvscfg(editor) "gvim"</cmp>

The following variables are supported by TkCVS:

<h2>Startup</h2>

<h3>cvscfg(startwindow)</h3>
Which window you want to see on startup. (workdir or module)

<h3>cvscfg(cvsroot)</h3>
If set, it overrides the CVSROOT environment variable.

<h2>GUI</h2>

Most colors and fonts can be customized by using the options database. For example, you can add lines like these to your .tkcvs file:
<cmp>   option add *Canvas.background #c3c3c3 </cmp>
<cmp>   option add *Menu.background #c3c3c3 </cmp>
<cmp>   option add *selectColor #ffec8b </cmp>
<cmp>   option add *Text.background gray92 </cmp>
<cmp>   option add *Entry.background gray92 </cmp>
<cmp>   option add *Listbox.background gray92 </cmp>
<cmp>   option add *ToolTip.background LightGoldenrod1 </cmp>
<cmp>   option add *ToolTip.foreground black </cmp>

<h3>cvscfg(picklist_items)</h3>
Maximum number of visited directories and repositories to save in the picklist history

<h2>Log browser</h2>
<h3>cvscfg(colourA) cvscfg(colourB)</h3>
Hilight colours for revision-log boxes
<h3>cvscfg(tagdepth)</h3>
Number of tags you want to see for each revision on the branching diagram before it says "more..." and offers a pop-up to show the rest
<h3>cvscfg(tagcolour,tagstring)</h3>
Colors for marking tags. For example:
<cmp>    set cvscfg(tagcolour,tkcvs_r6) Purple</cmp>

<h2>Module browser</h2>
<h3>cvscfg(aliasfolder)</h3>
In the CVS module browser, if true this will cause the alias modules to be grouped in one folder. Cleans up clutter if there are a lot of aliases.

<h2>User preferences</h2>
<h3>cvscfg(allfiles)</h3>
Set this to false to see normal files only in the directory browser. Set it to true to see all files including hidden files.
<h3>cvscfg(auto_status)</h3>
Set the default for automatic status-refresh of a CVS controlled directory. Automatic updates are done when a directory is entered and after some operations.
<h3>cvscfg(auto_tag)</h3>
Whether to tag the merged-from revision when using TkCVS to merge different revisions of files by default.  A dialog still lets you change your mind, regardless of the default.
<h3>cvscfg(confirm_prompt)</h3>
Ask for confirmation before performing an operation(true or false)
<h3>cvscfg(dateformat)</h3>
Format for the date string shown in the "Date" column, for example "%Y/%m/%d %H:%M"
<h3>cvscfg(cvslock)</h3>
Set to true to turn on the ability to use cvs-admin locking from the GUI.
<h3>cvscfg(econtrol)</h3>
Set this to true to turn on the ability to use CVS Edit and Unedit, if your site is configured to allow the feature.
<h3>cvscfg(editor)</h3>
Preferred default editor
<h3>cvscfg(editors)</h3>
String pairs giving the editor-command and string-match-pattern, for deciding which editor to use
<h3>cvscfg(editorargs)</h3>
Command-line arguments to send to the default editing program.
<h3>cvscfg(ldetail)</h3>
Detail level for status reports (latest, summary, verbose)
<h3>cvscfg(mergetoformat)</h3>
<h3>cvscfg(mergefromformat)</h3>
Format for mergeto- and mergefrom- tags.  The _BRANCH_ part must be
left as-is, but you can change the prefix and the date format, for
example "mergeto_BRANCH_%d%b%y".  The date format must be the same
for both.  CVS rule: a tag must not contain the characters `$,.:;@'
<h3>cvscfg(rdetail)</h3>
Detail for repository and workdir reports (terse, summary, verbose)
<h3>cvscfg(recurse)</h3>
Whether reports are recursive (true or false)
<h3>cvscfg(savelines)</h3>
How many lines to keep in the trace window
<h3>cvscfg(status_filter)</h3>
Filter out unknown files (status "?") from CVS Check and CVS Update reports.
<h3>cvscfg(use_cvseditor)</h3>
Let CVS invoke an editor for commit log messages rather than having tkcvs use its own input box.  By doing this, your site's commit template (rcsinfo) can be used.

<h2>File filters</h2>
<h3>cvscfg(file_filter)</h3>
Pattern for which files to list. Empty string is equivalent to the entire directory (minus hidden files)
<h3>cvscfg(ignore_file_filter)</h3>
Pattern used in the workdir filter for files to be ignored
<h3>cvscfg(clean_these)</h3>
Pattern to be used for cleaning a directory (removing unwanted files)

<h2>System</h2>
<h3>cvscfg(print_cmd)</h3>
System command used for printing. lpr, enscript -Ghr, etc)
<h3>cvscfg(shell)</h3>
What you want to happen when you ask for a shell
<h3>cvscfg(terminal)</h3>
Command prefix to use to run something in a terminal window

<h2>Portability</h2>
<h3>cvscfg(aster)</h3>
File mask for all files (* for Unix, *.* for windows)
<h3>cvscfg(null)</h3>
The null device. /dev/null for Unix, nul for windows
<h3>cvscfg(tkdiff)</h3>
How to start tkdiff. Example sh /usr/local/bin/tkdiff
<h3>cvscfg(tmpdir)</h3>
Directory in which to do behind-the-scenes checkouts. Usually /tmp or /var/tmp)

<h2>Debugging</h2>
<h3>cvscfg(log_classes)</h3>
For debugging: C=CVS commands, E=CVS stderr output, F=File creation/deletion, T=Function entry/exit tracing, D=Debugging
<h3>cvscfg(logging)</h3>
Logging (debugging) on or off
  }
}

proc environment_variables {} {

  do_help "Environment Variables" {

<h1>Environment Variables</h1>

You should have the CVSROOT environment variable pointing to the location of your CVS repository before you run TkCVS. It will still allow you to work with different repositories within the same session.

If you wish TkCVS to point to a Subversion repository by default, you can set the environment variable SVNROOT.  This has no meaning to Subversion itself, but it will clue TkCVS if it's started in an un-versioned directory.
  }
}

proc user_defined_menu {} {

  do_help "User Defined Menu" {

<h1>User Configurable Menu Extensions</h1>

It is possible to extend the TkCVS menu by inserting additional commands into the .tkcvs or tkcvs_def.tcl files. These extensions appear on an extra menu to the right of the TkCVS Options menu.

To create new menu entries on the user-defined menu, set the following variables:

<h2>cvsmenu(command)</h2>

Setting a variable with this name to a value like "commandname" causes the CVS command "cvs commandname" to be run when this menu option is selected. For example, the following line:

<cmp>    set cvsmenu(update_A) "update -A"</cmp>

Causes a new menu option titled "update_A" to be added to the user defined menu that will run the command "cvs update -A" on the selected files when it is activated.

(This example command, for versions of CVS later than 1.3, will force an update to the head version of a file, ignoring any sticky tags or versions attached to the file).

<h2>usermenu(command)</h2>

Setting a variable with this name to a value like "commandname" causes the command "commandname" to be run when this menu option is selected. For example, the following line:

<cmp>    set usermenu(view) "cat"</cmp>

Causes a new menu option titled "view" to be added to the User defined menu that will run the command "cat" on the selected files when it is activated.

Any user-defined commands will be passed a list of file names corresponding to the files selected on the directory listing on the main menu as arguments.

The output of the user defined commands will be displayed in a window when the command is finished.
  }
}

proc cvs_modules_file {} {

  do_help "CVS Modules File" {

<h1>CVS Modules File</h1>

If you haven't put anything in your CVSROOT/modules file, do so. See the "Administrative Files" section of the CVS manual. Then, you can add comments which TkCVS can use to title the modules and to display them in a tree structure.

The simplest use of TkCVS's "#D" directive is to display a meaningful title for the module:

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


When you are installing TkCVS, you may like to add these additional lines to the modules file (remember to check out the modules module from the repository, and then commit it again when you have finished the edits).

These extension lines commence with a "#" character, so CVS interprets them as comments. They can be safely left in the file whether you are using TkCVS or not.

"#M" is equivalent to "#D". The two had different functions in previous versions of TkCVS, but now both are parsed the same way.
  }
}

