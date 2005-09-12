#
# Tcl Library for TkCVS
#

#
# $Id: search.tcl,v 1.11 2003/05/05 06:24:44 dorothyr Exp $
#
# Search functionality for text widgets
#

proc search_textwidget_init {} {
# Initialize the globals for general text searches
  global cvsglb

  if {! [info exists cvsglb(searchstr)] } {
    set cvsglb(searchstr) ""
  }
  set cvsglb(searchidx) "1.0"
}

proc search_textwidget { wtx } {
# Search the text widget
  global cvsglb
  global cvscfg

  gen_log:log T "ENTER ($wtx)"
  set searchstr $cvsglb(searchstr)

  set match [$wtx search -- $searchstr $cvsglb(searchidx)]
  if {[string length $match] > 0} {
    set length [string length $searchstr]
    $wtx mark set insert $match
    $wtx tag add sel $match "$match + ${length}c"
    $wtx see $match
    set cvsglb(searchidx) "$match + ${length}c"
  }
}

