proc cde_open_resourcefile { file } {
  set ans ""
  set ret [catch {open $file r} ans]
  if {$ret == 0} {
    #puts "LEAVE cde_open_resourcefile ($ans)"
    return $ans
  } else {
    #puts "LEAVE cde_open_resourcefile ($ans)"
    #puts "Error: $ans"
    return ""
  }
}

proc get_cde_params { } {
  global cvsglb
  global cvscfg
  global tk_version

  # Set defaults for all the necessary things
  set bg [option get . background background]
  set fg [option get . foreground foreground]
  set guifont [option get . buttonFontList buttonFontList]
  set txtfont [option get . FontSet FontSet]
  set listfont [option get . textFontList textFontList]

  set textbg white
  set textfg black

  # If any of these aren't set, I don't think we're in CDE after all
  if {![string length $fg]} {return 0}
  if {![string length $bg]} {return 0}
  if {![string length $guifont]} {
    # For AIX
    set guifont [option get . FontList FontList]
  }
  if {![string length $guifont]} {return 0}
  if {![string length $txtfont]} {return 0}

  set guifont [string trimright $guifont ":"]
  set txtfont [string trimright $txtfont ":"]
  set listfont [string trimright $txtfont ":"]
  regsub {medium} $txtfont "bold" dlgfont

  # They don't tell us the slightly darker color they use for the
  # scrollbar backgrounds and graphics backgrounds, so we'll make
  # one up.
  shades $bg

  set cvscfg(guifont) $guifont
  set cvscfg(dialogfont) $dlgfont

  # If we can find the user's dt.resources file, we can find out the
  # palette and background/foreground colors
  set fh ""
  set palette ""
  set cur_rsrc ~/.dt/sessions/current/dt.resources
  set hom_rsrc ~/.dt/sessions/home/dt.resources
  if {[file readable $cur_rsrc] && [file readable $hom_rsrc]} {
    # Both exist.  Use whichever is newer
    if {[file mtime $cur_rsrc] > [file mtime $hom_rsrc]} {
      #puts "  $cur_rsrc is newer"
      set fh [cde_open_resourcefile $cur_rsrc]
      if {$fh == ""} {
        set fh [cde_open_resourcefile $hom_rsrc]
      }
    } else {
      #puts "  $hom_rsrc is newer"
      set fh [cde_open_resourcefile $hom_rsrc]
      if {$fh == ""} {
        set fh [cde_open_resourcefile $cur_rsrc]
      }
    }
  } elseif {[file readable $cur_rsrc]} {
    # Otherwise try current first
    set fh [cde_open_resourcefile $cur_rsrc]
    if {$fh == ""} {
      set fh [cde_open_resourcefile $hom_rsrc]
    }
  } elseif {[file readable $hom_rsrc]} {
    set fh [cde_open_resourcefile $hom_rsrc]
  }
  if {[string length $fh]} {
    set palf ""
    while {[gets $fh ln] != -1} {
      regexp "^\\*background:\[ \t]*(.*)\$" $ln nil textbg
      regexp "^\\*foreground:\[ \t]*(.*)\$" $ln nil textbg
      regexp "^\\*0\\*ColorPalette:\[ \t]*(.*)\$" $ln nil palette
      regexp "^Window.Color.Background:\[ \t]*(.*)\$" $ln nil textbg
      regexp "^Window.Color.Foreground:\[ \t]*(.*)\$" $ln nil textfg
    }
    catch {close $fh}
    #
    # If the *0*ColorPalette setting was found above, try to find the
    # indicated file in ~/.dt, $DTHOME, or /usr/dt.
    #
    if {[string length $palette]} {
      foreach dtdir {/usr/dt /etc/dt ~/.dt} {
        # This uses the last palette that we find
        if {[file readable [file join $dtdir palettes $palette]]} {
          set palf [file join $dtdir palettes $palette]
        }
      }
      # puts "Using palette $palf"
      if {[string length $palf]} {
        if {![catch {open $palf r} fh]} {
          gets $fh activetitle
          gets $fh inactivetitle
          gets $fh wkspc1
          gets $fh textbg
          gets $fh guibg   ;#(*.background) - default for tk under cde
          gets $fh menubg
          gets $fh wkspc4
          gets $fh iconbg  ;#control panel bg too
          close $fh

          set hlbg $activetitle
        }
      }
    }
  } else {
    puts stderr "Neither ~/.dt/sessions/current/dt.resources nor"
    puts stderr "        ~/.dt/sessions/home/dt.resources was readable"
    puts stderr "   Falling back to plain X"
    return 0
  }

  set hlfg $fg
  if {! [info exists hlbg]} {
    set hlbg $bg
  }

  set cvsglb(bg) $bg
  set cvsglb(fg) $fg
  set cvsglb(textbg) $textbg
  set cvsglb(textfg) $textfg
  set cvsglb(hlbg) $hlbg
  set cvsglb(hlfg) $hlfg

  option add *selectColor $activetitle
  option add *Button.activeBackground $bg
  option add *Button.activeForeground $fg
  option add *Canvas.Background $cvsglb(shadow)
  option add *Canvas.Foreground black
  option add *Dialog.Background $menubg
  option add *Entry.Background $textbg
  option add *Entry.Foreground $textfg
  option add *Entry.readonlyBackground $bg
  option add *Entry.highlightBackground $bg
  option add *Entry.highlightColor $activetitle
  option add *Listbox.background $textbg
  option add *Listbox.selectBackground $hlbg
  option add *Listbox.selectForeground $hlfg
  option add *Scrollbar.activeBackground $bg
  option add *Scrollbar.troughColor $cvsglb(shadow)
  option add *Text.Background $textbg
  option add *Text.Foreground $textfg
  option add *Text.highlightBackground $bg
  option add *Text.highlightColor $wkspc4

  option add *Menu.borderWidth 1
  option add *Menu.Background $menubg
  option add *Menu.activeBackground $menubg
  option add *Menu.activeForeground $fg
  option add *Menubutton.Background $menubg
  option add *Menubutton.activeBackground $menubg
  option add *Menubutton.activeForeground $fg
  # Menu checkboxes
  if {$tk_version >= 8.5} {
    # This makes it look like the native CDE checkbox
    option add *Menu.selectColor $fg
    option add *Checkbutton.offRelief sunken
    option add *Checkbutton.selectColor ""
  } else {
    option add *Menu.selectColor $hlbg
  }
  option add *Checkbutton.activeBackground $bg
  option add *Checkbutton.activeForeground $fg

  return 1
}

