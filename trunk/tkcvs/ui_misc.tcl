
# Bindings to make canvases scroll.  Canvases have no bindings at all
# by default.
proc scrollbindings {cnvs} {
  # Page keys
  bind $cnvs <Next>  [list %W yview scroll  1 pages]
  bind $cnvs <Prior> [list %W yview scroll -1 pages]
  bind $cnvs <Up>    [list %W yview scroll -1 units]
  bind $cnvs <Down>  [list %W yview scroll  1 units]
  bind $cnvs <Left>  [list %W xview scroll -1 pages]
  bind $cnvs <Right> [list %W xview scroll  1 pages]
  # Middle button dragging
  bind $cnvs <B2-Motion> [list dragbind %W %x %y]
  # Wheelmouse
  bind $cnvs <MouseWheel> [list wheelbind %W %D]
  bind $cnvs <ButtonPress-4> [list %W yview scroll -1 pages]
  bind $cnvs <ButtonPress-5> [list %W yview scroll 1 pages]
}

# Generic Copy popup for read-only text widgets
proc copy_paste_popup {win X Y} {
  #gen_log:log T "ENTER ($win $X $Y)"

  if {! [winfo exists $win.copy_paste_pop] } {
    menu $win.copy_paste_pop
    $win.copy_paste_pop add command -label "Copy selection" \
      -command [list event generate $win <<Copy>>]
    $win.copy_paste_pop add command -label "Select all" \
      -command [list $win tag add sel 0.0 end]
  }
  tk_popup $win.copy_paste_pop $X $Y
}

# Disable all key sequences for text widget except for navigation
# and copy-to-clipboard
proc ro_textbindings {txtw} {

  #gen_log:log T "ENTER ($txtw)"
  bind $txtw <KeyPress>   {break}

  bind $txtw <Key-Home>   {catch {%W yview moveto 0};break}
  bind $txtw <Key-Up>     {catch {%W yview scroll -1 units};break}
  bind $txtw <Key-Prior>  {catch {%W yview scroll -1 pages};break}
  bind $txtw <Key-Next>   {catch {%W yview scroll  1 pages};break}
  bind $txtw <Key-Down>   {catch {%W yview scroll  1 units};break}
  bind $txtw <Key-End>    {catch {%W yview moveto 1};break}
  bind $txtw <Key-Left>   {catch {%W xview scroll -1 units};break}
  bind $txtw <Key-Right>  {catch {%W xview scroll  1 units};break}

  bind $txtw <Control-Key-c> {tk_textCopy %W;break}
  bind $txtw <Meta-Key-c>    {tk_textCopy %W;break}
  bind $txtw <Control-Key-a> {%W tag add sel 0.0 end;break}
  bind $txtw <Meta-Key-a>    {%W tag add sel 0.0 end;break}

  # Disable the cut and paste events.
  bind $txtw <<Paste>> "break"
  bind $txtw <<Cut>> "break"
  bind $txtw <2> "copy_paste_popup $txtw %X %Y"
  bind $txtw <3> "copy_paste_popup $txtw %X %Y"
}

# Save the contents of a text widget to a file
proc save_viewcontents {w} {
  set types  { {"Text Files" {*.txt *.log}} {"All Files" *} }
  set savfile [ \
    tk_getSaveFile -title "Save Results Summary" \
       -initialdir "." \
       -filetypes $types \
       -parent $w \
  ]  
  if {$savfile == ""} {
    return
  } 
  if {[catch {set fo [open $savfile w]}]} {
    puts "Cannot open $savfile for writing"
    return
  }
  puts $fo [$w.text get 1.0 end]
  close $fo
}

# Get the selected text lines, to pass to git annotate
# Works with what's already selected
proc get_textlines {w} {
  lassign [$w.text tag ranges sel] firstsel lastsel
  set firstline [lindex [split $firstsel "."] 0]
  set lastline [lindex [split $lastsel "."] 0]

  return [list $firstline $lastline]
}

#
# Search functionality for text widgets
#
proc search_textwidget_init {} {
# Initialize the globals for general text searches
  global cvsglb

  if {! [info exists cvsglb(searchstr)] } {
    set cvsglb(searchstr) ""
    set cvsglb(last_searchstr) ""
  }
  set cvsglb(searchidx) "1.0"
}

proc search_textwidget { wtx } {
# Search the text widget
  global cvsglb
  global cvscfg

  #gen_log:log T "ENTER ($wtx)"

  if {$cvsglb(searchstr) != $cvsglb(last_searchstr)} {
    $wtx tag delete match
    set cvsglb(searchidx) "1.0"
  }

  $wtx tag configure sel -background gray -foreground black
  $wtx tag raise sel
  $wtx tag configure match -background gray -foreground black \
     -relief groove -borderwidth 2
  $wtx tag raise match
  set searchstr $cvsglb(searchstr)

  set match [$wtx search -- $searchstr $cvsglb(searchidx)]
  if {[string length $match] > 0} {
    set length [string length $searchstr]
    $wtx mark set insert $match
    $wtx tag add match $match "$match + ${length}c"
    $wtx see $match
    set cvsglb(searchidx) "$match + ${length}c"
  }
  set cvsglb(last_searchstr) $cvsglb(searchstr)
}

