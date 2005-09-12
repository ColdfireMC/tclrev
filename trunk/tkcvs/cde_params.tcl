# Most of this was stolen from the "CDE" package by D. J. Hagberg.
# I dig a couple more things out of the palette. -dar

proc get_cde_params { } {
  global cvscfg
  global cvsglb

  # Set defaults for all the necessary things
  set bg [option get . background background]
  set fg [option get . foreground foreground]
  set guifont [option get . buttonFontList buttonFontList]
  set txtfont [option get . FontSet FontSet]
  set listfont [option get . textFontList textFontList]
  set textbg $bg
  set textfg $fg

  # If any of these aren't set, I don't think we're in CDE after all
  if {![string length $fg]} {return 0}
  if {![string length $bg]} {return 0}
  if {![string length $guifont]} {return 0}
  if {![string length $txtfont]} {return 0}

  set guifont [string trimright $guifont ":"]
  set txtfont [string trimright $txtfont ":"]
  set listfont [string trimright $txtfont ":"]
  regsub {medium} $txtfont "bold" dlgfont

  #puts "Background $bg"
  #puts "Foreground $fg"
  #puts "UI Font $guifont"
  #puts "User Font $txtfont"
  #puts "Text Font $listfont"
  #puts "Dialog Font $dlgfont"

  set cvscfg(guifont) $guifont
  set cvscfg(listboxfont) $listfont
  set cvscfg(dialogfont) $dlgfont

  # They don't tell us the slightly darker color they use for the
  # scrollbar backgrounds and graphics backgrounds, so we'll make
  # one up.
  set rgb_bg [winfo rgb . $bg]
  set shadow [format #%02x%02x%02x [expr (9*[lindex $rgb_bg 0])/2560] \
                                   [expr (9*[lindex $rgb_bg 1])/2560] \
                                   [expr (9*[lindex $rgb_bg 2])/2560]]

  # If we can find the user's dt.resources file, we can find out the 
  # palette and background/foreground colors
  set fh ""
  set palette ""
  set cur_rsrc ~/.dt/sessions/current/dt.resources
  set hom_rsrc ~/.dt/sessions/home/dt.resources
  if {[file readable $cur_rsrc] && [file readable $hom_rsrc]} {
    if {[file mtime $cur_rsrc] > [file mtime $hom_rsrc]} {
      if {[catch {open $cur_rsrc r} fh]} {set fh ""}
    } else {
      if {[catch {open $hom_rsrc r} fh]} {set fh ""}
    }
  } elseif {[file readable $cur_rsrc]} {
    if {[catch {open $cur_rsrc r} fh]} {set fh ""}
  } elseif {[file readable $hom_rsrc]} {
    if {[catch {open $hom_rsrc r} fh]} {set fh ""}
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
        if {[file readable $dtdir/palettes/$palette]} {
          set palf $dtdir/palettes/$palette
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
      
          option add *Entry.highlightColor $activetitle userDefault
          option add *selectColor $activetitle userDefault
          option add *Text.highlightColor $wkspc4 userDefault
          option add *Dialog.Background $menubg userDefault
          option add *Menu.Background $menubg userDefault
          option add *Menubutton.Background $menubg userDefault
          option add *Menu.activeBackground $menubg userDefault
          option add *Menubutton.activeBackground $menubg userDefault
          set cvsglb(hlbg) $wkspc1
        }
      }
    }
  } else {
    puts stderr "Neither ~/.dt/sessions/current/dt.resources nor"
    puts stderr "        ~/.dt/sessions/home/dt.resources was readable"
    puts stderr "   Falling back to plain X"
    return 0
  }
  set cvsglb(canvbg) $shadow
  set cvsglb(hlfg) $fg
  set cvsglb(textbg) $textbg
  set cvsglb(textfg) $textfg
  if {![info exists cvsglb(hlbg)]} {
    set cvsglb(hlbg) $fg
    set cvsglb(hlfg) $bg
  }

  option add *Button.font $guifont userDefault
  option add *Label.font $guifont userDefault
  option add *Menu.font $guifont userDefault
  option add *Menubutton.font $guifont userDefault
  option add *Dialog.msg.font $dlgfont userDefault

  option add *Text.Background $textbg userDefault
  option add *Entry.Background $textbg userDefault
  option add *Text.Foreground $textfg userDefault
  option add *Entry.Foreground $textfg userDefault
  option add *Button.activeBackground $bg userDefault
  option add *Button.activeForeground $fg userDefault
  option add *Scrollbar.activeBackground $bg userDefault
  option add *Scrollbar.troughColor $shadow userDefault
  option add *Canvas.Background $shadow userDefault

  # These menu configs work if you use native menus.
  option add *Menu.borderWidth 1 userDefault
  option add *Menu.activeForeground $fg userDefault
  option add *Menubutton.activeForeground $fg userDefault

  # This draws a thin border around buttons
  #option add *highlightBackground $bg userDefault
  # Suppress the border
  option add *HighlightThickness 0 userDefault
  # Add it back for text and entry widgets
  option add *Text.highlightBackground $bg userDefault
  option add *Entry.highlightBackground $bg userDefault
  option add *Text.HighlightThickness 2 userDefault
  option add *Entry.HighlightThickness 1 userDefault

  return 1
}
