#
# Debugging trace functions adapted from set by Marcel Koelewijn 
#

proc gen_log:init {} {
  global cvscfg
  global cvsglb
  global tcl_platform

  toplevel .trace
  wm protocol .trace WM_DELETE_WINDOW { .trace.close invoke }
  if {[info exists cvscfg(tracgeom)]} {
    wm geometry .trace $cvscfg(tracgeom)
  }
  text .trace.text -setgrid yes -relief sunken -border 2 \
      -exportselection 1 -yscroll ".trace.scroll set"
  scrollbar .trace.scroll -relief sunken \
      -command ".trace.text yview"
  frame .trace.bottom

  button .trace.bottom.clear -text "Clear" -highlightbackground $cvsglb(bg) \
    -command gen_log:clear
  button .trace.bottom.save -text "Save to File" -highlightbackground $cvsglb(bg) \
    -command gen_log:save

  search_textwidget_init
  button .trace.bottom.srchbtn -text Search -highlightbackground $cvsglb(bg) \
    -command "search_textwidget .trace.text"
  entry .trace.bottom.entry -width 20 -textvariable cvsglb(searchstr)
  bind .trace.bottom.entry <Return> \
      "search_textwidget .trace.text"

  button .trace.close -text "Stop Tracing" -highlightbackground $cvsglb(bg) \
    -command { gen_log:quit; exit_cleanup 0 }

  pack .trace.bottom -side bottom -fill x
  pack .trace.scroll -side right -fill y
  pack .trace.text -fill both -expand 1

  pack .trace.bottom.srchbtn -side left
  pack .trace.bottom.entry -side left
  pack .trace.bottom.clear -side left -expand 1 -anchor c
  pack .trace.bottom.save -side left
  pack .trace.close -in .trace.bottom -side right

  # Lets hard-code these colors - otherwise at least one is very
  # likely to blend into the bakcground
  .trace.text configure -background gray92
  .trace.text tag configure tagC -foreground purple
  .trace.text tag configure tagE -foreground maroon
  .trace.text tag configure tagF -foreground darkgreen
  .trace.text tag configure tagT -foreground black
  .trace.text tag configure tagD -foreground red

  # Focus in the text widget to activate the text bindings
  focus .trace.text
  #bind_show .trace.text

  wm title .trace "TkCVS Trace"
  if {$tcl_platform(platform) != "windows"} {
    wm iconbitmap .trace @$cvscfg(bitmapdir)/trace.xbm
  }
}

proc gen_log:log { class string } { 
  global cvscfg

  # check class+level first, if no logging required, skip
  if {$cvscfg(logging) && [string match "*\[$class\]*" $cvscfg(log_classes)]} {
    set callerlevel [expr {[info level] - 1}]
    if { $callerlevel == 0 } {
      # called from the toplevel
      set callerid "toplevel"
    } else {
      set callerid [lindex [info level $callerlevel] 0]
    }
    # Uncomment this to see the trace on stdout
    #puts "$class ($callerid) $string"
    .trace.text insert end [format "\[%s] %s\n" $callerid "$string"] tag$class
    set overflow [expr {[.trace.text index end] - $cvscfg(trace_savelines)}]
    if { $overflow > 10 } {
       .trace.text delete 0.0 $overflow
    }
    .trace.text yview end
  }
}

proc gen_log:quit { } {
  global cvscfg

  set cvscfg(logging) false
  if {[winfo exists .trace]} {
    set cvscfg(tracgeom) [wm geometry .trace]
    destroy .trace
  }
}

proc gen_log:clear { } {
   .trace.text delete 1.0 end
}

proc gen_log:save { } {
  set initialfile "tkcvs_log.txt"

  set types  { {{All Files} *} }
  set savfile [ \
    tk_getSaveFile -title "Save Trace" \
       -filetypes $types \
       -initialfile $initialfile \
       -parent .trace
  ]
  if {$savfile == ""} {
    return
  }

  if {[catch {set fo [open $savfile w]}]} {
    catchputs "Cannot open $savfile for writing"
    return
  }
  puts $fo [.trace.text get 1.0 end]
  close $fo
}

proc gen_log:changeclass { } {
  global cvscfg
  global logclass

  set cvscfg(log_classes) ""
  foreach c [array names logclass] {
    append cvscfg(log_classes) $logclass($c)
  }
}
