# TkRev defaults file.
#
# This file is read by TkRev on startup.  It will be installed
# automatically by the "configure" script.
#
# Defaults in the .tkrev file in the user's home directory will
# over-ride this file.
#

# Working Directory Browser options
# If you want to use "cvs edit"
set cvscfg(econtrol) false
# If you want to use cvs in locking mode
set cvscfg(cvslock) false
# If you want to see the status column
set cvscfg(showstatcol) true
# If you want to see the date column
set cvscfg(showdatecol) true
# If you want to see the revision (commit ID) column
set cvscfg(showwrevcol) true
# If you want to see the editors/author/lockers column
set cvscfg(showeditcol) true
# Sort by filename or status (filecol or statcol)
set cvscfg(sort_pref) {filecol -increasing}

# If you want to see hash and author in Git workdir
set cvscfg(gitdetail) false
# Since date for git log diagram
set cvscfg(gitlog_since) ""
# Since date for git blame
set cvscfg(gitblame_since) ""
# Max number of revs to go back in a git branch diagram
set cvscfg(gitmaxhist) 500
# Max number of git branches to process
set cvscfg(gitmaxbranch) 100
# Which groups of git branches to consider. F can't be excluded.
#  F    only those captured in the file log
#  L    local, found by "git branch"
#  R    remote, found by "git branch -r"
set cvscfg(gitbranchgroups) "FL"
# Max number of branches in a git branch diagram
set cvscfg(gitmaxbranch) 100
# Which git log options to use for the branch diagram
set cvscfg(gitlog_opts) "--first-parent"
# Which branches to process for the branch diagram
# as a regexp pattern
set cvscfg(gitbranchregex) ""

# Branch Diagram options
# Number of tags in a Subversion repository that's "too many", ie
# will take longer to proecess than you're willing to wait.
set cvscfg(toomany_tags) 25
# Number of tags you want to see for each revision on the branching
# diagram before it says "more..."
set cvscfg(tagdepth) 6
# Hilight colours for revision-log boxes


#set cvscfg(dateformat) "%Y/%m/%d %H:%M:%S"
set cvscfg(dateformat) "%Y-%m-%d %H:%M:%S"
# Format for mergeto- and mergefrom- tags.  The _BRANCH_ part must be
# left as-is, but you can change the prefix and the date format, for
# example "mergeto_BRANCH_%d%b%y".  The date format must be the same
# for both.
# CVS rule: a tag must not contain the characters `$,.:;@'
#set cvscfg(mergetoformat) "t_BRANCH_%d%b%y_%H-%M"
#set cvscfg(mergefromformat) "f_BRANCH_%d%b%y_%H-%M"
set cvscfg(mergetoformat) "mergeto_BRANCH_%d%b%y"
set cvscfg(mergefromformat) "mergefrom_BRANCH_%d%b%y"
set cvscfg(mergetrunkname) "trunk"

# The branch browser depends on the convention of having a trunk, branches, and
# tags structure to draw the diagram.  These variables may give you a little
# more flexibility.
set cvscfg(svn_trunkdir) "trunk"
set cvscfg(svn_branchdir) "branches"
set cvscfg(svn_tagdir) "tags"

# --------------------
# Platform specific configuration.
#
# Decide wether you are unlucky and have to run tkrev on DOS/WIN
# some things will be setup in the following
#
# Please note that you may have to setup a bit more.
#
# file mask for all files
set cvscfg(aster) "*.*"
# null-device
set cvscfg(null) "nul"
# Terminal program
set cvscfg(terminal) "command /c"
set cvscfg(home) [file normalize $::env(HOMEPATH)]
# Please don't ask me why you have to set -T on DOS,
# experiments say you have! - CJ
#set cvs "cvs -T $cvscfg(tmpdir)"
set cvs "cvs"
set cvscfg(editor) "notepad"
# set temp directory
set cvscfg(tmpdir) [file normalize $::env(PATH)]
set cvscfg(print_cmd)    "pr"
set cvscfg(shell)  ""
set cvscfg(allow_abort)  "no"
#
# --------------------
# User Menus
#
# Add a cvs command to add to the User Menu
#  set cvsmenu(Show_My_Checkouts) "history"
#  set cvsmenu(Show_All_Checkouts) "history -a"
# Run a a shell command whose output you want to catch
#   set usermenu(show_makevars) "gmake -pn | grep '='"
# Run a standalone programs
#   set execmenu(tkman_cvs) "tkman cvs"
#   set execmenu(GitK) {gitk [lindex $cvsglb(current_selection) $i]}

#
# --------------------
# Other defaults
# These can be set and saved from the GUI.
#

# Set this to 1 to see all files displayed in the directory
# browser (including hidden files) by default.
set cvscfg(allfiles)           false

# set the default pattern to be used by the filter.  Use any valid
# pattern that can be used for a pattern for 'ls'. An empty string
# is equivalent to the entire directory (minus hidden files);
# i.e., ls *
set cvscfg(show_file_filter)   ""
set cvscfg(ignore_file_filter) "*.a *.o *~"
set cvscfg(clean_these)        "*.bak *~ .#* *tmp #* *%"

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
#         E       stderr from commands
#         F       File creation/deletion
#         T       Function entry/exit tracing
#         D       Debugging"
set cvscfg(log_classes) "CEF"
# On (1) or off (0)
set cvscfg(logging)    false
# How many trace lines to save.  The debugging output can get very large.
set cvscfg(trace_savelines) 100000

# In the Repository Browser, if true this will cause the alias modules
# to be grouped in one folder.  Cleans up clutter if there are a lot of
# aliases.  If it's false, they will be listed separately at the top
# level.
set cvscfg(aliasfolder) true
