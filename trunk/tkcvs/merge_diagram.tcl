#
# TCL Library for TkCVS
#

# Simplified version of Jaggy's logcanvas browser, for use in the
# directory merge tool
#

namespace eval ::mergecanvas {
  variable instance 0

  proc new {filename how command scope} {
    #
    # Creates a new log canvas.
    #
    variable instance
    set my_idx $instance
    incr instance
    global current_tagname
    global module_dir
    variable sys
    variable loc

    namespace eval $my_idx {
      set my_idx [uplevel {concat $my_idx}]
      set how [uplevel {concat $how}]
      set filename [uplevel {concat $filename}]
      set command [uplevel {concat $command}]
      set scope [uplevel {concat $scope}]
      global cvscfg
      global cvsglb
      global tcl_platform
      variable revbranches
      variable branchrevs
      variable revtags
      variable mergecanvas ".mergecanvas$my_idx"

      set sys_loc [split $how {,}]
      set sys [lindex $sys_loc 0]
      set loc [lindex $sys_loc 1]

      proc ConfigureButtons {sys fname} {
        global cvsglb
        variable mergecanvas

        switch -- $sys {
         "SVN" {
          }
         "CVS" {
          }
        }
      }

      proc CalcCurrent { revision } {
        variable curr
        variable font_bold
        variable font_bold_h
        variable mergecanvas

        gen_log:log T "ENTER ($revision)"
        set box_width \
          [expr {[image width Man] \
                 + $curr(padx) \
                 + [font measure $font_bold \
                     -displayof $mergecanvas.canvas {You are}] \
                 + $curr(padx,2)}]
        set box_height [image height Man]
        set h [expr {2 * $font_bold_h}]
        if {$h > $box_height} {
          set box_height $h
        }
        incr box_height $curr(pady,2)
        gen_log:log T "LEAVE"
        return [list $box_width $box_height]
      }

      proc DrawCurrent { x y box_width box_height revision } {
        variable curr
        variable font_bold
        variable font_bold_h
        variable mergecanvas
        variable root_info
        variable revtags
        variable curr_x
        variable curr_y

        gen_log:log T "ENTER ($x $y $box_width $box_height $revision)"
        set curr_x $x
        set curr_y $y
        # draw the box
        set tx [expr {$x + $box_width}]
        set ty [expr {$y - $box_height}]
        $mergecanvas.canvas create rectangle \
          $x $y $tx $ty \
          -width 2 -fill gray90 -outline red3
        set pad \
          [expr {($box_width - [image width Man] \
            - [font measure $font_bold -displayof $mergecanvas.canvas {You are}]) \
            / 3}]
        set ty [expr {$y - $box_height/2}]
        # add the contents
        $mergecanvas.canvas create image \
          [expr {$x + $pad}] $ty \
          -image Man -anchor w
        $mergecanvas.canvas create text \
          [expr {$x + $box_width - $pad}] $ty \
          -text "You are\nhere" -anchor e \
          -fill red3 \
          -font $font_bold
        gen_log:log T "LEAVE"
        return
      }

      proc CalcRoot { branch } {
        global cvscfg
        variable curr
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable mergecanvas
        variable root_info
        variable revtags

        #gen_log:log T "ENTER ($branch)"
        set box_width 0
        foreach s [subst $root_info] {
          set w [font measure $font_norm -displayof $mergecanvas.canvas $s]
          if {$w > $box_width} {
            set box_width $w
          }
        }
        incr box_width $curr(padx,2)
        #gen_log:log T "LEAVE"
        return [list $box_width \
          [expr {$curr(pady,2) + [llength [subst $root_info]] * $font_norm_h}]]
      }

      proc DrawRoot { x y box_width box_height root_rev branch } {
        global cvscfg
        variable curr
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable mergecanvas
        variable root_info
        variable revtags

puts "DrawRoot [subst $root_info] ( $x $y $box_width $box_height $root_rev $branch )"
puts "DrawRoot $root_info ( $x $y $box_width $box_height $root_rev $branch )"
        gen_log:log T "ENTER ($x $y $box_width $box_height $root_rev $branch )"
        # draw the box
        set revtag $revtags($branch)
puts "REVTAG $revtag"
        $mergecanvas.canvas create rectangle \
          $x $y \
          [expr {$x + $box_width}] [expr {$y - $box_height}] \
            -width 2 \
            -fill gray90 -outline blue \
            -tags b$revtag

        set tx [expr {$x + $box_width/2}]
        set ty [expr {$y - $curr(pady)}]

        gen_log:log D "[subst $root_info]"
        foreach s [subst $root_info] {
          $mergecanvas.canvas create text \
            $tx $ty \
            -text $s \
            -anchor s \
            -font $font_norm -fill blue \
            -tags b$revtag

          incr ty -$font_norm_h
        }

        $mergecanvas.canvas bind b$revtag <ButtonPress-1> \
           [namespace code "select_rectangle $revtag"]

        gen_log:log T "LEAVE"
        return
      }

      proc select_rectangle {rev} {
        global cvscfg
        variable mergecanvas

        gen_log:log T "ENTER ($rev)"

        $mergecanvas.up.rversFrom delete 0 end
        $mergecanvas.up.rversFrom insert end $rev
      }

      proc CalcRevision { revision } {
        global cvscfg
        variable opt
        variable curr
        variable box_height
        variable rev_info
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable mergecanvas
        variable revtags
        variable tlist

        #gen_log:log T "ENTER ($revision)"
        set height $box_height
        set tag_width 0
        set box_width 0
        set tlist($revision) {}

        foreach s [subst $rev_info] {
          set w [font measure $font_norm -displayof $mergecanvas.canvas $s]
          if {$w > $box_width} {
            set box_width $w
          }
        }
        incr box_width $curr(padx,2)
        #gen_log:log T "LEAVE"
        #return [list $tag_width $box_width $height]
        return [list $tag_width $box_width 0]
      }

      proc DrawBranch { x y root_rev branch } {
        variable mergecanvas
        variable opt
        variable curr
        variable highest_y
        variable box_height
        variable branchrevs
        variable revbranches
        variable revtags

        gen_log:log T "ENTER ($x $y $root_rev $branch)"
if {$y < $highest_y} { set highest_y $y}
        # What revisions to show on this branch?
        if {$branchrevs($branch) == {}} {
          set revlist {}
        } else {
          # Always have the head revision
          set revlist [lindex $branchrevs($branch) 0]
          foreach r [lrange $branchrevs($branch) 1 end-1] {
            # Only if there are non-empty branches off this revision
            foreach b $revbranches($r) {
              if {$branchrevs($b) != {}} {
                lappend revlist $r
                break
              }
            }
          }
          if {[llength $branchrevs($branch)] > 1} {
            # Always have the first revision on a branch
            set bq [lindex $branchrevs($branch) end]
            if {[info exists revbranches($bq)] && $revbranches($bq) != ""} {
            lappend revlist [lindex $branchrevs($branch) end]
            }
          }
        }

        # Work out width and height of this limb, saving sizes of revisions
        set tag_width 0
        if {$branch == {current}} {
puts "Branch equals current"
          foreach {box_width root_height} [CalcCurrent $branch] { break }
        } else {
          foreach {box_width root_height} [CalcRoot $branch] { break }
        }
        set height [expr {$root_height + $curr(spcy)}]
        set rdata {}
        foreach revision $revlist {
          set rtw 0
          set rbw 0
          set rh 0
          if {$revision == {current}} {
puts "Revision equals current"
            foreach {rbw rh} [CalcCurrent $revision] { break }
          }
          lappend rdata $rtw $rh
          if {$rtw > $tag_width} {
            set tag_width $rtw
          }
          if {$rbw > $box_width} {
            set box_width $rbw
          }
          incr height $curr(spcy)
          incr height $rh
        }
        # Position branch.
        # Look for overlap horizontally
        while {1} {
          $mergecanvas.canvas addtag ol_x overlapping \
            [expr {$x - $curr(spcx)}] [expr {$y - $height + $curr(yfudge)}] \
            [expr {$x + $tag_width + $box_width}] $y
            set bbox [$mergecanvas.canvas bbox ol_x]
          $mergecanvas.canvas dtag ol_x
          if {$bbox == {}} {
          break
        }
        gen_log:log D "horizontal overlap with $bbox"
          # Move branch to rightmost point of overlapped objects plus some space
          # N.B. +1 because exactly equal counts as an overlap
          set x [expr {[lindex $bbox 2] + $curr(spcx) + 1}]
        }
        # Look for overlap vertically
        $mergecanvas.canvas addtag ol_y overlapping \
          $x [expr {$y - $height}] \
          [expr {$x + $tag_width + $box_width}] [expr {$y - $height +\
               $curr(yfudge)}]
        set bbox [$mergecanvas.canvas bbox ol_y]
        $mergecanvas.canvas dtag ol_y
        if {$bbox != {}} {
          # Move down to make space
          gen_log:log D "vertical overlap with $bbox"
          incr y [expr {[lindex $bbox 3] - ($y - $height)}]
        }
        # Position to top of branch
        incr x $tag_width
        incr y -$height
        # Draw the branch
        set midx [expr {$x + $box_width/2}]
        set last_y {}
        foreach revision $revlist {rtag_width rheight} $rdata {
          incr y $curr(spcy)
          incr y $rheight
          # For each branch off this revision, draw it to the right of this
          # revision box and a little above the centre line of this box.
          set x2 [expr {$x +$box_width + $curr(spcx)}]
          set y2 [expr {$y - $box_height/2 - $curr(boff)}]
          set brevs {}
          set bxys {}
          if {[info exists revbranches($revision)]} {
            foreach r2 $revbranches($revision) {
              # Do we display the branch if it is empty?
              # If it's the you-are-here, we do anyway
              if {$branchrevs($r2) == {} && $r2 != {current}} {
                continue
              }
              lappend brevs $r2
              foreach {lx y2 lbw rh lly} [DrawBranch $x2 $y2 $revision $r2] {
puts "DrawBranch ($revision $r2) returned ($lx $y2 $lbw $rh $lly)"
                lappend bxys $lx $lbw $rh $lly
                break
              }
              set x2 [expr {$lx + $lbw + $curr(spcx)}]
            }
          }
          # y2 may have changed to accomodate a long branch. If so we need
          # to figure out what our y should be
          set y [expr {$y2 + $box_height/2 + $curr(boff)}]
          set rx [expr {$x + $box_width/2}]
          set ry [expr {$y - $box_height/2}]
          set by [expr {$ry - $curr(boff) + 2}]
          foreach b $brevs {bx bw rh ly} $bxys {
            set mx [expr {$bx + $bw/2}]
            if {$b == {current}} {
              DrawCurrent $bx $by $bw $rh $revision
            } else {
              set last_rev [lindex $branchrevs($b) 0]
              if {$last_rev == {current}} {
                set last_rev [lindex $branchrevs($b) 1]
              }
              DrawRoot $bx $by $bw $rh $revision $b
            }
            $mergecanvas.canvas lower [ \
              $mergecanvas.canvas create line \
                $rx [expr {$y + $curr(boff)} + 2]\
                $rx $ry $mx $ry $mx $by \
                -arrow last -arrowshape $curr(arrowshape) \
                -width 2 \
                -fill blue
            ]
          }
          if {$revision == {current}} {
            DrawCurrent $x $y $box_width $rheight $revision
          }
          set last_y $y
          set last_rev $revision
        }
        gen_log:log T "LEAVE"
        return [list $x [expr {$y + $root_height + $curr(spcy)}] \
        $box_width $root_height $last_y]
      }
  
      proc UpdateBndBox {} {
        variable mergecanvas
        variable font_bold
        variable view_xoff
        variable view_yoff
        variable curr_x
        variable curr_y

        #gen_log:log T "ENTER"

        foreach {x1 y1 x2 y2} [$mergecanvas.canvas bbox all] { break }
        $mergecanvas.canvas configure \
          -scrollregion [list \
            [expr {$x1 - 5}] [expr {$y1 - 5}] \
            [expr {$x2 + 5}] [expr {$y2 + 5}]
          ]

        if {[info exists curr_x]} {
          set canv_width [$mergecanvas.canvas cget -width]
          set canv_height [$mergecanvas.canvas cget -height]
          gen_log:log D "visible width $canv_width"
          gen_log:log D "visible height $canv_height"
          gen_log:log D "x $curr_x"
          gen_log:log D "y $curr_y"
          set bbox [$mergecanvas.canvas bbox all]
          set llx [lindex $bbox 0]
          set lly [lindex $bbox 1]
          set urx [lindex $bbox 2]
          set ury [lindex $bbox 3]
          set bbox_width [expr {$urx - $llx}]
          set bbox_height [expr {$ury - $lly}]
          gen_log:log D "diagram width $bbox_width"
          gen_log:log D "diagram height $bbox_height"
          set curr_y [expr {$curr_y - [image height Man]}]
          if {$curr_x > $canv_width} {
            set curr_x [expr {$curr_x - 3 * [font measure $font_bold \
                     -displayof $mergecanvas.canvas {You are}]}]
            gen_log:log D "positioning x:  new x $curr_x"
          } else {
            gen_log:log D "not re-positioning x"
            set curr_x 0
          }
          set abs_y [expr abs($curr_y)]
          if {$abs_y > [expr {$bbox_height - $canv_height}]} {
            set abs_y [expr {$canv_height - $curr_y}]
            gen_log:log D "positioning y:  new y $abs_y"
          } else {
            gen_log:log D "not re-positioning y"
            set curr_y 0
          }
          set view_xoff [expr {$curr_x / ($bbox_width * 1.0)}]
          set view_yoff [expr {1 - ($abs_y / $bbox_height * 1.0)}]
        }
        gen_log:log D "set offset $view_xoff $view_yoff"
        $mergecanvas.canvas xview moveto $view_xoff
        $mergecanvas.canvas yview moveto $view_yoff
        update
        #gen_log:log T "LEAVE"
        return
      }
  
      proc DrawTree { {now {}} } {
        global cvscfg
        global logcfg
        variable scope
        variable mergecanvas
        variable box_height
        variable root_info
        variable boxwidth
        variable view_xoff
        variable view_yoff
        variable curr
        variable rev_info
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable font_bold_h
        variable highest_y 0

        variable revtags
        variable revbranches
        variable branchrevs

        gen_log:log T "ENTER ($now)"
        foreach a [array names $scope\::revtags] {
          set revtags($a) [set $scope\::revtags($a)]
        }
        foreach a [array names $scope\::revbranches] {
          set revbranches($a) [set $scope\::revbranches($a)]
        }
        foreach a [array names $scope\::branchrevs] {
          set branchrevs($a) [set $scope\::branchrevs($a)]
        }

        busy_start $mergecanvas
        set view_xoff [lindex [$mergecanvas.canvas xview] 0]
        set view_yoff [lindex [$mergecanvas.canvas yview] 0]
        $mergecanvas.canvas delete all
        set root_info {}
        append root_info {$branch }
        append root_info {$revtags($branch) }
        set rev_info {}

        set my_size $logcfg(font_size)
        set font_norm [font create \
          -family Helvetica -size $my_size]
        set font_norm_h [font metrics \
          $font_norm -displayof $mergecanvas -linespace]
        set font_bold [font create \
          -family Helvetica -size $my_size -weight bold]
        set font_bold_h [font metrics \
          $font_bold -displayof $mergecanvas -linespace]
        # Scale the layout constants
        foreach x {spcx spcy yfudge boff} {
          set curr($x) [expr {round($logcfg($x) * $font_norm_h)}]
          if {$curr($x) < 1} {
            set curr($x) 1
          }
        }
        foreach x {padx pady tspcb width} {
          set curr($x) $logcfg($x)
          set curr($x,2) [expr {$curr($x) << 1}]
        }
        set curr(arrowshape) {}
        foreach x $logcfg(arrowshape) {
          lappend curr(arrowshape) $x
        }
        set box_height [expr {$curr(pady,2) + [llength $rev_info]*$font_norm_h}]
        foreach a [array names revtags] {
          if {$revtags($a) == "trunk"} {
            set trunkrev $a
          }
        }
        if {! [info exists trunkrev]} {
           set min 100000
           foreach a [array names revtags] {
             if {$revtags($a) != {} } {
               set rnum [string trimleft $a {r}]
               if {$rnum < $min} {set min $rnum}
             }
           }
           set basebranch $revtags(r$min)
        }

        # Start drawing, beginning with the trunk
        if {[info exists trunkrev]} {
          foreach {lx y2 lbw rh lly} [DrawBranch 0 0 {} $trunkrev] {
            lappend bxys $lx $lbw $rh $lly
             break
          }
          set x2 [expr {$lx + $lbw + $curr(spcx)}]
          set mx [expr {$lx + $lbw/2}]
          set ry [expr {$y2 - $rh/2 - $curr(spcy)}]
          set by [expr {$y2 - $curr(boff)}]
puts "drawing root axis arrow"
          $mergecanvas.canvas lower [$mergecanvas.canvas create line \
            $mx $ry $mx [expr {$highest_y + 2}] \
            -arrow last -arrowshape $curr(arrowshape) \
            -width 2
          ]

          foreach {box_width root_height} [CalcRoot $trunkrev] { break }
          DrawRoot $lx $y2 $lbw $rh $trunkrev $trunkrev
          UpdateBndBox
        } elseif {[info exists basebranch]} {
          gen_log:log D "DrawBranch 0 0 {} $basebranch"
          if {! [info exists revtags($basebranch)]} {set revtags($basebranch) {} }
          DrawBranch 0 0 {} $basebranch
          UpdateBndBox
        }

        busy_done $mergecanvas
        gen_log:log T "LEAVE"
        return
      }

      toplevel $mergecanvas
      wm title $mergecanvas "$sys Log $filename"
      if {$tcl_platform(platform) != "windows"} {
        wm iconbitmap $mergecanvas @$cvscfg(bitmapdir)/dirbranch.xbm
      }

      wm protocol $mergecanvas WM_DELETE_WINDOW \
        [namespace code {$mergecanvas.close invoke}]

      frame $mergecanvas.up -relief groove -border 2
      pack $mergecanvas.up -side top -fill x

      label $mergecanvas.up.lversFrom -text "Merge From" -anchor w
      entry $mergecanvas.up.rversFrom
      label $mergecanvas.up.lversSince -text "   Since" -anchor w
      entry $mergecanvas.up.rversSince
      label $mergecanvas.up.lversTo -text "Merge To" -anchor w
      entry $mergecanvas.up.rversTo
      # Put the name in the "To" entry and disable it.  You can only
      # merge to where you are.
      $mergecanvas.up.rversTo delete 0 end
      $mergecanvas.up.rversTo insert end $current_tagname
      $mergecanvas.up.rversTo configure -state readonly -bg $cvsglb(textbg)

      grid columnconf $mergecanvas.up 1 -weight 1
      grid rowconf $mergecanvas.up 3 -weight 1
      grid $mergecanvas.up.lversFrom -column 0 -row 1 -sticky w
      grid $mergecanvas.up.rversFrom -column 1 -row 1 -padx 4 -sticky ew
      grid $mergecanvas.up.lversSince -column 0 -row 2 -sticky w
      grid $mergecanvas.up.rversSince -column 1 -row 2 -padx 4 -sticky ew
      grid $mergecanvas.up.lversTo -column 0 -row 3 -sticky w
      grid $mergecanvas.up.rversTo -column 1 -row 3 -padx 4 -sticky ew

      # Pack the bottom before the middle so it doesnt disappear if
      # the window is resized smaller
      frame $mergecanvas.down -relief groove -border 2
      pack $mergecanvas.down -side bottom -fill x

      # The canvas for the diagram
      canvas $mergecanvas.canvas -relief sunken -border 2 \
        -yscrollcommand "$mergecanvas.yscroll set" \
        -xscrollcommand "$mergecanvas.xscroll set"
      scrollbar $mergecanvas.xscroll -relief sunken -orient horizontal \
        -command "$mergecanvas.canvas xview"
      scrollbar $mergecanvas.yscroll -relief sunken \
        -command "$mergecanvas.canvas yview"

      #
      # Create buttons
      #
      button $mergecanvas.help -text "Help" \
        -padx 0 -pady 0 \
        -command directory_branch_viewer
      button $mergecanvas.join -image Mergebranch \
          -command [namespace code {
                   variable sys
                   merge_dialog $sys \
                     [$mergecanvas.up.rversFrom get] \
                     "" \
                     {}
                 }]
      button $mergecanvas.delta -image Mergediff \
          -command [namespace code {
                   variable sys
                   merge_dialog $sys \
                     [$mergecanvas.up.rversFrom get] \
                     [$mergecanvas.up.rversSince get] \
                     {}
                 }]

      button $mergecanvas.close -text "Close" \
        -padx 0 -pady 0 \
        -command [namespace code "
                   destroy $mergecanvas
                   namespace delete [namespace current]
                   exit_cleanup 0
                 "]

      pack $mergecanvas.help \
           $mergecanvas.join \
           $mergecanvas.delta \
        -in $mergecanvas.down -side left \
        -ipadx 1 -ipady 1 -fill both -expand 1
      pack $mergecanvas.close \
        -in $mergecanvas.down -side right \
        -ipadx 1 -ipady 1 -fill both -expand 1

      set_tooltips $mergecanvas.join \
         {"Merge to current"}
      set_tooltips $mergecanvas.delta \
         {"Merge changes to current"}

      #
      # Put the canvas on to the display.
      #
      pack $mergecanvas.xscroll -side bottom -fill x -padx 1 -pady 1
      pack $mergecanvas.yscroll -side right -fill y -padx 1 -pady 1
      pack $mergecanvas.canvas -fill both -expand 1

      $mergecanvas.canvas delete all

      wm minsize $mergecanvas 1 1
      scrollbindings Canvas
      focus $mergecanvas

      return [list [namespace current] $mergecanvas]
    }
  }
}
