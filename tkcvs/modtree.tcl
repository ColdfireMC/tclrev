# Adapted from tree.tcl released under GPL by
#
# Copyright (C) 1997,1998 D. Richard Hipp
#
# $Revision: 1.18 $
#

#
# Create a new two-paned widget for the modules.
#
proc ModTree:create {w {open_func {}} } {
  global Tree
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($w $open_func)"
  set Tree(open_function) $open_func

  if {[catch "image type ModTree:closedbm"]} {
    ModTree:loadimages
  }

  ModTree:panedwindow_create $w
  ModTree:panedwindow_divide $w 0.4
  set parent [winfo parent $w]

  canvas $w.tree.list
  canvas $w.labl.list

  set cvsglb(fg) [lindex [.modbrowse.bottom.buttons.modfuncs.filebrowse configure -foreground] 4]
  set cvsglb(dfg) \
      [lindex [.modbrowse.top.bworkdir configure -disabledforeground] 4]
  set buttonhilite \
      [lindex [.modbrowse.top.bworkdir configure -highlightbackground] 4]
  set cvsglb(canvbg) [lindex [$w.tree.list configure -background] 4]
  set selcolor [option get . selectColor selectColor]

  if {[string length $selcolor]} {
    set cvsglb(hlbg) $selcolor
  }
  if {$cvsglb(hlbg) == $cvsglb(canvbg)} {
    set cvsglb(hlbg) $buttonhilite
  }

  scrollbar $parent.yscroll -orient vertical -highlightthickness 0 \
      -command "ModTree:scroll_windows $w"
  pack $parent.yscroll -side right -fill y
  bind $w.tree.list <1> "ModTree:clearselection $w"
  foreach canv {tree labl} {
    $w.$canv.list configure -yscrollcommand "$parent.yscroll set"
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

    # These frames are just to keep the label-windows on the canvas
    # from drawing over the frame relief when scrolling
    frame $w.$canv.head -relief raised -bd 2
    label $w.$canv.head.lbl
    pack $w.$canv.head -side top -fill x -expand no -padx 2
    pack $w.$canv.head.lbl -fill x -expand yes
    pack $w.$canv.list -side top -ipadx 2 -fill both -expand yes
  }
  $w.tree.head.lbl configure -text "Module"
  $w.labl.head.lbl configure -text "Information"

  ModTree:dfltconfig $w /
  set Tree(vsize) 16
  ModTree:buildwhenidle $w
  set Tree($w:selection) {}
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

  gen_log:log T "ENTER ($w $v $name \"$title\" $args)"
  set dir [file dirname $v]
  set n [file tail $v]

  if {![info exists Tree($w:$dir:open)]} {
    cvsfail "parent item \"$dir\" is missing" .modbrowse
  }
  set i [lsearch -exact $Tree($w:$dir:children) $n]
  if {$i>=0} {
    cvsfail "item \"$v\" already exists" .modbrowse
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
  gen_log:log T "LEAVE"
}

#
# Delete element $v from the tree $w.  If $v is /, then the widget is
# deleted.
#
proc ModTree:delitem {w v} {
  global Tree

  gen_log:log T "ENTER ($w $v)"
  if {![info exists Tree($w:$v:open)]} return
  if {[string compare $v /]==0} {
    # delete the whole widget
    catch {destroy $w.tree}
    catch {destroy $w.labl}
    set parent [winfo parent $w]
    catch {destroy $parent.yscroll}
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
  gen_log:log T "LEAVE"
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

  gen_log:log T "ENTER ($w)"
  $w.tree.list delete all
  $w.labl.list delete all
  catch {unset Tree($w:buildpending)}
  set Tree($w:y) 30
  ModTree:buildlayer $w / $Tree(vsize)
  $w.tree.list config -scrollregion [$w.tree.list bbox all]
  # Use tree's bbox for labl, because labl's is a little shorter
  # but we need to keep them in sync
  $w.labl.list config -scrollregion [$w.tree.list bbox all]
  gen_log:log T "LEAVE"
}

# Internal use only.
# Build a single layer of the tree on the canvas.  Indent by $in pixels
proc ModTree:buildlayer {w v in} {
  global Tree
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER ($w $v $in)"
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
      incr x 24
    }
    # Draw the label
    set lbl $Tree($w:$vx/$c:name)


    $w.tree.list create text $x $y \
        -text $lbl \
        -fill $cvsglb(fg) \
        -font $cvscfg(listboxfont) -anchor w \
        -tag $w.tree.list.tx$j
    
    $w.tree.list bind $w.tree.list.tx$j <1> "ModTree:setselection $w \"$vx/$c\""
    $w.tree.list bind $w.tree.list.tx$j <Enter> "ModTree:flash $w \"$vx/$c\""
    $w.tree.list bind $w.tree.list.tx$j <Leave> "ModTree:unflash $w \"$vx/$c\""

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
         $w.tree.list bind $k <1> "set Tree($w:$vx/$c:open) 0; ModTree:build $w"
         ModTree:buildlayer $w $vx/$c [expr {$in+$Tree(vsize)+8}]
      } else {
         set k [$w.tree.list create image $in $y -image ModTree:closedbm]
         if {$Tree(open_function) == {} } {
           $w.tree.list bind $k <1> "set Tree($w:$vx/$c:open) 1; \
                                    ModTree:build $w"
         } else {
           $w.tree.list bind $k <1> "set Tree($w:$vx/$c:open) 1; \
                                    $Tree(open_function) $w $vx/$c; \
                                    ModTree:build $w"
         }
      }
    }
  }
  if {![info exists y]} {return}
  set j [$w.tree.list create line $in $start $in [expr {$y+1}] -fill gray50 ]
  $w.tree.list lower $j
  gen_log:log T "LEAVE"
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
  gen_log:log T "LEAVE"
}

