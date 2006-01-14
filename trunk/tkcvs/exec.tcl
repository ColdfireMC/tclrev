proc cvs_usercmd {args} {
  #
  # Run a cvs command from the user menu and view its output.
  # called for cvsmenu() entries.
  #
  global cvs

  gen_log:log T "ENTER ($args)"
  #gen_log:log C "$cvs $args"
  set my_viewer [viewer::new "CVS $args"]
  $my_viewer\::do "$cvs $args"
  gen_log:log T "LEAVE"
}

proc cvs_execcmd {args} {
  #
  # Run any command from the user menu without
  # a viewer to capture its output and without
  # the ability to abort it.
  # called for execmenu() entries.
  #
  gen_log:log T "ENTER ($args)"
  gen_log:log C "$args"
  eval "exec $args &"
  gen_log:log T "LEAVE"
}

proc cvs_catchcmd {args} {
  #
  # Run any command from the user menu and view its output.
  # You can abort it too.
  # called for usermenu() entries.
  #
  gen_log:log T "ENTER ($args)"
  #gen_log:log C "$args"
  set my_viewer [viewer::new "$args"]
  $my_viewer\::do "$args"
  gen_log:log T "LEAVE"
}

namespace eval ::exec {
  variable instance 0

  proc new {command {viewer {}} {show_stderr {1}} {filter {}}} {
    variable instance
    set my_idx $instance
    incr instance

    gen_log:log T "ENTER (\"$command\" \"$show_stderr\" \"$filter\")"

    namespace eval $my_idx {
      set my_idx [uplevel {concat $my_idx}]
      variable command [uplevel {concat $command}]
      variable viewer [uplevel {concat $viewer}]
      variable filter [uplevel {concat $filter}]
      variable show_stderr [uplevel {concat $show_stderr}]

      global cvscfg
      global errorCode

      variable data {}
      variable errmsg {}
      variable procout ""
      variable procerr ""
      variable errpos 0
      variable ExecDone 0
      variable v_w

      if {$viewer != ""} {
        set v_w [namespace inscope $viewer {set w}]
      }

      proc out_handler { {viewer {}} {filter {}} } {
        variable procout
        variable procerr
        variable ExecDone
        variable errmsg
        variable data
        variable v_w
        variable my_idx
        variable show_stderr
        global errorCode
      
        # Blocking read -- returns -1 on EOF.  Then you get the process return
        # from errorCode
        if {[gets $procout line] < 0} {
          # [close] blocks until child process completes
          if {[catch {close $procout} res]} {
            gen_log:log E "  Close Failed - errorCode $errorCode"
            set ExecDone [list 1 $res $errorCode]
            gen_log:log E "  ExecDone $ExecDone"
            if {$errmsg == ""} { set errmsg $res }

            [namespace current]::err_handler

            if {! [info exists command]} {set command ""}
            if {! [info exists status]} {set status ""}
            if {$errmsg == ""} {set errmsg "$command exited status $status"}
            if {[string length $errmsg] < 256} {
               cvsfail $errmsg .
            }
            # If we don't pop up an error dialog, let's at least try to show
            # what happened in the viewer window, if there is one
            if {$viewer != {}} {
              $v_w.text insert end "\n$res" stderr
              if {[tell $procerr]} {
                seek $procerr 0
                while {[gets $procerr erline] != -1} {
                  $v_w.text insert end "$erline\n" stderr
                }
              }
            }
            ::exec::$my_idx\::abort
          } else {
            gen_log:log D "  Close OK"
            # Many CVS commands write stderr without err exit
            if {[tell $procerr]} {
              seek $procerr 0
              while {[gets $procerr erline] != -1} {
                gen_log:log E "$erline"
                #if {$show_stderr && $viewer != {}} {
                  #$v_w.text insert end "$erline\n" stderr
                #}
              }
            }
            set ExecDone [list 0]
            gen_log:log D "  ExecDone $ExecDone"
            
          }
          catch {close $procerr}
          if {$viewer != {}} {
            pack forget $v_w.stop
            pack $v_w.close -in $v_w.bottom -side right -ipadx 15
            $v_w.close configure -state normal
          }
          return
        }

        if {$filter != ""} {
          set filtered_line [$filter [namespace current] $line]
          set texttag [lindex $filtered_line 0]
          set line [lindex $filtered_line 1]
        }
        append data "$line\n"
        if {$viewer != ""} {
          if {$filter != ""} {
            if {$texttag != "noshow"} {
              $v_w.text insert end "$line\n" $texttag
            }
          } else {
            $v_w.text insert end "$line\n"
          }
          $v_w.text yview end
        }
        gen_log:log D "STDOUT:  $line"
      }

      proc err_handler {} {
        variable errpos
        variable procerr
        variable errmsg
        variable viewer
        variable filter
        variable show_stderr
        variable v_w

        # When new stuff appears in the error output file, get it.  There may
        # be more than one line.
        set errmsg ""
        if {[tell $procerr] != $errpos} {
          seek $procerr $errpos start
          while {[gets $procerr erline] != -1} {
            append errmsg "\n$erline"
            set errpos [tell $procerr]
          }
          gen_log:log E "$errmsg"
          if {$viewer != "" && $show_stderr == 1} {
            $v_w.text insert end "\n$errmsg" stderr
          }
        }

      }

      proc abort {} {
        variable procout
        variable procerr
        variable procid
        variable viewer
        variable v_w
	global tcl_platform

        gen_log:log T "ENTER"
        # This does the trick but it wont work on windows
        if {![info exists procid]} {
          gen_log:log D "procid is not defined"
          return
        }
        catch "exec kill $procid" kres
        unset procid

        err_handler
        if {$viewer != {}} {
          pack forget $v_w.stop
          pack $v_w.close -in $v_w.bottom -side right -ipadx 15
          $v_w.close configure -state normal
        }

        catch {close $procout} cres
        catch {close $procerr} cres
        gen_log:log D "$kres"

        gen_log:log T "LEAVE"
      }

      proc wait {} {
        variable ExecDone
        gen_log:log T "ENTER"

        if {!$ExecDone} {
          vwait [namespace current]::ExecDone
        }
        gen_log:log T "LEAVE"
      }

      proc output {} {
        variable data
        variable ExecDone

        gen_log:log T "ENTER"
        if {!$ExecDone} {
          [namespace current]::wait
        }
        gen_log:log T "LEAVE"
        return $data
      }

      proc run_exec {} {
        global cvscfg
        variable my_idx
        variable procout
        variable procerr
        variable procid
        variable errmsg
        variable command
        variable viewer
        variable filter
        variable v_w
        variable w

        fconfigure stderr -blocking false -buffering line
        fconfigure stdout -blocking false -buffering line
  
        # Set up the file we send the proc's stderr to
        set errordir [file join $cvscfg(tmpdir) "cvstmpdir.[pid]"]
        file mkdir $errordir
        set errorfile [file join $errordir "exec$my_idx"]
        set procerr [open $errorfile w+]
  

        # Here's where we do it
        gen_log:log C "$command"
        set procout [open "| $command 2>@$procerr" r]
        set procid [pid $procout]
        # Dont ever do this.  The whole thing depends on procout blocking
        #fconfigure $procout -blocking false -buffering line

        fileevent $procout readable [list [namespace current]::out_handler $viewer $filter]
        flush $procerr
        fileevent $procerr readable [list [namespace current]::err_handler]
  
        # set buffering back to normal
        fconfigure stdout -blocking true -buffering line
        catch {fileevent $procerr readable {} }
      }

      after 0 [list [namespace current]::run_exec]

      return [namespace current]
    }
  }
}

