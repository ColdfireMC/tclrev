#
# TCL Library
#

#
# $Id: errors.tcl,v 1.10 2005/07/18 16:16:53 dorothyr Exp $
#
# Procedures for unimplemented procedures and error messages used by
# TkCVS.
#

proc cvsok {mess {parent {.}} } {
# Sometimes cancel is meaningless, we just want an acknowlegement
  global cvscfg

  if {! [winfo exists $parent]} {set parent .}
  set title {Acknowledge!}
  tk_messageBox \
        -icon info \
        -title $title \
        -message $mess \
        -parent $parent \
        -type ok
}

proc cvsconfirm {mess {parent {.}} } {
  global cvscfg

  if {$cvscfg(confirm_prompt) != "true"} { return "ok" }
  if {! [winfo exists $parent]} {set parent .}
  set title {Confirm!}
  set answer [tk_messageBox \
        -icon question \
        -title $title \
        -message $mess \
        -parent $parent \
        -type okcancel]
  gen_log:log D "$answer"
  return $answer
}

proc cvsfail {mess {parent {.}} } {
  global cvscfg

  if {! [winfo exists $parent]} {set parent .}
  set title {TkCVS Warning!}
  tk_messageBox \
        -icon warning \
        -title $title \
        -message $mess \
        -parent $parent \
        -type ok
}

proc cvserror {mess {parent {.}} } {
  global cvscfg

  if {! [winfo exists $parent]} {set parent .}
  set title {TkCVS Error!}
  tk_messageBox \
        -icon error \
        -title $title \
        -message $mess \
        -parent $parent \
        -type ok

  exit_cleanup 0
}