proc ModTree:close {w v} {
  global Tree
  if {[info exists Tree($w:$v:open)] && $Tree($w:$v:open)==1} {
    set Tree($w:$v:open) 0
    ModTree:build $w
  }
  gen_log:log T "LEAVE"
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
  global cvsglb

  gen_log:log T "ENTER ($w \"$v\")"

  # Clear old selection
  set oldv $Tree($w:selection)
  if {$oldv != ""} {
    set j $Tree($w:$oldv:tag)
    ModTree:clearTextHBox $w $w.tree.list.tx$j
  }

  # Hilight new selection
  if {$v != ""} {
    set Tree($w:selection) $v
    set j $Tree($w:$v:tag)
    ModTree:setTextHBox $w $w.tree.list.tx$j
    gen_log:log D "$v   $Tree($w:$v:name)"
    set modbrowse_module $Tree($w:$v:name)
    set modbrowse_path $v
  }
  gen_log:log T "LEAVE"
}

# Clear selection, invoked when clicking over a blank 
proc ModTree:clearselection {w} {
  global Tree
  global modbrowse_module

  gen_log:log T "ENTER ($w)"
 # Don't clear unless we are'nt over anything
  if {[ $w.tree.list gettags current ] == "" } {
    set Tree($w.tree:selection) {}
    ModTree:setselection $w ""
    set modbrowse_module ""
  }
}

proc ModTree:flash {widg v} {
  global Tree
  global cvsglb

  set j $Tree($widg:$v:tag)
  ModTree:setTextHBox $widg $widg.tree.list.tx$j
}

proc ModTree:unflash {widg v} {
  global Tree
  global cvsglb

  set j $Tree($widg:$v:tag)

  # Don't unflash if this is one that is selected:
  if { $Tree($widg:selection) != $v  } {
  	ModTree:clearTextHBox $widg $widg.tree.list.tx$j
  }

}

proc ModTree:scroll_windows {w args} {
  #gen_log:log T "ENTER ($w $args)"
  set parent [winfo parent $w]

  set yget [$parent.yscroll get]
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

proc ModTree:drag_windows {w W y} {
#Scrolling caused by dragging

  set height [$W cget -height]
  #gen_log:log D "$w %y $height"
  if {$y < 0} {set y 0}
  if {$y > $height} {set y $height}
  set yfrac [expr {double($y) / $height}]

  eval $w.tree.list yview moveto $yfrac
  eval $w.labl.list yview moveto $yfrac
}

proc ModTree:panedwindow_create {w} {

  frame $w
  frame $w.tree
  place $w.tree -relx 0.0 -rely 0.5 -anchor w -relwidth 0.5 -relheight 1.0
  frame $w.labl
  place $w.labl -relx 1.0 -rely 0.5 -anchor e -relwidth 0.5 -relheight 1.0

  frame $w.sash -width 4 -borderwidth 2 -relief raised
  place $w.sash -relx 0.5 -rely 0.5 -relheight 1.0 -anchor c

  frame $w.grip -width 10 -height 10 -borderwidth 2 -relief raised \
      -cursor sb_h_double_arrow
  place $w.grip -relx 0.5 -y 25 -anchor c

  bind $w.grip <ButtonPress-1>   "ModTree:panedwindow_grab $w"
  bind $w.grip <B1-Motion>       "ModTree:panedwindow_drag $w %X"
  bind $w.grip <ButtonRelease-1> "ModTree:panedwindow_drop $w %X"
}

proc ModTree:panedwindow_grab {w} {
  $w.grip configure -relief sunken
}

proc ModTree:panedwindow_drag {w x} {
  # Where we are now, relative to the west side of $w
  set relX [expr {$x - [winfo rootx $w]}]
  # How far we can go to the right relative to the west side of $w
  set maxX [winfo width $w]
  # minX is 0
  # Our position as a fraction of the traversible space
  set frac [expr {double($relX) / $maxX}]
  # Rails to keep us from going any further
  if {$frac < 0.05} {
    set frac 0.05
  }
  if {$frac > 0.95} {
    set frac 0.95
  }
  place $w.sash -relx $frac
  place $w.grip -relx $frac
  return $frac
}

proc ModTree:panedwindow_drop {w x} {
  set frac [ModTree:panedwindow_drag $w $x]
  ModTree:panedwindow_divide $w $frac
  $w.grip configure -relief raised
}

proc ModTree:panedwindow_divide {w frac} {
  place $w.sash -relx $frac
  place $w.grip -relx $frac

  place $w.tree -relwidth $frac
  place $w.labl -relwidth [expr {1 - $frac}]
}

# clear any text highlight box (used by set/clearselection)
proc ModTree:clearTextHBox {w id} {
   global cvsglb

    # clear the tag corresponding to the text label
    catch {$w.tree.list delete HBox$id}
    $w.tree.list itemconfigure $id -fill $cvsglb(textfg) 
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
