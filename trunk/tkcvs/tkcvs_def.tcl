# TkCVS defaults file.
#
# This file is read by TkCVS on startup.  It will be installed
# automatically by the "configure" script.
#
# Defaults in the .tkcvs file in the user's home directory will
# over-ride this file.
#

# If you want to use "cvs edit"
set cvscfg(econtrol) false
# If you want to use cvs in locking mode
set cvscfg(cvslock) false
# If you want to see the status column
set cvscfg(showstatcol) true
# If you want to see the date column
set cvscfg(showdatecol) true
# If you want to see the editors/author/lockers column
set cvscfg(showeditcol) true

# Number of tags you want to see for each revision on the branching
# diagram before it says "more..."
set cvscfg(tagdepth) 6
# Hilight colours for revision-log boxes
set cvscfg(colourA) darkgreen
set cvscfg(colourB) brown

# Maximum number of places to save in the picklist history
set cvscfg(picklist_items) 10

# If you want the module browser to come up on startup instead of the
# working-directory browser, uncomment this.
#set cvscfg(startwindow) "module"

# Colours.  "Colors" that is if you are a yanqui who can't spell.
# Added support for monochrome machines. -sj
if { [winfo depth .] == 1 } {
    option add *ToolTip.background  "white"
    option add *ToolTip.foreground  "black"
}

#
# You can either un-comment these lines or
# you can use the Xdefaults method of colouring the windows.
# The conditional at the beginning prevents over-writing CDE's
# options in case you sometimes use CDE and sometimes not.
#
#if {![string length [option get . background background]]} {
## These are subtle shades that work well in vanilla X
#  option add *Canvas.background #c3c3c3
#  option add *Menu.background #c3c3c3
#  option add *selectColor #ffec8b
#  option add *Text.background gray92
#  option add *Entry.background gray92
#  option add *Listbox.background gray92
#}

#
# To use the Xdefaults method, put lines like the following into
# your .Xdefaults or .Xresources file:
#
# tkcvs*background:			SkyBlue2
# tkcvs*activeBackground:		green
# tkcvs*Button.background:		LightSteelBlue
# tkcvs*Button.activeBackground:	green
# tkcvs*Scrollbar.background:		LightSteelBlue
# tkcvs*Scrollbar.activeBackground:	green

#
# Format of date display in workdir dialog
# The default:
#
#   %Y/%m/%d %H:%M:%S    - 2000/03/25 14:41:33
#
# is useful because it sorts properly. Other possibilities
# are:
#
#   %d/%m/%y %I:%M:%S %p   - 03/25/00 02:41:33 PM
#   %d-%b-%y %H:%M:%S      - 03-Mar-00 14:41:33
#
# Look up "date" in the tcl reference manual for a complete
# description of date formats.
#
#set cvscfg(dateformat) "%Y/%m/%d %H:%M:%S"
set cvscfg(dateformat) "%Y/%m/%d %H:%M"
# Format for mergeto- and mergefrom- tags.  The _BRANCH_ part must be
# left as-is, but you can change the prefix and the date format, for
# example "mergeto_BRANCH_%d%b%y".  The date format must be the same
# for both.
# CVS rule: a tag must not contain the characters `$,.:;@'
#set cvscfg(mergetoformat) "t_BRANCH_%d%b%y"
#set cvscfg(mergefromformat) "f_BRANCH_%d%b%y"
set cvscfg(mergetoformat) "mergeto_BRANCH_%d%b%y"
set cvscfg(mergefromformat) "mergefrom_BRANCH_%d%b%y"

# --------------------
# Revision tree log display configuration.

# Font size for tag lists and box contents (+ve = points, -ve = pixels)
set logcfg(font_size) -12

# Gaps between revisions in units of the chosen font's line spacing
# spcx = x spacing between revisions
# spcy = y spacing between revisions
# yfudge = max extra y space used to fit branch in rather than moving right
# boff = vertical offset for branch placement
set logcfg(spcx) 1
set logcfg(spcy) 1
set logcfg(yfudge) 12
set logcfg(boff) 1

# Padding between box outline and box contents in pixels
set logcfg(padx) 4
set logcfg(pady) 2

# Space between tag list and box in pixels
set logcfg(tspcb) 2