namespace eval ::viewer {
  variable instance 0
  #
  # Set up a dialog containing a text box to view
  # the report of the command during execution.
  #
  proc new {title} {
    variable instance
    set my_idx $instance
    incr instance

    namespace eval $my_idx {
      global cvscfg
      variable my_idx [uplevel {concat $my_idx}]
      variable title [uplevel {concat $title}]
      variable w ".view$my_idx"
      variable log {}
      variable searchstr {}
      variable searchidx 1.0
      variable v_e

      viewer_window $w $title [namespace current]

      proc do { command {show_stderr {1}} {filter {}} } {
        global cvscfg
        variable w
        variable v_e

        gen_log:log T "ENTER (\"$command\" \"$show_stderr\" \"$filter\")"

        pack forget $w.close
        pack $w.stop -in $w.bottom -side right -ipadx 15

        # Send the command to the execution module
        set v_e [::exec::new $command [namespace current] $show_stderr $filter]

        gen_log:log T "LEAVE"
      }

      proc abort {} {
        variable v_e
        namespace inscope $v_e abort
      }

      proc wait {} {
        variable v_e
        namespace inscope $v_e wait
      }

      # Call this proc to write arbitrary text to the viewer
      proc log { text {texttag {}} } {
        variable w
        $w.text insert end $text $texttag 
        $w.text yview end
      }

      proc search {} {
        variable searchidx
        variable w

        set str [$w.bottom.entry get]
        set match [$w.text search -- $str $searchidx]
        if {[string length $match] > 0} {
          set length [string length $str]
          $w.text mark set insert $match
          $w.text tag add sel $match "$match + ${length}c"
          $w.text see $match
          set searchidx "$match + ${length}c"
        }
      }

      return [namespace current]
    }
  }
}

