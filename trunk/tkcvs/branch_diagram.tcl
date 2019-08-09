#
# Tcl Library for TkCVS
#

# This is a major rewrite over the original version. It uses a
# top down, recursive, branch-at-a-time, latest-revision-first
# algorithm to layout the graph sensibly.
# -- Mike Jagdis <jaggy@purplet.demon.co.uk>
#

namespace eval ::logcanvas {
  variable instance 0

  proc new {filename how scope} {
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
      set scope [uplevel {concat $scope}]
      #variable cmd_log
      # Global constants scaled by current scaling factor for this instance
      variable curr
      global cvscfg
      global cvsglb
      global logcfg
      global tcl_platform
      # User options for info display for this instance
      variable revwho
      variable revdate
      variable revtime
      variable revstate
      variable revbranches
      variable branchrevs
      variable revcomment
      variable revtags
      variable revbtags
      variable revpath
      variable sel_tag
      set sel_tag(A) {}
      set sel_tag(B) {}
      variable sel_rev
      variable current_revnum
      set sel_rev(A) {}
      set sel_rev(B) {}
      variable search_lastpattern ""
      variable search_elements [list]
      variable search_index 0
      variable search_lastcase 0
      variable search_nocase
      variable logcanvas ".logcanvas$my_idx"

      gen_log:log T "ENTER [namespace current]"
      set sys_loc [split $how {,}]
      set sys [lindex $sys_loc 0]
      set loc [lindex $sys_loc 1]

      proc ClearSelection {AorB} {
        variable logcanvas
        variable sel_tag
        variable sel_rev
        #catch {$logcanvas.canvas itemconfigure Sel$AorB -outline black}
        catch {$logcanvas.canvas itemconfigure Sel$AorB -fill white}
        $logcanvas.canvas dtag Sel$AorB
        $logcanvas.up.rev${AorB}_rvers configure -state normal
        $logcanvas.up.rev${AorB}_rvers delete 0 end
        $logcanvas.up.rev${AorB}_rvers configure -state readonly
        $logcanvas.up.log${AorB}_rlogfm.rcomment configure -state normal
        $logcanvas.up.log${AorB}_rlogfm.rcomment delete 1.0 end
        $logcanvas.up.log${AorB}_rlogfm.rcomment configure -state disabled
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
        set other [expr {$AorB == "A" ? {B} : {A}}]
        if {$rev == $sel_rev($other)} { ClearSelection $other }
        if {! [info exists revcomment($rev)]} {
           set revcomment($rev) "*** empty log message ***"
        }
        if {$tag != {}} {
          $logcanvas.up.rev${AorB}_rvers configure -state normal
          $logcanvas.up.rev${AorB}_rvers delete 0 end
          $logcanvas.up.rev${AorB}_rvers insert end "$tag"
          $logcanvas.up.rev${AorB}_rvers configure -state readonly
        } else {
          $logcanvas.up.rev${AorB}_rvers configure -state normal
          $logcanvas.up.rev${AorB}_rvers delete 0 end
          $logcanvas.up.rev${AorB}_rvers insert end "$rev"
          $logcanvas.up.rev${AorB}_rvers configure -state readonly
        }
        if {$rev != {} && [info exists revwho($rev)]} {
          $logcanvas.up.rev${AorB}_rwho configure -text $revwho($rev)
          $logcanvas.up.rev${AorB}_rdate configure -text\
              "$revdate($rev) $revtime($rev)"
          $logcanvas.up.log${AorB}_rlogfm.rcomment configure -state normal
          $logcanvas.up.log${AorB}_rlogfm.rcomment insert end $revcomment($rev)
          $logcanvas.up.log${AorB}_rlogfm.rcomment configure -state disabled
        }
        $logcanvas.canvas addtag Sel$AorB withtag rect$rev
        $logcanvas.canvas itemconfigure SelA -fill $cvscfg(colourA)
        $logcanvas.canvas itemconfigure SelB -fill $cvscfg(colourB)
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

      proc Unselect {AorB} {
        variable logcanvas
        set t [$logcanvas.canvas gettags current]
        if {$t != {} } {return}
        ClearSelection $AorB
      }

      proc ConfigureButtons {fname} {
        global cvsglb
        global module_dir
        variable logcanvas
        variable sys
        variable loc
        variable current_revnum

        switch -- $sys {
          "SVN" {
            # Find out current rev and if it's a directory, if we can
            set kind ""
            set info_cmd [exec::new "svn info \"[file tail $fname]\""]
            set info_lines [split [$info_cmd\::output] "\n"]
            foreach infoline $info_lines {
              if {[string match "Node Kind:*" $infoline]} {
                gen_log:log D "$infoline"
                set kind [lindex $infoline end]
              } elseif {[string match "Last Changed Rev:*" $infoline]} {
                gen_log:log D "$infoline"
                set current_revnum [lindex $infoline end]
              }
            }
            if {! [info exists current_revnum]} {
              gen_log:log E "Warning: couldn't find current revision number!"
            }
            $logcanvas.up.bmodbrowse configure -command modbrowse_run \
              -image Modules_svn -state normal
            $logcanvas.up.lfname configure -text "SVN Path"
            $logcanvas.up.rfname configure -state normal
            $logcanvas.up.rfname delete 0 end
            $logcanvas.up.rfname insert end "$module_dir/$fname"
            $logcanvas.up.rfname configure -state readonly
            $logcanvas.log configure \
                -command [namespace code {
                    set rev [$logcanvas.up.revA_rvers get]
                    if {$rev == ""} {
                      svn_log_rev $filename
                    } else {
                      svn_log_rev $revpath($rev)
                    }
                 }]
            if {$kind == "directory"} {
              $logcanvas.diff configure -state disabled
              $logcanvas.annotate configure -state disabled
              $logcanvas.view configure \
                 -command [namespace code {
                    set rev [$logcanvas.up.revA_rvers get]
                    if {$rev ==""} { set rev "r$current_revnum" }
                    svn_fileview $rev $revpath($rev) directory
                 }]
            } else {
              $logcanvas.view configure \
                 -command [namespace code {
                    set rev [$logcanvas.up.revA_rvers get]
                    if {$rev ==""} { set rev "r$current_revnum" }
                    svn_fileview $rev $revpath($rev) file
                 }]
              $logcanvas.diff configure \
                -command [namespace code {
                   set revA [$logcanvas.up.revA_rvers get]
                   set revB [$logcanvas.up.revB_rvers get]
                   set A [string trimleft $revA {r}]
                   set B [string trimleft $revB {r}]
                   # Let's be generous and let either A or B be selected
                   if {$revB == ""} {
                     comparediff_r "$revpath($revA)@$A" "" $logcanvas $filename
                   } elseif {$revA == ""} {
                     comparediff_r "" "$revpath($revB)@$B" $logcanvas $filename
                   } else {
                     comparediff_files $logcanvas "$revpath($revA)@$A" "$revpath($revB)@$B"
                   }
                }]
              $logcanvas.annotate configure \
                 -command [namespace code {
                   set rev [$logcanvas.up.revA_rvers get]
                   if {$rev == ""} {
                     svn_annotate_r "" $filename
                   } else {
                     svn_annotate_r [string trimleft $rev {r}] $revpath($rev)
                   }
                 }]
            }
            $logcanvas.delta configure \
              -command [namespace code {
                 set currentrevpath "$revpath(r$current_revnum)@$current_revnum"
                 set fromrev [$logcanvas.up.revA_rvers get]
                 if {$fromrev == ""} {cvsfail "Please select a revision!" $logcanvas; return}
                 set fromrevpath "$revpath($fromrev)@[string trimleft $fromrev {r}]"
                 set sincerev [$logcanvas.up.revB_rvers get]
                 set fromtag ""
                 if {[info exists revbtags($sincerev)]} {
                   set fromtag [lindex $revbtags($sincerev) 0]
                 }
                 if {$fromtag == ""} {
                   foreach brev [array names revbtags] {
                     set b $revbtags($brev)
                     if {$b == ""} continue
                     foreach r $branchrevs($b) {
                       if {$r == $fromrev} {
                         set fromtag $b
                       }
                     }
                   }
                 }
                 if {$sincerev == ""} {
                   svn_merge $logcanvas $fromrevpath "" $currentrevpath $fromtag $filename
                 } else {
                   set sincerevpath "$revpath($sincerev)@[string trimleft $sincerev {r}]"
                   svn_merge $logcanvas $fromrevpath $sincerev $sincerevpath $fromtag $filename
                 }
               }]
          }
         "CVS" {
           $logcanvas.up.bmodbrowse configure -command modbrowse_run \
              -image Modules_cvs -state normal
           $logcanvas.up.lfname configure -text "RCS file"
           $logcanvas.up.rfname configure -state normal
           $logcanvas.up.rfname delete 0 end
           $logcanvas.up.rfname insert end "$fname,v"
           $logcanvas.up.rfname configure -state readonly
           if {$loc == "rep"} {
             # Working on repository files, not checked out
             $logcanvas.view configure \
                -command [namespace code {
                  cvs_fileview_checkout [$logcanvas.up.revA_rvers get] $filename
                }]
             $logcanvas.log configure \
                  -command [namespace code {
                    cvs_filelog $filename $logcanvas 0
                  }]
             $logcanvas.annotate configure \
                -command [namespace code {
                   cvs_annotate_r [$logcanvas.up.revA_rvers get] $filename
                }]
             $logcanvas.diff configure \
                -command [namespace code {
                   comparediff_sandbox [$logcanvas.up.revA_rvers get] \
                     [$logcanvas.up.revB_rvers get] $logcanvas \
                     $filename
                }]
             $logcanvas.delta configure -state disabled
           } else {
             # We have a checked-out local file
             $logcanvas.log configure \
                  -command [namespace code {
                    set rev [$logcanvas.up.revA_rvers get]
                    if {$rev == ""} {
                      cvs_log_rev "" $filename
                    } else {
                      regsub {\.\d+$} $rev {} baserev
                      cvs_log_rev $baserev $filename
                    }
                  }]
             $logcanvas.view configure \
               -command [namespace code {
                  cvs_fileview_update [$logcanvas.up.revA_rvers get] $filename
               }]
             $logcanvas.annotate configure \
               -command [namespace code {
                 cvs_annotate [$logcanvas.up.revA_rvers get] $filename
               }]
             $logcanvas.delta configure \
               -command [namespace code {
                 set fromrev [$logcanvas.up.revA_rvers get]
                 set sincerev [$logcanvas.up.revB_rvers get]
                 set fromtag ""
                 set fromrev_root [join [lrange [split $fromrev {.}] 0 end-1] {.}]
                 if {[info exists revbtags($fromrev_root)]} {
                   set fromtag [lindex $revbtags($fromrev_root) 0]
                 } else {
                   # Just a rev number will do
                   set fromtag $fromrev_root
                 }
                 cvs_merge $logcanvas $fromrev $sincerev $fromtag [list $filename]
                }]
            }
         }
         "GIT" {
            $logcanvas.up.bmodbrowse configure -command modbrowse_run \
              -image Modules_git -state normal
            $logcanvas.up.lfname configure -text "GIT Path"
            $logcanvas.up.rfname configure -state normal
            $logcanvas.up.rfname delete 0 end
            $logcanvas.up.rfname insert end "$cvsglb(relpath)/$fname"
            $logcanvas.up.rfname configure -state readonly
           set info_cmd [exec::new "git log --abbrev-commit --pretty=oneline --max-count=1 --no-color -- \"$fname\""]
           set infoline [$info_cmd\::output]
           gen_log:log D "$infoline"
           # don't split infoline because comments like this break it:
           #f6c73a2 Reinstate debug command. Apparently "$1"x != x works differently in bash 4.2
           regsub { .*$} $infoline {} current_revnum
           #gen_log:log D "current_revnum $current_revnum"
           if {! [info exists current_revnum]} {
             gen_log:log E "Warning: couldn't find current revision number!"
           }
           if {$loc == "rep"} {
             # Working on repository files, not checked out
             # can we implement this?
           } else {
             # We have a checked-out local file
             $logcanvas.log configure \
                  -command [namespace code {
                    set rev [$logcanvas.up.revA_rvers get]
                    if {$rev == ""} {
                      git_log_rev "" $filename
                    } else {
                      git_log_rev $rev $filename
                    }
                  }]
             $logcanvas.view configure -state normal \
               -command [namespace code {
                    set rev [$logcanvas.up.revA_rvers get]
                    if {$rev ==""} { set rev "r$current_revnum" }
                    git_fileview $rev $cvsglb(relpath) $filename
               }]
             $logcanvas.annotate configure -state normal \
               -command [namespace code {
                   set rev [$logcanvas.up.revA_rvers get]
                   if {$rev == ""} {
                     git_annotate_r "" $filename
                   } else {
                     git_annotate_r $rev $filename
                   }
               }]
             $logcanvas.delta configure -state disabled
             $logcanvas.viewtags configure -state normal \
               -command {git_list_tags}
            }
         }
         "RCS" {
           $logcanvas.up.bmodbrowse configure -state disabled -image {}
           $logcanvas.up.lfname configure -text "RCS file"
           $logcanvas.up.rfname configure -state normal
           $logcanvas.up.rfname delete 0 end
           $logcanvas.up.rfname insert end "$fname"
           $logcanvas.up.rfname configure -state readonly
           $logcanvas.view configure \
             -command [namespace code {
               rcs_fileview_checkout  [$logcanvas.up.revA_rvers get] $filename
                }]
           $logcanvas.annotate configure -state disabled
           $logcanvas.log configure -command [namespace code {rcs_log $filename}]
           $logcanvas.delta configure -state disabled
          }
        }
      }

      # Pop up a transient window with a listbox of the tags for a specific
      # revision
      proc PopupTags { x y } {
        global cvscfg
        global cvsglb
        variable logcanvas
        variable revtags

        gen_log:log T "ENTER ($x $y)"

        # We tagged the "more..." text with R$revision
        foreach tag [$logcanvas.canvas gettags current] {
          if {[string index $tag 0] == {R}} {
            set rev [string range $tag 1 end]
            lassign [$logcanvas.canvas coords $tag] rev_x rev_y
            gen_log:log D "item $tag coords: $rev_x $rev_y"
            break
          }
        }
        set mname "$logcanvas.canvas.[join [split $rev {.}] {_}]"
        set ntags [llength $revtags($rev)]
        incr ntags
        if {$ntags > 20} {set ntags 20}
        set line_h [font metrics $cvscfg(listboxfont) -displayof $logcanvas -linespace]
        gen_log:log D "line height: $line_h"
        set h [expr {$ntags * $line_h}]
        gen_log:log D "height for $ntags tags: $h"
        incr h $line_h
        set maxlen 0
        foreach t $revtags($rev) {
          set len [string length $t]
          if {$len > $maxlen} {
            set maxlen $len
            set maxtag $t
          }
        }
        set maxtag "mm$maxtag"
        set w [font measure $cvscfg(listboxfont) -displayof $logcanvas "$maxtag"]
        if {! [winfo exists $mname]} {
          gen_log:log D "width from $maxtag: $w"
          frame $mname -relief raised -bd 2 -bg $cvsglb(hlbg)
          listbox $mname.lbx -font $cvscfg(listboxfont) \
            -yscroll "$mname.yscr set" \
            -listvar [namespace current]::revtags($rev)
          scrollbar $mname.yscr -orient vertical -command "$mname.lbx yview"
          button $mname.but -text "Close" -command "$logcanvas.canvas delete lbx"
          incr w [winfo reqwidth $mname.yscr]
          incr h [winfo reqheight $mname.but]
          $logcanvas.canvas create window $rev_x $rev_y -anchor w \
            -height $h -width $w -window $mname -tags lbx
          pack $mname.but -in $mname -side bottom
          pack $mname.yscr -in $mname -side right -fill y
          pack $mname.lbx -in $mname -side left -expand yes -fill both
          bind $mname.lbx <Button-1> [namespace code "
                variable revtags
                set i \[$mname.lbx nearest %y\]
                SetSelection A \[lindex \$revtags($rev) \$i\] $rev
                $mname.lbx selection clear 0 end
                $mname.lbx selection set \$i"]
          bind $mname.lbx <Button-2> [namespace code "
                variable revtags
                set i \[$mname.lbx nearest %y\]
                SetSelection A \[lindex \$revtags($rev) \$i\] $rev
                $mname.lbx selection clear 0 end
                $mname.lbx selection set \$i"]
          bind $mname.lbx <Button-3> [namespace code "
                variable revtags
                set i \[$mname.lbx nearest %y\]
                SetSelection B \[lindex \$revtags($rev) \$i\] $rev
                $mname.lbx selection clear 0 end
                $mname.lbx selection set \$i"]
        } else {
          gen_log:log D "$mname already exists"
          $logcanvas.canvas create window $rev_x $rev_y -anchor w \
            -height $h -width $w -window $mname -tags lbx
        }
        gen_log:log T "LEAVE"
        return
      }

      # Calculate size of the You are Here box
      proc CalcCurrent { revision } {
        variable curr
        variable font_bold
        variable font_bold_h
        variable logcanvas

        #gen_log:log T "ENTER ($revision)"
        set redbox_width \
          [expr {[image width Man] \
                 + $curr(padx) \
                 + [font measure $font_bold \
                     -displayof $logcanvas.canvas {You are}] \
                 + $curr(padx,2)}]
        set redbox_height [image height Man]
        set h [expr {2 * $font_bold_h}]
        if {$h > $redbox_height} {
          set redbox_height $h
        }
        incr redbox_height $curr(pady,2)
        #gen_log:log T "LEAVE box sixe ($redbox_width x $redbox_height)"
        return [list $redbox_width $redbox_height]
      }

      # Draw You are Here box
      proc DrawCurrent { x y width height revision } {
        global cvsglb
        variable curr
        variable revstate
        variable font_bold
        variable logcanvas
        variable curr_x
        variable curr_y

        #gen_log:log T "ENTER ($x $y $width $height $revision)"
        set curr_x $x
        set curr_y $y
        # draw the box
        set tx [expr {$x + $width}]
        set ty [expr {$y - $height}]
        $logcanvas.canvas create rectangle \
          $x $y $tx $ty \
          -width $curr(width) -fill $cvsglb(textbg) -outline red3
        if {[info exists revstate(current)]} {
          if {$revstate(current) == {dead}} {
            $logcanvas.canvas create line \
              $x $y $tx $ty -fill red -width $curr(width)
            $logcanvas.canvas create line \
              $tx $y $x $ty -fill red -width $curr(width)
          }
        }
        set pad \
          [expr {($width - [image width Man] - \
            [font measure $font_bold -displayof $logcanvas.canvas {You are}]) \
            / 3}]
        set ty [expr {$y - [expr {$height/2}]}]
        # add the contents
        $logcanvas.canvas create image \
          [expr {$x + $pad}] $ty \
          -image Man -anchor w
        $logcanvas.canvas create text \
          [expr {$x + $width - $pad}] $ty \
          -text "You are\nhere" -anchor e \
          -fill red3 \
          -font $font_bold
        #gen_log:log T "LEAVE ()"
        return
      }

      # Finds the dimensions including tags, but not the location, for the blue root box.
      # That (tags on the root) can only happen in CVS, I think
      proc CalcRoot { root_rev } {
        global cvscfg
        global logcfg
        variable curr
        variable box_height
        variable font_bold
        variable font_norm
        variable font_norm_h
        variable logcanvas
        variable root_info
        variable revtags
        variable revbtags
        variable tlist

        #gen_log:log T "ENTER ($root_rev)"
        set height $box_height
        set root_width 0
        set tag_width 0

        set tlist($root_rev) {}
        if {[info exists revtags($root_rev)]} {
          # We want to show all the coloured tags plus others to take
          # the total to at least cvscfg(tagdepth)
          set tag_colour {}
          set tag_black {}
          foreach tag $revtags($root_rev) {
            if {[info exists cvscfg(tagcolour,$tag)]} {
              lappend tag_colour $tag
            } else {
              lappend tag_black $tag
            }
          }
          set tlist($root_rev) [concat $tag_colour $tag_black]

          if {$logcfg(show_tags)} {
            if {[info exists cvscfg(tagdepth)] && $cvscfg(tagdepth) != 0} {
              set n [expr {$cvscfg(tagdepth) - [llength $tag_colour]}]
              if {$n < [llength $tag_black]} {
                set tag_black [concat [lrange $tag_black 0 [expr {$n-1}]] {more...}]
              }
            }
            set my_font $font_bold
            foreach tag $tlist($root_rev) {
              set w [font measure $my_font -displayof $logcanvas.canvas $tag]
              if {$w > $tag_width} {
                set tag_width $w
              }
            }
            incr tag_width $curr(tspcb,2)
            set h [expr {[llength $tlist($root_rev)] * $font_norm_h}]
            if {$h > $height} {
              set height $h
            }
          }
        }
        if {![info exists revbtags($root_rev)]} {set revbtags($root_rev) {}}
        foreach s [subst $root_info] {
          set w [font measure $font_norm -displayof $logcanvas.canvas " $s "]
          if {$w > $root_width} {
            set root_width $w
          }
        }
        incr width $curr(padx,2)
        set height [expr {$curr(pady,2) + \
          [llength [subst $root_info]] * $font_norm_h}]
        gen_log:log T "LEAVE (tag_width $tag_width root_width $root_width height $height)"
        return [list $tag_width $root_width $height]
      }

      proc DrawRoot { x y rbox_width rbox_height cur_rev root_rev } {
        global cvscfg
        global cvsglb
        variable curr
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable logcanvas
        variable root_info
        variable revbtags
        variable revbranches
        variable tlist

        #gen_log:log T "ENTER ($x $y $rbox_width $rbox_height $cur_rev $root_rev)"
        if {[info exists revbtags($root_rev)]} {
          #gen_log:log D "revbtags($root_rev) $revbtags($root_rev)"
          gen_log:log D "Drawing root for $revbtags($root_rev) $root_rev"
        } else {
          gen_log:log D "Drawing nameless root for $root_rev"
          set revbtags() {}
        }

        # draw the box
        $logcanvas.canvas create rectangle \
          $x $y \
          [expr {$x + $rbox_width}] [expr {$y - $rbox_height}] \
          -width $curr(width) \
          -tags box \
          -fill $cvsglb(textbg) -outline blue

        set tx [expr {$x + $rbox_width/2}]
        set ty [expr {$y - $curr(pady)}]
        #gen_log:log D "[subst $root_info]"
        foreach s [subst $root_info] {
          $logcanvas.canvas create text \
            $tx $ty \
            -text $s \
            -anchor s \
            -font $font_norm -fill navy \
            -tags "R$root_rev"
          incr ty -$font_norm_h
        }
        #gen_log:log T "LEAVE ()"
        return
      }

      # Finds the dimensions including tags, but not the location, of each revision box
      proc CalcRevision { revision } {
        global cvscfg
        global logcfg
        global ingit
        variable curr
        variable box_height
        variable rev_info
        variable revdate
        variable revtime
        variable revwho
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable logcanvas
        variable revtags
        variable revbtags
        variable tlist
        variable btlist

        #gen_log:log T "ENTER ($revision)"
        set height $box_height
        set width 0
        set tag_width 0

        set tlist($revision) {}
        if {[info exists revtags($revision)]} {
          # We want to show all the coloured tags plus others to take
          # the total to at least cvscfg(tagdepth)
          set tag_colour {}
          set tag_black {}
          foreach tag $revtags($revision) {
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
          if {$logcfg(show_tags)} {
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
        }
        if {$ingit && $logcfg(show_tags) && ! $logcfg(show_branches)} {
          # If show_branches is off but we're in git, it doesn't cost anything to
          # get branch tags, so we can show them like tags
          set btlist($revision) {}
          set btag_colour {}
          set btag_black {}
          if {[info exists revbtags($revision)]} {
            foreach btag $revbtags($revision) {
              lappend btag_colour $btag
            }
            if {[info exists cvscfg(tagdepth)] && $cvscfg(tagdepth) != 0} {
              set n [expr {$cvscfg(tagdepth) - [llength $btag_colour]}]
              if {$n < [llength $btag_black]} {
                set btag_black [concat [lrange $btag_black 0 [expr {$n-1}]] {more...}]
              }
            }
            set btlist($revision) [concat $btag_colour $btag_black]
            set my_font $font_bold
            foreach rbt $revbtags($revision) {
              set w [font measure $my_font -displayof $logcanvas.canvas $rbt]
              if {$w > $tag_width} {
                set tag_width $w
              }
            }
            incr tag_width $curr(tspcb,2)
            set h [expr {[llength $btlist($revision)] * $font_norm_h}]
            if {$h > $height} {
              set height $h
            }
          }
        }

        if {![info exists revtime($revision)]} {set revtime($revision) {}}
        if {![info exists revdate($revision)]} {set revdate($revision) {}}
        if {![info exists revinfo($revision)]} {set revinfo($revision) {}}
        if {![info exists revwho($revision)]} {set revwho($revision) {}}
        foreach s [subst $rev_info] {
          set w [font measure $font_norm -displayof $logcanvas.canvas $s]
          if {$w > $width} {
            set width $w
          }
        }
        incr width $curr(padx,2)
        #gen_log:log T "LEAVE (tag_width $tag_width  width $width  height $height)"
        return [list $tag_width $width $height]
      }

      proc DrawRevision { x y width height revision} {
        global cvscfg
        global cvsglb
        global logcfg
        global ingit
        variable curr
        variable rev_info
        variable revdate
        variable revtime
        variable revwho
        variable revstate
        variable revkind
        variable revtags
        variable revbtags
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable logcanvas
        variable btlist
        variable tlist
        variable match
        variable fromtags
        variable totags
        variable xyw
        variable boxwidth
        variable fromprefix
        variable toprefix
        variable mrev
        variable drawn_revs
        upvar branch branch

        #gen_log:log T "ENTER ($x $y $width $height $revision)"
        if {! [info exists drawn_revs]} {
          set drawn_revs ""
        }
        if {$revision in $drawn_revs} {
          gen_log:log E "$revision is already drawn!"
          return
        }
        set xyw($revision) [list $x [expr {$y - ($height / 4)}] $width ]
        # Draw the list of tags
        set tx [expr {$x - $curr(tspcb)}]
        set ty $y
        set revbtag $revbtags($branch)
        if {$ingit && $logcfg(show_tags) && ! $logcfg(show_branches)} {
          # This is a git-only thing. Treat branches as tags
          foreach btag $btlist($revision) {
            gen_log:log D "$revision: btag $btag"
            set my_font $font_bold
            set btagcolour blue
            set btaglist {}
            if {$btag == {more...}} {
              set my_font $font_bold
              set btaglist [list R$revision tag active]
              set tagcolour $cvscfg(tagcolour,$btag)
            }
            $logcanvas.canvas create text \
               $tx $ty \
               -text $btag \
               -anchor se -fill $btagcolour \
               -font $my_font \
               -tags $btaglist
            incr ty -$font_norm_h
          }
        }
        foreach tag $tlist($revision) {
          gen_log:log D "$revision: tag $tag"
          if {[string match "${fromprefix}_*" $tag]} {
            set mrev($tag) $revision
            lappend fromtags $tag
            regsub {.*_(.*$)} $tag {\1} tagend
            gen_log:log D "  $tag is a FROM TAG"
            gen_log:log D "  will need a TO TAG ${toprefix}_${revbtag}_$tagend"
            set match($tag) ${toprefix}_${revbtag}_$tagend
          }
          if {[string match "${toprefix}_*" $tag]} {
            set mrev($tag) $revision
            lappend totags $tag
          }
          if {$logcfg(show_tags)} {
            set my_font $font_norm
            set tagcolour black
            set taglist {}
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
        }
        # draw the box...
        set tx [expr {$x + $width}]
        set ty [expr {$y - $height}]
        $logcanvas.canvas create rectangle \
          $x $y $tx $ty \
          -width $curr(width) -fill $cvsglb(textbg) -outline black \
          -tags [list box selectable R$revision rect$revision active]
        # ...and add the contents
        if {[info exists revstate($revision)]} {
          if {$revstate($revision) == {dead}} {
            # in CVS, a "dead" revision, which is often present if a file was
            # added on a branch
            $logcanvas.canvas create line \
              $x $y $tx $ty -fill red -width $curr(width)
            $logcanvas.canvas create line \
              $tx $y $x $ty -fill red -width $curr(width)
          } elseif {$revstate($revision) == {ghost}} {
            # In GIT, a similar thing happens if a file was added on a branch.
            # It's not dead, it's just not reachable from the current branch.
            $logcanvas.canvas create line \
              $x $y $tx $ty -fill gray -width $curr(width)
            $logcanvas.canvas create line \
              $tx $y $x $ty -fill gray -width $curr(width)
          }
        }
        set tx [expr {$x + $width/2}]
        set ty [expr {$y - $curr(pady)}]
        foreach s [subst $rev_info] {
          $logcanvas.canvas create text \
            $tx $ty \
            -text $s \
            -anchor s \
            -font $font_norm \
            -tags [list selectable R$revision active]
          incr ty -$font_norm_h
        }
        lappend drawn_revs $revision
        #gen_log:log T "LEAVE ()"
        return
      }

      proc DrawBranch { x y root_rev branch } {
        global logcfg
        global ingit
        variable logcanvas
        variable curr
        variable box_height
        variable bot_height
        variable tip_height
        variable lbl_height
        variable cur_height
        variable revkind
        variable branchrevs
        variable revbranches
        variable revbtags
        variable drawn_revs

        gen_log:log T "ENTER ($x $y $root_rev $branch)"
        gen_log:log T "level [info level]"
        if {! [info exists drawn_revs]} {
          set drawn_revs ""
        }
        if {[info exists revbtags($branch)]} {
          gen_log:log D "Drawing $revbtags($branch) $branch rooted at $root_rev ($x $y)"
        } else {
          gen_log:log D "Drawing nameless branch rooted at $root_rev ($x $y)"
        }
        # What revisions to show on this branch? Options may hide some
        if {![info exists branchrevs($branch)]} {set branchrevs($branch) {}}
        foreach r $drawn_revs {
          if {$r in $branchrevs($branch)} {
            gen_log:log E "Revision $r already drawn!"
            return [list $x $y 200 18 $y]
          }
        }
        if {$branchrevs($branch) == {}} {
          set revlist {}
        } else {
          # Always have the head revision
          set revlist [lindex $branchrevs($branch) 0]
          foreach r [lrange $branchrevs($branch) 1 end-1] {
            if {![info exists revbranches($r)]} {set revbranches($r) {}}
            if {$logcfg(show_inter_revs) || $logcfg(show_empty_branches) \
                && $revbranches($r) != {}} {
              lappend revlist $r
            } else {
              # Only if there are non-empty branches off this revision
              foreach b $revbranches($r) {
                if {![info exists branchrevs($b)]} {set branchrevs($b) {}}
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
        set rdata {}
        # On encountering a branch, it may be just a You are Here, which
        # has a simplified special procedure. Otherwise, kick off a new
        # branch.
        if {$branch == {current}} {
          set rtw 0
          lassign [CalcCurrent $branch] box_width cur_height
          set lbl_height(current) $cur_height
        } else {
          lassign [CalcRoot $branch] rtw box_width bot_height
          set tip_height 0
          if {$ingit} {
            set tip_height $bot_height
            set bot_height 0
          }
          set lbl_height($branch) $bot_height
          gen_log:log D "set lbl_height($branch) ($lbl_height($branch))"
          #set tip_height $lbl_height($branch)
          if {$rtw > $tag_width} {
            set tag_width $rtw
          }
        }
        set height [expr {$lbl_height($branch) + $curr(spcy)}]
        # calculate the size of each revision in the branch, and keep
        # track of the largest x and y dimensions, which we will use
        # for all when drawing
        set rev_height 0      
        foreach revision $revlist {
          if {$revision == {current}} {
            set rtw 0
            lassign [CalcCurrent $revision] rbw cur_height
            set lbl_height(current) $cur_height
          } else {
            lassign [CalcRevision $revision] rtw rbw rev_height
          }
          if {$rev_height != 0} {
            set rh $rev_height
          } else {
            set rh $cur_height
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
        # At the end, we've saved the height and width of the whole column

        # Position branch. Query the canvas to look for overlaps, using the
        # lower-left x and y that were passed in, and the measured width and
        # accumulated height. Use tk's canvas overlap command to find and tag
        # any overlapping objects within the rectangle. We haven't drawn
        # anything yet, this is still just in memory

        # Look for overlap horizontally
        while {1} {
          set overlap_llx [expr {$x - $curr(spcx)}]
          set overlap_lly [expr {$y - $height + $curr(yfudge)}]
          set overlap_urx [expr {$x + $tag_width + $box_width}]
          set overlap_ury $y
          $logcanvas.canvas addtag ol_x overlapping \
              $overlap_llx $overlap_lly $overlap_urx $overlap_ury
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
          set overlap_llx $x
          set overlap_lly [expr {$y - $height}]
          set overlap_urx [expr {$x + $tag_width + $box_width}]
          set overlap_ury [expr {$y - $height + $curr(yfudge)}]
          $logcanvas.canvas addtag ol_y overlapping \
            $overlap_llx $overlap_lly $overlap_urx $overlap_ury
          set bbox [$logcanvas.canvas bbox ol_y]
          $logcanvas.canvas dtag ol_y
          if {$bbox != {}} {
            # Move down to make space
            gen_log:log D "vertical overlap with $bbox"
            incr y [expr {[lindex $bbox 3] - ($y - $height) + $curr(spcy) + $tip_height}]
          }

        # Now we're ready to start drawing
        # Position to top of branch
        incr x $tag_width
        set top_y $y
        incr y -$height
        # Draw this branch
        set midx [expr {$x + $box_width/2}]
        set last_y {}
        foreach revision $revlist {rtag_width rheight} $rdata {
          incr y $curr(spcy)
          incr y $rheight
          # For each branch off this revision, draw it to the right of this
          # revision box and a little above the centre line of this box.
          set x2 [expr {$x + $box_width + $curr(spcx)}]
          set y2 [expr {$y - $box_height/2 - $curr(boff)}]
          set brevs {}
          set bxys {}
          if {[info exists revbranches($revision)]} {
            # Here we recurse into branches off of the current branch
            foreach r2 $revbranches($revision) {
              if {![info exists branchrevs($r2)] } { set branchrevs($r2) {} }
              # Don't display the branch if it is empty unless
              # logcfg(show_empty_branches) is set.  Except for You are Here,
              # which is a special case
              if {$branchrevs($r2) == {} && $r2 != {current} && !\
                  $logcfg(show_empty_branches)} {
                continue
              }
              lappend brevs $r2
              foreach {lx y2 lbw rh lly} [DrawBranch $x2 $y2 $revision $r2] {
                lappend bxys $lx $lbw $rh $lly
                break
              }
              set x2 [expr {$lx + $lbw + $curr(spcx)}]
            }
          }

          # y2 may have changed to accomodate a long branch. If so we need
          # to figure out what our y should be
          set y [expr {$y2 + $box_height/2 + $curr(boff)}]
          set rx [expr {$x + $box_width}]
          set ry [expr {$y - $box_height/2}]
          set by [expr {$ry - $curr(boff)}]

          # If it has brevs, it's the root of a branch
          # Draw the arrows before the boxes, leaving box-high spaces between them
          foreach b $brevs {bx bw rh ly} $bxys {
            set mx [expr {$bx + $bw/2}]
            if {$ly != {} && ! $ingit} {
              # The up-pointing arrow below the bottom revision, if that has been raised
              $logcanvas.canvas create line \
                $mx $ly $mx [expr {$by - $rh}] \
                -arrow first -arrowshape $curr(arrowshape) -width $curr(width)
            }
            if {$ingit && $ly != {}} {
              set ny [expr {$ly + $curr(boff)}]
              if {$ny != $by} {
                # The up-pointing arrow below the bottom revision, if that has been raised
                  $logcanvas.canvas create line \
                    $mx $ly $mx [expr {$by - $curr(boff)}] \
                    -arrow first -arrowshape $curr(arrowshape) -width 1
              }
            }
            if {$b == {current}} {
              # treat this "current" as a branch. The arrow points sideways to it
              DrawCurrent $bx $by $bw $cur_height $revision
              $logcanvas.canvas lower [ \
                $logcanvas.canvas create line \
                  $rx $ry $mx $ry $mx $by \
                  -arrow last -arrowshape $curr(arrowshape) -width $curr(width)
              ]
              # And we're done, no arrows or boxes above it
              continue
            } else {
              # if the last (top) revision is current, we don't draw that one now.
              # We save it for when we draw the regular revboxes, below
              set last_rev [lindex $branchrevs($b) 0]
              if {$last_rev == {current}} {
                set last_rev [lindex $branchrevs($b) 1]
              }
            }
            if {! $ingit} {
              DrawRoot $bx $by $bw $lbl_height($b) $revision $b
              #if {$ly == {} } {
              #$logcanvas.canvas create line \
                #$mx [expr {$by - $rh}] $mx [expr {$by - $rh - $curr(boff)}] \
                #-arrow last -arrowshape $curr(arrowshape) \
                #-width $curr(width) -fill brown
              #}
            }
            # Arrow connecting the branch root box to its parent
            if {$ingit} {
              # Curved line.
              #set ay [expr {$by - $tip_height - $curr(boff)}]
              set ay [expr {$by - $curr(boff)}]
              $logcanvas.canvas lower [ \
                $logcanvas.canvas create line \
                  $rx $ry $mx $ry $mx $ay \
                  -arrow last -arrowshape $curr(arrowshape) -smooth 1
              ]
            } else {
              # Blue elbow
              $logcanvas.canvas lower [ \
                $logcanvas.canvas create line \
                  $rx $ry $mx $ry $mx $by \
                  -arrow last -arrowshape $curr(arrowshape) -width $curr(width) \
                  -fill blue
              ]
            }
            if {$logcfg(update_drawing) < 1} {
              UpdateBndBox
            }
          }
          # finised drawing special items for sub-branches

          if {$last_y != {}} {
            # This is a regular between-revisions arrow
            $logcanvas.canvas create line \
              $midx $last_y $midx [expr {$y - $box_height}] \
              -arrow first -arrowshape $curr(arrowshape) -width $curr(width)
          }

          # Start drawing the boxes.
          # First, the top one may well be "current" which is
          # a special case.
          if {$revision == {current}} {
            DrawCurrent $x $y $box_width $rheight $revision
          } else {
            # Otherwise, draw normal revision
            DrawRevision $x $y $box_width $rheight $revision
          }
          if {$logcfg(update_drawing) < 1} {
            UpdateBndBox
          }
          set last_y $y
          set last_rev $revision
        }
        # Finished individual revisions and their branches

        if {$ingit} {
          # For Git, now we draw the root box at the top
          lassign [CalcRoot $branch] rtw ignore bot_height
          if {$last_y != {} } {
            set gy [expr {$top_y - $height}]
            DrawRoot [expr {$midx - ($box_width/2)}] $gy $box_width $bot_height [lindex $branchrevs($branch) end] $branch
            $logcanvas.canvas lower [ \
              $logcanvas.canvas create line \
               $midx $gy $midx [expr {$gy + $curr(spcy)}] \
               -arrow first -arrowshape $curr(arrowshape) -width $curr(width) -fill blue
            ]
          }
        }
        if {$logcfg(update_drawing) < 2} {
          UpdateBndBox
        }
        set new_y [expr {$y + $lbl_height($branch) + $curr(spcy)}]
        gen_log:log T "LEAVE ($x $new_y $box_width $lbl_height($branch) $last_y)"
        return [list $x $new_y $box_width $lbl_height($branch) $last_y]
      }

      proc DrawSideTree { x y root_rev } {
        global ingit
        variable logcanvas
        variable curr
        variable lbl_height
        variable branchrevs
        variable revmergefrom
        variable xyw

        gen_log:log T "ENTER: ($x $y $root_rev)"
        gen_log:log D "Drawing SideTree branch at $root_rev"
        foreach {lx y2 lbw rh lly} [DrawBranch $x $y $root_rev $root_rev] {
          lappend bxys $lx $lbw $rh $lly
          break
        }
        gen_log:log D "Drawing root for $root_rev SideTree"
        lassign [CalcRoot $root_rev] rtw box_width box_height
        set x2 [expr {$lx + $lbw + $curr(spcx)}]
        set mx [expr {$lx + $lbw/2}]
        set ry [expr {$y2 - $rh/4 - $curr(spcy)}]
        set by [expr {$y2 - $curr(boff)}]
        lassign [CalcRoot $root_rev] rtw box_width ignore

        if {! $ingit} {
          # This is the blue box at the bottom of the side branch
          DrawRoot $lx $y2 $lbw $lbl_height($root_rev) $root_rev $root_rev
          # This is the arrow at the base of the side branch
          $logcanvas.canvas lower [\
            $logcanvas.canvas create line \
              $mx $ry $mx [expr {$by - $rh}] \
              -arrow last -arrowshape $curr(arrowshape) \
              -width $curr(width)
          ]
        }
        # See if any merges were from this branch back to one we've already drawn
        foreach to [array names revmergefrom] {
          if {$revmergefrom($to) ni $branchrevs($root_rev)} continue
          #gen_log:log D "revmergefrom($to) $revmergefrom($to)"
          set from $revmergefrom($to)
          if [info exists xyw($from)] {
                #gen_log:log D " xyw($from) $xyw($from)"
          } else {
            #gen_log:log D " xyw($from) doesn't exist"
            continue
          }
          if [info exists xyw($to)] {
            gen_log:log D " xyw($to) $xyw($to)"
          } else {
            #gen_log:log D " xyw($to) doesn't exist"
                continue
          }
          set xto [lindex $xyw($from) 0]
          set yto [lindex $xyw($from) 1]
          set bwto [lindex $xyw($from) 2]
          set xfrom [lindex $xyw($to) 0]
          set yfrom [lindex $xyw($to) 1]
          set bwfrom [lindex $xyw($to) 2]
          set xmid $xto
          set ymid $yto
          if {$xto > $xfrom} {
            set xfrom [expr {$xfrom + $bwfrom}]
            set yfrom [expr {$yfrom - ($box_height / 2)}]
            set yto [expr {$yto - ($box_height / 2)}]
            set xmid [expr {$xfrom + (($xto - $xfrom) / 2)}]
            set ymid [expr {$yto - $box_height}]
          } elseif {$xfrom > $xto} {
            set xto [expr {$xto + $bwto}]
            set xmid [expr {$xto + (($xfrom - $xto) / 2)}]
            set ymid [expr {$yto + ($box_height / 2)}]
          } elseif {$xto == $xfrom} {
            set xmid [expr {$xto - ($bwfrom / 2)}]
            set ymid [expr {$yfrom - (($yfrom - $yto) / 2)}]
          }
          $logcanvas.canvas create line \
              $xfrom $yfrom $xmid $ymid $xto $yto \
              -arrow first -smooth 1
        }

        UpdateBndBox

        gen_log:log T "LEAVE"
        return $x2
      }

      proc UpdateBndBox {} {
        global ingit
        variable logcanvas
        variable font_bold
        variable view_xoff
        variable view_yoff
        variable curr_x
        variable curr_y

        #gen_log:log T "ENTER ()"
        lassign [$logcanvas.canvas bbox all] x1 y1 x2 y2
        if {$x1 == ""} {
          gen_log:log D "No BBOX"
          return
        }
        if {! $ingit} {
          $logcanvas.canvas configure \
            -scrollregion [list \
              [expr {$x1 - 5}] [expr {$y1 - 5}] \
              [expr {$x2 + 5}] [expr {$y2 + 5}]
            ]
        } else {
          # In git, we may have merge arrows to the left of the first column.
          # tk doesn't include these in the bounding box, for some reason
          $logcanvas.canvas configure \
            -scrollregion [list \
              [expr {$x1 - 25}] [expr {$y1 - 5}] \
              [expr {$x2 + 5}] [expr {$y2 + 5}]
            ]
        }

        if {[info exists curr_x]} {
          set canv_width [$logcanvas.canvas cget -width]
          set canv_height [$logcanvas.canvas cget -height]
          set bbox [$logcanvas.canvas bbox all]
          set llx [lindex $bbox 0]
          set lly [lindex $bbox 1]
          set urx [lindex $bbox 2]
          set ury [lindex $bbox 3]
          set bbox_width [expr {$urx - $llx}]
          set bbox_height [expr {$ury - $lly}]
          #gen_log:log D "diagram size: $bbox_width x $bbox_height"
          #gen_log:log D "canvas size:  $canv_width x $canv_height"
          set canv_bot [expr {$ury - $canv_height}]
          set view_y [expr {$canv_bot - $ury}]
          #gen_log:log D "bbox:         $bbox"
          #gen_log:log D "canvas view:  $llx $canv_bot  $canv_width $view_y"
          #gen_log:log D "curr x & y:  $curr_x, $curr_y"
          #gen_log:log D "x: (curr_x $curr_x) >? (canv_width $canv_width)"
          if {$curr_x > $canv_width} {
            set dist_x [expr {$curr_x - $canv_width/2}]
            set dist_x [expr {$dist_x - 3 * [font measure $font_bold \
                     -displayof $logcanvas.canvas {You are}]}]
            #gen_log:log D "positioning x:  new x $dist_x"
          } else {
            #gen_log:log D "not re-positioning x"
            set dist_x 0
          }
          #gen_log:log D "y: (curr_y $curr_y) <? (view_y $view_y)"
          if {$curr_y < $view_y} {
            set dist_y [expr {$curr_y - $lly}]
            #gen_log:log D " $curr_y is $dist_y pixels from the top"
            set dist_y [expr {$dist_y - 2 * [image height Man]}]
            #gen_log:log D "positioning y:  new y $dist_y"
          } else {
            #gen_log:log D "not re-positioning y"
            set dist_y 0
          }
          # Multiplying by 1.0 keeps it from being rounded to an int
          set x_proportion [expr {($dist_x * 1.0) / ($bbox_width * 1.0)}]
          set view_xoff $x_proportion
          set y_proportion [expr {($dist_y * 1.0) / ($bbox_height * 1.0)}]
          set view_yoff $y_proportion
        }
        #gen_log:log D "set offset $view_xoff $view_yoff"
        $logcanvas.canvas xview moveto $view_xoff
        $logcanvas.canvas yview moveto $view_yoff
        update
        #gen_log:log T "LEAVE ()"
        return
      }

      proc DrawTree { {now {}} } {
        global cvscfg
        global logcfg
        global ingit
        variable scope
        variable after_id_draw
        variable logcanvas
        variable box_height
        variable bot_height
        variable tip_height
        variable lbl_height
        variable cur_height
        variable root_info
        variable fromtags {}
        variable totags {}
        variable toprefix
        variable fromprefix
        variable xyw
        variable boxwidth
        variable view_xoff
        variable view_yoff
        variable curr
        variable rev_info
        variable scale
        variable font_norm
        variable font_norm_h
        variable font_bold
        variable font_bold_h
        variable sys

        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable revstate
        variable revtags
        variable revbtags
        variable revpath
        variable revkind
        variable revbranches
        variable revmergefrom
        variable branchrevs
        variable mrev
        variable match
        variable drawn_revs

        gen_log:log D "=================================="
        gen_log:log T "ENTER ($now)"

        catch {unset drawn_revs}
        catch {unset xyw}

        catch { unset revwho }
        foreach a [array names $scope\::revwho] {
          set revwho($a) [set $scope\::revwho($a)]
        }
        catch { unset revdate }
        foreach a [array names $scope\::revdate] {
          set revdate($a) [set $scope\::revdate($a)]
        }
        catch { unset revtime }
        foreach a [array names $scope\::revtime] {
          set revtime($a) [set $scope\::revtime($a)]
        }
        catch { unset revcomment }
        foreach a [array names $scope\::revcomment] {
          set revcomment($a) [set $scope\::revcomment($a)]
        }
        catch { unset revstate }
        foreach a [array names $scope\::revstate] {
          set revstate($a) [set $scope\::revstate($a)]
        }
        catch { unset revtags }
        foreach a [array names $scope\::revtags] {
          set revtags($a) [set $scope\::revtags($a)]
        }
        catch { unset revbtags }
        foreach a [array names $scope\::revbtags] {
          set revbtags($a) [set $scope\::revbtags($a)]
        }
        catch { unset revpath }
        foreach a [array names $scope\::revpath] {
          set revpath($a) [set $scope\::revpath($a)]
        }
        catch { unset revbranches }
        foreach a [array names $scope\::revbranches] {
          set revbranches($a) [set $scope\::revbranches($a)]
        }
        catch { unset revmergefrom }
        foreach a [array names $scope\::revmergefrom] {
          set revmergefrom($a) [set $scope\::revmergefrom($a)]
        }
        catch { unset revkind }
        foreach a [array names $scope\::revkind] {
          set revkind($a) [set $scope\::revkind($a)]
        }
        catch { unset branchrevs }
        foreach a [array names $scope\::branchrevs] {
          set branchrevs($a) [set $scope\::branchrevs($a)]
        }

        set totagbegin [string first "_BRANCH_" $cvscfg(mergetoformat) ]
        set fromtagbegin [string first "_BRANCH_" $cvscfg(mergefromformat) ]
        set fromprefix [string range $cvscfg(mergefromformat) 0 [expr {$fromtagbegin -1}]]
        set toprefix [string range $cvscfg(mergetoformat) 0 [expr {$totagbegin - 1}]]

        catch {after cancel $after_id_draw}
        busy_start $logcanvas
        if {$now != {now} && [info exists logcfg(draw_delay)]} {
          set after_id_draw \
            [after $logcfg(draw_delay) [namespace code {DrawTree now}]]
        } else {
          set view_xoff [lindex [$logcanvas.canvas xview] 0]
          set view_yoff [lindex [$logcanvas.canvas yview] 0]
          $logcanvas.canvas delete all
          # These put the names of variables into one variable to be passed.
          # Because they're in braces, we don't need to know about the
          # variables here.  But the proc they're evaluated in has to know
          # about them.
          set root_info {}
          if {$logcfg(show_root_tags)} {
            append root_info {$revbtags($root_rev) }
          }
          if {$logcfg(show_box_rev)} {
            if {$sys eq "CVS" || $sys eq "RCS"} {
              append root_info {$root_rev}
            }
          }
          set rev_info {}
          if {$logcfg(show_box_revtime)} {
            append rev_info {$revtime($revision) }
          }
          if {$logcfg(show_box_revdate)} {
            append rev_info {$revdate($revision) }
          }
          if {$logcfg(show_box_revwho)} {
            append rev_info {"$revwho($revision)" }
          }
          if {$logcfg(show_box_rev)} {
            append rev_info {$revision}
          }

          # Note: the boxes and tag lists are sized according to the font
          # so do not need to be scaled.
          set my_size [expr {round($logcfg(font_size) * $logcfg(scale))}]
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
            set curr($x) [expr {round($logcfg($x) * $font_norm_h * $logcfg(scale))}]
            if {$curr($x) < 1} {
              set curr($x) 1
            }
          }
          foreach x {padx pady tspcb width} {
            set curr($x) [expr {round($logcfg($x) * $logcfg(scale))}]
            set curr($x,2) [expr {$curr($x) << 1}]
          }
          set curr(arrowshape) {}
          foreach x $logcfg(arrowshape) {
            lappend curr(arrowshape) [expr {$x * $logcfg(scale)}]
          }
          set box_height [expr {$curr(pady,2) + [llength $rev_info]*$font_norm_h}]

          # Find the root. (needed for SVN and GIT). If there's a trunk, use that
          foreach a [array names revkind] {
            if {$revkind($a) == "root"} {
              set trunkrev $a
              break
            }
          }
          # If there's no trunk, find the beginning of a branch
          if {! [info exists trunkrev] || $trunkrev == ""} {
            gen_log:log D "No trunk found!"
            set min 999999
            foreach a [array names revbtags] {
              if {$a == "" } {continue}
              foreach tag $revbtags($a) {
                if {$revbtags($a) != {} } {
                  set rnum [string trimleft $a {r}]
                  if {$rnum < $min} {set min $rnum}
                }
              }
            }
            if {$min != 999999} {
              set basebranch "r$min"
              gen_log:log D "No trunk, starting with basebranch $basebranch"
            }
          }

          # Start drawing, beginning with the trunk or the lowest branch
          if {[info exists trunkrev] && $trunkrev != ""} {
            gen_log:log D "Drawing trunkrev $trunkrev"
            foreach {lx y2 lbw rh lly} [DrawBranch 0 0 {} $trunkrev] {
              lappend bxys $lx $lbw $rh $lly
              break
            }
            set x2 [expr {$lx + $lbw + $curr(spcx)}]
            set mx [expr {$lx + $lbw/2}]
            set ry [expr {$y2 - $rh/4 - $curr(spcy)}]
            set by [expr {$y2 - $curr(boff)}]
            lassign [CalcRoot $trunkrev] rtw box_width ignore

            if {! $ingit} {
              # This is the blue box at the bottom of the trunk
              DrawRoot $lx $y2 $lbw $lbl_height($trunkrev) $trunkrev $trunkrev
              # This is the arrow at the base of the trunk
              $logcanvas.canvas lower [ \
                $logcanvas.canvas create line \
                  $mx $ry $mx [expr {$by - $rh}] \
                  -arrow last -arrowshape $curr(arrowshape) \
                  -width $curr(width)
              ]
            }
            UpdateBndBox
          } elseif {[info exists basebranch]} {
            gen_log:log D "Drawing basebranch $basebranch"
            foreach {lx y2 lbw rh lly} [DrawBranch 0 0 {} $basebranch] {
              lappend bxys $lx $lbw $rh $lly
              break
            }
            set x2 [expr {$lx + $lbw + $curr(spcx)}]
            set mx [expr {$lx + $lbw/2}]
            set ry [expr {$y2 - $rh/2 - $curr(spcy)}]
            set by [expr {$y2 - $curr(boff)}]
            lassign [CalcRoot $basebranch] rtw box_width bot_height

            if {! $ingit} {
              $logcanvas.canvas create line \
                $mx $by $mx [expr {$by - $rh}] \
                -arrow last -arrowshape $curr(arrowshape) \
                -width $curr(width)
              DrawRoot $lx $y2 $lbw $lbl_height($basebranch) $basebranch $basebranch
            }
            UpdateBndBox
          }

          gen_log:log D "fromtags: $fromtags"
          gen_log:log D "totags: $totags"
          if {$logcfg(show_merges)} {
            # Draw merge arrows derived from tags
            foreach from $fromtags {
              gen_log:log D "  $from on $mrev($from)"
              if {! [info exists match($from)]} {
                gen_log:log D "  No match for $match($from)"
                continue
              }
              foreach to $totags {
                 if {[string equal $to $match($from)]} {
                    gen_log:log D "  $to on $mrev($to)"
                    if {! [info exists revmergefrom($mrev($from))]} {
                      set revmergefrom($mrev($from)) $mrev($to)
                      gen_log:log D "Set revmergefrom($mrev($from)) = $mrev($to)"
                    } else {
                      gen_log:log D "revmergefrom($mrev($from)) exists. Not changing"
                    }
                 }
              }
            }
            # Draw merge arrows derived from cvsnt mergepoint, svn mergeinfo, or git
            foreach to [array names revmergefrom] {
              #gen_log:log D "revmergefrom($to) $revmergefrom($to)"
              set from $revmergefrom($to)
              if [info exists xyw($from)] {
                gen_log:log D " xyw($from) $xyw($from)"
              } else {
                #gen_log:log D " xyw($from) doesn't exist"
                continue
              }
              if [info exists xyw($to)] {
                gen_log:log D " xyw($to) $xyw($to)"
              } else {
                #gen_log:log D " xyw($to) doesn't exist"
                continue
              }
              set xto [lindex $xyw($from) 0]
              set yto [lindex $xyw($from) 1]
              set bwto [lindex $xyw($from) 2]
              set xfrom [lindex $xyw($to) 0]
              set yfrom [lindex $xyw($to) 1]
              set bwfrom [lindex $xyw($to) 2]
              set xmid $xto
              set ymid $yto
              if {$xto > $xfrom} {
                set xfrom [expr {$xfrom + $bwfrom}]
                set yfrom [expr {$yfrom - ($box_height / 2)}]
                set yto [expr {$yto - ($box_height / 2)}]
                set xmid [expr {$xfrom + (($xto - $xfrom) / 2)}]
                set ymid [expr {$yto - $box_height}]
              } elseif {$xfrom > $xto} {
                set xto [expr {$xto + $bwto}]
                set xmid [expr {$xto + (($xfrom - $xto) / 2)}]
                set ymid [expr {$yto + ($box_height / 2)}]
              } elseif {$xto == $xfrom} {
                set xmid [expr {$xto - ($bwfrom / 2)}]
                set ymid [expr {$yfrom - (($yfrom - $yto) / 2)}]
              }
              $logcanvas.canvas create line \
                  $xfrom $yfrom $xmid $ymid $xto $yto \
                  -arrow first -smooth 1
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
        gen_log:log T "LEAVE ()"
        if {[info exists x2]} {
          return $x2
        } else {
          return 0
        }
      }

      proc SaveOptions {} {
        global logcfg
        variable loc

        # Save the options to the global set
        set logcfg(update_drawing) $logcfg(update_drawing)
        foreach {key value} [array get opt] {
          gen_log:log D "logcfg($key) $value"
          set logcfg($key) $value
        }
        save_options
      }

      # Search functionality for log viewer that searches for strings in the
      # log windows. It will create a new button and an entry box below the logs. You
      # can enter a glob-style search pattern in the entry field and click the search
      # button. With every click (or pressing enter), the log viewer jumps from one
      # occurrence of the pattern to the next, highlighting it in red.
      #
      # The following special characters are used in the search pattern:
      #
      # *      Matches any sequence of characters in string, including a null string.
      #
      # ?      Matches any single character in string.
      #
      # [chars] Matches any character in the set given by chars. If a sequence of the
      # form x-y appears in chars, then any character between x and y, inclusive, will
      # match.
      #
      # \x      Matches the single character x. This provides a way of avoiding the
      # special interpretation of the characters *?[]\ in pattern.
      #
      # If you only enter "FOO" (without the ") in the entry box, it searches the exact
      # string "FOO". If you want to search all strings starting with "FOO", you have
      # to put "FOO*". For all strings containing "FOO", you must put "*FOO*".
      proc Search {} {
        global cvscfg
        global cvsglb
        variable logcanvas
        variable font_bold
        variable search_elements
        variable search_index
        variable search_lastpattern
        variable search_lastcase
        variable search_nocase
        variable revwho
        variable revdate
        variable revtime
        variable revcomment
        variable revtags
        variable revbtags

        gen_log:log T "ENTER search_index $search_index, search_elements $search_elements"

        # Read search pattern from entry box
        set pattern [string trim [$logcanvas.down.search.e get]]
        # Check if search pattern or nocase flag have been changed since the
        # last call
        if {([string equal $pattern $search_lastpattern] == 0) \
          ||($search_lastcase != $search_nocase)} {
          # Restore box colors
          foreach item [$logcanvas.canvas find withtag box] {
            $logcanvas.canvas itemconfigure $item -fill $cvsglb(textbg)
          }
          $logcanvas.canvas itemconfigure SelA -fill $cvscfg(colourA)
          $logcanvas.canvas itemconfigure SelB -fill $cvscfg(colourB)
          # Rebuild matching element list
          set search_lastpattern $pattern
          set search_lastcase $search_nocase
          set search_elements [list]
          # Ignore empty patterns
          if {[string length $pattern] != 0} {
            # Collect all the revision data
            foreach r [array names revdate] {
              set data "$r "
              catch {append data "$revwho($r) "}
              catch {append data "$revdate($r) "}
              catch {append data "$revtime($r) "}
              catch {append data "$revcomment($r) "}
              catch {append data "$revtags($r) "}
              catch {append data "$revbtags($r) "}

              # Check if text element matches search pattern
              if {$search_nocase} {
                if {[string match -nocase "*$pattern*" $data]} {
                  # Add element to list of matching elements
                  lappend search_elements $r
                  gen_log:log D "$pattern MATCHED $data"
                }
              } else {
                if {[string match "*$pattern*" $data]} {
                  # Add element to list of matching elements
                  lappend search_elements $r
                  gen_log:log D " $pattern MATCHED $data"
                }
              }
            }
          }
          # Reset highlight index
          set search_index 0
          # Pattern has not been changed since last call and there have been
          # matching elements found in the last call
        } elseif {[llength $search_elements] != 0} {
          # Select next matching element (restart if last one has been passed)
          incr search_index
          if {$search_index >= [llength $search_elements]} {
            set search_index 0
          }
          set rev [lindex $search_elements $search_index]
          gen_log:log D "   $rev"
        }
        # Check if there are matching elements
        set length [llength $search_elements]
        if {$length > 0} {
          foreach rev $search_elements {
            # This is the counter in the status bar
            $logcanvas.down.search.l configure -text "[expr {$search_index + 1}] / $length"
            # Find canvas items with tag rect$r
            foreach item [$logcanvas.canvas find withtag "box&&rect$rev"] {
              # Color the rectangle
              $logcanvas.canvas itemconfigure $item -fill lightsalmon
            }
          }
          set rev [lindex $search_elements $search_index]
          # There should only be one match but things go wrong
          set items [$logcanvas.canvas find withtag "box&&rect$rev"]
          set il [llength $items]
          if { $il > 1} {
            gen_log:log D "$il ITEMS MATCH the tag rect$rev"
          }
          set item [lindex $items 0]
          # There may be a data item for $rev but it isn't drawn
          if {$item != {}} {
            $logcanvas.canvas itemconfigure $item -fill orangered
            # Scroll to next matching item
            set scrollregion [$logcanvas.canvas cget -scrollregion]
            set coords [$logcanvas.canvas bbox $item]
            set sx1 [lindex $scrollregion 0]
            set sy1 [lindex $scrollregion 1]
            set sx2 [lindex $scrollregion 2]
            set sy2 [lindex $scrollregion 3]
            set ix1 [lindex $coords 0]
            set iy1 [lindex $coords 1]
            set ix2 [lindex $coords 2]
            set iy2 [lindex $coords 3]
            set xview [$logcanvas.canvas xview]
            set yview [$logcanvas.canvas yview]
            set vx1 [lindex $xview 0]
            set vx2 [lindex $xview 1]
            set vy1 [lindex $yview 0]
            set vy2 [lindex $yview 1]
            set x [expr {(double($ix1 - $sx1) / double($sx2 - $sx1)) -(($vx2 - $vx1) / 2)}]
            set y [expr {(double($iy1 - $sy1) / double($sy2 - $sy1)) -(($vy2 - $vy1) / 2)}]
            $logcanvas.canvas xview moveto $x
            $logcanvas.canvas yview moveto $y

            if {! [info exists revcomment($rev)]} {
               set revcomment($rev) "*** empty log message ***"
            }
          }
          $logcanvas.up.revA_rvers configure -state normal
          $logcanvas.up.revA_rvers delete 0 end
          $logcanvas.up.revA_rvers insert end "$rev"
          $logcanvas.up.revA_rvers configure -state readonly
          if {$rev != {} && [info exists revwho($rev)]} {
            $logcanvas.up.revA_rwho configure -text $revwho($rev)
            $logcanvas.up.revA_rdate configure -text "$revdate($rev) $revtime($rev)"
            $logcanvas.up.logA_rlogfm.rcomment configure -state normal
            $logcanvas.up.logA_rlogfm.rcomment delete 1.0 end
          if {$item == {}} {
              $logcanvas.up.logA_rlogfm.rcomment insert end "*** not drawn ***\n"
            }
            $logcanvas.up.logA_rlogfm.rcomment insert end $revcomment($rev)
            $logcanvas.up.logA_rlogfm.rcomment configure -state disabled
          }
        } else {
          $logcanvas.down.search.l configure -text "Not found"
        }
      } ;# End of Search proc


      toplevel $logcanvas
      wm title $logcanvas "TkCVS $cvscfg(version) -- $sys Log $filename"

      menubar_menus $logcanvas
      set filemenu_idx [$logcanvas.menubar index "File"]
      $logcanvas.menubar insert [expr {$filemenu_idx + 1}] cascade -label "Diagram"\
         -menu [menu $logcanvas.menubar.view] -underline 0

      help_menu $logcanvas

      # Diagram
      menu $logcanvas.menubar.view.update
      $logcanvas.menubar.view.update add radiobutton -label "Every Revision" \
        -variable logcfg(update_drawing) -value 0
      $logcanvas.menubar.view.update add radiobutton -label "Every Branch" \
        -variable logcfg(update_drawing) -value 1
      $logcanvas.menubar.view.update add radiobutton -label "When Finished" \
        -variable logcfg(update_drawing) -value 2
      $logcanvas.menubar.view add separator
      $logcanvas.menubar.view add cascade -label "Tree Layout" \
        -menu $logcanvas.menubar.view.tree
      menu $logcanvas.menubar.view.tree
      $logcanvas.menubar.view.tree add checkbutton -label \
        "Show tags" \
        -variable logcfg(show_tags) \
        -onvalue 1 -offvalue 0 \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.tree add checkbutton -label \
        "Show branches" \
        -variable logcfg(show_branches) \
        -onvalue 1 -offvalue 0 \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.tree add checkbutton -label \
        "Show empty branches" \
        -variable logcfg(show_empty_branches) \
        -onvalue 1 -offvalue 0 \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.tree add checkbutton -label \
        "Show intermediate revisions" \
        -variable logcfg(show_inter_revs) \
        -onvalue 1 -offvalue 0 \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.tree add checkbutton -label \
        "Show merges" \
        -variable logcfg(show_merges) \
        -onvalue 1 -offvalue 0 \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view add cascade -label "Branch Layout" \
        -menu $logcanvas.menubar.view.branch
      menu $logcanvas.menubar.view.branch
      $logcanvas.menubar.view.branch add command -label "Turn all options on" \
        -command [namespace code {
          set logcfg(show_root_tags) 1
          DrawTree
        }]
      $logcanvas.menubar.view.branch add command -label "Turn all options off" \
        -command [namespace code {
          set logcfg(show_root_tags) 0
          DrawTree
        }]
      $logcanvas.menubar.view.branch add separator
      $logcanvas.menubar.view.branch add checkbutton -label "Show label" \
        -variable logcfg(show_root_tags) \
        -onvalue 1 -offvalue 0 \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view add cascade -label "Revision Layout" \
        -menu $logcanvas.menubar.view.rev
      menu $logcanvas.menubar.view.rev
      $logcanvas.menubar.view.rev add command -label "Turn all options on" \
        -command [namespace code {
          set logcfg(show_tags) 1
          set logcfg(show_branches) 1
          set logcfg(show_box_rev) 1
          set logcfg(show_box_revwho) 1
          set logcfg(show_box_revdate) 1
          set logcfg(show_box_revtime) 1
          DrawTree
        }]
      $logcanvas.menubar.view.rev add command -label "Turn all options off" \
        -command [namespace code {
          set logcfg(show_tags) 0
          set logcfg(show_branches) 0
          set logcfg(show_box_rev) 0
          set logcfg(show_box_revwho) 0
          set logcfg(show_box_revdate) 0
          set logcfg(show_box_revtime) 0
          DrawTree
        }]
      $logcanvas.menubar.view.rev add separator
      $logcanvas.menubar.view.rev add checkbutton -label "Show revision" \
        -variable logcfg(show_box_rev) \
        -onvalue 1 -offvalue 0 \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.rev add checkbutton -label "Show author" \
        -variable logcfg(show_box_revwho) \
        -onvalue 1 -offvalue 0 \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.rev add checkbutton -label "Show date" \
        -variable logcfg(show_box_revdate) \
        -onvalue 1 -offvalue 0 \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view.rev add checkbutton -label "Show time" \
        -variable logcfg(show_box_revtime) \
        -onvalue 1 -offvalue 0 \
        -command [namespace code { DrawTree }]
      $logcanvas.menubar.view add separator
      $logcanvas.menubar.view add cascade -label "Size" \
        -menu $logcanvas.menubar.view.size
      menu $logcanvas.menubar.view.size
      foreach {label factor} $logcfg(scaling_options) {
        $logcanvas.menubar.view.size add radiobutton -label $label \
          -variable logcfg(scale) -value $factor \
          -command [namespace code { DrawTree }]
      }
      $logcanvas.menubar.view add separator
      $logcanvas.menubar.view add command -label "Save options" \
        -command [namespace code {
          SaveOptions
        }]

      if {$ingit} {
        # The git options menu
        git_branch_menu $logcanvas $filename
      }

      if {$tcl_platform(platform) != "windows"} {
        wm iconbitmap $logcanvas @$cvscfg(bitmapdir)/branch.xbm
        wm iconphoto $logcanvas -default Tclfish64
      }
      wm protocol $logcanvas WM_DELETE_WINDOW \
        [namespace code {$logcanvas.close invoke}]
      frame $logcanvas.up -relief groove -border 2
      set textfont $cvscfg(listboxfont)
      set disbg [lindex [$logcanvas.up configure -background] 4]
      label $logcanvas.up.lfname -width 12 -anchor w
      entry $logcanvas.up.rfname -font $textfont -relief groove \
        -bd 1 -relief sunk -state readonly

      button $logcanvas.up.bmodbrowse -image Modules \
        -command modbrowse_run
      button $logcanvas.up.bworkdir -image Workdir \
        -command { workdir_setup }
      pack $logcanvas.up -side top -fill x
      foreach fm {A B} {
        label $logcanvas.up.rev${fm}_lvers -text "Revision $fm"
        entry $logcanvas.up.rev${fm}_rvers -text {} \
        -width 8 -bd 1 -relief sunk -state readonly

        label $logcanvas.up.rev${fm}_ldate -text "Committed"
        label $logcanvas.up.rev${fm}_rdate -text {} \
           -anchor w -font $textfont
        label $logcanvas.up.rev${fm}_lwho -text " by "
        label $logcanvas.up.rev${fm}_rwho -text {} \
           -anchor w -font $textfont
        label $logcanvas.up.log${fm}_lcomment -text "Log $fm"

        frame $logcanvas.up.log${fm}_rlogfm -bd 3 -bg $cvscfg(colour$fm)
        text  $logcanvas.up.log${fm}_rlogfm.rcomment -height 5 \
           -fg $cvsglb(textfg) -bg $cvsglb(textbg) -state disabled \
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
      grid $logcanvas.up.bmodbrowse -column 7 -row 0 -rowspan 2 -sticky e\
        -padx 2 -pady 1
      grid $logcanvas.up.revA_lvers -column 0 -row 1 -sticky w
      grid $logcanvas.up.revA_rvers -column 1 -row 1 -sticky w
      grid $logcanvas.up.revA_ldate -column 2 -row 1 -sticky w
      grid $logcanvas.up.revA_rdate -column 3 -row 1 -sticky w
      grid $logcanvas.up.revA_lwho -column 4 -row 1 -sticky w
      grid $logcanvas.up.revA_rwho -column 5 -row 1 -sticky ew
      grid $logcanvas.up.logA_lcomment -column 0 -row 2 -sticky nw
      grid $logcanvas.up.logA_rlogfm -column 1 -row 2 -columnspan 7 -sticky ew
      pack $logcanvas.up.logA_rlogfm.yscroll -side right -fill y
      pack $logcanvas.up.logA_rlogfm.rcomment -side left -fill x -expand y
      grid $logcanvas.up.revB_lvers -column 0 -row 3 -sticky w
      grid $logcanvas.up.revB_rvers -column 1 -row 3 -sticky w
      grid $logcanvas.up.revB_ldate -column 2 -row 3 -sticky w
      grid $logcanvas.up.revB_rdate -column 3 -row 3 -sticky w
      grid $logcanvas.up.revB_lwho -column 4 -row 3 -sticky w
      grid $logcanvas.up.revB_rwho -column 5 -row 3 -sticky ew
      grid $logcanvas.up.logB_lcomment -column 0 -row 4 -sticky nw
      grid $logcanvas.up.logB_rlogfm -column 1 -row 4 -columnspan 7 -sticky ew
      pack $logcanvas.up.logB_rlogfm.yscroll -side right -fill y
      pack $logcanvas.up.logB_rlogfm.rcomment -side left -fill x -expand y
      # Pack the bottom before the middle so it doesnt disappear if
      # the window is resized smaller
      frame $logcanvas.down -relief groove -border 2
      pack $logcanvas.down -side bottom -fill x

      frame $logcanvas.down.search -relief sunk -bd 2
      button $logcanvas.down.search.b -text "Search" -command [namespace code {Search}]
      entry $logcanvas.down.search.e
      bind $logcanvas.down.search.e <Return> [namespace code {Search}]
      label $logcanvas.down.search.l -anchor e -width 10 -text ""
      checkbutton $logcanvas.down.search.c -anchor e -text "Ignore case" \
        -variable [namespace current]::search_nocase
      pack $logcanvas.down.search -side top -fill x
      pack $logcanvas.down.search.b -side left
      pack $logcanvas.down.search.e -side left
      pack $logcanvas.down.search.c -side left
      pack $logcanvas.down.search.l -side left

      # The canvas for the big picture
      canvas $logcanvas.canvas -relief sunken -border 2 \
        -height 300 -bg $cvsglb(canvbg) \
        -yscrollcommand [namespace code "$logcanvas.yscroll set"] \
        -xscrollcommand [namespace code "$logcanvas.xscroll set"]
      scrollbar $logcanvas.xscroll -relief sunken -orient horizontal \
        -command [namespace code "$logcanvas.canvas xview"]
      scrollbar $logcanvas.yscroll -relief sunken \
        -command [namespace code "$logcanvas.canvas yview"]
      #
      # Create buttons
      #
      frame $logcanvas.down.btnfm
      frame $logcanvas.down.closefm
      button $logcanvas.refresh -image Refresh \
        -command [namespace code {
                 $scope\::reloadLog
               }]
      button $logcanvas.view -image Fileview
      button $logcanvas.log -image Log
      button $logcanvas.annotate -image Annotate
      button $logcanvas.diff -image Diff \
        -command [namespace code {
          comparediff_r [$logcanvas.up.revA_rvers get] \
          [$logcanvas.up.revB_rvers get] $logcanvas $filename
        }]
      button $logcanvas.delta -image Mergediff
      button $logcanvas.viewtags -image Tags \
        -command [namespace code {
                   variable revtags
                   variable revbtags
                   set taglist {}
                   foreach r [lsort -command sortrevs \
                       [concat [array names revtags] \
                               [array names revbtags]]] {
                     if [info exists revtags($r)] {
                       append taglist "$r: $revtags($r)\n"
                     } elseif [info exists revbtags($r)] {
                       append taglist "$r: $revbtags($r)\n"
                     }
                   }
                   view_output::new Tags $taglist
                 }]
      button $logcanvas.close -text "Close" \
        -command [namespace code {
                 global cvscfg
                 variable logcanvas
                 variable my_idx
                 set cvscfg(loggeom) [wm geometry $logcanvas]
                 destroy $logcanvas
                 catch {namespace delete ::cvs_branchlog::$my_idx}
                 catch {namespace delete ::svn_branchlog::$my_idx}
                 namespace delete [namespace current]
                 exit_cleanup 0
               }]
      button $logcanvas.stop -text "Stop" -bg red4 -fg white \
        -activebackground red4 -activeforeground white \
        -state [expr {$cvscfg(allow_abort) ? {normal} : {disabled}}] \
        -command "$scope\::abortLog"

      pack $logcanvas.refresh \
        -in $logcanvas.down -side left \
        -ipadx 4 -ipady 4
      pack $logcanvas.down.btnfm -side left -fill y -expand 1
      pack $logcanvas.view \
           $logcanvas.log \
           $logcanvas.annotate \
           $logcanvas.diff \
           $logcanvas.delta \
           $logcanvas.viewtags \
        -in $logcanvas.down.btnfm -side left \
        -ipadx 4 -ipady 4
      pack $logcanvas.down.closefm -side right -expand yes -fill x
      pack $logcanvas.close \
        -in $logcanvas.down.closefm -side right -padx 15

      set_tooltips $logcanvas.refresh \
        {"Re-read the log information"}
      set_tooltips $logcanvas.up.bworkdir \
        {"Open the Working Directory Browser"}
      set_tooltips $logcanvas.up.bmodbrowse \
        {"Open the Repository Browser"}
      set_tooltips $logcanvas.view \
        {"View a version of the file"}
      set_tooltips $logcanvas.log \
        {"Revision Log of the file"}
      set_tooltips $logcanvas.annotate \
        {"View revision where each line was modified"}
      set_tooltips $logcanvas.diff \
        {"Compare two versions of the file"}
      set_tooltips $logcanvas.delta \
        {"Merge to current"}
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
        wm geometry $logcanvas $cvscfg(loggeom)
      }

      $logcanvas.canvas bind active <Enter> \
        "$logcanvas.canvas config -cursor hand2"
      $logcanvas.canvas bind active <Leave> \
        "$logcanvas.canvas config -cursor {}"

      $logcanvas.canvas bind tag <Button-1> \
        [namespace code "PopupTags %x %y"]

      $logcanvas.canvas bind selectable <ButtonPress-1> \
        [namespace code "RevSelect A"]
      # Tcl/TK for Windows doesn't do Button 3, so we duplicate it on Button 2
      $logcanvas.canvas bind selectable <ButtonPress-2> \
        [namespace code "RevSelect B"]
      $logcanvas.canvas bind selectable <ButtonPress-3> \
        [namespace code "RevSelect B"]

      # Clicking in a blank part of the canvas unselects boxes
      bind $logcanvas.canvas <ButtonPress-1> \
        [namespace code "Unselect A"]
      bind $logcanvas.canvas <ButtonPress-2> \
        [namespace code "Unselect B"]
      bind $logcanvas.canvas <ButtonPress-3> \
        [namespace code "Unselect B"]

      focus $logcanvas.canvas
      # FIXME: Why isn't there a bbox when we get here?
      # Then the yview moveto doesn't work, although it does in tkinter
      $logcanvas.canvas xview moveto 0
      $logcanvas.canvas yview moveto 0

      return [list [namespace current] $logcanvas]
    }
  }
}