# Line and box outline width in pixels
set logcfg(width) 3

# Arrow shape for connecting lines
set logcfg(arrowshape) { 6 6.7 3 }

# Delay between a user option being changed and the redraw of the
# tree taking place. This is to allow the user chance to change
# several options at once without the tree being redrawn unecessarily.
# It's in milliseconds and something in the 1.5-3 second range is
# generally reasonable.
set logcfg(draw_delay) 2000

# Scaling options to offer user
set logcfg(scaling_options) {50% 0.5 75% 0.75 100% 1.0 150% 1.5 200% 2.0 250% 2.5}

# User options for info display
set logcfg(update_drawing) 2
set logcfg(scale) 1.0
set logcfg(show_tags) 1
set logcfg(show_merges) 1
set logcfg(show_empty_branches) 1
set logcfg(show_inter_revs) 1
set logcfg(show_root_tags) 1
set logcfg(show_root_rev) 1
set logcfg(show_box_rev) 1
set logcfg(show_box_revwho) 1
set logcfg(show_box_revdate) 1
set logcfg(show_box_revtime) 0

# --------------------
# Platform specific configuration.
#
# Decide wether you are unlucky and have to run tkcvs on DOS/WIN
# some things will be setup in the following
#
# Please note that you may have to setup a bit more.
#
if {$tcl_platform(platform) == "windows"} {
    # file mask for all files
    set cvscfg(aster) "*.*"
    # null-device
    set cvscfg(null) "nul"
    # Terminal program
    set cvscfg(terminal) "command /c"
    # Please don't ask me why you have to set -T on DOS,
    # experiments say you have! - CJ
    #set cvs "cvs -T $cvscfg(tmpdir)"
    set cvs "cvs"
    set cvscfg(editor) "notepad"
    set cvscfg(editorargs) {}

    # set temp directory
    set cvscfg(tmpdir) "c:/temp"
    set cvscfg(tkdiff) "$TclExe [file join \"[file dirname $ScriptBin] tkdiff.tcl\"]"
    set cvscfg(print_cmd)          "pr"
    set cvscfg(shell)  ""
    set cvscfg(allow_abort)  "no"
} else {
    set cvscfg(tmpdir) "/tmp"
    set cvscfg(aster) "*"
    set cvscfg(null) "/dev/null"
    # Terminal program
    set cvscfg(terminal) "xterm -e"
    #
    # Other defaults
    #
    # Full path to the CVS program if you want to give it,
    # otherwise the PATH environment variable will be searched.
    set cvs "cvs"
    # To override the default editor (setup when tkcvs is configured and
    # installed) a user can set the cvscfg(editor) variable to the editor
    # of choice in their .tkcvs file (if they have one).
    #set cvscfg(editor) "dtpad"
    set cvscfg(editor) "xterm"
    set cvscfg(editorargs) "-e vi"
    # The file editor to be used may also be identified by pattern-matching the
    # filename by setting the cvscfg(editors) variable.  This contains a series
    # of string pairs giving the editor-command and string-match-pattern.  The
    # first pattern (see rules for [string match]) which matches the filename
    # going down the list determines which editor is run.  If no patterns match
    # or the option is not set, the cvscfg(editor) value will be used instead.
    # - anj@aps.anl.gov
    #set cvscfg(editors) {
    #    nedit *.html
    #    nedit *.c
    #    bitmap *.xbm
    #    gimp *.xpm
    #    gimp *.gif
    #}
    set cvscfg(tkdiff) "tkdiff"
    #set cvscfg(print_cmd)          "enscript -Ghr -fCourier8"
    set cvscfg(print_cmd)          "lpr"
    set cvscfg(allow_abort)  "yes"
    # What do you want to happen when you ask for a shell?
    set cvscfg(shell) "xterm -name tkcvsxterm -n {TkCVS xterm}"

    # Some special stuff for MacOSX "native" Tk
    if {! [catch {set windowingsystem [tk windowingsystem]}] && $windowingsystem == "aqua"} {
      set cvscfg(editor) /Applications/TextEdit.app/Contents/MacOS/TextEdit
      set cvscfg(editorargs) {}
      # If you invoke vim this way, -psn_ tells it to run in its own window
      #set cvscfg(editor) /Applications/Vim.app/Contents/MacOS/Vim
      #set cvscfg(editorargs) -psn
      set cvscfg(shell) /Applications/Utilities/Terminal.app/Contents/MacOS/Terminal
      set cvscfg(tkdiff) "\"/Applications/TkDiff.app/Contents/MacOS/Wish Shell\""

      # We can't do the Aqua "pinstripes", but at least this helps keep
      # the UI from being completely washed out (thanks Bryan Oakley)
      option add *background #ebebeb
      option add *Canvas.background #f0f0f0
      option add *Entry.background #ffffff
    }
}

