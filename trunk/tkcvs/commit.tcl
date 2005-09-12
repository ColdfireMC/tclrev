#
# Tcl Library for TkCVS
#
 
# 
# $Id: commit.tcl,v 1.22 2004/11/14 07:07:27 dorothyr Exp $
#
# Set up a small commit dialog.
# 
proc commit_run {} {
  global incvs
  global cvsglb
  global cvscfg

  gen_log:log T "ENTER"

  if {! $incvs} {
    cvs_notincvs
    gen_log:log T "LEAVE"
    return
  }

  # If marked files, commit these.  If no marked files, then
  # commit any files selected via listbox selection mechanism.
  # The cvsglb(commit_list) list remembers the list of files
  # to be committed.
  set cvsglb(commit_list) [workdir_list_files]

  # If we want to use an external editor, just do it
  if {$cvscfg(use_cvseditor)} {
    cvs_commit "" "" $cvsglb(commit_list)
    return
  }

  if {[winfo exists .commit]} {
    wm deiconify .commit
    raise .commit
    #grab set .commit
    gen_log:log T "LEAVE"
    return
  }

  toplevel .commit
  grab set .commit

  frame .commit.top -border 8
  frame .commit.vers
  frame .commit.down -relief groove -border 2

  pack .commit.top -side top -fill x
  pack .commit.down -side bottom -fill x
  pack .commit.vers -side top -fill y

  label .commit.lvers -text "Specify Revision (-r) (usually ignore)" \
     -anchor w
  entry .commit.tvers -relief sunken -textvariable version

  pack .commit.lvers .commit.tvers -in .commit.vers \
    -side left -fill x -pady 3

  frame .commit.comment
  pack .commit.comment -side top -fill both -expand 1
  label .commit.lcomment
  text .commit.tcomment -relief sunken -width 70 -height 10 \
    -exportselection 1 \
    -wrap word -border 2 -setgrid yes


  # Explain what it means to "commit" files
  message .commit.message -justify left -aspect 500 -relief groove \
    -text "This will commit changes from your \
           local, working directory into the repository, recursively.

\
          For any local (sub)directories or files that are on a branch, \
           your changes will be added to the end of that branch.  \
           This includes new or deleted files as well as modifications.

\
          For any local (sub)directories or files that have \
           a non-branch tag, a branch will be created, and \
           your changes will be placed on that branch.  \
           (CVS bug.  Sorry.)

\
          For all other (sub)directories, your changes will be \
           added to the end of the main trunk."

  pack .commit.message -in .commit.top -padx 2 -pady 5


  button .commit.ok -text "OK" \
    -command {
      grab release .commit
      wm withdraw .commit
      cvs_commit $version [.commit.tcomment get 1.0 end] $cvsglb(commit_list)
    }
  button .commit.apply -text "Apply" \
    -command {
      cvs_commit $version [.commit.tcomment get 1.0 end] $cvsglb(commit_list)
    }
  button .commit.clear -text "ClearAll" \
    -command {
      set version ""
      .commit.tcomment delete 1.0 end
    }
  button .commit.quit \
    -command {
      grab release .commit
      wm withdraw .commit
    }
 
  .commit.lcomment configure -text "Your log message" \
    -anchor w
  .commit.ok configure -text "OK"
  .commit.quit configure -text "Close"
  pack .commit.lcomment -in .commit.comment \
    -side left -fill x -pady 3
  pack .commit.tcomment -in .commit.comment \
    -side left -fill both -expand 1 -pady 3

  pack .commit.ok .commit.apply .commit.clear .commit.quit -in .commit.down \
    -side left -ipadx 2 -ipady 2 -padx 4 -pady 4 -fill both -expand 1
  # May be needed for slower framebuffers, but it doesn't work with
  # some window managers (fvwm 2.4 and tvtwm are known)
  #tkwait visibility .commit

  wm title .commit "Commit Changes to a Module"
  wm minsize .commit 1 1

  gen_log:log T "LEAVE"
}
