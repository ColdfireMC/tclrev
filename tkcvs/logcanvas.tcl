#
# TCL Library for TkCVS
#

#
# $Id: logcanvas.tcl,v 1.74 2005/06/26 06:15:29 dorothyr Exp $
#
# Contains procedures used for the log canvas for tkCVS.
#
# This is a major rewrite over the previous version. It uses a
# top down, recursive, branch-at-a-time, latest-revision-first
# algorithm to layout the graph sensibly.
# -- Mike Jagdis <jaggy@purplet.demon.co.uk>
#

namespace eval ::logcanvas {
  variable instance 0

  proc new {directory filename localfile command} {
    #
    # Creates a new log canvas.  If filename is not "no file" then it is
    # the file name in the local directory that this applies to.
    #
    variable instance
    set my_idx $instance
    incr instance
    global inrcs
    global current_tagname

    set cwd [pwd]
    if {[catch "image type Fileview"]} {
      #::workdir::images
      workdir_images
    }
    if {[catch "image type Workdir"]} {
      #::repository::images
      modbrowse_images
    }
    if {![info exists current_tagname]} {
      set current_tagname ""
      if {$localfile != "no file"} {
        cvsroot_check $cwd
        read_cvs_dir [file join $cwd CVS]
      }
    }

    namespace eval $my_idx {
      set my_idx [uplevel {concat $my_idx}]
      global cvscfg
      global cvs
      global tcl_platform
      variable directory [uplevel {concat $directory}]
      variable filename [uplevel {concat $filename}]
      variable localfile [uplevel {concat $localfile}]
      variable command [uplevel {concat $command}]
      variable cmd_log
      # Global constants scaled by current scaling factor for this instance
      variable curr
      # User options for info display for this instance
      variable opt
      variable revwho
      variable revdate
      variable revtime
      variable revlines
      variable revstate
      variable revbranches
      variable branchrevs
      variable revcomment
      variable tags
      variable sel_tag
      set sel_tag(A) {}
      set sel_tag(B) {}
      variable sel_rev
      set sel_rev(A) {}
      set sel_rev(B) {}
      variable logcanvas ".logcanvas$my_idx"

      proc reloadLog { } {
        variable directory
        variable command
        variable cmd_log
        variable logcanvas
        variable revwho
        variable revdate
        variable revtime
        variable revlines
        variable revstate
        variable revcomment
        variable tags
        variable revbranches
        variable branchrevs
        variable logstate
        variable cwd

        gen_log:log T "ENTER"
        catch { $logcanvas.canvas delete all }
        catch { unset revwho }
        catch { unset revdate }
        catch { unset revtime }
        catch { unset revlines }
        catch { unset revstate }
        catch { unset revcomment }
        catch { unset tags }
        catch { unset revbranches }
        catch { unset branchrevs }
        set cwd [pwd]
        if {[catch {cd $directory}]} {
          cvsfail "unable to access $directory" $logcanvas
          gen_log:log T "LEAVE unable to access $directory"
          return
        }

        busy_start $logcanvas
        set tags(1) {}
        set logstate {R}
        set cmd_log [::exec::new $command {} 0 [namespace current]::ParseLog]
        # wait for it to finish so our arrays are all populated
        $cmd_log\::wait
        if {[catch {cd $cwd}]} {
          # FIXME: WTF do we do now?!?
          gen_log:log T "LEAVE unable to return to $cwd"
          return
        }

        [namespace current]::sort_it_all_out
        gen_log:log T "LEAVE"
        return
      }

      proc ParseLog { exec logline } {
        #
        # Splits the rcs file up and parses it using a simple state machine.
        #
        global module_dir
        global inrcs
        global cvsglb
        variable filename
        variable localfile
        variable logcanvas
        variable revwho
        variable revdate
        variable revtime
        variable revlines
        variable revstate
        variable revcomment
        variable tags
        variable revbranches
        variable branchrevs
        variable logstate
        variable revnum
        variable rootbranch
        variable revbranch

        #gen_log:log D "$logline"
        if {$logline != {}} {
          switch -exact -- $logstate {
            {R} {
              # Look for the first text line which should give the file name.
              if {[string match {RCS file: *} $logline]} {
                # I think the whole path to the "RCS file" from the log isn't
                # really what # we want here.  More like module_dir, so we know
                # what to feed to cvs rdiff and rannotate.
                set fname [string range $logline 10 end]
                set fname [file tail $fname]
                if {[string range $fname end-1 end] == {,v}} {
                  set fname [string range $fname 0 end-2]
                }
                set fname [file join $module_dir $fname]
                wm title $logcanvas "CVS Log: $fname"
                if {$inrcs && [file isdir RCS]} {
                   set fname [file join RCS $fname]
                }
                $logcanvas.up.rfname delete 0 end
                $logcanvas.up.rfname insert end "$fname,v"
                $logcanvas.up.rfname configure -state readonly -bg $cvsglb(robg)
              } elseif {[string match {Working file: *} $logline]} {
                # If we care about a working copy we need to look
                # at the name of the working file here. It may be
                # different from what we were given if we were invoked
                # on a directory.
                if {$localfile != "no file"} {
                  set localfile [string range $logline 14 end]
                }
              } elseif {$logline == "symbolic names:"} {
                set logstate {T}
              }
            }
            {T} {
              # Any line with a tab leader is a tag
              if { [string index $logline 0] == "\t" } {
                set parts [split $logline {:}]
                set tagstring [string trim [lindex $parts 0]]
                set revnum [string trim [lindex $parts 1]]
  
                set parts [split $revnum {.}]
                if {[expr {[llength $parts] & 1}] == 1} {
                  set parts [linsert $parts end-1 {0}]
                  set revnum [join $parts {.}]
                }
                lappend tags($revnum) $tagstring
  
                if {[lindex $parts end-1] == 0} {
                  set revnum [join [lreplace $parts end-1 end-1] {.}]
                  set rootbranch($tagstring) [join [lrange $parts 0 end-2] {.}]
                  set revbranch($tagstring) $revnum
                  lappend tags($revnum) $tagstring
                  lappend revbranches([join [lrange $parts 0 end-2] {.}]) \
                    $revnum
                  append branchrevs($revnum) {}
                } else {
                  # Is it possible that this tag is the only surviving
                  # record that this revision ever existed?
                  if {[llength $parts] == 2} {
                    # A trunk revision but not necessarily 1.x because CVS allows
                    # the first part of the revision number to be changed. We have
                    # to assume that people always increase it if they change it
                    # at all.
                    lappend branchrevs(1) $revnum
                  } else {
                    lappend branchrevs([join [lrange $parts 0 end-1]\
                        {.}]) $revnum
                  }
                  # Branches for this revision may have already been created
                  # during tag parsing
                  append revbranches($revnum) {}
                  foreach "revwho($revnum) revdate($revnum) revtime($revnum)
                    revlines($revnum) revstate($revnum) revcomment($revnum)" \
                    {{} {} {} {} {dead} {}} \
                    { break }
                }
              } else {
                if {$logline == "description:"} {
                  set logstate {S}
                } elseif {$logline == "----------------------------"} {
                  # Oops, missed something.
                  set logstate {V}
                }
              }
            }
            {S} {
              # Look for the line that starts a revision message.
              if {$logline == "----------------------------"} {
                set logstate {V}
              }
            }
            {V} {
              # Look for a revision number line
              set revnum [lindex [split $logline] 1]
              set parts [split $revnum {.}]
              if {[llength $parts] == 2} {
                # A trunk revision but not necessarily 1.x because CVS allows
                # the first part of the revision number to be changed. We have
                # to assume that people always increase it if they change it
                # at all.
                lappend branchrevs(1) $revnum
              } else {
                lappend branchrevs([join [lrange $parts 0 end-1] {.}]) $revnum
              }
              # Branches for this revision may have already been created
              # during tag parsing
              append revbranches($revnum) {}
              foreach "revwho($revnum) revdate($revnum) revtime($revnum)
                revlines($revnum) revstate($revnum) revcomment($revnum)" \
                {{} {} {} {} {} {}} \
                { break }
              set logstate {D}
            }
            {D} {
              # Look for a date line.  This also has the name of the author.
              set parts [split $logline]
	      if {[lindex $parts 4] == "author:"} {
                foreach [list \
                    revwho($revnum) revdate($revnum) revtime($revnum) \
                    revlines($revnum) revstate($revnum) \
                  ] \
                  [list \
                    [string trimright [lindex $parts 5] {;}] \
                    [lindex $parts 1] \
                    [string trimright [lindex $parts 2] {;}] \
                    [lrange $parts 11 end] \
                    [string trimright [lindex $parts 8] {;}] \
                  ] \
                  { break }
	      } else {
                foreach [list \
                    revwho($revnum) revdate($revnum) revtime($revnum) \
                    revlines($revnum) revstate($revnum) \
                  ] \
                  [list \
                    [string trimright [lindex $parts 6] {;}] \
                    [lindex $parts 1] \
                    [string trimright [lindex $parts 2] {;}] \
                    [lrange $parts 11 end] \
                    [string trimright [lindex $parts 8] {;}] \
                  ] \
                  { break }
	      }
              set logstate {L}
            }
            {L} {
              # See if there are branches off this revision
              if {[string match "branches:*" $logline]} {
                foreach br [lrange $logline 1 end] {
                  set br [string trimright $br {;}]
                  lappend revbranches($revnum) $br
                  append tags($br) {}
                }
              } elseif {$logline == {----------------------------}} {
                set logstate {V}
              } elseif {$logline ==\
  {=============================================================================}} {
                set logstate {X}
              } else {
                append revcomment($revnum) $logline "\n"
              }
            }
            {X} {
              # ignore any further lines
            }
          }
        }
  
        if {$logstate == {X}} {
          gen_log:log D "********* Done parsing *********"
        }
        return [list {} $logline]
      }

      proc sort_it_all_out {} {
        global cvscfg
        global logcfg
        global module_dir
        variable filename
        variable logcanvas
        variable revwho
        variable revdate
        variable revtime
        variable revlines
        variable revstate
        variable revcomment
        variable tags
        variable revbranches
        variable branchrevs
        variable logstate
        variable revnum
        variable rootbranch
        variable revbranch
        variable fromprefix
        variable toprefix
  
        # Construct tag names
        set totagbegin [string first "_BRANCH_" $cvscfg(mergetoformat) ]
        set toprefix [string range $cvscfg(mergetoformat) 0 [expr {$totagbegin - 1}]]
        set fromtagbegin [string first "_BRANCH_" $cvscfg(mergefromformat) ]
        set fromprefix [string range $cvscfg(mergefromformat) 0 [expr {$fromtagbegin -1}]]

        # Sort the revision and branch lists and remove duplicates
        foreach r [array names branchrevs] {
          set branchrevs($r) \
            [lsort -unique -decreasing -command sortrevs $branchrevs($r)]
          #gen_log:log D "branchrevs($r) $branchrevs($r)"
        }
        foreach r [array names revbranches] {
          set revbranches($r) \
            [lsort -unique -command sortrevs $revbranches($r)]
          #gen_log:log D "revbranches($r) $revbranches($r)"
        }
        # Find out where to put the working revision icon (if anywhere)
        # FIXME: we don't know that the log parsed was derived from the
        # file in this directory. Maybe we should check CVS/{Root,Repository}?
        # Maybe this check should be done elsewhere?
        variable directory
        if {$filename != "no file"} {
          gen_log:log D "$filename is local. Reading CVS/Entries"
          set basename [file tail $filename]
          if {![catch {open [file join \
                              $directory [file dirname $filename] {CVS}\
                        {Entries}] \
                        {r}} entries]} \
          {
            foreach line [split [read $entries] "\n"] {
              # What does the entry for an added/deleted file look like?
              set parts [split $line {/}]
              if {[lindex $parts 1] == $basename} {
                set revnum [lindex $parts 2]
                if {[string index $revnum 0] == {-}} {
                  # File has been locally removed and cvs removed but not
                  # committed.
                  set revstate(current) {dead}
                  set revnum [string range $revnum 1 end]
                } else {
                  set revstate(current) {Exp}
                }
  
                set root [join [lrange [split $revnum {.}] 0 end-1] {.}]
                gen_log:log D "root $root"
                set tag [string range [lindex $parts 5] 1 end]
                if {$revnum == {0}} {
                  # A locally added file has a revision of 0. Presumably
                  # there is no log and no revisions to show.
                  # FIXME: what if this is a resurrection?
                  lappend branchrevs(1) {current}
                  set revbranches(current) {}
                } elseif {[info exists rootbranch($tag)] && \
                    $rootbranch($tag) == $revnum} {
                  # The sticky tag specifies a branch and the branch's
                  # root is the same as the source revision. Place the
                  # you-are-here box at the start of the branch.
                  lappend branchrevs($revbranch($tag)) {current}
                  set revbranches(current) {}
                } else {
                  if {[catch {info exists $branchrevs($root)}] == 0} {
                    if {$revnum == [lindex $branchrevs($root) 0]} {
                      # The revision we are working on is the latest on its
                      # branch. Place the you-are-here box on the end of the
                      # branch.
                      set branchrevs($root) [linsert $branchrevs($root) 0\
                        {current}]
                      set revbranches(current) {}
                    } else {
                      # Otherwise we will place it as a branch off the
                      # revision.
                      set revbranches($revnum) [linsert $revbranches($revnum)\
                        0 {current}]
                    }
                  }
                }
                foreach {revwho(current) revdate(current) revtime(current)
                    revlines(current) revcomment(current)
                    branchrevs(current)} \
                    {{} {} {} {} {} {}} \
                    { break }
                  break
                }
              }
              close $entries
            }
        } else {
          gen_log:log D "$filename"
        }
        # We only needed these to place the you-are-here box.
        catch {unset rootbranch revbranch}
        DrawTree now
      }

      proc ClearSelection {AorB} {
        variable logcanvas
        variable sel_tag
        variable sel_rev
        catch {$logcanvas.canvas itemconfigure Sel$AorB -outline black}
        $logcanvas.canvas dtag Sel$AorB
        $logcanvas.up.rev${AorB}_rvers configure -text {}
        $logcanvas.up.log${AorB}_rlogfm.rcomment delete 1.0 end
        $logcanvas.up.rev${AorB}_rwho configure -text {}
        $logcanvas.up.rev${AorB}_rdate configure -text {}
        set sel_tag($AorB) {}
        set sel_rev($AorB) {}
        return
      }

      proc SetSelection {AorB tag rev} {
        global cvscfg
        variable logcanvas
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
          $logcanvas.up.rev${AorB}_rvers configure -text $tag
        } else {
          $logcanvas.up.rev${AorB}_rvers configure -text $rev
        }
        if {$rev != {} && [info exists revwho($rev)]} {
          $logcanvas.up.rev${AorB}_rwho configure -text $revwho($rev)
          $logcanvas.up.rev${AorB}_rdate configure -text\
              "$revdate($rev) $revtime($rev)"
          $logcanvas.up.log${AorB}_rlogfm.rcomment insert end $revcomment($rev)
        }
        $logcanvas.canvas addtag Sel$AorB withtag rect$rev
        $logcanvas.canvas itemconfigure SelA -outline $cvscfg(colourA)
        $logcanvas.canvas itemconfigure SelB -outline $cvscfg(colourB)
        set sel_tag($AorB) $tag
        set sel_rev($AorB) $rev
        return
      }

      proc RevSelect {AorB} {
        variable logcanvas
        set t [$logcanvas.canvas gettags current]
        SetSelection $AorB \
          [string range [lindex $t [lsearch -glob $t {T*}]] 1 end] \
          [string range [lindex $t [lsearch -glob $t {R*}]] 1 end]
        return
      }

      proc DeltaSelect {} {
        variable logcanvas

        set t [$logcanvas.canvas gettags current]
        set atag {}
        set arev [string range [lindex $t [lsearch -glob $t {A*}]] 1 end]
        set btag [string range [lindex $t [lsearch -glob $t {T*}]] 1 end]
        set brev [string range [lindex $t [lsearch -glob $t {B*}]] 1 end]
        # We have the branch tag, we want to know the corresponding tag
        # that marks the root of this branch. If we can't find it we can't
        # use tags in this delta selection.
        if {$btag != {}} {
          variable tags
          # FIXME: should use a site policy routine to convert the tag
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
        global inrcs
        variable logcanvas
        variable tags
        foreach tag [$logcanvas.canvas gettags current] {
          if {[string index $tag 0] == {R}} {
            set rev [string range $tag 1 end]
            break
          }
        }
        set mname "$logcanvas.[join [split $rev {.}] {_}]"
        if {[winfo exists $mname]} {
          # Don't let them hit the button twice
          wm deiconify $mname
          raise $mname
        } else {
          toplevel $mname
          wm title $mname "Tags: $rev"
          wm transient $mname $logcanvas.canvas
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
          # FIXME: add capability to delete a tag here?
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
        variable logcanvas

        gen_log:log T "ENTER ($revision)"
        set box_width \
          [expr {[image width Man] \
                 + $curr(padx) \
                 + [font measure $font_bold \
                     -displayof $logcanvas.canvas {You are}] \
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
        variable revstate
        variable font_bold
        variable font_bold_h
        variable logcanvas
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
        $logcanvas.canvas create rectangle \
          $x $y $tx $ty \
          -width $curr(width) -fill gray90 -outline red3 \
          -tags [list box active]
        if {$revstate(current) == {dead}} {
          $logcanvas.canvas create line \
            $x $y $tx $ty -fill red -width $curr(width) \
            -tags [list box active]
          $logcanvas.canvas create line \
            $tx $y $x $ty -fill red -width $curr(width) \
            -tags [list box active]
        }
        #$logcanvas.canvas create rectangle \
          #$x $y $tx $ty \
          #-width $curr(width) \
          #-tags [list box rect active]
        set pad \
          [expr {($box_width - [image width Man] \
            - [font measure $font_bold -displayof $logcanvas.canvas {You are}]) \
            / 3}]
        set ty [expr {$y - [expr {$box_height/2}]}]
        # add the contents
        $logcanvas.canvas create image \
          [expr {$x + $pad}] $ty \
          -image Man -anchor w \
          -tags [list box active]
        $logcanvas.canvas create text \
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
        variable logcanvas
        variable root_info
        variable tags

        #gen_log:log T "ENTER ($branch)"
        set box_width 0
        foreach s [subst $root_info] {
          set w [font measure $font_norm -displayof $logcanvas.canvas $s]
          if {$w > $box_width} {
            set box_width $w
          }
        }
        incr box_width $curr(padx,2)
        #gen_log:log T "LEAVE"
        return [list $box_width \
          [expr {$curr(pady,2) + [llength [subst $root_info]] * $font_norm_h}]]
      }

      proc DrawRoot { x y box_width box_height root_rev branch last_rev } {
        global cvscfg
        variable curr
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable logcanvas
        variable root_info
        variable tags

        gen_log:log T "ENTER ($x $y $box_width $box_height $root_rev $branch $last_rev)"
        set btag [lindex $tags($branch) 0]
        # draw the box
        $logcanvas.canvas create rectangle \
          $x $y \
          [expr {$x + $box_width}] [expr {$y - $box_height}] \
            -width $curr(width) \
            -fill gray90 -outline blue \
            -tags [list T$btag A$root_rev B$last_rev delta active]
        set tx [expr {$x + $box_width/2}]
        set ty [expr {$y - $curr(pady)}]
        gen_log:log D "[subst $root_info]"
        foreach s [subst $root_info] {
          $logcanvas.canvas create text \
            $tx $ty \
            -text $s \
            -anchor s \
            -font $font_norm -fill blue \
            -tags [list T$btag A$root_rev B$last_rev delta active]
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
        variable revstate
        variable revlines
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable logcanvas
        variable tags
        variable tlist

        #gen_log:log T "ENTER ($revision)"
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
            set w [font measure $my_font -displayof $logcanvas.canvas $tag]
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
          set w [font measure $font_norm -displayof $logcanvas.canvas $s]
          if {$w > $box_width} {
            set box_width $w
          }
        }
        incr box_width $curr(padx,2)
        #gen_log:log T "LEAVE"
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
        variable revstate
        variable revlines
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable logcanvas
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

        gen_log:log T "ENTER ($x $y $tag_width $box_width $height $revision)"
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
          $logcanvas.canvas create text \
            $tx $ty \
            -text $tag \
            -anchor se -fill $tagcolour \
            -font $my_font \
            -tags $taglist
          incr ty -$font_norm_h
        }
        # draw the box...
        set tx [expr {$x + $box_width}]
        set ty [expr {$y - $box_height}]
        $logcanvas.canvas create rectangle \
          $x $y $tx $ty \
          -fill gray90 \
          -tags [list box R$revision active]
        if {$revstate($revision) == {dead}} {
          $logcanvas.canvas create line \
            $x $y $tx $ty -fill red -width $curr(width) \
            -tags [list box R$revision active]
          $logcanvas.canvas create line \
            $tx $y $x $ty -fill red -width $curr(width) \
            -tags [list box R$revision active]
        }
        $logcanvas.canvas create rectangle \
          $x $y $tx $ty \
          -width $curr(width) \
          -tags [list box R$revision rect$revision active]
        # ...and add the contents
        set tx [expr {$x + $box_width/2}]
        set ty [expr {$y - $curr(pady)}]
        foreach s [subst $rev_info] {
          $logcanvas.canvas create text \
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
        variable logcanvas
        variable opt
        variable curr
        variable box_height
        variable branchrevs
        variable revbranches

        gen_log:log T "ENTER ($x $y $root_rev $branch)"
        # What revisions to show on this branch?
        if {$branchrevs($branch) == {}} {
          set revlist {}
        } else {
          # Always have the head revision
          set revlist [lindex $branchrevs($branch) 0]
          foreach r [lrange $branchrevs($branch) 1 end-1] {
            if {$opt(show_inter_revs)
            || ($opt(show_empty_branches) && $revbranches($r) != {})} {
              lappend revlist $r
            } else {
              # Only if there are non-empty branches off this revision
              foreach b $revbranches($r) {
                if {$branchrevs($b) != {}} {
                  lappend revlist $r
                  break
                }
              }
            }
          }
          if {[llength $branchrevs($branch)] > 1} {
            # Always have the first revision on a branch
            lappend revlist [lindex $branchrevs($branch) end]
          }
        }
        # Work out width and height of this limb, saving sizes of revisions
        set tag_width 0
        if {$branch == {current}} {
          foreach {box_width root_height} [CalcCurrent $branch] { break }
        } else {
          foreach {box_width root_height} [CalcRoot $branch] { break }
        }
        set height [expr {$root_height + $curr(spcy)}]
        set rdata {}
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
          $logcanvas.canvas addtag ol_x overlapping \
            [expr {$x - $curr(spcx)}] [expr {$y - $height + $curr(yfudge)}] \
            [expr {$x + $tag_width + $box_width}] $y
            set bbox [$logcanvas.canvas bbox ol_x]
          $logcanvas.canvas dtag ol_x
          if {$bbox == {}} {
          break
        }
        gen_log:log D "horizontal overlap with $bbox"
          # Move branch to rightmost point of overlapped objects plus some space
          # N.B. +1 because exactly equal counts as an overlap
          set x [expr {[lindex $bbox 2] + $curr(spcx) + 1}]
        }
        # Look for overlap vertically
        $logcanvas.canvas addtag ol_y overlapping \
          $x [expr {$y - $height}] \
          [expr {$x + $tag_width + $box_width}] [expr {$y - $height +\
               $curr(yfudge)}]
        set bbox [$logcanvas.canvas bbox ol_y]
        $logcanvas.canvas dtag ol_y
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
          foreach r2 $revbranches($revision) {
            # Do we display the branch if it is empty?
            # If it's the you-are-here, we do anyway
            if {$branchrevs($r2) == {} && $r2 != {current} && !\
                $opt(show_empty_branches)} {
              continue
            }
            lappend brevs $r2
            foreach {lx y2 lbw rh lly} [DrawBranch $x2 $y2 $revision $r2] {
              lappend bxys $lx $lbw $rh $lly
              break
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
              $logcanvas.canvas create line \
                $mx $ly $mx [expr {$by - $rh}] \
                -arrow first -arrowshape $curr(arrowshape) -width $curr(width) \
                -tags [list A$revision B$b delta active]
            }
            if {$b == {current}} {
              DrawCurrent $bx $by $bw $rh $revision
            } else {
              set last_rev [lindex $branchrevs($b) 0]
              if {$last_rev == {current}} {
                set last_rev [lindex $branchrevs($b) 1]
              }
              DrawRoot $bx $by $bw $rh $revision $b $last_rev
            }
            # We could draw this with -smooth 1 but without anti-aliasing
            # the curves look yukky :-(
            $logcanvas.canvas lower [ \
              $logcanvas.canvas create line \
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
            $logcanvas.canvas create line \
              $midx $last_y $midx [expr {$y - $box_height}] \
              -arrow first -arrowshape $curr(arrowshape) -width $curr(width) \
              -tags [list A$revision B$last_rev delta active]
          }
          if {$revision == {current}} {
            DrawCurrent $x $y $box_width $rheight $revision
          } else {
            DrawRevision $x $y $rtag_width $box_width $rheight $revision
          }
          if {$opt(update_drawing) < 1} {
            UpdateBndBox
          }
          set last_y $y
          set last_rev $revision
        }
        if {$opt(update_drawing) < 2} {
          UpdateBndBox
        }
        gen_log:log T "LEAVE"
        return [list $x [expr {$y + $root_height + $curr(spcy)}] \
        $box_width $root_height $last_y]
      }
  
      proc UpdateBndBox {} {
        variable logcanvas
        variable font_bold
        variable view_xoff
        variable view_yoff
        variable curr_x
        variable curr_y

        #gen_log:log T "ENTER"
        foreach {x1 y1 x2 y2} [$logcanvas.canvas bbox all] { break }
        $logcanvas.canvas configure \
          -scrollregion [list \
            [expr {$x1 - 5}] [expr {$y1 - 5}] \
            [expr {$x2 + 5}] [expr {$y2 + 5}]
          ]

        if {[info exists curr_x]} {
          set canv_width [$logcanvas.canvas cget -width]
          set canv_height [$logcanvas.canvas cget -height]
          gen_log:log D "visible width $canv_width"
          gen_log:log D "visible height $canv_height"
          gen_log:log D "x $curr_x"
          gen_log:log D "y $curr_y"
          set bbox [$logcanvas.canvas bbox all]
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
                     -displayof $logcanvas.canvas {You are}]}]
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
        $logcanvas.canvas xview moveto $view_xoff
        $logcanvas.canvas yview moveto $view_yoff
        update
        #gen_log:log T "LEAVE"
        return
      }
  
      proc DrawTree { {now {}} } {
        global cvscfg
        global logcfg
        global module_dir
        variable after_id_draw
        variable logcanvas
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

          busy_start $logcanvas
          set view_xoff [lindex [$logcanvas.canvas xview] 0]
          set view_yoff [lindex [$logcanvas.canvas yview] 0]
          $logcanvas.canvas delete all
          set root_info {}
          if {$opt(show_root_rev)} {
            append root_info {$branch }
          }
          if {$opt(show_root_tags)} {
            append root_info {$tags($branch) }
          }
          set rev_info {}
          if {$opt(show_box_revstate)} {
            append rev_info {"$revstate($revision)" }
          }
          if {$opt(show_box_revlines)} {
            append rev_info {"$revlines($revision)" }
          }
          if {$opt(show_box_revtime)} {
            append rev_info {$revtime($revision) }
          }
          if {$opt(show_box_revdate)} {
            append rev_info {$revdate($revision) }
          }
          if {$opt(show_box_revwho)} {
            append rev_info {$revwho($revision) }
          }
          if {$opt(show_box_rev)} {
            append rev_info {$revision}
          }
          # Note: the boxes and tag lists are sized according to the font
          # so do not need to be scaled.
          set my_size [expr {round($logcfg(font_size) * $opt(scale))}]
          set font_norm [font create \
            -family Helvetica -size $my_size]
          set font_norm_h [font metrics \
            $font_norm -displayof $logcanvas -linespace]
          set font_bold [font create \
            -family Helvetica -size $my_size -weight bold]
          set font_bold_h [font metrics \
            $font_bold -displayof $logcanvas -linespace]
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
          set box_height [expr {$curr(pady,2) + [llength $rev_info]*$font_norm_h}]
          variable branchrevs
          if {[info exists branchrevs(1)]} {
            DrawBranch 0 0 {} 1
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
                    $logcanvas.canvas create line \
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
          busy_done $logcanvas
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
      toplevel $logcanvas
      wm title $logcanvas "CVS Log"
      $logcanvas configure -menu $logcanvas.menubar
      menu $logcanvas.menubar
  
      $logcanvas.menubar add cascade -label "File"\
         -menu $logcanvas.menubar.file -underline 0
      menu $logcanvas.menubar.file -tearoff 0
      $logcanvas.menubar.file add command -label "Close" -underline 0 \
        -command [namespace code {$logcanvas.close invoke}]
      $logcanvas.menubar.file add separator
      $logcanvas.menubar.file add command -label "Shell window" -underline 0 \
        -command {eval exec $cvscfg(shell) >& $cvscfg(null) &}
      $logcanvas.menubar.file add separator
      $logcanvas.menubar.file add command -label "Exit" -underline 1 \
        -command { exit_cleanup 1 }
      set selcolor [option get $logcanvas selectColor selectColor]
      $logcanvas.menubar add cascade -label "View"\
         -menu $logcanvas.menubar.view -underline 0
      menu $logcanvas.menubar.view -tearoff 0
      $logcanvas.menubar.view add cascade -label "Update When Drawing" \
        -menu $logcanvas.menubar.view.update
      menu $logcanvas.menubar.view.update
      $logcanvas.menubar.view.update add radiobutton -label "Every Revision" \
        -selectcolor $selcolor \
        -variable [namespace current]::opt(update_drawing) -value 0
      $logcanvas.menubar.view.update add radiobutton -label "Every Branch" \
        -selectcolor $selcolor \
        -variable [namespace current]::opt(update_drawing) -value 1
      $logcanvas.menubar.view.update add radiobutton -label "When Finished" \
        -selectcolor $selcolor \
        -variable [namespace current]::opt(update_drawing) -value 2
      $logcanvas.menubar.view add separator
      $logcanvas.menubar.view add cascade -label "Tree Layout" \
        -menu $logcanvas.menubar.view.tree
      menu $logcanvas.menubar.view.tree
      $logcanvas.menubar.view.tree add checkbutton -label \
        "Show empty branches" \
        -variable [namespace current]::opt(show_empty_branches) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.tree add checkbutton -label \
        "Show intermediate revisions" \
        -variable [namespace current]::opt(show_inter_revs) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.tree add checkbutton -label \
        "Show merges" \
        -variable [namespace current]::opt(show_merges) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view add cascade -label "Branch Layout" \
        -menu $logcanvas.menubar.view.branch
      menu $logcanvas.menubar.view.branch
      $logcanvas.menubar.view.branch add command -label "Turn all options on" \
        -command [namespace code {
          set opt(show_root_rev) [set opt(show_root_tags) 1]
          DrawTree
        }]
      $logcanvas.menubar.view.branch add command -label "Turn all options off" \
        -command [namespace code {
          set opt(show_root_rev) [set opt(show_root_tags) 0]
          DrawTree
        }]
      $logcanvas.menubar.view.branch add separator
      $logcanvas.menubar.view.branch add checkbutton -label "Show revision" \
        -variable [namespace current]::opt(show_root_rev) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.branch add checkbutton -label "Show tags" \
        -variable [namespace current]::opt(show_root_tags) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view add cascade -label "Revision Layout" \
        -menu $logcanvas.menubar.view.rev
      menu $logcanvas.menubar.view.rev
      $logcanvas.menubar.view.rev add command -label "Turn all options on" \
        -command [namespace code {
          set opt(show_tags) [\
          set opt(show_box_rev) [\
          set opt(show_box_revwho) [\
          set opt(show_box_revdate) [\
          set opt(show_box_revtime) [\
          set opt(show_box_revlines) [\
          set opt(show_box_revstate) 1]]]]]]
          DrawTree
        }]
      $logcanvas.menubar.view.rev add command -label "Turn all options off" \
        -command [namespace code {
          set opt(show_tags) [\
          set opt(show_box_rev) [\
          set opt(show_box_revwho) [\
          set opt(show_box_revdate) [\
          set opt(show_box_revtime) [\
          set opt(show_box_revlines) [\
          set opt(show_box_revstate) 0]]]]]]
          DrawTree
        }]
      $logcanvas.menubar.view.rev add separator
      $logcanvas.menubar.view.rev add checkbutton -label "Show tags" \
        -variable [namespace current]::opt(show_tags) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.rev add checkbutton -label "Show revision" \
        -variable [namespace current]::opt(show_box_rev) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.rev add checkbutton -label "Show author" \
        -variable [namespace current]::opt(show_box_revwho) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.rev add checkbutton -label "Show date" \
        -variable [namespace current]::opt(show_box_revdate) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.rev add checkbutton -label "Show time" \
        -variable [namespace current]::opt(show_box_revtime) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.rev add checkbutton -label "Show lines changed" \
        -variable [namespace current]::opt(show_box_revlines) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.rev add checkbutton -label "Show RCS state" \
        -variable [namespace current]::opt(show_box_revstate) \
        -onvalue 1 -offvalue 0 \
        -selectcolor $selcolor \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view add separator
      $logcanvas.menubar.view add cascade -label "Size" \
        -menu $logcanvas.menubar.view.size
      menu $logcanvas.menubar.view.size
      foreach {label factor} $logcfg(scaling_options) {
        $logcanvas.menubar.view.size add radiobutton -label $label \
          -variable [namespace current]::opt(scale) -value $factor \
          -selectcolor $selcolor \
          -command [namespace code { DrawTree }]
      }
      $logcanvas.menubar.view add separator
      $logcanvas.menubar.view add command -label "Save options" \
        -command [namespace code {
          SaveOptions
        }]
      menu_std_help $logcanvas.menubar
      if {$tcl_platform(platform) != "windows"} {
        wm iconbitmap $logcanvas @$cvscfg(bitmapdir)/branch.xbm
      }
      wm protocol $logcanvas WM_DELETE_WINDOW \
        [namespace code {$logcanvas.close invoke}]
      frame $logcanvas.up -relief groove -border 2
      set textfont $cvscfg(listboxfont)
      set disbg [lindex [$logcanvas.up configure -background] 4]
      gen_log:log D "module_dir $module_dir"
      label $logcanvas.up.lfname -text "CVS Path" \
        -width 12 -anchor w
      entry $logcanvas.up.rfname -font $textfont -relief groove
      #$logcanvas.up.rfname configure -bg $disbg
      button $logcanvas.up.bworkdir -image Workdir -command { workdir_setup }
      pack $logcanvas.up -side top -fill x
      foreach fm {A B} {
        label $logcanvas.up.rev${fm}_lvers -text "Revision $fm"
        label $logcanvas.up.rev${fm}_rvers -text {} \
           -anchor w -font $textfont
  
        label $logcanvas.up.rev${fm}_ldate -text "Committed"
        label $logcanvas.up.rev${fm}_rdate -text {} \
           -anchor w -font $textfont
        label $logcanvas.up.rev${fm}_lwho -text " by "
        label $logcanvas.up.rev${fm}_rwho -text {} \
           -anchor w -font $textfont
        label $logcanvas.up.log${fm}_lcomment -text "Log $fm"
         
        frame $logcanvas.up.log${fm}_rlogfm -bd 3 -bg $cvscfg(colour$fm)
        text  $logcanvas.up.log${fm}_rlogfm.rcomment -height 5 \
           -yscrollcommand [namespace code\
           "$logcanvas.up.log${fm}_rlogfm.yscroll set"]
           scrollbar $logcanvas.up.log${fm}_rlogfm.yscroll \
           -command [namespace code\
           "$logcanvas.up.log${fm}_rlogfm.rcomment yview"]
      }
      grid columnconf $logcanvas.up 5 -weight 1
      grid $logcanvas.up.lfname -column 0 -row 0 -sticky nw
      grid $logcanvas.up.rfname -column 1 -row 0 -columnspan 5 -sticky ew
      grid $logcanvas.up.bworkdir -column 6 -row 0 -rowspan 2 -sticky e\
        -padx 2 -pady 1
      grid $logcanvas.up.revA_lvers -column 0 -row 1 -sticky w
      grid $logcanvas.up.revA_rvers -column 1 -row 1 -sticky w
      grid $logcanvas.up.revA_ldate -column 2 -row 1 -sticky w
      grid $logcanvas.up.revA_rdate -column 3 -row 1 -sticky w
      grid $logcanvas.up.revA_lwho -column 4 -row 1 -sticky w
      grid $logcanvas.up.revA_rwho -column 5 -row 1 -sticky ew
      grid $logcanvas.up.logA_lcomment -column 0 -row 2 -sticky nw
      grid $logcanvas.up.logA_rlogfm -column 1 -row 2 -columnspan 6 -sticky ew
      pack $logcanvas.up.logA_rlogfm.yscroll -side right -fill y
      pack $logcanvas.up.logA_rlogfm.rcomment -side left -fill x -expand y
      grid $logcanvas.up.revB_lvers -column 0 -row 3 -sticky w
      grid $logcanvas.up.revB_rvers -column 1 -row 3 -sticky w
      grid $logcanvas.up.revB_ldate -column 2 -row 3 -sticky w
      grid $logcanvas.up.revB_rdate -column 3 -row 3 -sticky w
      grid $logcanvas.up.revB_lwho -column 4 -row 3 -sticky w
      grid $logcanvas.up.revB_rwho -column 5 -row 3 -sticky ew
      grid $logcanvas.up.logB_lcomment -column 0 -row 4 -sticky nw
      grid $logcanvas.up.logB_rlogfm -column 1 -row 4 -columnspan 6 -sticky ew
      pack $logcanvas.up.logB_rlogfm.yscroll -side right -fill y
      pack $logcanvas.up.logB_rlogfm.rcomment -side left -fill x -expand y
      # Pack the bottom before the middle so it doesnt disappear if
      # the window is resized smaller
      frame $logcanvas.down -relief groove -border 2
      pack $logcanvas.down -side bottom -fill x
      # The canvas for the big picture
      canvas $logcanvas.canvas -relief sunken -border 2 \
        -height 300 \
        -yscrollcommand [namespace code "$logcanvas.yscroll set"] \
        -xscrollcommand [namespace code "$logcanvas.xscroll set"]
      scrollbar $logcanvas.xscroll -relief sunken -orient horizontal \
        -command [namespace code "$logcanvas.canvas xview"]
      scrollbar $logcanvas.yscroll -relief sunken \
        -command [namespace code "$logcanvas.canvas yview"]
      #
      # Create buttons
      #
      button $logcanvas.refresh -image Refresh \
        -command [namespace code {
                 reloadLog
               }]
      button $logcanvas.view -image Fileview \
        -command [namespace code {
                 cvs_fileview_update [$logcanvas.up.revA_rvers cget -text] $filename
               }]
      button $logcanvas.annotate -image Annotate \
        -command [namespace code {
                 cvs_annotate [$logcanvas.up.revA_rvers cget -text] $filename
               }]
      button $logcanvas.diff -image Diff \
        -command [namespace code {
                 comparediff_r [$logcanvas.up.revA_rvers cget -text] \
                   [$logcanvas.up.revB_rvers cget -text] $cwd $logcanvas $filename
               }]
      button $logcanvas.join -image Mergebranch \
        -command [namespace code {
                   variable tags
                   set rv [$logcanvas.up.revA_rvers cget -text]
                   set rt [join [lrange [split $rv {.}] 0 end-1] {.}]
                   merge_dialog \
                     [$logcanvas.up.revA_rvers cget -text] \
                     "" \
                     [list $filename] \
                     [lindex $tags($rt) 0]
                 }]
      button $logcanvas.delta -image Mergediff \
        -command [namespace code {
                   merge_dialog \
                     [$logcanvas.up.revA_rvers cget -text] \
                     [$logcanvas.up.revB_rvers cget -text] \
                     [list $filename]
                 }]
      button $logcanvas.viewtags -image Tags \
        -command [namespace code {
                   variable tags
                   set taglist {}
                   foreach r [ \
                     lsort -command sortrevs [array names tags] \
                   ] {
                     append taglist "$r: $tags($r)\n"
                   }
                   view_output::new Tags $taglist
                 }]
      button $logcanvas.close -text "Close" \
        -padx 0 -pady 0 \
        -command [namespace code {
                 global cvscfg
                 variable logcanvas
                 variable cmd_log
                 set cvscfg(loggeom) [wm geometry $logcanvas]
                 destroy $logcanvas
                 namespace delete [namespace current]
                 exit_cleanup 0
               }]
      pack $logcanvas.refresh \
           $logcanvas.view \
           $logcanvas.annotate \
           $logcanvas.diff \
           $logcanvas.join \
           $logcanvas.delta \
           $logcanvas.viewtags \
        -in $logcanvas.down -side left \
        -ipadx 1 -ipady 1 -fill both -expand 1
      pack $logcanvas.close \
        -in $logcanvas.down -side right \
        -ipadx 1 -ipady 1 -fill both -expand 1
      if {$localfile == "no file"} {
        $logcanvas.view configure \
        -command [namespace code {
                 cvs_fileview_checkout [$logcanvas.up.revA_rvers cget -text] $filename
               }]
        $logcanvas.join configure -state disabled
        $logcanvas.annotate configure \
        -command [namespace code {
                   cvs_annotate_r [$logcanvas.up.revA_rvers cget\
                   -text] $filename
                 }]
        $logcanvas.join configure -state disabled
        $logcanvas.delta configure -state disabled
      }
      if {$inrcs} {
        $logcanvas.up.lfname configure -text "RCS File"
        $logcanvas.view configure -state disabled
        $logcanvas.annotate configure -state disabled
        $logcanvas.join configure -state disabled
        $logcanvas.delta configure -state disabled
        $logcanvas.viewtags configure -state disabled
        $logcanvas.diff configure -command [namespace code {
                 comparediff_r [$logcanvas.up.revA_rvers cget -text] \
                   [$logcanvas.up.revB_rvers cget -text] $cwd $logcanvas $filename
               }]
      }
  
      set_tooltips $logcanvas.refresh \
        {"Re-read the log information"}
      set_tooltips $logcanvas.up.bworkdir \
        {"Open the Working Directory Browser"}
      set_tooltips $logcanvas.view \
         {"View a version of the file"}
      set_tooltips $logcanvas.annotate \
         {"View revision where each line was modified"}
      set_tooltips $logcanvas.diff \
         {"Compare two versions of the file"}
      set_tooltips $logcanvas.join \
         {"Merge branch to current"}
      set_tooltips $logcanvas.delta \
         {"Merge changes to current"}
      set_tooltips $logcanvas.viewtags \
         {"List all the file\'s tags"}
  
      #
      # Put the canvas on to the display.
      #
      pack $logcanvas.xscroll -side bottom -fill x -padx 1 -pady 1
      pack $logcanvas.yscroll -side right -fill y -padx 1 -pady 1
      pack $logcanvas.canvas -fill both -expand 1
      scrollbindings $logcanvas.canvas
  
      #
      # Window manager stuff.
      #
      wm minsize $logcanvas 1 1
      if {[info exists cvscfg(loggeom)]} {
        #regsub {\d+x\d+} $cvscfg(loggeom) {} winloc
        #wm geometry $logcanvas $winloc
        wm geometry $logcanvas $cvscfg(loggeom)
      }
  
      $logcanvas.canvas bind active <Enter> \
        "$logcanvas.canvas config -cursor hand2"
      $logcanvas.canvas bind active <Leave> \
        "$logcanvas.canvas config -cursor {}"
  
      $logcanvas.canvas bind tag <Button-1> \
        [namespace code "PopupTags %X %Y"]
      $logcanvas.canvas bind box <ButtonPress-1> \
        [namespace code "RevSelect A"]
      # Tcl/TK for Windows doesn't do Button 3, so we duplicate it on Button 2
      $logcanvas.canvas bind box <ButtonPress-2> \
        [namespace code "RevSelect A"]
      $logcanvas.canvas bind box <ButtonPress-3> \
        [namespace code "RevSelect B"]
      $logcanvas.canvas bind delta <ButtonPress-1> \
        [namespace code "DeltaSelect"]
      # Tcl/TK for Windows doesn't do Button 3, so we duplicate it on Button 2
      $logcanvas.canvas bind delta <ButtonPress-2> \
        [namespace code "DeltaSelect"]
      $logcanvas.canvas bind delta <ButtonPress-3> \
        [namespace code "DeltaSelect"]
      focus $logcanvas.canvas
      $logcanvas.canvas xview moveto 0
      $logcanvas.canvas yview moveto 0
      # Collect the history from the RCS log
      reloadLog
      return [namespace current]
    }
  }
}

proc sortrevs {a b} {
    # Proc for lsort -command, to sort revision numbers
    # Return -1 if a<b, 0 if a=b, and 1 if a>b
    foreach ax [split $a {.}] bx [split $b {.}] {
	if {$ax < $bx} {
	    return -1
	}\
	elseif {$ax > $bx} {
	    return 1
	}
    }
    return 0
}
