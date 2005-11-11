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
          if { $cvsglb(relpath) == {} } {
            set path "$cvscfg(svnroot)/branches/$branch/$filename"
          } else {
            set path "$cvscfg(svnroot)/branches/$branch/$cvsglb(relpath)/$filename"
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
      puts " revbranches($bp) $branch"
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

      proc node {svnjoin rev x y} {
        global cvscfg
        variable cvscanv
        variable tags
        upvar treelist treelist
        upvar ylevel ylevel
        upvar ind ind
      
        gen_log:log T "ENTER ($rev $x $y)"
        $svnjoin.canvas create line \
          [expr {$x + $cvscanv(midy)}] [expr {$y + $cvscanv(midy)}] \
          $x [expr {$y + $cvscanv(boxy)}] \
          $x [expr {$y + $cvscanv(space)}]
        if {$cvscfg(logging) && [regexp -nocase {d} $cvscfg(log_classes)] && $ind < 2} {
          $svnjoin.canvas create text \
            [expr {$x + 4}] [expr {$y + 18}] \
            -text $rev \
            -fill red2 \
            -anchor nw
        }
        gen_log:log T "LEAVE"
      }

      proc rectangle {svnjoin rev x y} {
        #
        # Breaks out some of the code from the svnjoin procedure.
        # Work out the width of the text to go in the box first, then draw a
        # box wide enough.
        #
        global cvscfg
        variable cvscanv
        variable tags
        variable current_tagname
        upvar x xpos

        gen_log:log T "ENTER ($rev $x $y)"

        set parts [split $rev "."]

        set tagtext $tags($rev)
        gen_log:log D "$tagtext\t$rev"
        $svnjoin.canvas create text \
           [expr {$x + 4}] [expr {$y + 2}] \
           -text "$tagtext" \
           -anchor nw -fill blue \
           -font {Helvetica -12 bold} \
           -tags b$rev

        set tagwidth [font measure {Helvetica -12 bold} \
           -displayof $svnjoin.canvas $tagtext]
        if {$tagwidth < $cvscanv(boxmin)} { set tagwidth $cvscanv(boxmin) }

        # Put the version number under the box if in debug mode.
        if {$cvscfg(logging) && [regexp -nocase {d} $cvscfg(log_classes)]} {
          $svnjoin.canvas create text \
            [expr {$x + 4}] [expr {$y + 18}] \
            -text $rev \
            -fill red2 \
            -anchor nw
        }

        # draw the box
        set boxid [$svnjoin.canvas create rectangle \
          $x $y \
          [expr {$x + $tagwidth + 5}] [expr {$y + $cvscanv(boxy)}] \
          -width 3 \
          -fill gray90 \
          -tags b$rev ]
        # Drop the fill color below the text so the text isn't hidden
        $svnjoin.canvas lower $boxid

        # Bind button-presses to the rectangles.
        if {$tags($rev) != ""} {
        $svnjoin.canvas bind b$rev <ButtonPress-1> \
           [namespace code "select_rectangle $tags($rev)"]
        }

        if {"$current_tagname" == "$tagtext"} {
          you_are_here $rev $tagwidth $x $y
        }
        gen_log:log T "LEAVE"
      }

      proc select_rectangle {rev} {
        global cvscfg
        variable svnjoin

        gen_log:log T "ENTER ($rev)"

        $svnjoin.up.rversFrom delete 0 end
        $svnjoin.up.rversFrom insert end $rev
      }

      proc fillcanvas {} {
        global cvscfg
        variable revkind
        variable branchrevs
        variable revbranches
        variable svnjoin
        variable cvscanv
        variable current_tagname
       
        gen_log:log T "ENTER "

        catch {unset branches}
        foreach r [lsort -dictionary [array names revkind]] {
           puts "$r \"$revkind($r)\""
           if {$revkind($r) == "root"} {set headrev $r}
        }
        if {[info exists branchrevs(trunk)]} {
           puts "branchrevs(trunk) $branchrevs(trunk)"
        }
puts "revbranches: [array names revbranches]"
        # Now prepare to draw the revision tree
        # Root first
        set y $cvscanv(space)
        set px(0) 10
        set x [font measure {Helvetica -12 bold} \
           -displayof $svnjoin.canvas Trunk]

        set px(1) [expr {$px(0) + $x / 2}]
        set py(1) [expr {$cvscanv(boxy) - 4}]

        $svnjoin.canvas create text \
           $px(1) $y \
           -text "ROOT" \
           -anchor n -fill black \
           -font {Helvetica -12 bold}

        # Then the rest
        foreach branch [array names revbranches] {
          gen_log:log D "$rev"
          if {[info exists children($rev)]} {
            foreach r $children($rev) {
              gen_log:log D "\tparent of $r"
            } 
            set nchildren($rev) [llength $children($rev)]
            set kids [array names children $rev.*]
            foreach kid $kids {
              set descendents $children($kid)
              set ndescendents [llength $descendents]
              gen_log:log D "\tgranchildren: $descendents"
              incr nchildren($rev) $ndescendents
            }
          } else {
            set nchildren($rev) 0
          }
          gen_log:log D "\t$nchildren($rev) descendents"
          if {[info exists parent($rev)]} {
            gen_log:log D "\tchild of $parent($rev)"
          }

          set alist [split $rev "."]
          set alength [llength $alist]
          # Round up instead of down
          set ind [expr {($alength +1)/ 2}]
          set pind [expr {$ind - 1}]

          if {! [info exists py($ind)]} {
            gen_log:log D "  starting new column $ind"
            set py($ind) $cvscanv(space)
            set px($ind) [expr {$px($pind) + $cvscanv(midx) + $cvscanv(space)}]
          }
          if {[info exists parent($rev)] && $parent($rev) != ""} {
            gen_log:log D "  this one has a parent in col >=1"
            if {$py($ind) > $ylevel($parent($rev))} {
              gen_log:log D "  jumping to level of parent"
              set py($ind) $ylevel($parent($rev))
              if {$ind > 2} {
                # Give it a node if its parent isn't in column1
                incr ylevel($parent($rev)) -$cvscanv(space)
                set px($ind) [expr {$px($pind) + $cvscanv(boxx) + $cvscanv(space)}]
                set py($ind) $ylevel($parent($rev))
                node $svnjoin $rev \
                  [expr {$px($pind) + $cvscanv(midx)}] \
                  [expr {$py($ind) - 1}]
              }
            } else {
              gen_log:log D "  parent not higher"
              set py($ind) [expr {$py($ind) - $cvscanv(space)}]
            }
            set xlevel($rev) [expr {$px($ind) + $cvscanv(midx)}]
          } else {
            set py($ind) [expr {$py($ind) - $cvscanv(space)}]
            gen_log:log D "  just stacking it above the last one"
            set xlevel($rev) $px($ind)
          }
          set ylevel($rev) $py($ind)

          # For column 1, just draw a nondescript node
          if {$ind == 1} {
            node $svnjoin $rev $px($ind) $py($ind)
            set py($ind) [expr {$py($ind) - ($nchildren($rev) - 1) * $cvscanv(space)}]
          } else {
            if {! [info exists tags($rev)]} {
              set tags($rev) ""
            }
            gen_log:log D "  tag:  $tags($rev)"
            rectangle $svnjoin $rev $px($ind) $py($ind)
            # Line linking it to parent
            $svnjoin.canvas create line \
              [expr {$xlevel($parent($rev)) + 10}] \
              [expr {$ylevel($parent($rev)) + $cvscanv(midy)}] \
              $px($ind) \
              [expr {$py($ind) + $cvscanv(midy)}]
            set py($ind) [expr {$py($ind) - $nchildren($rev) * $cvscanv(space)}]
          }
        }

        set py(1) [expr {$cvscanv(boxy) - 4}]
        set maxyind 0
        foreach i [array names py] {
          if {$py($i) < $maxyind} {
            set maxyind $py($i)
          }
        }

        set tags($headrev) HEAD
        gen_log:log D "HEAD  $headrev"
        gen_log:log D "tagtext \"$tags($headrev)\""
        # Make a box for top of trunk
        set ylevel(trunk) [expr {$maxyind - $cvscanv(boxy)}]
        set tagwidth [font measure {Helvetica -12 bold} \
           -displayof $svnjoin.canvas Trunk]
        set boxid [$svnjoin.canvas create rectangle \
          [expr {$px(1) - $tagwidth / 2}] $ylevel(trunk) \
          [expr {$px(1) + 5 + $tagwidth / 2}] \
          [expr {$ylevel(trunk) - $cvscanv(boxy)}] \
          -width 3 \
          -fill gray90 \
          -tags b$headrev]
        $svnjoin.canvas lower $boxid
        $svnjoin.canvas create text \
           [expr {$px(1) + 2}] [expr {$ylevel(trunk) - 2}] \
           -text "Trunk" \
           -anchor s -justify center -fill blue \
           -font {Helvetica -12 bold} \
           -tags b$headrev
        # Bottom then top
        $svnjoin.canvas create line \
           $px(1) [expr {$cvscanv(space) - 4}] \
           $px(1) $ylevel(trunk)

        # Bind button-press
        $svnjoin.canvas bind b$headrev <ButtonPress-1> \
           [namespace code "select_rectangle HEAD"]

        # You are Here
        if {$current_tagname == ""} {
          you_are_here $headrev $tagwidth \
            [expr {$px(1) - $tagwidth / 2 }] \
            [expr {$ylevel(trunk) - $cvscanv(boxy)}]
        }

        # now calculate the bounding box using the canvas bbox function
        set bbox [$svnjoin.canvas bbox all]
        set boty [lindex $bbox 1]
        set topy [lindex $bbox 3]
        set bheight [expr {$topy - $boty}]

        set origheight [lindex [$svnjoin.canvas config -height] 4]

        set screenHeight [winfo vrootheight .]
        if {$bheight > $screenHeight} {
          set bheight $screenHeight
        }
        if {$bheight > $origheight} {
          $svnjoin.canvas config -height $bheight
        }

        $svnjoin.canvas config -scrollregion $bbox
        $svnjoin.canvas yview moveto 0
        gen_log:log T "LEAVE"
      }

      proc you_are_here {rev offset hx hy} {
        variable cvscanv
        variable svnjoin
        variable revname

        gen_log:log T "ENTER ($rev $offset $hx $hy)"
        gen_log:log D "revname($rev) $revname($rev)"
        $svnjoin.canvas create image \
          [expr {$hx + $offset + 16}] [expr {$hy + $cvscanv(boxy)}] \
          -image Man -anchor s \
          -tag you_are_here_icon
        $svnjoin.canvas create text \
          [expr {$hx + $offset + 26}] [expr {$hy + $cvscanv(boxy)}] \
          -text "You are\nhere" -anchor sw \
          -fill red3 \
          -font {Helvetica -10 bold} \
          -tag you_are_here_icon

        # Put the name in the "To" entry and disable it.  You can only
        # merge to where you are.
        $svnjoin.up.rversTo delete 0 end
        $svnjoin.up.rversTo insert end $revname($rev)
        set disbg [lindex [$svnjoin.up configure -background] 4]
        $svnjoin.up.rversTo configure -bg $disbg -state disabled
        $svnjoin.canvas bind b$rev <ButtonPress-1> {}
      }

      toplevel $svnjoin
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
      canvas $svnjoin.canvas -relief sunken -border 2 \
        -yscrollcommand "$svnjoin.yscroll set" \
        -xscrollcommand "$svnjoin.xscroll set"
      scrollbar $svnjoin.xscroll -relief sunken -orient horizontal \
        -command "$svnjoin.canvas xview"
      scrollbar $svnjoin.yscroll -relief sunken \
        -command "$svnjoin.canvas yview"

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
      pack $svnjoin.canvas -fill both -expand 1

      $svnjoin.canvas delete all

      #
      # Window manager stuff.
      #
      wm minsize $svnjoin 1 1

      wm title $svnjoin "Branches"
      scrollbindings Canvas
      focus $svnjoin.canvas

      do_log $relpath
      fillcanvas

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