proc search_listbox_init {} {
# Initialize the globals for searches
  global cvsglb

  if {! [info exists cvsglb(searchstr)] } {
    set cvsglb(searchstr) ""
    set cvsglb(last_searchstr) ""
  }
  set cvsglb(lsearchidx) 0
}

proc search_listbox { lbx } {
# Search a listbox
  global cvsglb

  gen_log:log T "ENTER ($lbx)"

  #gen_log:log D "search string = \"$cvsglb(searchstr)\""
  #gen_log:log D "search index = \"$cvsglb(lsearchidx)\""

  set ndx [$lbx index end]
  if {$cvsglb(searchstr) != $cvsglb(last_searchstr)} {
    set cvsglb(lsearchidx) 0
    for {set i 0} {$i < $ndx} {incr i} {
      $lbx itemconfigure $i -background $cvsglb(bg)
    }
  }
  if {$cvsglb(lsearchidx) > $ndx} {
    gen_log:log D "No more matches"
    return
  }
  for {set i $cvsglb(lsearchidx)} {$i < $ndx} {incr i} {
    set str [$lbx get $i]
    if {[string match "*$cvsglb(searchstr)*" $str]} {
      gen_log:log D "MATCH $str $cvsglb(searchstr)"
      set cvsglb(lsearchidx) $i
      $lbx itemconfigure $i -background $cvsglb(hlbg)
      $lbx see $i
      break
    } else {
      $lbx itemconfigure $i -background $cvsglb(bg)
    }
  }
  set cvsglb(last_searchstr) $cvsglb(searchstr)
  incr cvsglb(lsearchidx)
}

proc dragbind {W x y} {
  set height [$W cget -height]
  if {$y < 0} {set y 0}
  if {$y > $height} {set y $height}
  set yfrac [expr {double($y) / $height}]

  set width [$W cget -width]
  if {$x < 0} {set x 0}
  if {$x > $height} {set x $height}
  set xfrac [expr {double($x) / $width}]
  
  eval $W yview moveto $yfrac
  eval $W xview moveto $xfrac
}

proc wheelbind {W D} {
  eval $W yview scroll [expr {-($D/120)*4}] units
}

# start and stop busy cursor
proc busy_start {w} {
  foreach widget [winfo children $w] {
    catch {$widget config -cursor watch}
  }
  update idletasks
}

proc busy_done {w} {
  foreach widget [winfo children $w] {
    catch {$widget config -cursor ""}
  }
}

# Position the dialogs relative to the workdir or module browser
proc dialog_position {dialog parent} {
  set x [winfo x $parent]
  set x [winfo x $parent]
  set X [expr {$x + 60}]
  set y [winfo y $parent]
  set Y [expr {$y + 40}]
  wm geometry $dialog +$X+$Y
}

# Read a file containing user's saved picklist variables and values
proc picklist_load {} {
  global cvscfg
  global cvsglb

  if {! [catch {set file [open [file join $cvscfg(home) {.tkcvs-picklists}] r]}]} {
    while {[gets $file var_name] > 0} {
      lappend vars $var_name
      while {[gets $file item] > 0} {
        lappend cvsglb($var_name) "$item"
      }
    }
    close $file
  }
}

# See if current value is in the saved list. If not, add it.
# If so, promote it to the beginning (last used)
proc picklist_used {var_name value} {
  global cvsglb

  gen_log:log T "ENTER ($var_name $value)"
  if {$value == {} } {
    return
  }
  if {[info exists cvsglb($var_name)]} {
    if {[set i [lsearch -exact $cvsglb($var_name) "$value"]] >= 0} {
      gen_log:log D "$value is already in cvsglb($var_name). Removing to change position"
      set cvsglb($var_name) [lreplace $cvsglb($var_name) $i $i]
    }
    # The value might have spaces. That's what the concat list is about.
    set cvsglb($var_name) [lrange [concat [list "$value"] $cvsglb($var_name)] 0 50]
    gen_log:log D "appending $value to cvsglb($var_name)"
    #lappend cvsglb($var_name) "$value"
  } else {
    gen_log:log D "Initializing variable cvsglb($var_name)!"
    set cvsglb($var_name) [concat [list "$value"]]
  }
}

# Save user's picklist variables and values to a file
proc picklist_save {} {
  global cvscfg
  global cvsglb

  if {! [catch {set file [open [file join $cvscfg(home) {.tkcvs-picklists}] w]}]} {
    foreach var_name {cvsroot directory} {
      puts $file $var_name
      set c 0
      if {! [info exists cvsglb($var_name)]} { continue }
      foreach item $cvsglb($var_name) {
        # number of items saved is a preference
        if {$c >= $cvscfg(picklist_items)} {break}
        puts $file "$item"
        incr c
      }
      puts $file ""
    }
    close $file
  }
}

# Take a color like $d9d9d9 and darken it
proc rgb_shadow {color} {
  set rgb_color [winfo rgb . $color]
  set shadow [format #%02x%02x%02x [expr (9*[lindex $rgb_color 0])/2560] \
                                   [expr (9*[lindex $rgb_color 1])/2560] \
                                   [expr (9*[lindex $rgb_color 2])/2560]]
  return $shadow
}