# Filters output lines from CVS
# returns the name of the tag to use when printing
# the line in the text widget
# This filter doesn't need its exec argument, but filters
# must have it because some do need it
proc status_colortags {exec line} {
  global cvscfg

  set tag default
  # Return the type of the line being output
  # Neat trick I found on clt: -> is a valid variable name!
  if {[regexp {^([PUARMCD?!]) (.*)} $line -> mode file]} {
    gen_log:log D "$line"
    gen_log:log D "mode $mode file $file"
    switch -exact -- $mode {
      U { set tag updated }
      A { set tag added }
      R { set tag removed }
      D { set tag removed }
      M { set tag modified }
      C { set tag conflict }
      P { set tag patched }
      ! { set tag warning }
      ? { set tag [expr {$cvscfg(status_filter) ? {noshow} : {unknown}}] }
      default { set tag default }
    }
  } elseif {[regexp {^cvs server: warning: .*} $line]} {
    set tag warning
  }
  gen_log:log T "LEAVE: $tag"
  return [list $tag $line]
}

proc patch_colortags {exec line} {
  global cvscfg

  gen_log:log T "ENTER ($exec \"$line\")"

  set tag default
  # Return the type of the line being output
  switch -regexp -- $line {
    { is new;}       { set tag added }
    { changed from } { set tag modified }
    { is removed;}   { set tag removed }
    {^\+}            { set tag added }
    {^\-}            { set tag removed }
    {^Index}         { set tag modified }
    default          { set tag default }
  }

  return [list $tag $line]
}

proc parse_version {exec line} {
  if {[string match "Concurrent*" $line]} {
    set version [lindex [split $line] 4]
    return [list tagged $version]
  }
  return [list {} {}]
}

proc hilight_rcslog {exec line} {
  set tag default
  if {[string match "=============*" $line]} {
    set tag patched
  } elseif  {[string match "RCS file:*" $line]} {
    set tag patched
  } elseif  {[string match "Working file:*" $line]} {
    set tag patched
  }

  return [list $tag $line]
}

# This is a plain viewer that prints whatever text is sent to it
namespace eval ::view_output {
  variable instance 0

  proc new {title text_to_display} {
    variable instance
    set my_idx $instance
    incr instance

    gen_log:log T "ENTER ($title ...)"
    namespace eval $my_idx {
      global cvscfg
      variable my_idx [uplevel {concat $my_idx}]
      variable title [uplevel {concat $title}]
      variable text_to_display [uplevel {list $text_to_display}]
      variable w ".output$my_idx"
      variable searchstr {}
      variable searchidx 1.0

      viewer_window $w $title [namespace current]

      foreach line $text_to_display {
        $w.text insert end "$line"
      }

      proc search {} {
        variable searchidx
        variable w

        set str [$w.bottom.entry get]
        set match [$w.text search -- $str $searchidx]
        if {[string length $match] > 0} {
          set length [string length $str]
          $w.text mark set insert $match
          $w.text tag add sel $match "$match + ${length}c"
          $w.text see $match
          set searchidx "$match + ${length}c"
        }
      }

    }
  }
}

