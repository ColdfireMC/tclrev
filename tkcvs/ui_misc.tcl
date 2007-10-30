# Bindings to make canvases scroll.  Canvases have no bindings at all
# by default.
proc scrollbindings {bindtag} {
  # Page keys
  bind $bindtag <ButtonPress-1>    [list focus %W]
  bind $bindtag <Next>  [list %W yview scroll  1 pages]
  bind $bindtag <Prior> [list %W yview scroll -1 pages]
  bind $bindtag <Up>    [list %W yview scroll -1 units]
  bind $bindtag <Down>  [list %W yview scroll  1 units]
  bind $bindtag <Left>  [list %W xview scroll -1 pages]
  bind $bindtag <Right> [list %W xview scroll  1 pages]
  # Middle button dragging
  bind $bindtag <B2-Motion> [list dragbind %W %x %y]
  # Wheelmouse
  bind $bindtag <MouseWheel> [list wheelbind %W %D]
  bind $bindtag <ButtonPress-4> [list %W yview scroll -1 pages]
  bind $bindtag <ButtonPress-5> [list %W yview scroll 1 pages]
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

proc bind_show {w {mode "-verbose"}} {
  puts $w
  foreach tag [bindtags $w] {
    puts "\t$tag"
    foreach spec [bind $tag] {
      puts "\t\t$spec"
      if {$mode == "-verbose"} {
        #bind $tag
        set cmd [bind $tag $spec]
        set cmd [string trim $cmd "\n"]
        regsub -all "\n" $cmd "\n\t\t\t" cmd
        puts "\t\t\t$cmd"
      }
    }
  }
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

# Take a color like $d9d9d9 and darken it
proc rgb_shadow {color} {
  set rgb_color [winfo rgb . $color]
  set shadow [format #%02x%02x%02x [expr (9*[lindex $rgb_color 0])/2560] \
                                   [expr (9*[lindex $rgb_color 1])/2560] \
                                   [expr (9*[lindex $rgb_color 2])/2560]]
  return $shadow
}

# See if two colors might too close to distinguish, for highlighting
proc rgb_diff {c1 c2} {
  set rgb_c1 [winfo rgb . $c1]
  set rgb_c2 [winfo rgb . $c2]

  set r1 [lindex $rgb_c1 0]
  set g1 [lindex $rgb_c1 1]
  set b1 [lindex $rgb_c1 2]
  set r2 [lindex $rgb_c2 0]
  set g2 [lindex $rgb_c2 1]
  set b2 [lindex $rgb_c2 2]
  #puts "$r1 $g1 $b1"
  #puts "$r2 $g2 $b2"

  set maxdiff 0
  set dr [expr {abs($r2 - $r1)}]
  if {$dr > $maxdiff} {set maxdiff $dr}
  set dg [expr {abs($g2 - $g1)}]
  if {$dg > $maxdiff} {set maxdiff $dg}
  set db [expr {abs($b2 - $b1)}]
  if {$db > $maxdiff} {set maxdiff $db}
  #puts "$dr $dg $db"
  #puts "maxdiff: $maxdiff"
  return $maxdiff
}

proc is_gray {color} {
  set rgb_color [winfo rgb . $color]
  set r [lindex $rgb_color 0]
  set g [lindex $rgb_color 1]
  set b [lindex $rgb_color 2]

  set isgray 0
  if {$r == $g && $r == $b} {
    set isgray 1
  }
  return $isgray
}

proc static {args} {
    global staticvars
    set procName [lindex [info level -1] 0]
    foreach varPair $args {
        set varName [lindex $varPair 0]
        if {[llength $varPair] != 1} {
            set varValue [lrange $varPair 1 end]
        } else {
            set varValue {}
        }
        if {! [info exists staticvars($procName:$varName)]} {
            set staticvars($procName:$varName) $varValue
        }
        uplevel 1 "upvar #0 staticvars($procName:$varName) $varName"
    }
}

proc nop {} {}

