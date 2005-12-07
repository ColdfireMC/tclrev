namespace eval ::picklist {
  variable data
}


proc ::picklist::used { name args } {
  variable data

  # FIXME: max items in list should be configurable. Possibly with
  # different values for different lists.
  if {[info exists data($name)]} {
    foreach item $args {
      if {[set i [lsearch -exact $data($name) $item]] >= 0} {
        set data($name) [lreplace $data($name) $i $i]
      }
    }
    set data($name) [lrange [concat $args $data($name)] 0 50]
  } else {
    set data($name) [lrange $args 0 50]
  }

  return
}


proc ::picklist::choose { w data } {
  global cvscfg
  global cvsglb

  set line_h [font metrics \
    $cvscfg(listboxfont) -displayof $w -linespace]
  set x [winfo rootx $w]
  set y [expr {[winfo rooty $w] + [winfo height $w]}]
  set width [winfo width $w]

  toplevel .picklist

  listbox .picklist.list -relief raised -border 1 -font $cvscfg(listboxfont)
  pack .picklist.list -side left -fill both -expand 1

  if {[llength $data] <= 8} {
    set height [expr {($line_h
                        + [.picklist.list cget -borderwidth]
                        + [.picklist.list cget -selectborderwidth])
                      * [llength $data] + 8}]
  } else {
    set height [expr {($line_h
                        + [.picklist.list cget -borderwidth]
                        + [.picklist.list cget -selectborderwidth])
                      * 8 + 4}]
    scrollbar .picklist.scroll -relief sunken \
      -command ".picklist.list yview"
    pack .picklist.scroll -side right -fill y
    .picklist.list configure -yscroll ".picklist.scroll set"
  }

  foreach datum $data {
    .picklist.list insert end $datum
  }

  ::bind .picklist <Escape> {
    grab release .picklist
    destroy .picklist
  }
  ::bind .picklist <Return> "
    if {\[.picklist.list curselection\] != {}} {
      $w.e delete 0 end
      $w.e insert 0 \[.picklist.list get \[.picklist.list curselection\]\]
      $w.e icursor end
      focus -force $w.e
    }
    grab release .picklist
    destroy .picklist
    event generate $w.e <Return> -when tail
    focus -force $w.e
  "

  ::bind .picklist <ButtonRelease-1> "
    set eventw \[winfo containing -displayof .picklist.list %X %Y\]
    if {\$eventw == \".picklist.list\"} {
      $w.e delete 0 end
      $w.e insert 0 \[.picklist.list get @%x,%y\]
    }
    if {\$eventw != \".picklist.scroll\"} {
      grab release .picklist
      destroy .picklist
      event generate $w.e <Return> -when tail
      focus -force $w.e
    }
  "

  focus .picklist.list
  wm geometry .picklist "$width\x$height\+$x\+$y"
  wm overrideredirect .picklist 1
  tkwait visibility .picklist
  grab set -global .picklist
  return
}


proc ::picklist::entry { w varName listName } {
  global cvsglb
  variable data

  if {! [info exists data($listName)]} {
    set data($listName) {}
  }

  frame $w -relief sunken -border 2
  ::entry $w.e -relief flat -border 0 -textvariable $varName -bg $cvsglb(textbg)
  pack $w.e -side left -expand 1 -fill both
  button $w.b -image arr_dn -border 1 \
    -padx 0 -pady 0 -takefocus 0 \
    -command "
      ::picklist::choose $w \$::picklist::data($listName)
    "
  pack $w.b -side right
  ::bind $w.e <KeyPress-Down> "$w.b invoke"
  return
}


proc ::picklist::bind { w {sequence {}} {script {}} } {
  return [::bind $w.e $sequence $script]
}


proc ::picklist::load { } {
  global cvscfg

  if {! [catch {set file [open [file join $cvscfg(home) {.tkcvs-picklists}] r]}]} {
    variable data

    while {[gets $file name] > 0} {
      while {[gets $file item] > 0} {
        lappend data($name) $item
      }
    }
    close $file
  }
}


proc ::picklist::save { } {
  global cvscfg

  if {! [catch {set file [open [file join $cvscfg(home) {.tkcvs-picklists}] w]}]} {
    variable data

    foreach name {cvsroot directory} {
      puts $file $name
      set c 0
      if {! [info exists data($name)]} { continue }
      foreach item $data($name) {
        # number of items saved is a preference
        if {$c >= $cvscfg(picklist_items)} {break}
        puts $file $item
        incr c
      }
      puts $file ""
    }

    close $file
  }
}
