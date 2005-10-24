#
# TCL Library for TkCVS
#

#
# Contains procedures used for the log canvas for tkCVS.
#
# This is a major rewrite over the previous version. It uses a
# top down, recursive, branch-at-a-time, latest-revision-first
# algorithm to layout the graph sensibly.
# -- Mike Jagdis <jaggy@purplet.demon.co.uk>
#

namespace eval ::branch_canvas {
  variable instance 0

  proc new {relpath filename} {
    #
    # Creates a new log canvas.  If filename is not "no file" then it is
    # the file name in the local directory that this applies to.
    #
gen_log:log T "ENTER ($relpath $filename)"
    variable instance
    set my_idx $instance
    incr instance
    #global current_tagname

    set cwd [pwd]
    if {[catch "image type Fileview"]} {
      #::workdir::images
      workdir_images
    }
    if {[catch "image type Workdir"]} {
      #::repository::images
      modbrowse_images
    }
    #if {![info exists current_tagname]} {
      #set current_tagname ""
      #if {$localfile != "no file"} {
        #cvsroot_check $cwd
        #read_cvs_dir [file join $cwd CVS]
      #}
    #}

    namespace eval $my_idx {
      set my_idx [uplevel {concat $my_idx}]
      global cvscfg
      global cvs
      global tcl_platform
      variable filename [uplevel {concat $filename}]
      variable relpath [uplevel {concat $relpath}]
      variable cmd_log
      # Global constants scaled by current scaling factor for this instance
      variable curr
      # User options for info display for this instance
      variable opt
      variable revwho
      variable revdate
      variable revtime
      variable branchrevs
      variable revbranches
      variable revcomment
      variable tags
      variable sel_tag
      set sel_tag(A) {}
      set sel_tag(B) {}
      variable sel_rev
      set sel_rev(A) {}
      set sel_rev(B) {}
      variable branch_canvas ".branch_canvas$my_idx"

      proc reloadLog { } {
        global cvscfg
        #global current_tagname
        variable directory
        variable command
        variable cmd_log
        variable branch_canvas
        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable revkind
        variable revname
        variable tags
        variable branchrevs
        variable allrevs
        variable revbranches
        variable logstate
        variable cwd
        variable relpath
        variable filename

        gen_log:log T "ENTER"
        catch { $branch_canvas.canvas delete all }
        catch { unset revwho }
        catch { unset revdate }
        catch { unset revtime }
        catch { unset revcomment }
        catch { unset tags }
        catch { unset branchrevs }
        catch { unset revbranches }
        catch { unset revkind }
        catch { unset revname }
        set cwd [pwd]

        # might as well put someting in there
        $branch_canvas.up.rfname insert end "$relpath/$filename"

        busy_start $branch_canvas
        # The trunk
puts "Trunk"
        set tags(trunk) {}
        set branchrevs(trunk) {}
        # if the file was added on a branch, this will error out.
        # Come to think of it, there's nothing especially privileged
        #  about the trunk
        set command "svn log $cvscfg(svnroot)/trunk/$relpath/$filename"
        gen_log:log C "$command"
        set ret [catch {eval exec $command} log_output]
        if {$ret == 0} {
          set trunk_lines [split $log_output "\n"]
          set rr [parse_svnlog $trunk_lines trunk]
        } else {
          cvsfail "$log_output"
          return
        }
        foreach r $branchrevs(trunk) {
          puts " $r $revdate($r) ($revcomment($r))"
          gen_log:log D " $r $revdate($r) ($revcomment($r))"
          set revkind($r) "revision"
        }
        set revkind($rr) "root"
        set revname($rr) "trunk"
puts "branchrevs(trunk) $branchrevs(trunk)"

        # Branches
puts "Branches"
        set command "svn list $cvscfg(svnroot)/branches"
        set ret [catch {eval "exec $command"} branches]
        foreach branch $branches {
          set branch [string trimright $branch "/"]
puts " $branch"
          set tags($branch) {}
          set path "$cvscfg(svnroot)/branches/$branch/$relpath/$filename"
          set command "svn log --stop-on-copy $path"
          gen_log:log C "$command"
          set ret [catch {eval exec $command} log_output]
          if {$ret != 0} {
            cvsfail "$log_output"
            return
          }
          set loglines [split $log_output "\n"]
          set rb [parse_svnlog $loglines $branch]
          foreach r $branchrevs($branch) {
            puts "  $r $revdate($r) ($revcomment($r))"
            gen_log:log D "  $r $revdate($r) ($revcomment($r))"
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
#puts $loglines
          parse_q $loglines $branch
puts "branchrevs($branch) $branchrevs($branch)"
puts "allrevs($branch)    $allrevs($branch)"
puts [llength $branchrevs($branch)]
puts [llength $allrevs($branch)]
set bp [lindex $allrevs($branch) [llength $branchrevs($branch)]]
          set revbranches($bp) $branch
puts " revbranches($bp) $branch"
        } 
if 0 {
        # Tags
puts "Tags"
        set command "svn list $cvscfg(svnroot)/tags"
        set ret [catch {eval "exec $command"} tagout]
        foreach tag $tagout {
          set tag [string trimright $tag "/"]
          set command \
            "svn log --stop-on-copy $cvscfg(svnroot)/tags/$tag/$relpath/$filename"
          gen_log:log C "$command"
          set ret [catch {eval exec $command} log_output]
          if {$ret != 0} {
            cvsfail "$log_output"
            return
          }
          set loglines [split $log_output "\n"]
          set rt [parse_svnlog $loglines $tag]
          set tags($rt) $tag
          set revkind($rt) "tag"
          puts " $rt $revdate($rt) ($revcomment($rt))"
          gen_log:log D " $rt $revdate($rt) ($revcomment($rt))"
        }
} ; #end if 0
        puts "\nList of Revisions"
        foreach r [lsort -dictionary [array names revkind]] {
          puts " revkind $r $revkind($r)"
          gen_log:log D " revkind $r $revkind($r)"
        }

        [namespace current]::sort_it_all_out
        gen_log:log T "LEAVE"
        return
      }

      proc parse_svnlog {lines r} {
        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable branchrevs

        set i 0
        set l [llength $lines]
        while {$i < $l} {
          set line [lindex $lines $i]
          gen_log:log D "$i of $l:  $line"
          if [regexp {^--*$} $line] {
            # Next line is new revision
            incr i
            if {[expr $l - $i] <= 1} {break}
            set line [lindex $lines $i]
            set splitline [split $line "|"]
            set revnum [string trim [lindex $splitline 0]]
            lappend branchrevs($r) $revnum
            set revwho($revnum) [string trim [lindex $splitline 1]]
            set date_and_time [string trim [lindex $splitline 2]]
            set revdate($revnum) [lindex $date_and_time 0]
            set revtime($revnum) [lindex $date_and_time 1]
            set notelen [lindex [string trim [lindex $splitline 3]] 0]
            gen_log:log D "revnum $revnum"
            gen_log:log D "revwho($revnum) $revwho($revnum)"
            gen_log:log D "revdate($revnum) $revdate($revnum)"
            gen_log:log D "revtime($revnum) $revtime($revnum)"
            gen_log:log D "notelen $notelen"
            
            incr i 2
            set revcomment($revnum) ""
            set c 0
            while {$c < $notelen} {
              append revcomment($revnum) "[lindex $lines [expr $c + $i]]\n"
              incr c
            }
            set revcomment($revnum) [string trimright $revcomment($revnum)]
            gen_log:log D "revcomment($revnum) $revcomment($revnum)"
          }
          incr i
        }
        return $revnum
      }

      proc parse_q {lines r} {
        variable allrevs

        set allrevs($r) ""
        foreach line $lines {
puts $line
          gen_log:log D "$line"
          if [regexp {^r} $line] {
            set splitline [split $line "|"]
puts "$splitline"
            set revnum [string trim [lindex $splitline 0]]
puts "revnum $revnum"
            lappend allrevs($r) $revnum
          }
        }
puts "allrevs($r) $allrevs($r)"
      }

      proc sort_it_all_out {} {
        global cvscfg
        global logcfg
        variable filename
        variable branch_canvas
        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable revkind
        variable revname
        variable tags
        variable branchrevs
        variable revbranches
        variable logstate
        variable revnum
        variable rootbranch
        variable revbranch
        variable fromprefix
        variable toprefix
  
        gen_log:log T "ENTER"
        # Construct tag names
        set totagbegin [string first "_BRANCH_" $cvscfg(mergetoformat) ]
        set toprefix [string range $cvscfg(mergetoformat) 0 [expr {$totagbegin - 1}]]
        set fromtagbegin [string first "_BRANCH_" $cvscfg(mergefromformat) ]
        set fromprefix [string range $cvscfg(mergefromformat) 0 [expr {$fromtagbegin -1}]]

        # Sort the revision and branch lists and remove duplicates
puts "\nsort_it_all_out"

        foreach r [lsort -dictionary [array names revkind]] {
           puts "$r $revkind($r)"
           if {$revkind($r) == "root" || $revkind($r) == "branch"} {
             puts "New index $r"
             set root $r
             set newlist($root) ""
           } elseif {$revkind($r) == "revision"} {
             lappend newlist($root) $r
           }
        }
#puts "\nnewlist"
        #unset branchrevs
        #foreach a [lsort -dictionary [array names newlist]] {
          #puts " $a $newlist($a)"
          #puts " $a $revname($a)"
          #set branchrevs($revname($a)) [concat $a $newlist($a)]
        #}

        # Find out where to put the working revision icon (if anywhere)
        variable directory
        if {$filename != "no file"} {
          set command "svn status -v $filename"
          set cmd [exec::new $command]
          set svnstat [$cmd\::output]
          set svnstat [string trimleft $svnstat]
          set revnum(current) [lindex $svnstat 1]
          set revnum(current) "r$revnum(current)"
          gen_log:log D "revnum(current) $revnum(current)"
          puts "revnum(current) $revnum(current)"
        } else {
          gen_log:log D "$filename"
        }
        # We only needed these to place the you-are-here box.
        catch {unset rootbranch revbranch}
        DrawTree now
        gen_log:log T "LEAVE"
      }

      proc ClearSelection {AorB} {
        variable branch_canvas
        variable sel_tag
        variable sel_rev
        catch {$branch_canvas.canvas itemconfigure Sel$AorB -outline black}
        $branch_canvas.canvas dtag Sel$AorB
        $branch_canvas.up.rev${AorB}_rvers configure -text {}
        $branch_canvas.up.log${AorB}_rlogfm.rcomment delete 1.0 end
        $branch_canvas.up.rev${AorB}_rwho configure -text {}
        $branch_canvas.up.rev${AorB}_rdate configure -text {}
        set sel_tag($AorB) {}
        set sel_rev($AorB) {}
        return
      }

      proc SetSelection {AorB tag rev} {
        global cvscfg
        variable branch_canvas
        variable revdate
        variable revtime
        variable revwho
        variable revcomment
        variable sel_tag
        variable sel_rev
        ClearSelection $AorB
        if {! [info exists revcomment($rev)]} {
           set revcomment($rev) "*** empty log message ***"
        }
        if {$tag != {}} {
          $branch_canvas.up.rev${AorB}_rvers configure -text $tag
        } else {
          set r [string trimleft $rev "r"]
          $branch_canvas.up.rev${AorB}_rvers configure -text $r
        }
        if {$rev != {} && [info exists revwho($rev)]} {
          $branch_canvas.up.rev${AorB}_rwho configure -text $revwho($rev)
          $branch_canvas.up.rev${AorB}_rdate configure -text\
              "$revdate($rev) $revtime($rev)"
          $branch_canvas.up.log${AorB}_rlogfm.rcomment insert end $revcomment($rev)
        }
        $branch_canvas.canvas addtag Sel$AorB withtag rect$rev
        $branch_canvas.canvas itemconfigure SelA -outline $cvscfg(colourA)
        $branch_canvas.canvas itemconfigure SelB -outline $cvscfg(colourB)
        set sel_tag($AorB) $tag
        set sel_rev($AorB) $rev
        return
      }

      proc RevSelect {AorB} {
        variable branch_canvas
        set t [$branch_canvas.canvas gettags current]
        SetSelection $AorB \
          [string range [lindex $t [lsearch -glob $t {T*}]] 1 end] \
          [string range [lindex $t [lsearch -glob $t {R*}]] 1 end]
        return
      }

      proc DeltaSelect {} {
        variable branch_canvas

        set t [$branch_canvas.canvas gettags current]
        set atag {}
        set arev [string range [lindex $t [lsearch -glob $t {A*}]] 1 end]
        set btag [string range [lindex $t [lsearch -glob $t {T*}]] 1 end]
        set brev [string range [lindex $t [lsearch -glob $t {B*}]] 1 end]
        # We have the branch tag, we want to know the corresponding tag
        # that marks the root of this branch. If we can't find it we can't
        # use tags in this delta selection.
        if {$btag != {}} {
          variable tags
          append atag $btag {-root}
          if {![info exists tags($arev)] \
          || [lsearch -exact $tags($arev) $atag] < 0} {
            foreach {atag btag} {{} {}} { break }
          }
        }
        SetSelection A $atag $arev
        SetSelection B $btag $brev
        return
      }

      proc PopupTags { x y } {
      #
      # Pop up a transient window with a listbox of the tags for a specific\
      # revision
      #
        global cvscfg
        variable branch_canvas
        variable tags
        foreach tag [$branch_canvas.canvas gettags current] {
          if {[string index $tag 0] == {R}} {
            set rev [string range $tag 1 end]
            break
          }
        }
        set mname "$branch_canvas.[join [split $rev {.}] {_}]"
        if {[winfo exists $mname]} {
          # Don't let them hit the button twice
          wm deiconify $mname
          raise $mname
        } else {
          toplevel $mname
          wm title $mname "Tags: $rev"
          wm transient $mname $branch_canvas.canvas
          set ntags [llength $tags($rev)]
          set h [expr {400 / [font metrics $cvscfg(listboxfont)\
              -displayof $mname -linespace]}]
          if {$h > $ntags} {
            set h $ntags
          }
          if {[info tclversion] >= 8.3} {
            listbox $mname.lbx -font $cvscfg(listboxfont) \
              -width 0 -height $h \
              -listvar [namespace current]::tags($rev)
          } else {
            # The list of tags won't get update on a reload of the log file
            # unless you close and reopen the pop up :-(
            listbox $mname.lbx -font $cvscfg(listboxfont) \
              -width 0 -height $h
            foreach tag $tags($rev) {
              $mname.lbx insert end $tag
            }
          }
          # Always have a scroll bar because a reload of the log might find
          # more tags and the list might not fit in the window any longer.
          scrollbar $mname.scroll -command "$mname.lbx yview"
          $mname.lbx configure -yscroll "$mname.scroll set"
          pack $mname.scroll -side right -fill y
          pack $mname.lbx -ipadx 10 -ipady 10 -expand y -fill both
          bind $mname.lbx <Button-1> [namespace code "
          variable tags
          set i \[$mname.lbx nearest %y\]
          SetSelection A \[lindex \$tags($rev) \$i\] $rev
          $mname.lbx selection clear 0 end
          $mname.lbx selection set \$i"]
          bind $mname.lbx <Button-2> [namespace code "
          variable tags
          set i \[$mname.lbx nearest %y\]
          SetSelection A \[lindex \$tags($rev) \$i\] $rev
          $mname.lbx selection clear 0 end
          $mname.lbx selection set \$i"]
          bind $mname.lbx <Button-3> [namespace code "
          variable tags
          set i \[$mname.lbx nearest %y\]
          SetSelection B \[lindex \$tags($rev) \$i\] $rev
          $mname.lbx selection clear 0 end
          $mname.lbx selection set \$i"]
          # We need it to get laid out before we query its geometry.
          update
        }
        # Centre the pop up on the cursor position then adjust so it doesn't
        # run off the edge of the screen (if possible!).
        set w [winfo width $mname]
        set h [winfo height $mname]
        set x [expr {$x - $w/2}]
        set y [expr {$y - $h/2}]
        set sx [expr {[winfo vrootx $mname] + [winfo vrootwidth $mname]}]
        if {[expr {$x + $w}] >= $sx} {
          set x [expr {$sx - $w}]
        }
        if {$x < 0} {
          set x 0
        }
        set sy [expr {[winfo vrooty $mname] + [winfo vrootheight $mname]}]
        if {[expr {$y + $h}] >= $sy} {
          set y [expr {$sy - $h}]
        }
        if {$y < 0} {
          set y 0
        }
        wm geometry $mname +$x+$y
        return
      }

      proc CalcCurrent { revision } {
        variable curr
        variable font_bold
        variable font_bold_h
        variable branch_canvas

        gen_log:log T "ENTER ($revision)"
        set box_width \
          [expr {[image width Man] \
                 + $curr(padx) \
                 + [font measure $font_bold \
                     -displayof $branch_canvas.canvas {You are}] \
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
        variable branch_canvas
        variable root_info
        variable tags
        variable curr_x
        variable curr_y

        gen_log:log T "ENTER ($x $y $box_width $box_height $revision)"
        set curr_x $x
        set curr_y $y
        # draw the box
        set tx [expr {$x + $box_width}]
        set ty [expr {$y - $box_height}]
        $branch_canvas.canvas create rectangle \
          $x $y $tx $ty \
          -fill gray90 \
          -tags [list box active]
        $branch_canvas.canvas create rectangle \
          $x $y $tx $ty \
          -width $curr(width) \
          -tags [list box rect active]
        set pad \
          [expr {($box_width - [image width Man] \
            - [font measure $font_bold -displayof $branch_canvas.canvas {You are}]) \
            / 3}]
        set ty [expr {$y - [expr {$box_height/2}]}]
        # add the contents
        $branch_canvas.canvas create image \
          [expr {$x + $pad}] $ty \
          -image Man -anchor w \
          -tags [list box active]
        $branch_canvas.canvas create text \
          [expr {$x + $box_width - $pad}] $ty \
          -text "You are\nhere" -anchor e \
          -fill red3 \
          -font $font_bold \
          -tags [list box active]
        gen_log:log T "LEAVE"
        return
      }

      proc CalcRoot { branch } {
        global cvscfg
        variable curr
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable branch_canvas
        variable root_info
        variable tags

        gen_log:log T "ENTER ($branch)"
        set box_width 0
        foreach s [subst $root_info] {
          set w [font measure $font_norm -displayof $branch_canvas.canvas $s]
          if {$w > $box_width} {
            set box_width $w
          }
        }
        incr box_width $curr(padx,2)
        gen_log:log T "LEAVE"
        return [list $box_width \
          [expr {$curr(pady,2) + [llength [subst $root_info]] * $font_norm_h}]]
      }

      proc DrawRoot { x y box_width root_rev branch } {
        global cvscfg
        variable box_height
        variable curr
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable branch_canvas
        variable root_info
        variable tags

        gen_log:log T "ENTER ($x $y $box_width $root_rev $branch)"
puts "DrawRoot $x $y"
        set root_text "$root_info"
        set btag [lindex $tags($branch) 0]
        # draw the box
        set rheight [expr {$curr(pady,2) + [llength $root_text] * $font_norm_h}]
        incr y $rheight
        $branch_canvas.canvas create rectangle \
          $x $y \
          [expr {$x + $box_width}] [expr {$y - $rheight}] \
            -width $curr(width) -fill gray90 -outline blue
        set mx [expr {$x + $box_width/2}]
        set my [expr $y - $rheight]
        $branch_canvas.canvas create line \
           $mx $my $mx [expr {$my - $curr(boff)}] \
           -arrow last -arrowshape $curr(arrowshape) -width $curr(width) \
           -fill blue
        set tx [expr {$x + $box_width/2}]
        set ty [expr {$y - $curr(pady)}]
        gen_log:log D "$root_text"
        foreach s [subst $root_text] {
          $branch_canvas.canvas create text \
            $tx $ty \
            -text $s \
            -anchor s \
            -font $font_norm -fill blue
          incr ty -$font_norm_h
        }
        gen_log:log T "LEAVE"
        return
      }

      proc CalcRevision { revision } {
        global cvscfg
        variable opt
        variable curr
        variable box_height
        variable rev_info
        variable revdate
        variable revtime
        variable revwho
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable branch_canvas
        variable tags
        variable tlist

        gen_log:log T "ENTER ($revision)"
if {$revision == ""} {return}
        set height $box_height
        set tag_width 0
        set box_width 0
        set tlist($revision) {}
        if {$opt(show_tags) && [info exists tags($revision)]} {
          # We want to show all the coloured tags plus others to take
          # the total to at least cvscfg(tagdepth)
          set tag_colour {}
          set tag_black {}
          foreach tag $tags($revision) {
            if {[info exists cvscfg(tagcolour,$tag)]} {
              lappend tag_colour $tag
            } else {
              lappend tag_black $tag
            }
          }
          if {[info exists cvscfg(tagdepth)] && $cvscfg(tagdepth) != 0} {
            set n [expr {$cvscfg(tagdepth) - [llength $tag_colour]}]
            if {$n < [llength $tag_black]} {
              set tag_black [concat [lrange $tag_black 0 [expr {$n-1}]] {more...}]
            }
          }
          set tlist($revision) [concat $tag_colour $tag_black]
          foreach tag $tlist($revision) {
            if {$tag == {more...}} {
              set my_font $font_bold
            } else {
              set my_font $font_norm
            }
            set w [font measure $my_font -displayof $branch_canvas.canvas $tag]
            if {$w > $tag_width} {
              set tag_width $w
            }
          }
          incr tag_width $curr(tspcb,2)
          set h [expr {[llength $tlist($revision)] * $font_norm_h}]
          if {$h > $height} {
            set height $h
          }
        }
        foreach s [subst $rev_info] {
          set w [font measure $font_norm -displayof $branch_canvas.canvas $s]
          if {$w > $box_width} {
            set box_width $w
          }
        }
        incr box_width $curr(padx,2)
        gen_log:log T "LEAVE"
        return [list $tag_width $box_width $height]
      }

      proc DrawRevision { x y tag_width box_width height revision} {
        global cvscfg
        variable curr
        variable box_height
        variable rev_info
        variable revdate
        variable revtime
        variable revwho
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable branch_canvas
        variable tlist
        variable tags
        variable fromtags
        variable totags
        variable fromtag_branch
        variable totag_branch
        variable xy
        variable boxwidth
        variable fromprefix
        variable toprefix

        #puts "ENTER ($x $y $tag_width $box_width $height $revision)"
        gen_log:log T "DrawRevision $revision)"
        # Draw the list of tags
        set tx [expr {$x - $curr(tspcb)}]
        set ty $y
        foreach tag $tlist($revision) {
          if {[string match "${fromprefix}_*" $tag]} {
            lappend fromtags $tag
            set boxwidth($tag) $box_width
            set xy($tag) [list $x [expr {$y - ($box_height / 4)}]]
            set lsplit [lrange [split $revision {.}] 0 end-1]
            if {[llength $lsplit] > 1} {
              set fromtag_branch($tag) $tags([join $lsplit {.}])
            } else {
              set fromtag_branch($tag) "trunk"
            }
            gen_log:log D "  fromtag($tag) - $revision - $fromtag_branch($tag)"
            
          }
          if {[string match "${toprefix}_*" $tag]} {
            lappend totags $tag
            set boxwidth($tag) $box_width
            set xy($tag) [list $x [expr {$y - ($box_height / 4)}]]
            set lsplit [lrange [split $revision {.}] 0 end-1]
            if {[llength $lsplit] > 1} {
              set totag_branch($tag) $tags([join $lsplit {.}])
            } else {
              set totag_branch($tag) "trunk"
            }
            gen_log:log D "  totag($tag) - $revision - $totag_branch($tag)"
          }
          set my_font $font_norm
          set tagcolour black
          set taglist [list T$tag R$revision box active]
          if {$tag == {more...}} {
            set my_font $font_bold
            set taglist [list R$revision tag active]
          } elseif {[info exists cvscfg(tagcolour,$tag)]} {
            set tagcolour $cvscfg(tagcolour,$tag)
          }
          $branch_canvas.canvas create text \
            $tx $ty \
            -text $tag \
            -anchor se -fill $tagcolour \
            -font $my_font \
            -tags $taglist
          incr ty -$font_norm_h
        }
gen_log:log D "x y $x $y box_width $box_width box_height $box_height"
        # draw the box...
        set tx [expr {$x + $box_width}]
        set ty [expr {$y - $box_height}]
        $branch_canvas.canvas create rectangle \
          $x $y $tx $ty \
          -fill gray90 \
          -tags [list box R$revision active]
        $branch_canvas.canvas create rectangle \
          $x $y $tx $ty \
          -width $curr(width) \
          -tags [list box R$revision rect$revision active]
        # ...and add the contents
        set tx [expr {$x + $box_width/2}]
        set ty [expr {$y - $curr(pady)}]
        foreach s [subst $rev_info] {
          $branch_canvas.canvas create text \
            $tx $ty \
            -text $s \
            -anchor s \
            -font $font_norm \
            -tags [list R$revision box active]
          incr ty -$font_norm_h
        }
        gen_log:log T "LEAVE"
        return
      }

      proc DrawBranch { x y root_rev branch } {
        variable branch_canvas
        variable opt
        variable curr
        variable box_height
        variable revbranches
        variable branchrevs
        variable revnum

        gen_log:log T "ENTER ($x $y \"$root_rev\" $branch)"
        puts "\nDrawBranch ($branch)"

        # Work out width and height of this limb, saving sizes of revisions
        set tag_width 0
        if {$branch == {current}} {
          foreach {box_width root_height} [CalcCurrent $branch] { break }
        } else {
          foreach {box_width root_height} [CalcRoot $branch] { break }
        }
        set height [expr {$root_height + $curr(spcy)}]
        set rdata {}

        set revlist [lsort -dictionary -decreasing $branchrevs($branch)]
        foreach revision $revlist {
          if {$revision == {current}} {
            set rtw 0
            foreach {rbw rh} [CalcCurrent $revision] { break }
          } else {
            foreach {rtw rbw rh} [CalcRevision $revision] { break }
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
          $branch_canvas.canvas addtag ol_x overlapping \
            [expr {$x - $curr(spcx)}] [expr {$y - $height + $curr(yfudge)}] \
            [expr {$x + $tag_width + $box_width}] $y
            set bbox [$branch_canvas.canvas bbox ol_x]
          $branch_canvas.canvas dtag ol_x
          if {$bbox == {}} {
          break
        }
        gen_log:log D "horizontal overlap with $bbox"
          # Move branch to rightmost point of overlapped objects plus some space
          # N.B. +1 because exactly equal counts as an overlap
          set x [expr {[lindex $bbox 2] + $curr(spcx) + 1}]
        }
        # Look for overlap vertically
        $branch_canvas.canvas addtag ol_y overlapping \
          $x [expr {$y - $height}] \
          [expr {$x + $tag_width + $box_width}] [expr {$y - $height +\
               $curr(yfudge)}]
        set bbox [$branch_canvas.canvas bbox ol_y]
        $branch_canvas.canvas dtag ol_y
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
puts "set last_y {}"
puts "revlist $revlist"
gen_log:log D "revlist $revlist"
        foreach revision [lrange $revlist 0 end] {rtag_width rheight} $rdata {
          #if {$revision == ""} {continue}
          incr y $curr(spcy)
          incr y $rheight
          # For each branch off this revision, draw it to the right of this
          # revision box and a little above the centre line of this box.
          set x2 [expr {$x + $box_width + $curr(spcx)}]
          set y2 [expr {$y - $box_height/2 - $curr(boff)}]
          set brevs {}
          set bxys {}
          if [info exists revbranches($revision)] {
            foreach r2 $revbranches($revision) {
              puts " revbranches($revision) $r2"
              gen_log:log D " revbranches($revision): $r2"
              #if {! [info exists revbranches($r2)]} {continue}
              # Do we display the branch if it is empty?
              # If it's the you-are-here, we do anyway
              #if {$revbranches($r2) == {} && $r2 != {current} && !\
                  #$opt(show_empty_branches)} {
                #continue
              #}
              lappend brevs $r2
              foreach {lx y2 lbw rh lly} [DrawBranch $x2 $y2 $revision $r2] {
                lappend bxys $lx $lbw $rh $lly
                break
              }
            }
            set x2 [expr {$lx + $lbw + $curr(spcx)}]
          }
          # y2 may have changed to accomodate a long branch. If so we need
          # to figure out what our y should be
          set y [expr {$y2 + $box_height/2 + $curr(boff)}]
          set rx [expr {$x + $box_width}]
          set ry [expr {$y - $box_height/2}]
          set by [expr {$ry - $curr(boff)}]
          foreach b $brevs {bx bw rh ly} $bxys {
            set mx [expr {$bx + $bw/2}]
            if {$ly != {}} {
              $branch_canvas.canvas create line \
                $mx $ly $mx [expr {$by - $rh}] \
                -arrow first -arrowshape $curr(arrowshape) -width $curr(width) \
                -tags [list A$revision B$b delta active]
            }
            # We could draw this with -smooth 1 but without anti-aliasing
            # the curves look yukky :-(
            $branch_canvas.canvas lower [ \
              $branch_canvas.canvas create line \
                $rx $ry $mx $ry $mx $by \
                -arrow last -arrowshape $curr(arrowshape) -width $curr(width) \
                -fill blue \
                -tags [list A$revision B[lindex $branchrevs($b) 0] delta active]
            ]
            if {$opt(update_drawing) < 1} {
              UpdateBndBox
            }
          }
          if {$last_y != {}} {
            $branch_canvas.canvas create line \
              $midx $last_y $midx [expr {$y - $box_height}] \
              -arrow first -arrowshape $curr(arrowshape) -width $curr(width) \
              -tags [list A$revision B$last_rev delta active]
          }
          DrawRevision $x $y $rtag_width $box_width $rheight $revision
          #if {$revision == $revnum(current)} {
            #set y [expr {$y - $box_height}]
            #DrawCurrent $x $y $box_width $box_height $revision
          #}
          if {$opt(update_drawing) < 1} {
            UpdateBndBox
          }
puts "set last_y $y"
          set last_y $y
          set last_rev $revision
        }
        incr y $curr(spcy)
        if {[info exists revision]} {
          DrawRoot $x $y $box_width $revision $branch
puts "Finished $branch\n"
          if {$opt(update_drawing) < 2} {
            UpdateBndBox
          }
        }
        gen_log:log T "LEAVE"
        return [list $x [expr {$y + $root_height + $curr(spcy)}] \
          $box_width $root_height $last_y]
      }
  
      proc UpdateBndBox {} {
        variable branch_canvas
        variable font_bold
        variable view_xoff
        variable view_yoff
        variable curr_x
        variable curr_y

        gen_log:log T "ENTER"
        foreach {x1 y1 x2 y2} { 0 0 100 100 } { break }
        foreach {x1 y1 x2 y2} [$branch_canvas.canvas bbox all] { break }
        $branch_canvas.canvas configure \
          -scrollregion [list \
            [expr {$x1 - 5}] [expr {$y1 - 5}] \
            [expr {$x2 + 5}] [expr {$y2 + 5}]
          ]

        if {[info exists curr_x]} {
          set canv_width [$branch_canvas.canvas cget -width]
          set canv_height [$branch_canvas.canvas cget -height]
          gen_log:log D "visible width $canv_width"
          gen_log:log D "visible height $canv_height"
          gen_log:log D "x $curr_x"
          gen_log:log D "y $curr_y"
          set bbox [$branch_canvas.canvas bbox all]
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
                     -displayof $branch_canvas.canvas {You are}]}]
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
        $branch_canvas.canvas xview moveto $view_xoff
        $branch_canvas.canvas yview moveto $view_yoff
        update
        gen_log:log T "LEAVE"
        return
      }
  
      proc DrawTree { {now {}} } {
        global cvscfg
        global logcfg
        variable after_id_draw
        variable branch_canvas
        variable cwd
        variable box_height
        variable root_info
        variable fromtags {}
        variable totags {}
        variable fromtag_branch
        variable totag_branch
        variable toprefix
        variable xy
        variable boxwidth

        gen_log:log T "ENTER ($now)"
puts "DrawTree"
        catch {after cancel $after_id_draw}
        if {$now != {now} && [info exists logcfg(draw_delay)]} {
          set after_id_draw \
            [after $logcfg(draw_delay) [namespace code {DrawTree now}]]
        } else {
          variable view_xoff
          variable view_yoff
          variable curr
          variable opt
          variable rev_info
          variable scale
          variable font_norm
          variable font_norm_h
          variable font_bold
          variable font_bold_h
          variable revbranches
          variable branchrevs

          busy_start $branch_canvas
          set view_xoff [lindex [$branch_canvas.canvas xview] 0]
          set view_yoff [lindex [$branch_canvas.canvas yview] 0]
          $branch_canvas.canvas delete all
          set root_info {}
          if {$opt(show_root_rev)} {
            append root_info {$branch}
          }
          #if {$opt(show_root_tags)} {
            #append root_info {$tags($branch)}
          #}
          set rev_info {}
          if {$opt(show_box_revtime)} {
            append rev_info {"$revtime($revision)" }
          }
          if {$opt(show_box_revdate)} {
            append rev_info {"$revdate($revision)" }
          }
          if {$opt(show_box_revwho)} {
            append rev_info {$revwho($revision) }
          }
          if {$opt(show_box_rev)} {
            append rev_info {$revision }
          }
#puts "rev_info $rev_info"
#gen_log:log D "rev_info $rev_info"
          # Note: the boxes and tag lists are sized according to the font
          # so do not need to be scaled.
          set my_size [expr {round($logcfg(font_size) * $opt(scale))}]
          set font_norm [font create \
            -family Helvetica -size $my_size]
          set font_norm_h [font metrics \
            $font_norm -displayof $branch_canvas -linespace]
          set font_bold [font create \
            -family Helvetica -size $my_size -weight bold]
          set font_bold_h [font metrics \
            $font_bold -displayof $branch_canvas -linespace]
          # Scale the layout constants
          foreach x {spcx spcy yfudge boff} {
            set curr($x) [expr {round($logcfg($x) * $font_norm_h * $opt(scale))}]
            if {$curr($x) < 1} {
              set curr($x) 1
            }
          }
          foreach x {padx pady tspcb width} {
            set curr($x) [expr {round($logcfg($x) * $opt(scale))}]
            set curr($x,2) [expr {$curr($x) << 1}]
          }
          set curr(arrowshape) {}
          foreach x $logcfg(arrowshape) {
            lappend curr(arrowshape) [expr {$x * $opt(scale)}]
          }
          set box_height [expr {$curr(pady,2) + [llength $rev_info] * $font_norm_h}]
          
          #foreach i [lsort -dictionary [array names revkind]] {
            #DrawRevision $x $y $rtag_width $box_width $rheight $revision
          #}
          if {[info exists branchrevs(trunk)]} {
            DrawBranch 0 0 {} trunk
            UpdateBndBox
          }

          if {$opt(show_merges)} {
            foreach from $fromtags {
              gen_log:log D "$from  to $fromtag_branch($from) at $xy($from)"
              set xfrom [lindex $xy($from) 0]
              set yfrom [lindex $xy($from) 1]
              regsub {^.*_} $from {} end
              set matchstr "${toprefix}_"
              append matchstr $fromtag_branch($from)
              append matchstr "_$end"
              foreach to $totags {
                 gen_log:log D " comparing $matchstr to $to"
                 if {[string equal $to $matchstr]} {
                    gen_log:log D "  to $to at $xy($to)"
                    set xto [lindex $xy($to) 0]
                    set yto [lindex $xy($to) 1]
                    set xmid $xto
                    set ymid $yto
                    if {$xto > $xfrom} {
                      set xfrom [expr {$xfrom + $boxwidth($from)}]
                      set yfrom [expr {$yfrom - ($box_height / 2)}]
                      set yto [expr {$yto - ($box_height / 2)}]
                      set xmid [expr {$xfrom + (($xto - $xfrom) / 2)}]
                      set ymid [expr {$yto - $box_height}]
                    } elseif {$xfrom > $xto} {
                      set xto [expr {$xto + $boxwidth($to)}]
                      set xmid [expr {$xto + (($xfrom - $xto) / 2)}]
                      set ymid [expr {$yto + ($box_height / 2)}]
                    }
                    if {$xto == $xfrom} {
                      set xmid [expr {$xto - ($boxwidth($from) / 2)}]
                      set ymid [expr {$yfrom - (($yfrom - $yto) / 2)}]
                    }
                    $branch_canvas.canvas create line \
                      $xfrom $yfrom $xmid $ymid $xto $yto \
                      -arrow first -smooth 1
                 }
              }
            }
          }
          # Reselect the previously selected revisions
          variable sel_tag
          variable sel_rev
	  foreach AorB {A B} {
            SetSelection $AorB $sel_tag($AorB) $sel_rev($AorB)
          }
          busy_done $branch_canvas
        }
        gen_log:log T "LEAVE"
        return
      }

      proc SaveOptions {} {
        global logcfg
        variable opt
        # Save the options to the global set
        set logcfg(update_drawing) $opt(update_drawing)
        foreach {key value} [array get opt] {
          gen_log:log D "logcfg($key) $value"
          set logcfg($key) $value
        }
        save_options
      }
      # Collect the user options from the global set
      set opt(update_drawing) $logcfg(update_drawing)
      set opt(scale) $logcfg(scale)
      foreach {key value} [array get logcfg show_*] {
        set opt($key) $value
      }
      toplevel $branch_canvas
      wm title $branch_canvas "SVN Log"
      $branch_canvas configure -menu $branch_canvas.menubar
      menu $branch_canvas.menubar
  
      $branch_canvas.menubar add cascade -label "File"\
         -menu $branch_canvas.menubar.file -underline 0
      menu $branch_canvas.menubar.file
      $branch_canvas.menubar.file add command -label "Close" -underline 0 \
        -command [namespace code {$branch_canvas.close invoke}]
      $branch_canvas.menubar.file add separator
      $branch_canvas.menubar.file add command -label "Shell window" -underline 0 \
        -command {eval exec $cvscfg(shell) >& $cvscfg(null) &}
      $branch_canvas.menubar.file add separator
      $branch_canvas.menubar.file add command -label "Exit" -underline 1 \
        -command { exit_cleanup 1 }
      set selcolor [option get $branch_canvas selectColor selectColor]
      $branch_canvas.menubar add cascade -label "View"\
         -menu $branch_canvas.menubar.view -underline 0
      menu $branch_canvas.menubar.view
      $branch_canvas.menubar.view add cascade -label "Update When Drawing" \
        -menu $branch_canvas.menubar.view.update
      menu $branch_canvas.menubar.view.update
      $branch_canvas.menubar.view.update add radiobutton -label "Every Revision" \
        -selectcolor $selcolor \
        -variable [namespace current]::opt(update_drawing) -value 0
      $branch_canvas.menubar.view.update add radiobutton -label "Every Branch" \
        -selectcolor $selcolor \
        -variable [namespace current]::opt(update_drawing) -value 1
      $branch_canvas.menubar.view.update add radiobutton -label "When Finished" \
        -selectcolor $selcolor \
        -variable [namespace current]::opt(update_drawing) -value 2
      $branch_canvas.menubar.view add separator
      $branch_canvas.menubar.view add cascade -label "Tree Layout" \
        -menu $branch_canvas.menubar.view.tree
      menu $branch_canvas.menubar.view.tree
      $branch_canvas.menubar.view.tree add checkbutton -label \
        "Show empty branches" \
        -variable [namespace current]::opt(show_empty_branches) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $branch_canvas.menubar.view.tree add checkbutton -label \
        "Show intermediate revisions" \
        -variable [namespace current]::opt(show_inter_revs) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $branch_canvas.menubar.view.tree add checkbutton -label \
        "Show merges" \
        -variable [namespace current]::opt(show_merges) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $branch_canvas.menubar.view add cascade -label "Branch Layout" \
        -menu $branch_canvas.menubar.view.branch
      menu $branch_canvas.menubar.view.branch
      $branch_canvas.menubar.view.branch add command -label "Turn all options on" \
        -command [namespace code {
          set opt(show_root_rev) [set opt(show_root_tags) 1]
          DrawTree
        }]
      $branch_canvas.menubar.view.branch add command -label "Turn all options off" \
        -command [namespace code {
          set opt(show_root_rev) [set opt(show_root_tags) 0]
          DrawTree
        }]
      $branch_canvas.menubar.view.branch add separator
      $branch_canvas.menubar.view.branch add checkbutton -label "Show revision" \
        -variable [namespace current]::opt(show_root_rev) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $branch_canvas.menubar.view.branch add checkbutton -label "Show tags" \
        -variable [namespace current]::opt(show_root_tags) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $branch_canvas.menubar.view add cascade -label "Revision Layout" \
        -menu $branch_canvas.menubar.view.rev
      menu $branch_canvas.menubar.view.rev
      $branch_canvas.menubar.view.rev add command -label "Turn all options on" \
        -command [namespace code {
          set opt(show_tags) [\
          set opt(show_box_rev) [\
          set opt(show_box_revwho) [\
          set opt(show_box_revdate) [\
          set opt(show_box_revtime) [\
          ]]]]]]
          DrawTree
        }]
      $branch_canvas.menubar.view.rev add command -label "Turn all options off" \
        -command [namespace code {
          set opt(show_tags) [\
          set opt(show_box_rev) [\
          set opt(show_box_revwho) [\
          set opt(show_box_revdate) [\
          set opt(show_box_revtime) [\
          ]]]]]]
          DrawTree
        }]
      $branch_canvas.menubar.view.rev add separator
      $branch_canvas.menubar.view.rev add checkbutton -label "Show tags" \
        -variable [namespace current]::opt(show_tags) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $branch_canvas.menubar.view.rev add checkbutton -label "Show revision" \
        -variable [namespace current]::opt(show_box_rev) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $branch_canvas.menubar.view.rev add checkbutton -label "Show author" \
        -variable [namespace current]::opt(show_box_revwho) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $branch_canvas.menubar.view.rev add checkbutton -label "Show date" \
        -variable [namespace current]::opt(show_box_revdate) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $branch_canvas.menubar.view.rev add checkbutton -label "Show time" \
        -variable [namespace current]::opt(show_box_revtime) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $branch_canvas.menubar.view add separator
      $branch_canvas.menubar.view add cascade -label "Size" \
        -menu $branch_canvas.menubar.view.size
      menu $branch_canvas.menubar.view.size
      foreach {label factor} $logcfg(scaling_options) {
        $branch_canvas.menubar.view.size add radiobutton -label $label \
          -variable [namespace current]::opt(scale) -value $factor \
          -selectcolor $selcolor \
          -command [namespace code { DrawTree }]
      }
      $branch_canvas.menubar.view add separator
      $branch_canvas.menubar.view add command -label "Save options" \
        -command [namespace code {
          SaveOptions
        }]
      menu_std_help $branch_canvas.menubar
      if {$tcl_platform(platform) != "windows"} {
        wm iconbitmap $branch_canvas @$cvscfg(bitmapdir)/branch.xbm
      }
      wm protocol $branch_canvas WM_DELETE_WINDOW \
        [namespace code {$branch_canvas.close invoke}]
      frame $branch_canvas.up -relief groove -border 2
      set textfont $cvscfg(listboxfont)
      set disbg [lindex [$branch_canvas.up configure -background] 4]
      label $branch_canvas.up.lfname -text "SVN Path" \
        -width 12 -anchor w
      entry $branch_canvas.up.rfname -font $textfont
      $branch_canvas.up.rfname configure -bg $disbg
      button $branch_canvas.up.bworkdir -image Workdir -command { workdir_setup }
      pack $branch_canvas.up -side top -fill x
      foreach fm {A B} {
        label $branch_canvas.up.rev${fm}_lvers -text "Revision $fm"
        label $branch_canvas.up.rev${fm}_rvers -text {} \
           -anchor w -font $textfont
  
        label $branch_canvas.up.rev${fm}_ldate -text "Committed"
        label $branch_canvas.up.rev${fm}_rdate -text {} \
           -anchor w -font $textfont
        label $branch_canvas.up.rev${fm}_lwho -text " by "
        label $branch_canvas.up.rev${fm}_rwho -text {} \
           -anchor w -font $textfont
        label $branch_canvas.up.log${fm}_lcomment -text "Log $fm"
         
        frame $branch_canvas.up.log${fm}_rlogfm -bd 3 -bg $cvscfg(colour$fm)
        text  $branch_canvas.up.log${fm}_rlogfm.rcomment -height 5 \
           -yscrollcommand [namespace code\
           "$branch_canvas.up.log${fm}_rlogfm.yscroll set"]
           scrollbar $branch_canvas.up.log${fm}_rlogfm.yscroll \
           -command [namespace code\
           "$branch_canvas.up.log${fm}_rlogfm.rcomment yview"]
      }
      grid columnconf $branch_canvas.up 5 -weight 1
      grid $branch_canvas.up.lfname -column 0 -row 0 -sticky nw
      grid $branch_canvas.up.rfname -column 1 -row 0 -columnspan 5 -sticky ew
      grid $branch_canvas.up.bworkdir -column 6 -row 0 -rowspan 2 -sticky e\
        -padx 2 -pady 1
      grid $branch_canvas.up.revA_lvers -column 0 -row 1 -sticky w
      grid $branch_canvas.up.revA_rvers -column 1 -row 1 -sticky w
      grid $branch_canvas.up.revA_ldate -column 2 -row 1 -sticky w
      grid $branch_canvas.up.revA_rdate -column 3 -row 1 -sticky w
      grid $branch_canvas.up.revA_lwho -column 4 -row 1 -sticky w
      grid $branch_canvas.up.revA_rwho -column 5 -row 1 -sticky ew
      grid $branch_canvas.up.logA_lcomment -column 0 -row 2 -sticky nw
      grid $branch_canvas.up.logA_rlogfm -column 1 -row 2 -columnspan 6 -sticky ew
      pack $branch_canvas.up.logA_rlogfm.yscroll -side right -fill y
      pack $branch_canvas.up.logA_rlogfm.rcomment -side left -fill x -expand y
      grid $branch_canvas.up.revB_lvers -column 0 -row 3 -sticky w
      grid $branch_canvas.up.revB_rvers -column 1 -row 3 -sticky w
      grid $branch_canvas.up.revB_ldate -column 2 -row 3 -sticky w
      grid $branch_canvas.up.revB_rdate -column 3 -row 3 -sticky w
      grid $branch_canvas.up.revB_lwho -column 4 -row 3 -sticky w
      grid $branch_canvas.up.revB_rwho -column 5 -row 3 -sticky ew
      grid $branch_canvas.up.logB_lcomment -column 0 -row 4 -sticky nw
      grid $branch_canvas.up.logB_rlogfm -column 1 -row 4 -columnspan 6 -sticky ew
      pack $branch_canvas.up.logB_rlogfm.yscroll -side right -fill y
      pack $branch_canvas.up.logB_rlogfm.rcomment -side left -fill x -expand y
      # Pack the bottom before the middle so it doesnt disappear if
      # the window is resized smaller
      frame $branch_canvas.down -relief groove -border 2
      pack $branch_canvas.down -side bottom -fill x
      # The canvas for the big picture
      canvas $branch_canvas.canvas -relief sunken -border 2 \
        -height 300 \
        -yscrollcommand [namespace code "$branch_canvas.yscroll set"] \
        -xscrollcommand [namespace code "$branch_canvas.xscroll set"]
      scrollbar $branch_canvas.xscroll -relief sunken -orient horizontal \
        -command [namespace code "$branch_canvas.canvas xview"]
      scrollbar $branch_canvas.yscroll -relief sunken \
        -command [namespace code "$branch_canvas.canvas yview"]
      #
      # Create buttons
      #
      button $branch_canvas.refresh -image Refresh \
        -command [namespace code {
                 reloadLog
               }]
      button $branch_canvas.view -image Fileview \
        -command [namespace code {
                 svn_cat [$branch_canvas.up.revA_rvers cget -text] $filename
               }]
      button $branch_canvas.annotate -image Annotate \
        -command [namespace code {
                 svn_annotate [$branch_canvas.up.revA_rvers cget -text] $filename
               }]
      button $branch_canvas.diff -image Diff \
        -command [namespace code {
                 comparediff_r [$branch_canvas.up.revA_rvers cget -text] \
                   [$branch_canvas.up.revB_rvers cget -text] $cwd $branch_canvas $filename
               }]
      button $branch_canvas.join -image Mergebranch \
        -command [namespace code {
                   variable tags
                   set rv [$branch_canvas.up.revA_rvers cget -text]
                   set rt [join [lrange [split $rv {.}] 0 end-1] {.}]
                   merge_dialog \
                     [$branch_canvas.up.revA_rvers cget -text] \
                     "" \
                     [list $filename] \
                     [lindex $tags($rt) 0]
                 }]
      button $branch_canvas.delta -image Mergediff \
        -command [namespace code {
                   merge_dialog \
                     [$branch_canvas.up.revA_rvers cget -text] \
                     [$branch_canvas.up.revB_rvers cget -text] \
                     [list $filename]
                 }]
      button $branch_canvas.viewtags -image Tags \
        -command [namespace code {
                   variable tags
                   set taglist {}
                   foreach r [ \
                     lsort [array names tags] \
                   ] {
                     append taglist "$r: $tags($r)\n"
                   }
                   view_output::new Tags $taglist
                 }]
      button $branch_canvas.close -text "Close" \
        -padx 0 -pady 0 \
        -command [namespace code {
                 global cvscfg
                 variable branch_canvas
                 variable cmd_log
                 set cvscfg(loggeom) [wm geometry $branch_canvas]
                 destroy $branch_canvas
                 namespace delete [namespace current]
                 exit_cleanup 0
               }]
      pack $branch_canvas.refresh \
           $branch_canvas.view \
           $branch_canvas.annotate \
           $branch_canvas.diff \
           $branch_canvas.join \
           $branch_canvas.delta \
           $branch_canvas.viewtags \
        -in $branch_canvas.down -side left \
        -ipadx 1 -ipady 1 -fill both -expand 1
      pack $branch_canvas.close \
        -in $branch_canvas.down -side right \
        -ipadx 1 -ipady 1 -fill both -expand 1
        $branch_canvas.view configure \
        -command [namespace code {
                 svn_cat [$branch_canvas.up.revA_rvers cget -text] $filename
               }]
        $branch_canvas.join configure -state disabled
        #$branch_canvas.annotate configure \
        #-command [namespace code {
                   #svn_annotate [$branch_canvas.up.revA_rvers cget-text] $filename "svn"
                 #}]
        $branch_canvas.join configure -state disabled
        #$branch_canvas.delta configure -state disabled
  
      set_tooltips $branch_canvas.refresh \
        {"Re-read the log information"}
      set_tooltips $branch_canvas.up.bworkdir \
        {"Open the Working Directory Browser"}
      set_tooltips $branch_canvas.view \
         {"View a version of the file"}
      set_tooltips $branch_canvas.annotate \
         {"View revision where each line was modified"}
      set_tooltips $branch_canvas.diff \
         {"Compare two versions of the file"}
      set_tooltips $branch_canvas.join \
         {"Merge branch to current"}
      set_tooltips $branch_canvas.delta \
         {"Merge changes to current"}
      set_tooltips $branch_canvas.viewtags \
         {"List all the file\'s tags"}
  
      #
      # Put the canvas on to the display.
      #
      pack $branch_canvas.xscroll -side bottom -fill x -padx 1 -pady 1
      pack $branch_canvas.yscroll -side right -fill y -padx 1 -pady 1
      pack $branch_canvas.canvas -fill both -expand 1
      scrollbindings $branch_canvas.canvas
  
      #
      # Window manager stuff.
      #
      wm minsize $branch_canvas 1 1
      if {[info exists cvscfg(loggeom)]} {
        #regsub {\d+x\d+} $cvscfg(loggeom) {} winloc
        #wm geometry $branch_canvas $winloc
        wm geometry $branch_canvas $cvscfg(loggeom)
      }
  
      $branch_canvas.canvas bind active <Enter> \
        "$branch_canvas.canvas config -cursor hand2"
      $branch_canvas.canvas bind active <Leave> \
        "$branch_canvas.canvas config -cursor {}"
  
      $branch_canvas.canvas bind tag <Button-1> \
        [namespace code "PopupTags %X %Y"]
      $branch_canvas.canvas bind box <ButtonPress-1> \
        [namespace code "RevSelect A"]
      # Tcl/TK for Windows doesn't do Button 3, so we duplicate it on Button 2
      $branch_canvas.canvas bind box <ButtonPress-2> \
        [namespace code "RevSelect A"]
      $branch_canvas.canvas bind box <ButtonPress-3> \
        [namespace code "RevSelect B"]
      $branch_canvas.canvas bind delta <ButtonPress-1> \
        [namespace code "DeltaSelect"]
      # Tcl/TK for Windows doesn't do Button 3, so we duplicate it on Button 2
      $branch_canvas.canvas bind delta <ButtonPress-2> \
        [namespace code "DeltaSelect"]
      $branch_canvas.canvas bind delta <ButtonPress-3> \
        [namespace code "DeltaSelect"]
      focus $branch_canvas.canvas
      $branch_canvas.canvas xview moveto 0
      $branch_canvas.canvas yview moveto 0
      # Collect the history from the RCS log
      reloadLog
      return [namespace current]
    }
  }
}
