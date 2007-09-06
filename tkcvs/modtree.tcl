# Adapted from tree.tcl released under GPL by
#
# Copyright (C) 1997,1998 D. Richard Hipp
#

#
# Create a new two-paned widget for the modules.
#
proc ModTree:create {w {open_func {}} } {
  global Tree
  global cvsglb

  gen_log:log T "ENTER ($w $open_func)"
  set Tree(open_function) $open_func

  if {[catch "image type ModTree:closedbm"]} {
    ModTree:loadimages
  }

  set winwid [winfo width $w]
  panedwindow $w.pw -relief sunk -bd 2
  $w.pw configure -handlepad 35 -sashwidth 4 -sashpad 0 -handlesize 10
  frame $w.tree
  frame $w.labl

  canvas $w.tree.list -highlightthickness 0 -width [expr {$winwid * 3/8}]
  canvas $w.labl.list -highlightthickness 0
  $w.tree configure -bg $cvsglb(canvbg)
  $w.labl configure -bg $cvsglb(canvbg)
  $w.tree.list configure -bg $cvsglb(canvbg)
  $w.labl.list configure -bg $cvsglb(canvbg)

  set cvsglb(fg) [lindex [.modbrowse.bottom.buttons.modfuncs.filebrowse configure -foreground] 4]
  set cvsglb(dfg) \
      [lindex [.modbrowse.top.bworkdir configure -disabledforeground] 4]
  set buttonhilite \
      [lindex [.modbrowse.top.bworkdir configure -highlightbackground] 4]
  set selcolor [option get . selectColor selectColor]

  if {[string length $selcolor]} {
    set cvsglb(hlbg) $selcolor
  }
  if {$cvsglb(hlbg) == $cvsglb(canvbg)} {
    set cvsglb(hlbg) $buttonhilite
  }

  scrollbar $w.yscroll -orient vertical -highlightthickness 0 \
      -command "ModTree:scroll_windows $w"
  pack $w.yscroll -side right -fill y
  bind $w.tree.list <1> "ModTree:clearselection $w"
  foreach canv {tree labl} {
    $w.$canv.list configure -yscrollcommand "$w.yscroll set"
    bind $w.$canv.list <Next>  "ModTree:scroll_windows $w scroll  1 pages"
    bind $w.$canv.list <Prior> "ModTree:scroll_windows $w scroll -1 pages"
    bind $w.$canv.list <Down>  "ModTree:scroll_windows $w scroll  1 units"
    bind $w.$canv.list <Up>    "ModTree:scroll_windows $w scroll -1 units"
    bind $w.$canv.list <B2-Motion> "ModTree:drag_windows $w %W %y"
    bind $w.$canv.list <B3-Motion> "ModTree:drag_windows $w %W %y"
    bind $w.$canv.list <MouseWheel> \
      "ModTree:scroll_windows $w scroll \[expr {-(%D/120)*4}\] units"
    bind $w.$canv.list <ButtonPress-4> \
      "ModTree:scroll_windows $w scroll -1 units"
    bind $w.$canv.list <ButtonPress-5> \
      "ModTree:scroll_windows $w scroll 1 units"

    label $w.$canv.lbl -relief raised -bd 2
    pack $w.$canv -side left -fill both -expand yes
    pack $w.$canv.lbl -ipady 2 -fill x -expand no
    pack $w.$canv.list -side top -fill both -expand yes -padx 8
  }
  $w.tree.lbl configure -text "Module"
  $w.labl.lbl configure -text "Information"
  $w.pw add $w.tree
  $w.pw add $w.labl


  ModTree:dfltconfig $w /
  set Tree(vsize) 16
  ModTree:buildwhenidle $w
  set Tree($w:selection) {}
  set Tree($w:selB) {}
  set Tree($w:jtems) 0

  focus $w.tree.list
  gen_log:log T "LEAVE"
}

# Initialize a element of the tree.
# Internal use only
#
proc ModTree:dfltconfig {w v} {
  global Tree

  #gen_log:log T "ENTER ($w $v)"
  set Tree($w:$v:children) {}
  set Tree($w:$v:open) 0
  set Tree($w:$v:icon) {}
  set Tree($w:$v:tags) {}
  #gen_log:log T "LEAVE"
}

