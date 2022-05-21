#
# tooltips version 0.1
# Paul Boyer
# Science Applications International Corp.
#
# THINGS I'D LIKE TO DO:
# 1. make a widget called "tooltip_button" which does it all
# and takes name and helptext as arguments in addition to all
# button args
# 2. Keep visibility of tooltip always on top
# 3. Must be a better way to maintain button presses than rebinding?
#   Because I don't want to explicitly handle all possible bindings
#   such as <Button-2> etc
# 4. Allow for capability for status window at bottom of a frame
#  that gets the status of the selected icon


##############################
# set_tooltips gets a button's name and the tooltip string as
# arguments and creates the proper bindings for entering
# and leaving the button

proc set_tooltips { widget name } {
  global cvsglb
  
  bind $widget <Enter> "
    catch { after 500 { internal_tooltips_PopUp %W $name } } \
        cvsglb(tooltip_id)
  "
  bind $widget <Leave> "internal_tooltips_PopDown"
  bind $widget <Button-1> "internal_tooltips_PopDown"
}

##############################
# internal_tooltips_PopUp is used to activate the tooltip window

proc internal_tooltips_PopUp { wid name } {
  global cvscfg cvsglb
  
  # get rid of other existing tooltips
  catch { destroy .tooltips_wind }
  
  toplevel .tooltips_wind -class ToolTip
  set size_changed 0
  set bg [option get .tooltips_wind background background]
  set fg [option get .tooltips_wind foreground foreground]
  
  # get the cursor position
  set X [winfo pointerx $wid]
  set Y [winfo pointery $wid]
  # add a slight offset to make tooltips fall below cursor
  set Y [expr { $Y + 20 }]
  
  # Now pop up the new widgetLabel
  wm overrideredirect .tooltips_wind 1
  wm geometry .tooltips_wind +$X+$Y
  label .tooltips_wind.l \
      -text $name \
      -border 2 \
      -relief raised \
      -font $cvscfg(listboxfont) \
      -background $bg \
      -foreground $fg
  pack .tooltips_wind.l
  
  # make invisible
  wm withdraw .tooltips_wind
  update idletasks
  
  set screenH [winfo screenheight .]
  set screenW [winfo screenwidth .]
  set reqW [winfo reqwidth .tooltips_wind]
  set reqH [winfo reqheight .tooltips_wind]
  # adjust for bottom of screen
  if { ($Y + $reqH) > $screenH } {
    set Y [expr { $Y - $reqH - 25 }]
    set size_changed 1
  }
  # adjust for right border of screen
  # The following correction tests whether X + reqwidth goes off the right side. But if it's a
  # second screen, X is already > screenwidth even before adding the reqwidth, so it will get
  # backed up onto the wrong screen. I don't know of a way to detect X relative to the actual
  # multiple-screen layout, so I'm skipping the correction until a better way is found.
  if { ($X < $screenW) && (($X + $reqW) > $screenW) } {
    set X [expr { $screenW - $reqW }]
    set size_changed 1
  }
  # reset position
  if { $size_changed == 1 } {
    wm geometry .tooltips_wind +$X+$Y
  }
  # make visible
  wm deiconify .tooltips_wind
  # must explicitly raise windows on Mac
  if {[tk windowingsystem] eq "aqua"} {
    raise .tooltips_wind
  }
  # make tooltip dissappear after 5 sec
  set cvsglb(tooltip_id) [after 5000 { internal_tooltips_PopDown }]
}

proc internal_tooltips_PopDown { } {
  global cvsglb
  
  after cancel $cvsglb(tooltip_id)
  catch { destroy .tooltips_wind }
}

