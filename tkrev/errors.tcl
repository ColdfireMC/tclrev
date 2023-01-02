#
# Tcl Library
#

#
# Procedures for unimplemented procedures and error messages used by
# TkRev.
#

proc cvsok {mess {parent {.}} } {
  # Sometimes cancel is meaningless, we just want an acknowlegement
  
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

# This one doesn't check cvscfg(confirm_prompt) preference
proc cvsalwaysconfirm {mess {parent {.}} } {
  
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

proc cvsfail {msg} {
  puts "$msg"
  return
}

proc cvserror {mess {parent {.}} } {
  
  if {! [winfo exists $parent]} {set parent .}
  set title {TkRev Error!}
  tk_messageBox \
      -icon error \
      -title $title \
      -message $mess \
      -parent $parent \
      -type ok
  
  exit_cleanup 0
}