#
# Insert a new element $v into the tree $w.
#
proc ModTree:newitem {w v name title args} {
  global Tree

  #gen_log:log T "ENTER ($w $v $name \"$title\" $args)"
  set dir [file dirname $v]
  set n [file tail $v]

  #puts "MTNewitem: dir $dir (dirname $v)   n $n (file tail $v)"
  # If a plain file starts with ~ file tail returns ./~ which is the
  # right thing for filesystem commands but not for this
  regsub {^\./} $n {} n
  if {![info exists Tree($w:$dir:open)]} {
    cvsfail "parent item \"$dir\" is missing" .modbrowse
  }
  set i [lsearch -exact $Tree($w:$dir:children) $n]
  if {$i>=0} {
    #cvsfail "item \"$v\" already exists" .modbrowse
    return
  }
  lappend Tree($w:$dir:children) $n
  set Tree($w:$dir:children) [lsort $Tree($w:$dir:children)]
  ModTree:dfltconfig $w $v
  set Tree($w:$v:name) $name
  set Tree($w:$v:title) $title
  foreach {op arg} $args {
    switch -exact -- $op {
      -image {set Tree($w:$v:icon) $arg}
      -tags {set Tree($w:$v:tags) $arg}
    }
  }
  ModTree:buildwhenidle $w
  #gen_log:log T "LEAVE"
}

#
# Delete element $v from the tree $w.  If $v is /, then the widget is
# deleted.
#
proc ModTree:delitem {w v} {
  global Tree

  #gen_log:log T "ENTER ($w $v)"
  if {![info exists Tree($w:$v:open)]} return
  if {[string compare $v /]==0} {
    # delete the whole widget
    catch {destroy $w.tree}
    catch {destroy $w.labl}
    set parent [winfo parent $w]
    catch {destroy $w.yscroll}
    foreach t [array names Tree $w:*] {
      unset Tree($t)
    }
    return
  }
  if {[info exists Tree($w:$v:children)]} {
    foreach c $Tree($w:$v:children) {
      catch {ModTree:delitem $w $v/$c}
    }
    unset Tree($w:$v:open)
    unset Tree($w:$v:children)
    unset Tree($w:$v:icon)
    set dir [file dirname $v]
    set n [file tail $v]
    set i [lsearch -exact $Tree($w:$dir:children) $n]
    if {$i>=0} {
      set Tree($w:$dir:children) [lreplace $Tree($w:$dir:children) $i $i]
    }
  }
  ModTree:buildwhenidle $w
  #gen_log:log T "LEAVE"
}


proc ModTree:loadimages {} {
#
# Bitmaps used to show which parts of the tree can be opened.
#
  global cvscfg

  set maskdata "#define solid_width 9\n#define solid_height 9"
  append maskdata {
    static unsigned char solid_bits[] = {
     0xff, 0x01, 0xff, 0x01, 0xff, 0x01, 0xff, 0x01, 0xff, 0x01, 0xff, 0x01,
     0xff, 0x01, 0xff, 0x01, 0xff, 0x01
    };
  }
  set data "#define open_width 9\n#define open_height 9"
  append data {
    static unsigned char open_bits[] = {
     0xff, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x7d, 0x01, 0x01, 0x01,
     0x01, 0x01, 0x01, 0x01, 0xff, 0x01
    };
  }
  image create bitmap ModTree:openbm -data $data -maskdata $maskdata \
    -foreground black -background white
  set data "#define closed_width 9\n#define closed_height 9"
  append data {
    static unsigned char closed_bits[] = {
     0xff, 0x01, 0x01, 0x01, 0x11, 0x01, 0x11, 0x01, 0x7d, 0x01, 0x11, 0x01,
     0x11, 0x01, 0x01, 0x01, 0xff, 0x01
    };
  }
  image create bitmap ModTree:closedbm -data $data -maskdata $maskdata \
    -foreground black -background white

  image create photo dir \
    -format gif -file [file join $cvscfg(bitmapdir) dir.gif]
  image create photo mdir \
    -format gif -file [file join $cvscfg(bitmapdir) mdir.gif]
  image create photo mod \
    -format gif -file [file join $cvscfg(bitmapdir) mod.gif]
  image create photo adir \
    -format gif -file [file join $cvscfg(bitmapdir) adir.gif]
  image create photo amod \
    -format gif -file [file join $cvscfg(bitmapdir) amod.gif]
}

# Internal use only.
# Draw the tree on the canvas
proc ModTree:build {w} {
  global Tree

  #gen_log:log T "ENTER ($w)"
  $w.tree.list delete all
  $w.labl.list delete all
  catch {unset Tree($w:buildpending)}
  set Tree($w:y) 30
  ModTree:buildlayer $w / $Tree(vsize)
  set tbox [$w.tree.list bbox all]
  #if {$tbox == ""} {return}
  $w.tree.list config -scrollregion $tbox
  # Use tree's bbox for labl, because labl's is a little shorter
  # but we need to keep them in sync
  $w.labl.list config -scrollregion $tbox

  #gen_log:log T "LEAVE"
}