proc viewer_window {w title parent} {
  global cvscfg
  global tcl_platform

  toplevel $w
  if {$tcl_platform(platform) != "windows"} {
    wm iconbitmap $w @$cvscfg(bitmapdir)/cvs-says.xbm
  }
  wm protocol $w WM_DELETE_WINDOW "$w.close invoke"

  text $w.text -setgrid yes -relief sunken -border 2 \
      -exportselection 1 -height 30 \
      -yscroll "$w.scroll set"
  bind $w.text <KeyPress> {
    switch -- %K {
      "Up" -
      "Left" -
      "Right" -
      "Down" -
      "Next" -
      "Prior" -
      "Home" -
      "End" {}
      "c" -
      "C" {
          if {(%s & 0x04) == 0} {
            break
          }
        }
      default {
          break
        }
    }
  }
  bind $w.text <<Paste>> {break}
  bind $w.text <<Cut>> {break}

  # Configure the various tags
  foreach outputcolor [array names cvscfg outputColor,*] {
    regsub {^.*,} $outputcolor {} mode
    $w.text tag configure "$mode" -foreground $cvscfg($outputcolor)
  }

  scrollbar $w.scroll -relief sunken -command "$w.text yview"
  frame $w.bottom
  button $w.bottom.srchbtn -text Search -command "$parent\::search"
  entry $w.bottom.entry -width 20 -textvariable searchstr
  bind $w.bottom.entry <Return> "$parent\::search"
  
  button $w.save -text "Save to File" -command "save_viewcontents $w"
  button $w.close -text "Close" -command "
    namespace delete $parent
    destroy $w
    exit_cleanup 0
  "
  button $w.stop -text "Stop" -bg red4 -fg white \
      -state [expr {$cvscfg(allow_abort) ? {normal} : {disabled}}] \
      -command "$parent\::abort"
  pack $w.bottom -side bottom -fill x ;#-padx 25
  pack $w.scroll -side right -fill y
  pack $w.text -fill both -expand 1
  pack $w.bottom.srchbtn -side left
  pack $w.bottom.entry -side left
  pack $w.save -in $w.bottom -side left -padx 25
  pack $w.close -in $w.bottom -side right -ipadx 15

  # Focus to activate text bindings
  focus $w
  wm title $w "$title"
}

proc save_viewcontents {w} {
  set types  { {{All Files} *} }
  set savfile [ \
    tk_getSaveFile -title "Save Results Summary" \
       -initialdir "." \
       -filetypes $types \
       -parent $w \
  ]  
  if {$savfile == ""} {
    return
  } 
  if {[catch {set fo [open $savfile w]}]} {
    puts "Cannot open $savfile for writing"
    return
  }
  puts $fo [$w.text get 1.0 end]
  close $fo
}

#
# Search functionality for text widgets
#
proc search_textwidget_init {} {
# Initialize the globals for general text searches
  global cvsglb

  if {! [info exists cvsglb(searchstr)] } {
    set cvsglb(searchstr) ""
  }
  set cvsglb(searchidx) "1.0"
}

proc search_textwidget { wtx } {
# Search the text widget
  global cvsglb
  global cvscfg

  #gen_log:log T "ENTER ($wtx)"
  set searchstr $cvsglb(searchstr)

  set match [$wtx search -- $searchstr $cvsglb(searchidx)]
  if {[string length $match] > 0} {
    set length [string length $searchstr]
    $wtx mark set insert $match
    $wtx tag add sel $match "$match + ${length}c"
    $wtx see $match
    set cvsglb(searchidx) "$match + ${length}c"
  }
}

