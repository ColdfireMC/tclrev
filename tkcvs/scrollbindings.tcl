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