# Internal use only.
# Build a single layer of the tree on the canvas.  Indent by $in pixels
proc ModTree:buildlayer {w v in} {
  global Tree
  global cvscfg
  global cvsglb

  #gen_log:log T "ENTER ($w $v $in)"
  if {$v=="/"} {
    set vx {}
  } else {
    set vx $v
  }
  set start [expr {$Tree($w:y)-10}]
  foreach c $Tree($w:$v:children) {
    set y $Tree($w:y)
    incr Tree($w:y) [expr {$Tree(vsize)+3}]
    $w.tree.list create line $in $y [expr {$in+$Tree(vsize)}] $y -fill gray50
    if {! [string length $Tree($w:$vx/$c:children)]} {
      if {$Tree($w:$vx/$c:icon) == "mdir"} {
         set Tree($w:$vx/$c:icon) "mod"
      }
    }
    set icon $Tree($w:$vx/$c:icon)
    set x [expr {$in+12}]
    set j $Tree($w:jtems)
    incr Tree($w:jtems)

    # Draw the icon
    if {[string length $icon]>0} {
      set k [$w.tree.list create image $x $y -image $icon -anchor w ]
      $w.tree.list bind k <1> "ModTree:setselection $w \"$vx/$c\""
      $w.tree.list bind k <2> "ModTree:setselB $w \"$vx/$c\""
      $w.tree.list bind k <3> "ModTree:setselB $w \"$vx/$c\""
      incr x 24
    }
    # Draw the label
    set lbl $Tree($w:$vx/$c:name)


    $w.tree.list create text $x $y \
        -text $lbl \
        -fill $cvsglb(fg) \
        -font $cvscfg(listboxfont) -anchor w \
        -tag $w.tree.list.tx$j
    
    # In the bindings, filenames need any single percents replaced with
    # double to avoid interpretation as an event field
    set f "$vx/$c"
    regsub -all {\%} $f {%%} fn
    regsub -all {\$} $fn {\$} fn

    $w.tree.list bind $w.tree.list.tx$j <1> "ModTree:setselection $w \"$fn\""
    $w.tree.list bind $w.tree.list.tx$j <2> "ModTree:setselB $w \"$fn\""
    $w.tree.list bind $w.tree.list.tx$j <3> "ModTree:setselB $w \"$fn\""
    $w.tree.list bind $w.tree.list.tx$j <Enter> "ModTree:flash $w \"$fn\""
    $w.tree.list bind $w.tree.list.tx$j <Leave> "ModTree:unflash $w \"$fn\""

    #gen_log:log D "$vx/$c $lbl   j=$j"
    if {[info exists Tree($w:$vx/$c:title)]} {
      set k [$w.labl.list create text [expr {$x - $Tree(vsize) - 22}] $y \
         -text $Tree($w:$vx/$c:title) \
         -fill $cvsglb(fg) \
         -font $cvscfg(listboxfont) -anchor w]
    }
    set Tree($w:tag:$j) $vx/$c
    set Tree($w:$vx/$c:tag) $j
    # Put an open/close image on it if it has children
    if {[string length $Tree($w:$vx/$c:children)]} {
      if {$Tree($w:$vx/$c:open)} {
         set k [$w.tree.list create image $in $y -image ModTree:openbm]
         $w.tree.list bind $k <1> "set \"Tree($w:$vx/$c:open)\" 0; \
                                   ModTree:build $w"
         ModTree:buildlayer $w $vx/$c [expr {$in+$Tree(vsize)+8}]
      } else {
         set k [$w.tree.list create image $in $y -image ModTree:closedbm]
         if {$Tree(open_function) == {} } {
           $w.tree.list bind $k <1> "set \"Tree($w:$vx/$c:open)\" 1; \
                                    ModTree:build $w"
         } else {
           $w.tree.list bind $k <1> "set \"Tree($w:$vx/$c:open)\" 1; \
                                    $Tree(open_function) $w \"$vx/$c\"; \
                                    ModTree:build $w"
         }
      }
    }
  }
  if {![info exists y]} {return}
  set j [$w.tree.list create line $in $start $in [expr {$y+1}] -fill gray50 ]
  $w.tree.list lower $j
  #gen_log:log T "LEAVE"
}

# Open a branch of a tree
#
proc ModTree:open {w v} {
  global Tree

  if {[info exists Tree($w:$v:open)] && $Tree($w:$v:open)==0
      && [info exists Tree($w:$v:children)]
      && [string length $Tree($w:$v:children)]>0} {
    set Tree($w:$v:open) 1
    ModTree:build $w
  }
}

