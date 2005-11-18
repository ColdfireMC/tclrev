#
# TCL Library for TkCVS
#

namespace eval svnjoin {
  variable instance 0

  proc new { relpath {current_tagname {}} } {
    variable instance
    set my_idx $instance
    incr instance

    #
    # Creates a new log canvas.
    #
    namespace eval $my_idx {
      set my_idx [uplevel {concat $my_idx}]
      variable relpath [uplevel {concat $relpath}]
      variable current_tagname [uplevel {concat $current_tagname}]

      global cvscfg
      global cvsglb
      global tcl_platform

      # Height and width to draw boxes
      variable cvscanv
      set cvscanv(boxx) 60
      set cvscanv(boxy) 20
      set cvscanv(midx) [expr {$cvscanv(boxx) / 2}]
      set cvscanv(midy) [expr {$cvscanv(boxy) / 2}]
      set cvscanv(boxmin) 72
      # Gaps between boxes
      set cvscanv(space) [expr {$cvscanv(boxy) + 16}]
      # Indent at top left of canvas
      set cvscanv(indx) 5
      set cvscanv(indy) 5
      # Static type variables used while drawing on the canvas.
      set cvscanv(xhigh) 0
      set cvscanv(yhigh) 0
      set cvscanv(xlow)  0
      set cvscanv(ylow)  0

      variable revlist
      variable revbranches
      variable tags
      variable headrev
      variable svnjoin

      set svnjoin ".svnjoin$my_idx"


      proc do_log { relpath } {
        global cvscfg
        variable revkind
        variable revname
        variable branchrevs
        variable revbranches
        variable allrevs

        # The trunk
      puts "\nTrunk"
        set branchrevs(trunk) {}
        # Can't use file join or it will mess up the URL
        if { $relpath == {} } {
          set path "$cvscfg(svnroot)/trunk"
        } else {
          set path "$cvscfg(svnroot)/trunk/$relpath"
        }
      
        set command "svn log $path"
        gen_log:log C "$command"
        set ret [catch {eval exec $command} log_output]
        if {$ret == 0} {
          set trunk_lines [split $log_output "\n"]
          set rr [short_parse_svnlog $trunk_lines trunk]
        } else {
          cvsfail "$log_output"
          return
        }
        foreach r $branchrevs(trunk) {
          puts " $r"
          set revkind($r) "revision"
        }
        set revkind($rr) "root"
        set revname($rr) "trunk"
      
        # Branches
      puts "Branches"
        set command "svn list $cvscfg(svnroot)/branches"
        gen_log:log C "$command"
        set ret [catch {eval "exec $command"} branches]
        if {$ret != 0} {
            gen_log:log E "$branches"
            puts "$branches"
            set branches ""
        }
        foreach branch $branches {
          gen_log:log D "$branch"
          # There can be files such as "README" here that aren't branches
          if {![string match {*/} $branch]} {continue}
          set branch [string trimright $branch "/"]
      puts " $branch"
          # Can't use file join or it will mess up the URL
          if { $relpath == {} } {
            set path "$cvscfg(svnroot)/branches/$branch"
          } else {
            set path "$cvscfg(svnroot)/branches/$branch/$relpath"
          }
          set command "svn log --stop-on-copy $path"
          gen_log:log C "$command"
          set ret [catch {eval exec $command} log_output]
          if {$ret != 0} {
            # This can happen a lot -let's not let it stop us
            gen_log:log E "$log_output"
            puts "$log_output"
            continue
          }
          set loglines [split $log_output "\n"]
          set rb [short_parse_svnlog $loglines $branch]
          foreach r $branchrevs($branch) {
            set revkind($r) "revision"
          }
          set revkind($rb) "branch"
          set revname($rb) "$branch"
      
          set command "svn log -q $path"
          gen_log:log C "$command"
          set ret [catch {eval exec $command} log_output]
          if {$ret != 0} {
            cvsfail "$log_output"
            return
          }
          set loglines [split $log_output "\n"]
          parse_q $loglines $branch
puts " branchrevs($branch) $branchrevs($branch)"
          set bp [lindex $allrevs($branch) [llength $branchrevs($branch)]]
          set revbranches($bp) $branch
puts " revbranches($bp) $revbranches($bp)"
set parent($revbranches($bp)) [lindex $branchrevs($branch) end]
puts " parent($revbranches($bp)) $bp"
          update idletasks
        }
      
        gen_log:log T "LEAVE"
      }

      proc short_parse_svnlog {lines r} {
        variable branchrevs

        set i 0
        set l [llength $lines]
        while {$i < $l} {
          set line [lindex $lines $i]
          #gen_log:log D "$i of $l:  $line"
          if [regexp {^--*$} $line] {
            # Next line is new revision
            incr i
            if {[expr {$l - $i}] <= 1} {break}
            set line [lindex $lines $i]
            set splitline [split $line "|"]
            set revnum [string trim [lindex $splitline 0]]
            lappend branchrevs($r) $revnum
            gen_log:log D "revnum $revnum"
            incr i 2
          }
          incr i
        }
        return $revnum
      }

      proc parse_q {lines r} {
        variable allrevs

        set allrevs($r) ""
        foreach line $lines {
#puts $line
          gen_log:log D "$line"
          if [regexp {^r} $line] {
            set splitline [split $line "|"]
#puts "$splitline"
            set revnum [string trim [lindex $splitline 0]]
#puts "revnum $revnum"
            lappend allrevs($r) $revnum
          }
        }
      }

      proc node {rev x y} {
        global cvscfg
        variable join_canvas
        variable cvscanv
        variable tags
        upvar treelist treelist
        upvar ylevel ylevel
        upvar ind ind
      
        gen_log:log T "ENTER ($rev $x $y)"
        $join_canvas create line \
          [expr {$x + $cvscanv(midy)}] [expr {$y + $cvscanv(midy)}] \
          $x [expr {$y + $cvscanv(boxy)}] \
          $x [expr {$y + $cvscanv(space)}]
        if {$cvscfg(logging) && [regexp -nocase {d} $cvscfg(log_classes)] && $ind < 2} {
          $join_canvas create text \
            [expr {$x + 4}] [expr {$y + 18}] \
            -text $rev \
            -fill red2 \
            -anchor nw
        }
        gen_log:log T "LEAVE"
      }

      proc sort_it_all_out {} {
        global cvscfg
        variable join_canvas
        variable revkind
        variable revname
        variable branchrevs
        variable revbranches
        variable logstate
        variable revnum
        variable rootbranch
        variable revbranch
  
        gen_log:log T "ENTER"

        # Sort the revision and branch lists and remove duplicates
puts "\nsort_it_all_out"
        foreach r [lsort -dictionary [array names revkind]] {
           puts "$r \"$revkind($r)\""
        }

        # Find out where to put the working revision icon (if anywhere)
        set command "svn log -q --stop-on-copy ."
        set cmd [exec::new $command]
        set log_output [$cmd\::output]
        set loglines [split $log_output "\n"]
        set svnstat [lindex $loglines 1]
        set revnum(current) [lindex $svnstat 0]
        gen_log:log D "revnum(current) $revnum(current)"
        puts "revnum(current) $revnum(current)"
        # We only needed these to place the you-are-here box.
        catch {unset rootbranch revbranch}
        DrawTree
        gen_log:log T "LEAVE"
      }

      proc DrawTree {} {
        global cvscfg
        variable branchrevs
        variable join_canvas
        variable cwd
        variable box_height
        variable xy
        variable boxwidth
        variable view_xoff
        variable view_yoff

        gen_log:log T "ENTER"
#puts "DrawTree"

        busy_start $join_canvas
        set view_xoff [lindex [$join_canvas xview] 0]
        set view_yoff [lindex [$join_canvas yview] 0]
        $join_canvas delete all
        set box_height [font metrics {Helvetica -10 bold} \
            -displayof $join_canvas -linespace]
          
          if {$branchrevs(trunk) != ""} {
            gen_log:log D "DrawBranch 0 0 {} trunk"
            DrawBranch 0 0 {} trunk
          } else {
            foreach a [array names branchrevs] {
              puts "   branchrevs($a) \"$branchrevs($a)\""
              if {$branchrevs($a) != ""} {
                gen_log:log D "DrawBranch 0 0 {} $a"
                DrawBranch 0 0 {} $a
                break
              }
            }
          }
          UpdateBndBox

          # Reselect the previously selected revisions
          #variable sel_tag
          #variable sel_rev
	  #foreach AorB {A B} {
            #SetSelection $AorB $sel_tag($AorB) $sel_rev($AorB)
          #}
          busy_done $join_canvas
        gen_log:log T "LEAVE"
        return
      }

      proc DrawBranch { x y root_rev branch } {
        variable join_canvas
        variable box_height
        variable font_norm_h
        variable revbranches
        variable branchrevs
        variable revnum

        gen_log:log T "ENTER ($x $y \"$root_rev\" $branch)"
        set top 1

        # Work out width and height of this limb, saving sizes of revisions
        set tag_width 0
        if {$branch == {current}} {
          set box_width [CalcCurrent $branch]
        } else {
          set box_width [CalcRoot $branch]
        }
        set height $box_height
        set rdata {}

        set revlist [lsort -dictionary -decreasing $branchrevs($branch)]
        foreach revision $revlist {
            set rtw 0
            set rbw $box_width
            set rh $box_height
          lappend rdata $rtw $rh
          incr height 1
          incr height $rh
        }
        # Position branch.
        # Look for overlap horizontally
        while {1} {
          $join_canvas addtag ol_x overlapping \
            [expr {$x - 1}] [expr {$y - $height }] \
            [expr {$x + $tag_width + $box_width}] $y
          set bbox [$join_canvas bbox ol_x]
          $join_canvas dtag ol_x
          if {$bbox == {}} {
            break
          }
          gen_log:log D "horizontal overlap with $bbox"
          # Move branch to rightmost point of overlapped objects plus some space
          # N.B. +1 because exactly equal counts as an overlap
          set x [expr {[lindex $bbox 2] + 1}]
        }
        # Look for overlap vertically
        $join_canvas addtag ol_y overlapping \
          $x [expr {$y - $height}] \
          [expr {$x + $tag_width + $box_width}] [expr {$y - $height}]
        set bbox [$join_canvas bbox ol_y]
        $join_canvas dtag ol_y
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
        gen_log:log D "revlist $revlist"
        set rl [llength $revlist]
        set c 0
        foreach revision [lrange $revlist 0 end] {rtag_width rheight} $rdata {
          #if {$revision == ""} {continue}
          incr c
          incr y 1
          incr y $rheight
          # For each branch off this revision, draw it to the right of this
          # revision box and a little above the centre line of this box.
          set x2 [expr {$x + $box_width}]
          set y2 [expr {$y - $box_height - 20}]
          set brevs {}
          set bxys {}
          if [info exists revbranches($revision)] {
            foreach r2 $revbranches($revision) {
              gen_log:log D " revbranches($revision): $r2"
              #if {! [info exists revbranches($r2)]} {continue}
              # Do we display the branch if it is empty?
              # If it's the you-are-here, we do anyway
              lappend brevs $r2
              foreach {lx y2 lbw rh lly} [DrawBranch $x2 $y2 $revision $r2] {
                lappend bxys $lx $lbw $rh $lly
                break
              }
            }
            set x2 [expr {$lx + $lbw + 1}]
          }
          # y2 may have changed to accomodate a long branch. If so we need
          # to figure out what our y should be
          set y [expr {$y2 + $box_height/2 + 10}]
          set rx [expr {$x + $box_width}]
          set ry [expr {$y - $box_height/2}]
          foreach b $brevs {bx bw rh ly} $bxys {
            set mx [expr {$bx + $bw/2}]
            set my [expr {$ly + $rh + 1}]
            $join_canvas create line \
                $rx $ry   $mx $ry  $mx $my\
                -arrow last -arrowshape { 6 6.7 3 } -width 2 \
                -fill blue \
                -tags [list A$revision B[lindex $branchrevs($b) 0] delta active]
          }
          if {$revision == $revnum(current)} {
            foreach {box_width curr_height} [CalcCurrent $branch] { break }
            set y [expr {$y - 1}]
            set y [expr {$y - $rheight}]
            DrawCurrent $x $y $box_width $curr_height $revision
            $join_canvas create line \
              $midx [expr {$y + 1}] $midx $y \
              -arrow last -arrowshape { 6 6.7 3 } -width 2
            incr y 10
            incr y $rheight
          }
          if {!$top} {incr y [expr {$box_height/2}]}
          if {$last_y != {}} {
            $join_canvas create line \
              $midx $last_y $midx [expr {$y - $box_height}] \
              -arrow first -arrowshape { 6 6.7 3 } -width 2 \
              -tags [list A$revision B$last_rev delta active]
          }
          #DrawRevision $x $y $rtag_width $box_width $rheight $revision
          set top 0
          UpdateBndBox
          set last_y $y
          set last_rev $revision
        }
        incr y 10
        if {[info exists revision]} {
          DrawRoot $x $y $box_width $revision $branch
#puts "Finished $branch\n"
        }
        gen_log:log T "LEAVE"
        set ret_y [expr {$y + $box_height + 1}]
        return [list $x $ret_y $box_width $box_height $last_y]
      }

      proc DrawRoot { x y box_width root_rev branch } {
        global cvscfg
        variable box_height
        variable join_canvas

        gen_log:log T "ENTER ($x $y $box_width $root_rev $branch)"
#puts "DrawRoot ($branch) x=$x y=$y"
        # draw the box
        set rheight $box_height
        incr y $rheight
        $join_canvas create rectangle \
          $x $y \
          [expr {$x + $box_width}] [expr {$y - $rheight}] \
            -width 2 -fill gray90 -outline blue
        set mx [expr {$x + $box_width/2}]
        set my [expr {$y - $box_height}]
        # This is the short arrow above the rectangle
        $join_canvas create line \
           $mx $my $mx [expr {$my - 10}] \
           -arrow last -width 2 \
           -fill blue
        set tx [expr {$x + $box_width/2}]
        set ty [expr {$y - 2}]
        gen_log:log D "branch $branch"
        $join_canvas create text \
            $tx $ty \
            -text $branch \
            -anchor s \
            -font {Helvetica -10 bold} -fill blue
        gen_log:log T "LEAVE"
        return
      }

      proc DrawCurrent { x y box_width box_height revision } {
        variable join_canvas
        variable revtags
        variable curr_x
        variable curr_y

        gen_log:log T "ENTER ($x $y $box_width $box_height $revision)"
#puts "DrawCurrent ($revision) x=$x y=$y"
        # draw the box
        set tx [expr {$x + $box_width}]
        set ty [expr {$y - $box_height}]
        $join_canvas create rectangle \
          $x $y $tx $ty \
          -width 2 -fill gray90 -outline red3
        set pad \
          [expr {($box_width - [image width Man] \
            - [font measure {Helvetica -10 bold} -displayof $join_canvas {You are}]) \
            / 3}]
        set ty [expr {$y - [expr {$box_height/2}]}]
        # add the contents
        $join_canvas create image \
          [expr {$x + $pad}] $ty \
          -image Man -anchor w \
          -tags [list box active]
        $join_canvas create text \
          [expr {$x + $box_width - $pad}] $ty \
          -text "You are\nhere" -anchor e \
          -fill red3 \
          -tags [list box active]
        gen_log:log T "LEAVE"
        return
      }

      proc CalcRoot { branch } {
        global cvscfg
        variable join_canvas

        gen_log:log T "ENTER ($branch)"
        set box_width 0
        set w [font measure {Helvetica -10 bold} \
            -displayof $join_canvas $branch]
        if {$w > $box_width} {
          set box_width $w
        }
        gen_log:log T "LEAVE"
        return $box_width 
      }

      proc CalcCurrent { revision } {
        variable curr
        variable join_canvas

        gen_log:log T "ENTER ($revision)"
        set box_width \
          [expr {[image width Man] \
            + [font measure {Helvetica -10 bold} -displayof $join_canvas {You are}] }]
        set box_height [image height Man]
        set h [expr {2 * 10}]
        if {$h > $box_height} {
          set box_height $h
        }
        gen_log:log T "LEAVE"
        return [list $box_width $box_height]
      }


      proc UpdateBndBox {} {
        variable join_canvas
        variable view_xoff
        variable view_yoff
        variable curr_x
        variable curr_y

        gen_log:log T "ENTER"
        foreach {x1 y1 x2 y2} { 0 0 100 100 } { break }
        foreach {x1 y1 x2 y2} [$join_canvas bbox all] { break }
        $join_canvas configure \
          -scrollregion [list \
            [expr {$x1 - 5}] [expr {$y1 - 5}] \
            [expr {$x2 + 5}] [expr {$y2 + 5}]
          ]

        if {[info exists curr_x]} {
          set canv_width [$join_canvas cget -width]
          set canv_height [$join_canvas cget -height]
          gen_log:log D "visible width $canv_width"
          gen_log:log D "visible height $canv_height"
          gen_log:log D "x $curr_x"
          gen_log:log D "y $curr_y"
          set bbox [$join_canvas bbox all]
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
            set curr_x [expr {$curr_x - 3 * [font measure {Helvetica -10 bold} \
                     -displayof $join_canvas {You are}]}]
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
        $join_canvas xview moveto $view_xoff
        $join_canvas yview moveto $view_yoff
        update
        gen_log:log T "LEAVE"
        return
      }

      toplevel .svnjoin$my_idx
      if {$tcl_platform(platform) != "windows"} {
        wm iconbitmap $svnjoin @$cvscfg(bitmapdir)/dirbranch.xbm
      }
      wm protocol $svnjoin WM_DELETE_WINDOW \
        [namespace code {$svnjoin.close invoke}]

      frame $svnjoin.up -relief groove -border 2
      pack $svnjoin.up -side top -fill x

      label $svnjoin.up.lversFrom -text "Merge From" -anchor w
      entry $svnjoin.up.rversFrom
      label $svnjoin.up.lversSince -text "   Since" -anchor w
      entry $svnjoin.up.rversSince
      label $svnjoin.up.lversTo -text "Merge To" -anchor w
      entry $svnjoin.up.rversTo

      grid columnconf $svnjoin.up 1 -weight 1
      grid rowconf $svnjoin.up 3 -weight 1
      grid $svnjoin.up.lversFrom -column 0 -row 1 -sticky w
      grid $svnjoin.up.rversFrom -column 1 -row 1 -padx 4 -sticky ew
      grid $svnjoin.up.lversSince -column 0 -row 2 -sticky w
      grid $svnjoin.up.rversSince -column 1 -row 2 -padx 4 -sticky ew
      grid $svnjoin.up.lversTo -column 0 -row 3 -sticky w
      grid $svnjoin.up.rversTo -column 1 -row 3 -padx 4 -sticky ew

      # Pack the bottom before the middle so it doesnt disappear if
      # the window is resized smaller
      frame $svnjoin.down -relief groove -border 2
      pack $svnjoin.down -side bottom -fill x

      # The canvas for the big picture
      set join_canvas $svnjoin.canvas
      canvas $join_canvas -relief sunken -border 2 \
        -yscrollcommand "$svnjoin.yscroll set" \
        -xscrollcommand "$svnjoin.xscroll set"
      scrollbar $svnjoin.xscroll -relief sunken -orient horizontal \
        -command "$join_canvas xview"
      scrollbar $svnjoin.yscroll -relief sunken \
        -command "$join_canvas yview"

      #
      # Create buttons
      #
      button $svnjoin.help -text "Help" \
        -padx 0 -pady 0 \
        -command directory_branch_viewer
      button $svnjoin.join -image Mergebranch \
          -command [namespace code {
                   merge_dialog \
                     [$svnjoin.up.rversFrom get] \
                     "" \
                     {}
                 }]
      button $svnjoin.delta -image Mergediff \
          -command [namespace code {
                   merge_dialog \
                     [$svnjoin.up.rversFrom get] \
                     [$svnjoin.up.rversSince get] \
                     {}
                 }]

      button $svnjoin.close -text "Close" \
        -padx 0 -pady 0 \
        -command [namespace code "
                   destroy $svnjoin
                   namespace delete [namespace current]
                   exit_cleanup 0
                 "]

      pack $svnjoin.help \
           $svnjoin.join \
           $svnjoin.delta \
        -in $svnjoin.down -side left \
        -ipadx 1 -ipady 1 -fill both -expand 1
      pack $svnjoin.close \
        -in $svnjoin.down -side right \
        -ipadx 1 -ipady 1 -fill both -expand 1

      set_tooltips $svnjoin.join \
         {"Merge to current"}
      set_tooltips $svnjoin.delta \
         {"Merge changes to current"}

      #
      # Put the canvas on to the display.
      #
      pack $svnjoin.xscroll -side bottom -fill x -padx 1 -pady 1
      pack $svnjoin.yscroll -side right -fill y -padx 1 -pady 1
      pack $join_canvas -fill both -expand 1

      $join_canvas delete all

      #
      # Window manager stuff.
      #
      wm minsize $svnjoin 1 1

      wm title $svnjoin "Branches"
      scrollbindings Canvas
      focus $svnjoin

      do_log $relpath
      sort_it_all_out

      return [namespace current]
    }
  }
}

proc svn_joincanvas { } {
# Find the bushiest file in the directory and diagram it
  global cvscfg
  global cvsglb

  gen_log:log T "ENTER"
  gen_log:log D "Relative Path: $cvsglb(relpath)"
  svnjoin::new $cvsglb(relpath)
  gen_log:log T "LEAVE"
}

