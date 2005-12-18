namespace eval ::annotate {
  variable instance 0

  proc new {revision file local} {
    #
    # show information on the last modification for each line of a file.
    #
    variable instance
    set my_idx $instance
    incr instance

    gen_log:log T "ENTER ($revision $file local)"
    namespace eval $my_idx {
      set my_idx [uplevel {concat $my_idx}]
      variable revision [uplevel {concat $revision}]
      variable file [uplevel {concat $file}]
      variable local [uplevel {concat $local}]
      variable w .annotate$my_idx

      global cvs
      global tcl_platform

      proc redo {w} {
        global cvscfg
        variable log_lines
        variable revcolors
        variable blameproc
        variable now
        variable nrevs
        variable revlist

        gen_log:log T "ENTER ($w)"

        catch {unset revcolors}
        $w.text delete 1.0 end
        busy_start $w
        foreach logline $log_lines {
          $blameproc $w.text $now $logline
        }
        $w.text configure -state disabled
        # Focus in the text widget to activate the text bindings
        focus $w.text
        #bind_show $w.text -verbose
        busy_done $w
        gen_log:log T "LEAVE"
      }

      proc cvs_annotate_color {w now logline} {
        global cvscfg
        global cvsglb
        variable revcolors
        variable agecolors
        variable revlist
        variable nrevs
        variable revspercolor
        variable log_lines

        set line [split $logline]
        #gen_log:log D "$line"
        set revnum [lindex $line 0]

        # Beginning of a revision
        if {! [info exists revcolors($revnum)]} {
          #gen_log:log D "revision $revnum needs new color"
          # determine the number of revisions
          # between this commit and the now, then set color accordingly
          set revticks [lsearch -exact $revlist $revnum]
          set revticks [expr {$nrevs - $revticks}]
          set revindex [expr {$revticks / $revspercolor}]
          set ncolors [expr {[array size agecolors] - 1}]
          if {$revindex > $ncolors} {set revindex $ncolors}
          if {$revindex < 0} {set revindex 0}

          set revcolors($revnum) $agecolors($revindex)

          #gen_log:log D "revindex $revindex revcolors($revnum)\
            $revcolors($revnum)"
          $w tag configure $revnum \
            -background $revcolors($revnum) -foreground black
          #gen_log:log D "$w tag configure $revnum $revcolors($revnum)"
          #$w tag lower $revnum 
        }

        $w insert end "$logline\n" $revnum
      }

      proc svn_annotate_color {w now logline} {
        global cvscfg
        global cvsglb
        variable revcolors
        variable agecolors
        variable revspercolor
        variable log_lines

        set trimline [string trimleft $logline]
        set line [split $trimline]
        #gen_log:log D "$line"
        set revnum [lindex $line 0]
        #gen_log:log D "\"$revnum\""
        if {$revnum == ""} return
        if {$revnum == "Skipping"} {
          cvsfail "Skipping binary file" $w
          return
        }

        # Beginning of a revision
        if {! [info exists revcolors($revnum)]} {
          #gen_log:log D "revision $revnum needs new color"
          set revticks [expr {$now - $revnum}]
          set revindex [expr {$revticks / $revspercolor}]
          set ncolors [expr {[array size agecolors] - 1}]
          if {$revindex > $ncolors} {set revindex $ncolors}
          if {$revindex < 0} {set revindex 0}

          set revcolors($revnum) $agecolors($revindex)

          #gen_log:log D "revindex $revindex revcolors($revnum)\
            $revcolors($revnum)"
          $w tag configure $revnum \
            -background $revcolors($revnum) -foreground black
          #gen_log:log D "$w tag configure $revnum $revcolors($revnum)"
          #$w tag lower $revnum 
        }
        $w insert end "$logline\n" $revnum
      }

      regsub {^-} $revision {} revlabel
      regsub -all {\$} $file {\$} file

      if {$local == "svn"} {
        set info_cmd [exec::new "svn info \"$file\""]
        set info_lines [split [$info_cmd\::output] "\n"]
        foreach infoline $info_lines {
          if {[string match "Revision:*" $infoline]} {
            gen_log:log D "$infoline"
            set now [lrange $infoline 1 end]
          }
        }
        set blameproc svn_annotate_color
        set commandline "svn blame $revision \"$file\""
      } elseif {$local == "cvs"} {
        set info_cmd [exec::new "cvs status \"$file\""]
        set info_lines [split [$info_cmd\::output] "\n"]
        foreach infoline $info_lines {
          if {[string match "*Working revision:*" $infoline]} {
            gen_log:log D "$infoline"
            set now [lindex $infoline 2]
          }
        }
        set blameproc cvs_annotate_color
        set commandline "$cvs annotate $revision \"$file\""
      } elseif {$local == "cvs_r"} {
        # First see if we can do this
        # rannotate appeared in 1.11.1
        set cvsglb(cvs_version) [cvs_version_number]
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
        set now $revlabel
      } else {
        cvsfail "I don't understand flag \"$local\""
        return
      }

      # Initialize searching
      search_textwidget_init

      # Make the window 
      toplevel $w
      text $w.text -setgrid yes -relief sunken -border 2 \
        -height 40 -width 122 -yscroll "$w.scroll set"
      scrollbar $w.scroll -relief sunken -command "$w.text yview"


      frame $w.bottom
      button $w.bottom.close -text "Close" -command "destroy $w; exit_cleanup 0"
      if {$local == "svn"} {
        label $w.bottom.days -text "Revs per Color" -width 20 -anchor e
      } else {
        label $w.bottom.days -text "Days per Color" -width 20 -anchor e
      }
      entry $w.bottom.dayentry -width 3 -textvariable [namespace current]::revspercolor
      button $w.bottom.redo -text "Redo Colors"

      button $w.bottom.srchbtn -text Search -command "search_textwidget $w.text"
      entry $w.bottom.entry -width 20 -textvariable cvsglb(searchstr)
      bind $w.bottom.entry <Return> "search_textwidget $w.text"

      pack $w.bottom -side bottom -fill x
      pack $w.bottom.srchbtn -side left
      pack $w.bottom.entry -side left
      pack $w.bottom.days -side left
      pack $w.bottom.dayentry -side left
      pack $w.bottom.redo -side left
      pack $w.bottom.close -side right -ipadx 15

      pack $w.scroll -side right -fill y
      pack $w.text -fill both -expand 1

      wm title $w "$file"
      if {$revision != ""} {
        wm title $w "$file Revision $revlabel"
      }
      if {$tcl_platform(platform) != "windows"} {
        wm iconbitmap $w @$cvscfg(bitmapdir)/annotate.xbm
      }

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

      #gen_log:log C "$commandline"
      set exec_cmd [exec::new "$commandline"]
      set log [$exec_cmd\::output]


      # Read the log lines.  Assign a color to each unique revision.
      catch {unset revcolors}
      set log_lines [split [set log] "\n"]
      busy_start $w

      # We have 24 colors.  How many revs do we have?
      set revlist {}
      foreach logline $log_lines {
        set line [split [string trimleft $logline]]
        set revnum [lindex $line 0]
        if {$revnum == ""} {continue}
        if {[lsearch -exact $revlist $revnum] == -1} {
          lappend revlist $revnum
        }
      }
      set revlist [lsort -command sortrevs $revlist]
      set nrevs [llength $revlist]
      gen_log:log D "$revlist"
      set ncolors [expr {[array size agecolors] - 1}]
      if {$nrevs < $ncolors} {
        set revspercolor 1
      } else {
        set rpc [expr {1 + ($nrevs / $ncolors)}]
        set revspercolor $rpc
      }
      gen_log:log D "nrevs $nrevs"
      gen_log:log D "revs/days per color $revspercolor"
      # Since there's an entry for changing revspercolor, make sure it's
      # something you can divide by or it will produce an error.
      if {[string length $revspercolor] == 0 || $revspercolor == 0} {
        gen_log:log D "revspercolor was \"$revspercolor\": setting to 1"
        set revspercolor 1
      }

      foreach logline $log_lines {
        $blameproc $w.text $now $logline
      }

      $w.text yview moveto 0
      update
      $w.text configure -state disabled
      bind $w.bottom.dayentry <Return> [namespace code {redo $w}]
      $w.bottom.redo configure -command [namespace code {redo $w}]
      # Focus in the text widget to activate the text bindings
      focus $w.text
      #bind_show $w.text -verbose
      busy_done $w
      return [namespace current]
    }
  }
}

