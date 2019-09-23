namespace eval ::annotate {
  variable instance 0

  proc new {revision file type {L1 {}} {L2 {}}} {
    #
    # show information on the last modification for each line of a file.
    #
    variable instance
    set my_idx $instance
    incr instance

    gen_log:log T "ENTER ($revision $file $type $L1 $L2)"
    namespace eval $my_idx {
      set my_idx [uplevel {concat $my_idx}]
      variable revision [uplevel {concat $revision}]
      variable file [uplevel {concat $file}]
      variable type [uplevel {concat $type}]
      variable L1 [uplevel {concat $L1}]
      variable L2 [uplevel {concat $L2}]
      variable blamewin .annotate$my_idx
      variable ll

      global cvs
      global tcl_platform
      global incvs insvn inrcs ingit

      proc redo {w} {
        variable log_lines
        variable revcolors
        variable blameproc
        variable lc

        gen_log:log T "ENTER ($blamewin)"

        catch {unset revcolors}
        $blamewin.text configure -state normal
        $blamewin.text delete 1.0 end
        busy_start $blamewin
        set lc 0
        foreach logline [lrange $log_lines 0 end-1] {
          incr lc
          $blameproc $blamewin.text $logline $lc
        }
        $blamewin.text configure -state disabled
        # Focus in the text widget to activate the text bindings
        focus $blamewin.text
        busy_done $blamewin
        update idletasks
        gen_log:log T "LEAVE"
      }

      # Get the line the mouse was clicked on
      proc get_blamerev {win x y} {
        global cvscfg
        
        set parent [winfo parent $win]
        set lineloc [$win index @$x,$y]
        set linenum [lindex [split $lineloc "."] 0]
        set linetext [$win get $linenum.0 $linenum.end]
        set f1 ""
        set f2 ""
        regexp {^\s*(\S+)\s+(\S+)} $linetext all f1 f2 orig_line 
        $parent.top.reventry delete 0 end
        if $cvscfg(blame_linenums) {
          $parent.top.reventry insert end $f2
        } else {
          $parent.top.reventry insert end $f1
        }
      }

      proc cvs_annotate_color {w logline ln} {
        global cvscfg
        global cvsglb
        global tk_version
        variable revcolors
        variable agecolors
        variable revlist
        variable nrevs
        variable revspercolor
        variable maxrevlen
        variable ll

        # Separate the line into annotations and content
        regexp {(^.*): (.*$)} $logline all annotations orig_line
        regexp {(^[\d\.]*)\s+(.*$)} $annotations all revnum who_when
        set line "$who_when: $orig_line"

        # Beginning of a revision
        if {! [info exists revcolors($revnum)]} {
          # determine the number of revisions then set color accordingly
          set revticks [lsearch -exact $revlist $revnum]
          set revticks [expr {$nrevs - $revticks}]
          set revindex [expr {$revticks / $revspercolor}]
          set ncolors [expr {[array size agecolors] - 1}]
          if {$revindex > $ncolors} {set revindex $ncolors}
          if {$revindex < 0} {set revindex 0}

          set revcolors($revnum) $agecolors($revindex)

          $w tag configure $revnum -background $revcolors($revnum) -foreground black
          if {$tk_version >= 8.6} {
            $w tag configure $revnum -selectbackground $cvsglb(hlbg)
          }
        }

        if {$cvscfg(blame_linenums)} {
          $w insert end [format "%${ll}d  " $ln]
        }
        $w insert end [format "%-${maxrevlen}s  " $revnum] $revnum
        $w insert end "$line\n" $revnum
      }

      proc git_annotate_color {w logline ln} {
        global cvscfg
        global cvsglb
        global tk_version
        variable revcolors
        variable agecolors
        variable revlist
        variable nrevs
        variable revspercolor
        variable maxrevlen
        variable ll

        # Separate the line into annotations and content
        regexp {(^\S+)\s+\((.*?)\)(.*$)} $logline all revnum annot orig_line
        set annot [string trim $annot]
        regsub -all {\s+} $annot { } annot
        set linenum [lindex $annot end]
        set when [lindex $annot end-3]
        # Is the name ever in two parts? (Yes. Or three.)
        set who [lrange $annot 0 end-4]
        set line "($who $when): $orig_line"

        # Beginning of a revision
        if {! [info exists revcolors($revnum)]} {
          # determine the number of revisions then set color accordingly
          set revticks [lsearch -exact $revlist $revnum]
          set revticks [expr {$nrevs - $revticks}]
          set revindex [expr {$revticks / $revspercolor}]
          set ncolors [expr {[array size agecolors] - 1}]
          if {$revindex > $ncolors} {set revindex $ncolors}
          if {$revindex < 0} {set revindex 0}

          set revcolors($revnum) $agecolors($revindex)

          $w tag configure $revnum -background $revcolors($revnum) -foreground black
          if {$tk_version >= 8.6} {
            $w tag configure $revnum -selectbackground $cvsglb(hlbg)
          }
        }

        if {$cvscfg(blame_linenums)} {
          $w insert end [format "%${ll}d  " $linenum]
        }
        $w insert end [format "%-${maxrevlen}s  " $revnum] $revnum
        $w insert end "$line\n" $revnum
      }

      proc svn_annotate_color {w logline ln} {
        global cvscfg
        global cvsglb
        global tk_version
        variable revcolors
        variable agecolors
        variable revlist
        variable nrevs
        variable revspercolor
        variable maxrevlen
        variable ll

        # Separate the line into annotations and content
        regexp {^\s*(\d+)\s+(.*?\) )(.*$)} $logline all revnum annotations orig_line
        regexp {(\S+).*\((.*?)\)} $annotations all who when
        if {$revnum == "Skipping"} {
          cvsfail "Skipping binary file" $w
          return
        }
        set line "($who $when): $orig_line"

        # Beginning of a revision
        if {! [info exists revcolors($revnum)]} {
          # determine the number of revisions then set color accordingly
          set revticks [lsearch -exact $revlist $revnum]
          set revticks [expr {$nrevs - $revticks}]
          set revindex [expr {$revticks / $revspercolor}]
          set ncolors [expr {[array size agecolors] - 1}]
          if {$revindex > $ncolors} {set revindex $ncolors}
          if {$revindex < 0} {set revindex 0}

          set revcolors($revnum) $agecolors($revindex)

          $w tag configure $revnum -background $revcolors($revnum) -foreground black
          if {$tk_version >= 8.6} {
            $w tag configure $revnum -selectbackground $cvsglb(hlbg)
          }
        }

        if {$cvscfg(blame_linenums)} {
          $w insert end [format "%${ll}d  " $ln]
        }
        # we're sticking an "r" on - one more character
        set lr [expr {$maxrevlen+1}]
        $w insert end [format "r%-${lr}s  " $revnum] $revnum
        $w insert end "$line\n" $revnum
      }

      regsub -all {\$} $file {\$} file
      switch $type {
       "svn" -
       "svn_r" {
         set blameproc svn_annotate_color
         set commandline "svn blame -v $revision \"$file\""
       }
       "cvs" {
         set blameproc cvs_annotate_color
         set commandline "$cvs annotate $revision \"$file\""
       }
       "cvs_r" {
         # First see if we can do this
         # rannotate appeared in 1.11.1
         set versionsplit [split $cvsglb(cvs_version) {.}]
         set major [lindex $versionsplit 1]
         set minor [lindex $versionsplit 2]
         set too_old 0
         if {$major < 11} {
           set too_old 1
         } elseif {($major == 11) && ($minor < 1)} {
           set too_old 1
         }
         if {$too_old} {
           cvsfail "You need CVS >= 1.11.1 to do this" $w
           namespace delete [namespace current]
           return
         }
         set blameproc cvs_annotate_color
         set commandline "$cvs -d $cvscfg(cvsroot) rannotate $revision \"$file\""
       }
       "git" -
       "git_r" {
         if {$cvscfg(gitblame_since) != ""} {
           set sinceflag "--since=\"$cvscfg(gitblame_since)\""
           regsub  -all {\s+} $sinceflag {\\ } sinceflag
         } else {
           set sinceflag ""
         }
         set blameproc git_annotate_color
         set commandline "git annotate --abbrev-commit $sinceflag $revision $file"
       }
       "git_range" {
         if {$cvscfg(gitblame_since) != ""} {
           set sinceflag "--since=\"$cvscfg(gitblame_since)\""
           regsub  -all {\s+} $sinceflag {\\ } sinceflag
         } else {
           set sinceflag ""
         }
         set blameproc git_annotate_color
         set commandline "git annotate --abbrev-commit $sinceflag -L$L1,$L2 $revision $file"
       }
       default {
         cvsfail "I don't understand flag \"$type\""
         return
       }
      }

      # Initialize searching
      search_textwidget_init

      # Make the window
      toplevel $blamewin
      text $blamewin.text -setgrid yes -exportselection 1 \
        -relief sunken -border 2 -height 40 -width 122 \
        -yscroll "$blamewin.scroll set"
      scrollbar $blamewin.scroll -relief sunken -command "$blamewin.text yview"

      frame $blamewin.top -relief groove -border 2
      entry $blamewin.top.reventry
      button $blamewin.top.viewfile -image Fileview
      button $blamewin.top.log -image Log
      button $blamewin.top.ddiff -image Difflines
      button $blamewin.top.rdiff -image Patches
      button $blamewin.top.diff -image Diff
      button $blamewin.top.workdir -image Workdir -command {workdir_setup}

      frame $blamewin.bottom
      button $blamewin.bottom.close -text "Close" \
        -command [namespace code {
                 global cvscfg
                 variable w
                 variable my_idx
                 set cvscfg(blamegeom) [wm geometry $blamewin]
                 destroy $blamewin
                 namespace delete [namespace current]
                 exit_cleanup 0
               }]
      label $blamewin.bottom.days -text "Revs per Color" -width 20 -anchor e
      checkbutton $blamewin.bottom.linum -text "Show Line Numbers" \
        -variable cvscfg(blame_linenums) \
        -onvalue 1 -offvalue 0
      entry $blamewin.bottom.dayentry -width 3 \
        -textvariable [namespace current]::revspercolor
      button $blamewin.bottom.redo -text "Redo Colors" 

      button $blamewin.bottom.srchbtn -text Search \
        -command "search_textwidget $blamewin.text"
      entry $blamewin.bottom.entry -width 20 -textvariable cvsglb(searchstr)
      bind $blamewin.bottom.entry <Return> "search_textwidget $blamewin.text"

      pack $blamewin.bottom -side bottom -fill x
      pack $blamewin.bottom.srchbtn -side left
      pack $blamewin.bottom.entry -side left
      pack $blamewin.bottom.linum -side left -ipadx 15
      pack $blamewin.bottom.days -side left
      pack $blamewin.bottom.dayentry -side left
      pack $blamewin.bottom.redo -side left
      pack $blamewin.bottom.close -side right -ipadx 15

      pack $blamewin.top -side top -fill x
      pack $blamewin.top.reventry -side left
      pack $blamewin.top.viewfile \
           $blamewin.top.log \
        -in $blamewin.top -side left -ipadx 4 -ipady 4
      if {$ingit} {
        pack $blamewin.top.diff \
             $blamewin.top.ddiff \
             $blamewin.top.rdiff \
          -in $blamewin.top -side left -ipadx 4 -ipady 4
      }
      
      pack $blamewin.top.workdir -side right

      pack $blamewin.scroll -side right -fill y
      pack $blamewin.text -fill both -expand 1

      wm title $blamewin "$commandline"
      if {$tcl_platform(platform) != "windows"} {
        wm iconbitmap $blamewin @$cvscfg(bitmapdir)/annotate.xbm
      }
      wm minsize $blamewin 1 1
      if {[info exists cvscfg(blamegeom)]} {
        wm geometry $blamewin $cvscfg(blamegeom)
      }

      switch -- $type {
        {cvs} {
          $blamewin.top.viewfile configure -state normal \
           -command [namespace code {
              set rev [$blamewin.top.reventry get]
              if {$rev ne ""} { cvs_fileview_update $rev $file }
           }]
          $blamewin.top.log configure -state normal \
           -command [namespace code {
              set rev [$blamewin.top.reventry get]
              if {$rev ne ""} { cvs_log_rev $rev $file }
           }]
          $blamewin.top.ddiff configure -state disabled
          $blamewin.top.rdiff configure -state disabled
        }
        {svn} {
          $blamewin.top.viewfile configure -state normal \
           -command [namespace code {
              set rev [$blamewin.top.reventry get]
              if {$rev ne ""} { svn_fileview $rev $file file}
           }]
          $blamewin.top.log configure -state normal \
           -command [namespace code {
              set rev [$blamewin.top.reventry get]
              if {$rev ne ""} { svn_log_rev $rev $file}
           }]
          $blamewin.top.ddiff configure -state disabled
          $blamewin.top.rdiff configure -state disabled
        }
        {git} {
          $blamewin.top.viewfile configure -state normal \
           -command [namespace code {
              set rev [$blamewin.top.reventry get]
              if {$rev ne ""} { git_fileview $rev "." $file}
           }]
          $blamewin.top.log configure -state normal \
           -command [namespace code {
              set rev [$blamewin.top.reventry get]
              if {$rev ne ""} { git_log_rev $rev $file}
           }]
          $blamewin.top.diff configure -state normal \
           -command [namespace code {
              set rev [$blamewin.top.reventry get]
              if {$rev ne ""} {
                comparediff_r $rev^ $rev $blamewin $file
              }
           }]
          $blamewin.top.ddiff configure -state normal \
           -command [namespace code {
              set rev [$blamewin.top.reventry get]
              if {$rev ne ""} { git_show $rev }
           }]
          $blamewin.top.rdiff configure -state normal \
           -command [namespace code {
              set rev [$blamewin.top.reventry get]
              if {$rev ne ""} { git_patch $file $rev }
           }]
         }
      }

      set_tooltips $blamewin.top.workdir \
        {"Open the Working Directory Browser"}
      set_tooltips $blamewin.top.viewfile \
        {"View a version of the file"}
      set_tooltips $blamewin.top.log \
        {"Revision Log of the file"}
      set_tooltips $blamewin.top.diff \
        {"Compare version with its predecessor"}
      set_tooltips $blamewin.top.ddiff \
        {"List changed files in a commit"}
      set_tooltips $blamewin.top.rdiff \
        {"Show file changes in a commit"}


      # Define the colors
      array set agecolors {
        0 #FFFF4B4B4B4B
        1 #FFFF6C6C4B4B
        2 #FFFF82824B4B
        3 #FFFF97974B4B
        4 #FFFFA8A84B4B
        5 #FFFFB4B44B4B
        6 #FFFFC5C54B4B
        7 #FFFFDBDB4B4B
        8 #FFFFFCFC4B4B
        9 #DBDBFFFF4B4B
        10 #ACACFFFF4B4B
        11 #7575FFFF4B4B
        12 #4F4FFFFF4B4B
        13 #4B4BFFFFB4B4
        14 #4B4BFFFFDFDF
        15 #4B4BF4F4FFFF
        16 #4B4BDFDFFFFF
        17 #4B4BD2D2FFFF
        18 #4B4BB0B0FFFF
        19 #4B4B8686FFFF
        20 #4B4B7979FFFF
        21 #4B4B6464FFFF
        22 #4B4B5757FFFF
        23 #4B4B4B4BFFFF
      }

      gen_log:log C "$commandline"
      busy_start $blamewin
      set exec_cmd [exec::new "$commandline"]
      set log [$exec_cmd\::output]

      # Read the log lines.  Assign a color to each unique revision.
      catch {unset revcolors}
      set log_lines [split [set log] "\n"]

      # We have 24 colors.  How many revs do we have?
      set revlist {}
      set maxrevlen 0
      switch -glob -- $type {
       {cvs*} -
       {svn*} {
         # Sort the revisions
         foreach logline $log_lines {
           set line [split [string trimleft $logline]]
           set revnum [lindex $line 0]
           if {$revnum == ""} {continue}
           if {$revnum ni $revlist} {
             lappend revlist $revnum
             set l [string length $revnum]
             if {$l > $maxrevlen} {
               set maxrevlen $l
             }
           }
         }
         set revlist [lsort -command sortrevs $revlist]
       }
       {git*} {
         # The abbrev-commit length of blame may not be the same as for rev-list
         set line [split [string trimleft [lindex $log_lines 0]]]
         set revlen [string length [lindex $line 0]]
         # All the commit hashes are the same length, and we only need to know for rev-list
         set blameproc git_annotate_color
         set rl_cmd "git rev-list $sinceflag --abbrev-commit --abbrev=$revlen --reverse $revision $file"
         set cmd_revlist [exec::new $rl_cmd {} 0 {} 1]
         set revlist_output [$cmd_revlist\::output]
         $cmd_revlist\::destroy
         set revlist_lines [split $revlist_output "\n"]
         set revlist {}
         foreach revnum $revlist_lines {
           if {$revnum == ""} {continue}
           if {$revnum ni $revlist} {
             lappend revlist $revnum
           }
         }
       }
      }

      set nrevs [llength $revlist]
      if {$nrevs == 0} {
        set msg "No output for $commandline"
        cvsfail $msg $blamewin
        return;
      }
      gen_log:log D "$revlist"
      set ncolors [expr {[array size agecolors] - 1}]
      if {$nrevs < $ncolors} {
        set revspercolor 1
      } else {
        set rpc [expr {1 + ($nrevs / $ncolors)}]
        set revspercolor $rpc
      }
      gen_log:log D "nrevs $nrevs"
      gen_log:log D "revs per color $revspercolor"
      # Since there's an entry for changing revspercolor, make sure it's
      # something you can divide by or it will produce an error.
      if {[string length $revspercolor] == 0 || $revspercolor == 0} {
        gen_log:log D "revspercolor was \"$revspercolor\": setting to 1"
        set revspercolor 1
      }

      # linecount
      set lc 0
      set ll [string length [llength $log_lines]]
      foreach logline [lrange $log_lines 0 end-1] {
        incr lc
        $blameproc $blamewin.text $logline $lc
      }

      $blamewin.text yview moveto 0
      update idletasks
      $blamewin.text configure -state disabled
      bind $blamewin.bottom.dayentry <Return> [namespace code {redo $blamewin}]
      $blamewin.bottom.redo configure -command [namespace code {redo $blamewin}]
      $blamewin.bottom.redo configure -command [namespace code {redo $blamewin}]
      $blamewin.bottom.linum configure -command [namespace code {redo $blamewin}]

      # Disable key presses and make a popup for mouse Copy
      ro_textbindings $blamewin.text
      bind $blamewin.text <ButtonPress-1> [namespace code {get_blamerev %W %x %y}]

      # Focus in the text widget to activate the text bindings
      focus $blamewin.text
      busy_done $blamewin
      return [namespace current]
    }
  }
}