proc ModTree:close {w v} {
  global Tree
  if {[info exists Tree($w:$v:open)] && $Tree($w:$v:open)==1} {
    set Tree($w:$v:open) 0
    ModTree:build $w
  }
}


# Internal use only
# Call ModTree:build then next time we're idle
proc ModTree:buildwhenidle {w} {
  global Tree

  #gen_log:log T "ENTER ($w)"
  if {![info exists Tree($w:buildpending)]} {
    set Tree($w:buildpending) 1
    after idle "ModTree:build $w"
  }
  #gen_log:log T "LEAVE"
}

#
# Change the selection to the indicated item
#
proc ModTree:setselection {w v} {
  global Tree
  global modbrowse_module
  global modbrowse_path
  global modbrowse_title

  #gen_log:log T "ENTER ($w \"$v\")"
  # Clear old selection
  set oldv $Tree($w:selection)
  if {$oldv != ""} {
    set j $Tree($w:$oldv:tag)
    ModTree:clearTextHBox $w $w.tree.list.tx$j
  }
  #foreach a [array names Tree "$w:$v:*"] { puts "$a $Tree($a)" }

  # Hilight new selection
  if {$v != ""} {
    set Tree($w:selection) $v
    set j $Tree($w:$v:tag)
    ModTree:setTextHBox $w $w.tree.list.tx$j
    set modbrowse_module $Tree($w:$v:name)
    set modbrowse_title $Tree($w:$v:title)
  }
  set modbrowse_path [string trimleft $v /]
}

#
# Change the secondary selection
#
proc ModTree:setselB {w v} {
  global Tree
  global selB_path

  # Clear old selection
  set oldv $Tree($w:selB)
  if {$oldv != ""} {
    set j $Tree($w:$oldv:tag)
    ModTree:clearTextHBox $w $w.tree.list.tx$j
  }

  # Hilight new selection
  if {$v != ""} {
    set Tree($w:selB) $v
    set j $Tree($w:$v:tag)
    ModTree:setTextHBox $w $w.tree.list.tx$j
  }
  set selB_path $v
}

# Clear selection, invoked when clicking over a blank 
proc ModTree:clearselection {w} {
  global Tree
  global modbrowse_module

  # Don't clear unless we aren't over anything
  if {[llength [$w.tree.list gettags current]] == 0 } {
    ModTree:setselection $w ""
    ModTree:setselB $w ""
    set Tree($w:selection) {}
    set Tree($w:selB) {}
    set modbrowse_module ""
  }
}

proc ModTree:flash {widg v} {
  global Tree

  set j $Tree($widg:$v:tag)
  ModTree:setTextHBox $widg $widg.tree.list.tx$j
}

proc ModTree:unflash {widg v} {
  global Tree

  set j $Tree($widg:$v:tag)

  # Don't unflash if this is one that is selected:
  if { $Tree($widg:selection) != $v && $Tree($widg:selB) != $v } {
  	ModTree:clearTextHBox $widg $widg.tree.list.tx$j
  }
}

proc ModTree:scroll_windows {w args} {
  #gen_log:log T "ENTER ($w $args)"
  set parent [winfo parent $w]

  set yget [$w.yscroll get]
  set way [lindex $args 2]
  set cmd [lindex $args 1]
  set first [lindex $yget 0]
  set last [lindex $yget 1]
  #gen_log:log D "$cmd $way: $first  $last"
  # If you dont do this, the scrollbar fills the whole trough when
  # you page past the top or bottom
  case $cmd {
    {units pages} {
      if {$way < 0} {
        if {$first == 0} {
          return
        }
      } else {
        if {$last == 1} {
          return
        }
      }
    }
  }
  eval $w.tree.list yview $args
  eval $w.labl.list yview $args
}

proc ModTree:destroy {w} {
  foreach u [winfo children $w] {
    catch {destroy $u}
  }
}

# clear any text highlight box (used by set/clearselection)
proc ModTree:clearTextHBox {w id} {
   global cvsglb

    # clear the tag corresponding to the text label
    catch {$w.tree.list delete HBox$id}
    $w.tree.list itemconfigure $id -fill $cvsglb(fg) 
}

# set a text highligh box (used by set/clearselection)
proc ModTree:setTextHBox {w id} {
   global cvsglb
   
   # get the bounding box for the text id
   set bbox [$w.tree.list bbox $id]
   if {[llength $bbox]==4} {
    # create rectangle with fill, tagged with the same ID as the text, so we can delete it later
    set i [eval $w.tree.list create rectangle $bbox -fill $cvsglb(hlbg) -tag HBox$id -outline \"\"] 
    $w.tree.list itemconfigure $id -fill $cvsglb(hlfg)
    $w.tree.list lower $i
  } 
}