proc get_gtk_params { } {
  global cvsglb
  global tk_version

  #puts " GTK: Getting X11 options"
  if {! [llength [auto_execok xrdb]]} {
    return 0
  }
  set pipe [open "|xrdb -q" r]
  while {[gets $pipe ln] > -1} {
    switch -glob -- $ln {
      {\*Toplevel.background:*} {
        #puts $ln
        set bg [lindex $ln 1]
      }
      {\*Toplevel.foreground:*} {
        #puts $ln
        set fg [lindex $ln 1]
      }
      {\*Text.background:*} {
        #puts $ln
        set textbg [lindex $ln 1]
      }
      {\*Text.foreground:*} {
        #puts $ln
        set textfg [lindex $ln 1]
      }
      {\*Text.selectBackground:*} {
        #puts $ln
        set hlbg [lindex $ln 1]
      }
      {\*Text.selectForeground:*} {
        #puts $ln
        set hlfg [lindex $ln 1]
      }
    }
  }
  close $pipe

  if {! [info exists bg] || ! [info exists fg]} {
    return 0
  }

  shades $bg

  set cvsglb(bg) $bg
  set cvsglb(fg) $fg
  set cvsglb(textbg) $textbg
  set cvsglb(textfg) $textfg
  set cvsglb(hlbg) $hlbg
  set cvsglb(hlfg) $hlfg

  # These are already set, but maybe I like mine better
  option add *Button.activeBackground $cvsglb(light)
  option add *Canvas.Background $cvsglb(shadow)
  option add *Canvas.Foreground black
  option add *Entry.Background $textbg
  option add *Entry.Foreground $textfg
  option add *Entry.selectBackground $hlbg
  option add *Entry.selectForeground $hlfg
  option add *Entry.readonlyBackground $bg
  option add *Listbox.background $textbg
  option add *Listbox.selectBackground $hlbg
  option add *Listbox.selectForeground $hlfg
  option add *Text.Background $textbg
  option add *Text.Foreground $textfg
  option add *Text.selectBackground $hlbg
  option add *Text.selectForeground $hlfg

  # Menu checkboxes
  if {$tk_version >= 8.5} {
    option add *Menu.selectColor $fg
  } else {
    option add *Menu.selectColor $hlbg
    option add *Checkbutton.selectColor $hlbg
  }
  option add *selectColor $hlbg

  return 1
}

proc shades {bg} {
  global cvsglb

  set rgb_bg [winfo rgb . $bg]
  set bg0 [expr [lindex $rgb_bg 0] / 256 ]
  set bg1 [expr [lindex $rgb_bg 1] / 256 ]
  set bg2 [expr [lindex $rgb_bg 2] / 256 ]

  set factor .9
  set shadow [format #%02x%02x%02x [expr int($factor * $bg0)] \
                                   [expr int($factor * $bg1)] \
                                   [expr int($factor * $bg2)]]

  set factor .3
  set darkest [format #%02x%02x%02x [expr int($factor * $bg0)] \
                                    [expr int($factor * $bg1)] \
                                    [expr int($factor * $bg2)]]

  set inv0 [expr 255 - $bg0]
  set inv1 [expr 255 - $bg1]
  set inv2 [expr 255 - $bg2]

  set factor .2
  set add0 [expr int($factor*$inv0)]
  set add1 [expr int($factor*$inv1)]
  set add2 [expr int($factor*$inv2)]

  set light [format #%02x%02x%02x [expr {$bg0 + $add0}] \
                                  [expr {$bg1 + $add1}] \
                                  [expr {$bg2 + $add2}]]

  set factor .5
  set add0 [expr int($factor*$inv0)]
  set add1 [expr int($factor*$inv1)]
  set add2 [expr int($factor*$inv2)]

  set lighter [format #%02x%02x%02x [expr {$bg0 + $add0}] \
                                  [expr {$bg1 + $add1}] \
                                  [expr {$bg2 + $add2}]]

  set cvsglb(shadow) $shadow
  set cvsglb(canvbg) $shadow
  set cvsglb(darkest) $darkest
  set cvsglb(light) $light
  set cvsglb(lighter) $lighter
}

