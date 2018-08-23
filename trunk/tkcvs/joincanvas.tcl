#
# Tcl Library for TkCVS
#

namespace eval joincanvas {
  variable instance 0

  proc new {localfile filelog {current_tagname {}}} {
    variable instance
    set my_idx $instance
    incr instance

    if {[catch "image type Modules"]} {
      workdir_images
    }
    if {[catch "image type Workdir"]} {
      modbrowse_images
    }

    #
    # Creates a new log canvas.  filelog must be the output of a cvs
    # log or rlog command.
    #
    namespace eval $my_idx {
      set my_idx [uplevel {concat $my_idx}]
      set filelog [uplevel {concat $filelog}]
      variable localfile [uplevel {concat $localfile}]
      variable current_tagname [uplevel {concat $current_tagname}]

      global cvscfg
      global cvsglb
      global cvs
      global tcl_platform

      # Height and width to draw boxes
      variable cvscanv
      set cvscanv(boxx) 60
      set cvscanv(boxy) 20
      set cvscanv(midx) [expr {$cvscanv(boxx) / 2}]
      set cvscanv(midy) [expr {$cvscanv(boxy) / 2}]
      set cvscanv(boxmin) 64
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
      variable joincanvas

      set joincanvas ".joincanvas$my_idx"

      proc parse_cvslog_tags {filelog} {
        variable joincanvas
        variable tags
        variable headrev

        gen_log:log T "ENTER ($joincanvas ...)"
        set loglist [split $filelog "\n"]
        set logstate "rcsfile"
        foreach logline $loglist {
          #puts "$logline"
          switch -exact -- $logstate {
            "rcsfile" {
              # Look for the first text line which should give the file name.
              set fileline [split $logline]
              if {[lindex $fileline 0] == "RCS"} {
                set logstate "head"
                continue
              }
            }
            "head" {
              set fileline [split $logline]
              if {[lindex $fileline 0] == "head:"} {
                set headrev [lindex $fileline 1]
                set logstate "tags"
                set taglist ""
                continue
              }
            }
            "tags" {
              # Any line with a tab leader is a tag
              if { [string index $logline 0] == "\t" } {
                set taglist "$taglist$logline\n"
                set tagitems [split $logline ":"]
                set tagrevision [string trim [lindex $tagitems 1]]
                set tagname [string trim [lindex $tagitems 0]]
                # Add all the tags to a picklist for our "since" tag
                ::picklist::used alltags $tagname

                set parts [split $tagrevision {.}]
                if {[expr {[llength $parts] & 1}] == 1} {
                  set parts [linsert $parts end-1 {0}]
                  set tagrevision [join $parts {.}]
                }
                # But we only want to know the branch tags
                if { [regexp {\.0\.\d+$} $tagrevision] } {
                  set tagstring [string trim [lindex $tagitems 0]]
                  lappend tags($tagrevision) $tagstring
                }
              } else {
                if {$logline == "description:"} {
                  # No more tags after this point
                  set logstate "searching"
                  continue
                }
                if {$logline == "----------------------------"} {
                  # Oops, missed something.
                  set logstate "revision"
                  continue
                }
              }
            }
            "terminated" {
              # ignore any further lines
              continue
            }
          }
        }
        ::picklist::used alltags ""
      }

      proc node {joincanvas rev x y} {
        global cvscfg
        variable cvscanv
        variable tags
        upvar treelist treelist
        upvar ylevel ylevel
        upvar ind ind
      
        gen_log:log T "ENTER ($rev $x $y)"
        $joincanvas.canvas create line \
          $x [expr {$y + $cvscanv(boxy)}] \
          $x [expr {$y + $cvscanv(space)}]

        gen_log:log T "LEAVE"
      }

      proc rectangle {joincanvas rev x y} {
        #
        # Breaks out some of the code from the joincanvas_draw_box procedure.
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
        $joincanvas.canvas create text \
           [expr {$x + 4}] [expr {$y + 2}] \
           -text "$tagtext" \
           -anchor nw -fill blue \
           -font {Helvetica -12 bold} \
           -tags b$rev

        set tagwidth [font measure {Helvetica -12 bold} \
           -displayof $joincanvas.canvas $tagtext]
        if {$tagwidth < $cvscanv(boxmin)} { set tagwidth $cvscanv(boxmin) }

        # draw the box
        set boxid [$joincanvas.canvas create rectangle \
          $x $y \
          [expr {$x + $tagwidth + 5}] [expr {$y + $cvscanv(boxy)}] \
          -width 3 \
          -fill gray90 \
          -tags [list b$rev rect$rev] \
        ]
        # Drop the fill color below the text so the text isn't hidden
        $joincanvas.canvas lower $boxid

        # Bind button-presses to the rectangles.
        if {$tags($rev) != ""} {
        $joincanvas.canvas bind b$rev <ButtonPress-1> \
           [namespace code "select_rectangle $rev $tags($rev)"]
        }

        if {"$current_tagname" == "$tagtext"} {
          you_are_here $rev $tagwidth $x $y
        }
        gen_log:log T "LEAVE"
      }

      proc unselect_all {} {
        variable joincanvas
        set t [$joincanvas.canvas gettags current]
        if {$t != {} } {return}
        unselect_rectangle
      }

      proc unselect_rectangle {} {
        variable joincanvas
        catch {$joincanvas.canvas itemconfigure SelA -fill gray90}
        $joincanvas.up.rversFrom delete 0 end
        $joincanvas.canvas dtag SelA
      }

      proc select_rectangle {rev tags} {
        global cvscfg
        variable joincanvas

        gen_log:log T "ENTER ($rev $tags)"

        unselect_rectangle
        $joincanvas.up.rversFrom delete 0 end
        $joincanvas.up.rversFrom insert end $tags
        $joincanvas.canvas addtag SelA withtag rect$rev
        $joincanvas.canvas itemconfigure SelA -fill $cvscfg(colourA)
      }

      proc fillcanvas {filename filelog} {
        global cvscfg
        variable joincanvas
        variable cvscanv
        variable headrev
        variable tags
        variable current_tagname
       
        gen_log:log T "ENTER ($filename <filelog suppressed>)"

        catch {unset tags}
        # Collect the history from the RCS log
        $joincanvas.canvas delete all
        parse_cvslog_tags $filelog

        # Sort the branch revisions
        set tagrevlist [lsort -command sortrevs [array names tags]]
        # Get rid of duplicates
        set revlist ""
        foreach t $tagrevlist {
          if {$t ni $revlist} {
            lappend revlist $t
          }
        }

        # Find everybody's parents.  Add parent nodes to a new nodelist.
        # Keep track of everybody's children
        set treelist ""
        foreach rev $revlist {
          gen_log:log D "$rev"
          # Find its parent
          set alist [split $rev "."]
          set alength [llength $alist]
          set isodd [expr {$alength % 2}]
          set parent($rev) [join [lrange $alist 0 [expr {$alength - 3}]] "."]
          #gen_log:log D " parent $parent($rev)"
          set parentbranch [join [lrange $alist 0 [expr {$alength - 5}]] "."]
          #gen_log:log D " parentbrancch $parentbranch"
          set branchnum       [lindex $alist [expr {$alength - 4}]]
          set branchparent [join [list $parentbranch 0 $branchnum] "."]
          #gen_log:log D " branchparent $branchparent"
          if {$isodd > 0} {
            set parent($rev) [join [lrange $alist 0 [expr {$alength - 2}]] "."]
            #gen_log:log D " parent $parent($rev)"
          }
          if {[string length $parentbranch] > 0} {
          gen_log:log D "set parent parent($rev)"
            set parent($rev) $branchparent
            lappend children($branchparent) $rev
          } else {
            lappend children($parent($rev)) $rev
          }
          # Add to new list of nodes
          if { ($parent($rev) ni $revlist) && ($parent($rev) ni $treelist) } {
            lappend treelist $parent($rev)
            gen_log:log D " add parent $parent($rev) of $rev"
          }
        }
        # Do it all over again for the new ones we added
        foreach rev $treelist {
          gen_log:log D "new $rev"
          # Find its parent
          set alist [split $rev "."]
          set alength [llength $alist]
          set isodd [expr {$alength % 2}]
          set parent($rev) [join [lrange $alist 0 [expr {$alength - 3}]] "."]
          #gen_log:log D " parent $parent($rev)"
          set parentbranch [join [lrange $alist 0 [expr {$alength - 5}]] "."]
          #gen_log:log D " parentbrancch $parentbranch"
          set branchnum       [lindex $alist [expr {$alength - 4}]]
          set branchparent [join [list $parentbranch 0 $branchnum] "."]
          #gen_log:log D " branchparent $branchparent"
          if {$isodd > 0} {
            set parent($rev) [join [lrange $alist 0 [expr {$alength - 2}]] "."]
            #gen_log:log D " parent $parent($rev)"
          }
          if {[string length $parentbranch] > 0} {
          gen_log:log D "set parent parent($rev)"
            set parent($rev) $branchparent
            lappend children($branchparent) $rev
          } else {
            lappend children($parent($rev)) $rev
          }
        }
        set treelist [concat $revlist $treelist]
        set treelist [lsort -command sortrevs $treelist]

        # Now prepare to draw the revision tree
        # Root first
        set y $cvscanv(space)
        set px(0) 10
        set x [font measure {Helvetica -12 bold} \
           -displayof $joincanvas.canvas $cvscfg(mergetrunkname)]

        set px(1) [expr {$px(0) + $x / 2}]
        set py(1) [expr {$cvscanv(boxy) - 4}]

        $joincanvas.canvas create text \
           $px(1) $y \
           -text "ROOT" \
           -anchor n -fill black \
           -font {Helvetica -12 bold}

        # Then the rest
        foreach rev $treelist {
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
            if {[info exists ylevel($parent($rev))] && $py($ind) > $ylevel($parent($rev))} {
              gen_log:log D "  jumping to level of parent"
              set py($ind) $ylevel($parent($rev))
              if {$ind > 2} {
                # Give it a node if its parent isn't in column1
                incr ylevel($parent($rev)) -$cvscanv(space)
                set px($ind) [expr {$px($pind) + $cvscanv(boxx) + $cvscanv(space)}]
                set py($ind) $ylevel($parent($rev))
                node $joincanvas $rev \
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
            #node $joincanvas $rev $px($ind) $py($ind)
            set py($ind) [expr {$py($ind) - ($nchildren($rev) - 1) * $cvscanv(space)}]
          } else {
            if {! [info exists tags($rev)]} {
              set tags($rev) ""
            }
            gen_log:log D "  tag:  $tags($rev)"
            rectangle $joincanvas $rev $px($ind) $py($ind)
            # Line linking it to parent
            if {$ind > 2} {
               set ly [expr {$ylevel($parent($rev)) + $cvscanv(midy)}]
            } else {
               set ly [expr {$py($ind) + $cvscanv(midy)}]
            }
            if {![info exists xlevel($parent($rev))]} {set xlevel($parent($rev)) $px([expr $ind-1])}
            $joincanvas.canvas create line \
              $xlevel($parent($rev)) [expr {$ly + 10}] \
              [expr {$xlevel($parent($rev)) + 10}] $ly \
              $px($ind) [expr {$py($ind) + $cvscanv(midy)}]
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

        set tags($headrev) $cvscfg(mergetrunkname)
        gen_log:log D "HEAD  $headrev"
        gen_log:log D "tagtext \"$tags($headrev)\""
        # Make a box for top of trunk
        set ylevel(trunk) [expr {$maxyind - $cvscanv(boxy)}]
        set tagwidth [font measure {Helvetica -12 bold} \
           -displayof $joincanvas.canvas $cvscfg(mergetrunkname)]
        if {$tagwidth < $cvscanv(boxmin)} { set tagwidth $cvscanv(boxmin) }
        set boxid [$joincanvas.canvas create rectangle \
          [expr {$px(1) - $tagwidth / 2}] $ylevel(trunk) \
          [expr {$px(1) + 5 + $tagwidth / 2}] \
          [expr {$ylevel(trunk) - $cvscanv(boxy)}] \
          -width 3 \
          -fill gray90 \
          -tags b$headrev]
        $joincanvas.canvas lower $boxid
        $joincanvas.canvas create text \
           [expr {$px(1) + 2}] [expr {$ylevel(trunk) - 2}] \
           -text "$cvscfg(mergetrunkname)" \
           -anchor s -justify center -fill blue \
           -font {Helvetica -12 bold} \
           -tags b$headrev
        # Bottom then top
        $joincanvas.canvas create line \
           $px(1) [expr {$cvscanv(space) - 4}] \
           $px(1) $ylevel(trunk)

        # Bind button-press
        $joincanvas.canvas bind b$headrev <ButtonPress-1> \
           [namespace code "select_rectangle $headrev $cvscfg(mergetrunkname)"]
        # Clicking in a blank part of the canvas unselects boxes
        bind $joincanvas.canvas <ButtonPress-1> \
           [namespace code unselect_all]


        # You are Here
        if {$current_tagname == "trunk"} {
          you_are_here $headrev $tagwidth \
            [expr {$px(1) - $tagwidth / 2 }] \
            [expr {$ylevel(trunk) - $cvscanv(boxy)}]
        }

        # now calculate the bounding box using the canvas bbox function
        set bbox [$joincanvas.canvas bbox all]
        set boty [lindex $bbox 1]
        set topy [lindex $bbox 3]
        set bheight [expr {$topy - $boty}]

        set origheight [lindex [$joincanvas.canvas config -height] 4]

        set screenHeight [winfo vrootheight .]
        if {$bheight > $screenHeight} {
          set bheight $screenHeight
        }
        if {$bheight > $origheight} {
          $joincanvas.canvas config -height $bheight
        }

        $joincanvas.canvas config -scrollregion $bbox
        $joincanvas.canvas yview moveto 0

        set here [$joincanvas.up.rversTo get]
        if {$here == ""} {
          cvsfail "I can't find where I am.  Perhaps the working directory isn't at the head of a branch?" $joincanvas
        }
        gen_log:log T "LEAVE"
      }

      proc you_are_here {rev offset hx hy} {
        variable cvscanv
        variable joincanvas
        variable tags

        gen_log:log T "ENTER ($rev $offset $hx $hy)"
        gen_log:log D "tags($rev) $tags($rev)"
        $joincanvas.canvas create image \
          [expr {$hx + $offset + 16}] [expr {$hy + $cvscanv(boxy)}] \
          -image Man -anchor s \
          -tag you_are_here_icon
        $joincanvas.canvas create text \
          [expr {$hx + $offset + 26}] [expr {$hy + $cvscanv(boxy)}] \
          -text "You are\nhere" -anchor sw \
          -fill red3 \
          -font {Helvetica -10 bold} \
          -tag you_are_here_icon

        # Put the name in the "To" entry and disable it.  You can only
        # merge to where you are.
        $joincanvas.up.rversTo configure -state normal
        $joincanvas.up.rversTo delete 0 end
        $joincanvas.up.rversTo insert end $tags($rev)
        $joincanvas.up.rversTo configure -state readonly
        $joincanvas.canvas bind b$rev <ButtonPress-1> {}
      }

      toplevel $joincanvas
      wm title $joincanvas "CVS Directory Merge"
      if {$tcl_platform(platform) != "windows"} {
        wm iconbitmap $joincanvas @$cvscfg(bitmapdir)/dirbranch.xbm
      }
      wm protocol $joincanvas WM_DELETE_WINDOW \
        [namespace code {$joincanvas.close invoke}]

      $joincanvas configure -menu $joincanvas.menubar
      menu $joincanvas.menubar

      $joincanvas.menubar add cascade -label "File" \
        -menu $joincanvas.menubar.file -underline 0
      menu $joincanvas.menubar.file
      $joincanvas.menubar.file add command -label "Close" -underline 0 \
        -command [namespace code {$joincanvas.close invoke}]
      $joincanvas.menubar.file add command -label "Exit" -underline 1 \
        -command { exit_cleanup 1 }

      $joincanvas.menubar add cascade -label "Help" \
        -menu $joincanvas.menubar.help -underline 0
      menu $joincanvas.menubar.help
      $joincanvas.menubar.help add command -label "Merge Tool" -underline 0 \
        -command directory_branch_viewer

      frame $joincanvas.up -relief groove -border 2
      pack $joincanvas.up -side top -fill x

      button $joincanvas.up.bworkdir -image Workdir \
       -command { workdir_setup }
      button $joincanvas.up.bmodbrowse -image Modules_cvs \
       -command { modbrowse_run cvs }

      label $joincanvas.up.lfname -text "Representative File" -anchor w
      entry $joincanvas.up.rfname -textvariable [namespace current]::repfile
      bind $joincanvas.up.rfname <Return> \
        [namespace code {join_getlog $repfile [namespace current]}]

      label $joincanvas.up.lversFrom -text "Merge From" -anchor w
      frame $joincanvas.up.eFrom -bg $cvscfg(colourA)
      entry $joincanvas.up.rversFrom

      label $joincanvas.up.lversSince -text "   Since" -anchor w
      frame $joincanvas.up.eSince -bg $cvscfg(colourB)
      ::picklist::clear alltags
      ::picklist::entry $joincanvas.up.rversSince "" alltags
      label $joincanvas.up.lversTo -text "Merge To" -anchor w
      entry $joincanvas.up.rversTo -relief groove \
        -bd 1 -relief sunk -state readonly -readonlybackground $cvsglb(bg)

      grid columnconf $joincanvas.up 1 -weight 1
      grid rowconf $joincanvas.up 3 -weight 1
      grid $joincanvas.up.lfname -column 0 -row 0 -sticky w
      grid $joincanvas.up.rfname -column 1 -row 0 -padx 3 -sticky ew
      grid $joincanvas.up.bworkdir -column 2 -row 0 -rowspan 2 \
        -sticky e -padx 2 -pady 1
      grid $joincanvas.up.lversFrom -column 0 -row 1 -sticky w
      grid $joincanvas.up.eFrom -column 1 -row 1 -sticky ew -padx 4
      grid $joincanvas.up.bmodbrowse -column 2 -row 2 -rowspan 2 \
        -sticky e -padx 2 -pady 1
      grid $joincanvas.up.lversSince -column 0 -row 2 -sticky w
      grid $joincanvas.up.eSince -column 1 -row 2 -sticky ew -padx 4
      grid $joincanvas.up.lversTo -column 0 -row 3 -sticky w
      grid $joincanvas.up.rversTo -column 1 -row 3 -padx 3 -sticky ew

      pack $joincanvas.up.rversFrom -in $joincanvas.up.eFrom \
        -padx 2 -pady 2 -fill x
      pack $joincanvas.up.rversSince -in $joincanvas.up.eSince \
        -padx 2 -pady 2 -fill x

      set textfont [$joincanvas.up.rfname cget -font]

      # Pack the bottom before the middle so it doesnt disappear if
      # the window is resized smaller
      frame $joincanvas.down -relief groove -border 2
      pack $joincanvas.down -side bottom -fill x

      set repfile $localfile

      # The canvas for the big picture
      canvas $joincanvas.canvas -relief sunken -border 2 \
        -yscrollcommand "$joincanvas.yscroll set" \
        -xscrollcommand "$joincanvas.xscroll set"
      scrollbar $joincanvas.xscroll -relief sunken -orient horizontal \
        -command "$joincanvas.canvas xview"
      scrollbar $joincanvas.yscroll -relief sunken \
        -command "$joincanvas.canvas yview"

      #
      # Create buttons
      #
      button $joincanvas.delta -image Mergediff \
          -command [namespace code {
                 set fromrev [$joincanvas.up.rversFrom get]
                 if {$fromrev == ""} {
                   cvsfail "Please select a branch!" $joincanvas; return
                 }
                 set sincerev [$joincanvas.up.rversSince.e get]
                 cvs_merge $joincanvas $fromrev $sincerev $fromrev .
                 }]

      button $joincanvas.down.blogfile -image Branches \
         -command "cvs_branches $repfile"
      frame $joincanvas.down.btnfm
      frame $joincanvas.down.closefm
      button $joincanvas.close -text "Close" \
        -command [namespace code "
                   destroy $joincanvas
                   namespace delete [namespace current]
                   exit_cleanup 0
                 "]

      pack $joincanvas.down.blogfile -side left \
        -ipadx 4 -ipady 4
      pack $joincanvas.down.btnfm -side left -fill y -expand 1
      pack $joincanvas.delta \
        -in $joincanvas.down.btnfm -side left \
        -ipadx 4 -ipady 4
      pack $joincanvas.down.closefm -side right -expand yes
      pack $joincanvas.close \
        -in $joincanvas.down.closefm -side right \
        -fill both -expand yes

      set_tooltips $joincanvas.down.blogfile \
         {"Revision Log and Branch Diagram of the current file"}
      set_tooltips $joincanvas.delta \
         {"Merge to current"}
      set_tooltips $joincanvas.up.bworkdir \
        {"Open the Working Directory Browser"}
      set_tooltips $joincanvas.up.bmodbrowse \
        {"Open the Repository Browser"}

      #
      # Put the canvas on to the display.
      #
      pack $joincanvas.xscroll -side bottom -fill x -padx 1 -pady 1
      pack $joincanvas.yscroll -side right -fill y -padx 1 -pady 1
      pack $joincanvas.canvas -fill both -expand 1

      $joincanvas.canvas delete all

      #
      # Window manager stuff.
      #
      wm minsize $joincanvas 1 1

      scrollbindings Canvas
      focus $joincanvas.canvas

      fillcanvas $localfile $filelog

      return [namespace current]
    }
  }
}

proc cvs_joincanvas { } {
# Find the bushiest file in the directory and diagram it
  global cvs
  global incvs
  global cvscfg
  global current_tagname

  gen_log:log T "ENTER"
  if {! $incvs} {
    cvs_notincvs
    return 1
  }
  set files [glob -nocomplain -types f -- .??* *]

  regsub -all {\$} $files {\$} files
  set commandline "$cvs -d $cvscfg(cvsroot) log $files"
  gen_log:log C "$commandline"
  catch {eval "exec $commandline"} raw_log
  set log_lines [split $raw_log "\n"]

  gen_log:log D "Directory tag: $current_tagname"
  foreach logline $log_lines {
    if {[string match "Working file:*" $logline]} {
      set filename [lrange [split $logline] 2 end]
      set nbranches($filename) 0
      continue
    }
    if {[string match "total revisions:*" $logline]} {
      set nrevs($filename) [lindex [split $logline] end]
      continue
    }
    if { [regexp {^\t[-\w]+: .*\.0\.\d+$} $logline] } {
      incr nbranches($filename)
    }
  }
  set bushiestfile ""
  set mostrevisedfile ""
  set nbrmax 0
  foreach br [array names nbranches] {
    if {$nbranches($br) > $nbrmax} {
      set bushiestfile $br
      set nbrmax $nbranches($br)
    }
  }
  set nrevmax 0
  foreach br [array names nrevs] {
    if {$nrevs($br) > $nrevmax} {
      set mostrevisedfile $br
      set nrevmax $nrevs($br)
    }
  }
  gen_log:log F "Bushiest file \"$bushiestfile\" has $nbrmax branches"
  gen_log:log F "Most Revised file \"$mostrevisedfile\" has $nrevmax revisions"

  # Sometimes we don't find a file with any branches at all, so bushiest
  # is empty.  Fall back to mostrevised.  All files have at least one rev.
  if {[string length $bushiestfile] > 0} {
    join_getlog $bushiestfile
  } else {
    join_getlog $mostrevisedfile
  }

  gen_log:log T "LEAVE"
}

# Get the file log.  Make a new canvas or re-draw an existing one.
proc join_getlog {filename {name_idx {}}} {
  global cvscfg
  global cvs
  global current_tagname

  gen_log:log T "ENTER ($filename $name_idx)"
  set commandline "$cvs -d $cvscfg(cvsroot) log \"$filename\""
  gen_log:log C "$commandline"
  set ret [catch {eval "exec $commandline"} view_this]
  # If you bail, sometimes you discard a perfectly good log
  #if {$ret} {
    #cvsfail $view_this
    #gen_log:log T "LEAVE ERROR ($view_this)"
    #return
  #}
  if {$name_idx == ""} {
    joincanvas::new $filename $view_this $current_tagname
  } else {
    $name_idx\::fillcanvas $filename $view_this
  }
  gen_log:log T "LEAVE"
}