#
# --------------------
# User Menus
#
# Set any of these strings to a cvs command to add to the User Menu
   set cvsmenu(Show_My_Checkouts) "history"
   set cvsmenu(Show_All_Checkouts) "history -a"
# Set these to a shell command whose output you want to catch
#   set usermenu(show_makevars) "gmake -pn | grep '='"
# Set these to standalone programs
#   set execmenu(tkman_cvs) "tkman cvs"


#
# --------------------
# Other defaults
# These can be set and saved from the GUI.
#

# Set this to 1 to see all files displayed in the directory
# browser (including hidden files) by default.
set cvscfg(allfiles)           false

# set the default log file detail to be reported; one of
#   "latest"     latest log message on the current branch
#   "summary"    version number and comment string for all check-ins
#   "verbose"    all logfile detail possible, including symbolic tags
set cvscfg(ldetail)            "summary"

# set the default detail for repository and workdir reports; one of
#   "terse"      report "status" only and only on those files which
#                are not "up-to-date"
#   "summary"    report the "status" and include "up-to-date"
#   "verbose"    provide the report as it would appear unmodified
set cvscfg(rdetail)            "summary"

# set the default pattern to be used by the filter.  Use any valid
# pattern that can be used for a pattern for 'ls'. An empty string
# is equivalent to the entire directory (minus hidden files);
# i.e., ls *
set cvscfg(file_filter)        ""
set cvscfg(ignore_file_filter) "*.a *.o *~"
set cvscfg(clean_these)        "*.bak *~ *tmp #* *%"

# set the default for automatic statusing of a CVS controlled
# directory.  Automatic updates are done when a directory is
# entered and after some operations.
set cvscfg(auto_status)        true

# set the default value for confirmation prompting before performing an
# operation over selected files.
set cvscfg(confirm_prompt)     true

# some of the reporting operations could usefully be recursive.  Set
# the default value here.
set cvscfg(recurse)            false
# Filter out "?" unknown files from CVS Check and CVS Update reports
set cvscfg(status_filter)      false

# Kinds of messages for debugging:
#         C       CVS commands
#         F       File creation/deletion
#         T       Function entry/exit tracing
#         D       Debugging"
set cvscfg(log_classes) "CEF"
# On (1) or off (0)
set cvscfg(logging)    false
# How many trace lines to save.  The debugging output can get very large.
set cvscfg(trace_savelines) 5000

# In the Repository Browser, if true this will cause the alias modules
# to be grouped in one folder.  Cleans up clutter if there are a lot of
# aliases.  If it's false, they will be listed separately at the top
# level.
set cvscfg(aliasfolder) true

# Set colours for tagging cvs output
set cvscfg(outputColor,patched) blue4
set cvscfg(outputColor,modified) purple
set cvscfg(outputColor,conflict) red
set cvscfg(outputColor,updated) darkgoldenrod
set cvscfg(outputColor,added)   darkgreen
set cvscfg(outputColor,removed) maroon
set cvscfg(outputColor,warning) orange
set cvscfg(outputColor,unknown) gray30
set cvscfg(outputColor,stderr) red4

# Print setup. Removed in v7.1
#set cvscfg(papersize) "A4"
#set cvscfg(pointsize) 10
#set cvscfg(headingsize) 13
#set cvscfg(subheadingsize) 11
#set cvscfg(printer) "ps"

#
# --------------------
# At the very end, look for a file called "site_def" in the installation
# directory.  That's a good place to define your tagcolours and other
# site-specific things.  It won't be overwritten by installs like this file is.
set tkcvs_path [lrange $auto_path 0 0]
if {[file exists [file join $tkcvs_path site_def]]} {
  source [file join $tkcvs_path site_def]
}

