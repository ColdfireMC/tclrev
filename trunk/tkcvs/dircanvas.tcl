#
# Columns for listing CVS files and their status
#

proc DirCanvas:create {w} {
  global cvscfg
  global cvsglb
  global arr
  global incvs insvn inrcs ingit

  gen_log:log T "ENTER ($w)"

  if {[catch "image type folder"]} {
    DirCanvas:loadimages
  }
  if [winfo exists $w.pw] {
    catch {DirCanvas:destroy $w.pw}
    catch {destroy $w.pw}
  }

  set winwid [winfo width $w]
  set beginwid [expr {$winwid / 5}]
  panedwindow $w.pw -relief sunk -bd 2
  $w.pw configure -handlepad 35 -sashwidth 4 -sashpad 0 -handlesize 10

  foreach column {filecol statcol datecol wrevcol editcol} {
    frame $w.$column
    canvas $w.$column.list -highlightthickness 0 -width $beginwid
    $w.$column configure -bg $cvsglb(canvbg)
    $w.$column.list configure -bg $cvsglb(canvbg)
  }
  scrollbar $w.yscroll -orient vertical -command "DirCanvas:scroll_windows $w" \
    -highlightthickness 0
  pack $w.yscroll -side right -fill y

  DirCanvas:column $w filecol "file"
  DirCanvas:column $w statcol "status"
  DirCanvas:column $w datecol "date"
  gen_log:log D "incvs=$incvs insvn=$insvn inrcs=$inrcs ingit=$ingit"
  if {$incvs || $insvn || $inrcs || $ingit} {
    DirCanvas:column $w wrevcol "revision"
    DirCanvas:column $w editcol "editors"
  }

  # Put an extra arrow on the file column for sorting by status
  set statusbutton $w.filecol.head.statbut
  button $statusbutton -image arr_dn \
    -relief raised -bd 1 -highlightthickness 0
  set arr(filestatcol) $statusbutton
  pack $statusbutton -side left
  bind $statusbutton <ButtonPress-1> \
    "DirCanvas:toggle_col $w statcol"
  bind $statusbutton <ButtonPress-2> \
    "DirCanvas:sort_by_col $w statcol -decreasing"
  bind $statusbutton <ButtonPress-3> \
    "DirCanvas:sort_by_col $w statcol -increasing"

  gen_log:log D "sort_pref:  $cvscfg(sort_pref)"
  set col [lindex $cvscfg(sort_pref) 0]
  set sense [lindex $cvscfg(sort_pref) 1]
  if { (! ($incvs || $inrcs || $insvn || $ingit))  && ( $col == "editcol" || $col == "wrevcol") } {
    gen_log:log T "setting sort to column \"filecol!\""
    set col "filecol"
    set sense "-decreasing"
  }
  if {[string match "-inc*" $sense]} {
    gen_log:log D "sort column $col -increasing"
    $arr($col) configure -image arh_up
    if {$col == "statcol"} {$arr(filestatcol) configure -image arh_up}
  } else {
    gen_log:log D "sort column $col -decreasing"
    if {[info exists arr($col)] && [winfo exists $arr($col)]} {
      $arr($col) configure -image arh_dn
    gen_log:log D "arr(col) = arr($col);  arr($col) = $arr($col)"
    }
    if {$col == "statcol"} {
      $arr(filestatcol) configure -image arh_dn
    }
  }

  focus $w.filecol.list
  if {! [winfo exists $w.paper_pop]} {
    DirCanvas:makepopup $w
  }
  gen_log:log T "LEAVE"
}

proc DirCanvas:headtext {w column lbltext} {
  $w.$column.head.lbl configure -text "$lbltext"
}

proc DirCanvas:column {w column headtext} {
  global cvscfg
  global incvs insvn inrcs ingit
  global arr

  gen_log:log T "ENTER ($w $column headtext)"
  gen_log:log T "showstatcol $cvscfg(showstatcol) showdatecol $cvscfg(showdatecol) showeditcol $cvscfg(showeditcol)"

  $w.$column.list configure -yscrollcommand "$w.yscroll set"
  bind $w.$column.list <Next>  "DirCanvas:scroll_windows $w scroll  1 pages"
  bind $w.$column.list <Prior> "DirCanvas:scroll_windows $w scroll -1 pages"
  bind $w.$column.list <Down>  "DirCanvas:scroll_windows $w scroll  1 units"
  bind $w.$column.list <Up>    "DirCanvas:scroll_windows $w scroll -1 units"
  bind $w.$column.list <B2-Motion> "DirCanvas:drag_windows $w %W %y"
  bind $w.$column.list <MouseWheel> \
      "DirCanvas:scroll_windows $w scroll \[expr {-(%D/120)*4}\] units"
  bind $w.$column.list <ButtonPress-4> \
      "DirCanvas:scroll_windows $w scroll -1 units"
  bind $w.$column.list <ButtonPress-5> \
      "DirCanvas:scroll_windows $w scroll 1 units"

  frame $w.$column.head -relief raised -bd 2
  label $w.$column.head.lbl -text "$headtext"
  button $w.$column.head.sbut -image arr_dn -relief flat \
    -highlightthickness 0
  set arr($column) $w.$column.head.sbut

  bind $w.$column.head.sbut <ButtonPress-1> "DirCanvas:toggle_col $w $column"
  bind $w.$column.head.sbut <ButtonPress-2> "DirCanvas:sort_by_col $w $column -decreasing"
  bind $w.$column.head.sbut <ButtonPress-3> "DirCanvas:sort_by_col $w $column -increasing"

  if {$column == "datecol"} {
    if {$cvscfg(showdatecol)} {
      DirCanvas:map_column $w datecol
    } else {
      gen_log:log T "LEAVE (skipping datecol)"
    }
    return
  }
  if {$column == "statcol"} {
    if {($incvs || $insvn || $inrcs || $ingit) && $cvscfg(showstatcol)} {
      DirCanvas:map_column $w statcol
    } else {
      gen_log:log T "LEAVE (skipping statcol)"
    }
    return
  }
  if {$column == "editcol"} {
    if {($incvs || $insvn || $inrcs || $ingit) && $cvscfg(showeditcol)} {
      DirCanvas:map_column $w editcol
    } else {
      gen_log:log T "LEAVE (skipping editcol)"
    }
    return
  }
  DirCanvas:map_column $w $column
}

proc DirCanvas:map_column {w column} {

  gen_log:log T "ENTER ($w $column)"
  set mapped_columns [$w.pw panes]

  if {"$w.statcol" in $mapped_columns} {
    set leftcol "$w.statcol"
  } else {
    set leftcol "$w.filecol"
  }

  if {$column == "datecol"} {
    $w.pw add $w.$column -after $leftcol -minsize 80
    #gen_log:log D "ADD $w.$column"
  } elseif {$column == "statcol"} {
    $w.pw add $w.$column -after $w.filecol -minsize 80
    #gen_log:log D "ADD $w.$column"
  } elseif {$column == "editcol"} {
    $w.pw add $w.$column -after $w.wrevcol -minsize 80
    #gen_log:log D "ADD $w.$column"
  } else {
    $w.pw add $w.$column -minsize 80
    #gen_log:log D "ADD $w.$column"
  }
  pack $w.$column.head -side top -fill x -expand no
  pack $w.$column.head.sbut -side right
  pack $w.$column.head.lbl -side right -fill x -expand yes
  pack $w.$column.list -side top -fill both -ipadx 2 -expand yes

  set winwid [winfo width $w]
  set mapped_columns [$w.pw panes]
  set num_columns [llength $mapped_columns]
  gen_log:log D "mapped_columns: $mapped_columns"
  set newwid [expr {$winwid / $num_columns}]
  for {set i 0} { $i < [expr {$num_columns - 1}] } {incr i} {
    set coords [$w.pw sash coord $i]
    set ypos [lindex $coords 1]
    set new_xpos [expr {($i+1) * $newwid}]
    #gen_log:log D "$column: moving sash $i from  $coords to $new_xpos $ypos"
    $w.$column configure -width $newwid
    $w.pw sash place $i $new_xpos $ypos
    set real_pos [$w.pw sash coord $i]
  }
  update idletasks

  gen_log:log T "LEAVE"
}

proc DirCanvas:unmap_column {w column} {
  gen_log:log T "ENTER ($w $column)"

  $w.pw forget $w.$column
  set winwid [winfo width $w]
  #gen_log:log D "WIDTH $winwid"
  set mapped_columns [$w.pw panes]
  set num_columns [llength $mapped_columns]
  gen_log:log D "mapped_columns: $mapped_columns"
  set newwid [expr {$winwid /$num_columns}]
  for {set i 0} { $i < [expr {$num_columns - 1}] } {incr i} {
    set coords [$w.pw sash coord $i]
    set ypos [lindex $coords 1]
    set new_xpos [expr {($i+1) * $newwid}]
    #gen_log:log D "$column: moving sash $i from  $coords to $new_xpos $ypos"
    $w.pw sash place $i $new_xpos $ypos
    set real_pos [$w.pw sash coord $i]
  }
  gen_log:log T "LEAVE"
}

#
# Insert a new element $v into the list $w.
#
proc DirCanvas:newitem {w f} {
  global DirList
  global Filelist
  global cvsglb

  gen_log:log T "ENTER ($w $f)"

  set DirList($w:$f:name) $f
  gen_log:log D "Newitem $f status $Filelist($f:status)"
  set DirList($w:$f:status) $Filelist($f:status)
  set DirList($w:$f:date) $Filelist($f:date)
  if {[info exists Filelist($f:stickytag)]} {
    set DirList($w:$f:sticky) $Filelist($f:stickytag)
  } else {
    set DirList($w:$f:sticky) ""
  }
  if {[info exists Filelist($f:option)]} {
    set DirList($w:$f:option) $Filelist($f:option)
  } else {
    set DirList($w:$f:option) ""
  }
  if { [info exists Filelist($f:editors)]} {
    set DirList($w:$f:editors) $Filelist($f:editors)
  } else {
    set DirList($w:$f:editors) ""
  }
  set DirList($w:$f:selected) 0

  DirCanvas:buildwhenidle $w
  gen_log:log T "LEAVE"
}

proc DirCanvas:loadimages { } {
  global cvscfg

  image create photo paper \
    -format gif -file [file join $cvscfg(bitmapdir) paper.gif]
  image create photo cvsdir \
    -format gif -file [file join $cvscfg(bitmapdir) dir_cvs.gif]
  image create photo svndir \
    -format gif -file [file join $cvscfg(bitmapdir) dir_svn.gif]
  image create photo rcsdir \
    -format gif -file [file join $cvscfg(bitmapdir) dir_rcs.gif]
  image create photo gitdir \
    -format gif -file [file join $cvscfg(bitmapdir) dir_git.gif]
  image create photo folder \
    -format gif -file [file join $cvscfg(bitmapdir) folder.gif]
  image create photo dir_ok \
    -format gif -file [file join $cvscfg(bitmapdir) dir_ok.gif]
  image create photo dir_ood \
    -format gif -file [file join $cvscfg(bitmapdir) dir_ood.gif]
  image create photo dir_plus \
    -format gif -file [file join $cvscfg(bitmapdir) dir_plus.gif]
  image create photo dir_minus \
    -format gif -file [file join $cvscfg(bitmapdir) dir_minus.gif]
  image create photo link \
    -format gif -file [file join $cvscfg(bitmapdir) link.gif]
  image create photo link_ok \
    -format gif -file [file join $cvscfg(bitmapdir) link_ok.gif]
  image create photo link_okml \
    -format gif -file [file join $cvscfg(bitmapdir) link_okml.gif]
  image create photo link_okol \
    -format gif -file [file join $cvscfg(bitmapdir) link_okol.gif]
  image create photo link_mod \
    -format gif -file [file join $cvscfg(bitmapdir) link_mod.gif]
  image create photo link_modml \
    -format gif -file [file join $cvscfg(bitmapdir) link_modml.gif]
  image create photo link_modol \
    -format gif -file [file join $cvscfg(bitmapdir) link_modol.gif]
  image create photo link_plus \
    -format gif -file [file join $cvscfg(bitmapdir) link_plus.gif]
  image create photo stat_ex \
    -format gif -file [file join $cvscfg(bitmapdir) stat_ex.gif]
  image create photo stat_kb \
    -format gif -file [file join $cvscfg(bitmapdir) stat_kb.gif]
  image create photo stat_cvsplus_kb \
    -format gif -file [file join $cvscfg(bitmapdir) stat_plus_kb.gif]
  image create photo stat_ok \
    -format gif -file [file join $cvscfg(bitmapdir) stat_ok.gif]
  image create photo stat_ood \
    -format gif -file [file join $cvscfg(bitmapdir) stat_ood.gif]
  image create photo stat_okml \
    -format gif -file [file join $cvscfg(bitmapdir) stat_okml.gif]
  image create photo stat_okol \
    -format gif -file [file join $cvscfg(bitmapdir) stat_okol.gif]
  image create photo stat_merge \
    -format gif -file [file join $cvscfg(bitmapdir) stat_merge.gif]
  image create photo stat_mod \
    -format gif -file [file join $cvscfg(bitmapdir) stat_mod.gif]
  image create photo stat_modml \
    -format gif -file [file join $cvscfg(bitmapdir) stat_modml.gif]
  image create photo stat_modol \
    -format gif -file [file join $cvscfg(bitmapdir) stat_modol.gif]
  image create photo stat_mod_red \
    -format gif -file [file join $cvscfg(bitmapdir) stat_mod_red.gif]
  image create photo stat_mod_green \
    -format gif -file [file join $cvscfg(bitmapdir) stat_mod_green.gif]
  image create photo stat_plus \
    -format gif -file [file join $cvscfg(bitmapdir) stat_plus.gif]
  image create photo stat_ques \
    -format gif -file [file join $cvscfg(bitmapdir) stat_ques.gif]
  image create photo stat_minus \
    -format gif -file [file join $cvscfg(bitmapdir) stat_minus.gif]
  image create photo stat_conf \
    -format gif -file [file join $cvscfg(bitmapdir) stat_conf.gif]
}

#
# Delete element $v from the list $w.
# deleted.
#
proc DirCanvas:delitem {w v} {
  gen_log:log T "ENTER ($w $v)"
  DirCanvas:buildwhenidle $w
  gen_log:log T "LEAVE"
}

proc DirCanvas:deltree {w} {
  global DirList

  foreach column {filecol statcol datecol wrevcol editcol} {
    catch {destroy $w.$column}
  }
  catch {destroy $w.yscroll}
  foreach t [array names DirList $w:*] {
    unset DirList($t)
  }
}

proc DirCanvas:flash {w y} {
  global cvscfg

  $w.filecol.list itemconfigure $w.filecol.list.tx$y -font $cvscfg(flashfont)
  foreach column [lrange [$w.pw panes] 1 end] {
    set i [$column.list find withtag $w.filecol.list.tx$y]
    $column.list itemconfigure $i -font $cvscfg(flashfont)
  }
}

proc DirCanvas:unflash {w y} {
  global cvscfg

  $w.filecol.list itemconfigure $w.filecol.list.tx$y -font $cvscfg(listboxfont)
  foreach column [lrange [$w.pw panes] 1 end] {
    set i [$column.list find withtag $w.filecol.list.tx$y]
    $column.list itemconfigure $i -font $cvscfg(listboxfont)
  }
}

#
# Change the selection to the indicated item
#
proc DirCanvas:setselection {w y f} {
  global DirList
  global cvsglb

  gen_log:log T "ENTER ($w $y $f)"

  DirCanvas:unselectall $w 1
  gen_log:log D "adding \"$f\""
  set DirList($w:$f:selected) 1
  set DirList($w:selection) [list "$f"]
  set cvsglb(current_selection) $DirList($w:selection)
  DirCanvas:setTextHBox $w $w.filecol.list.tx$y

  gen_log:log T "LEAVE"
}

proc DirCanvas:addselection {w y f} {
  global DirList
  global cvsglb

  gen_log:log T "ENTER ($w $y $f)"

  regsub -all {\%\%} $f {%} fn
  regsub -all {\\\$} $fn {$} fn
  # If it's already selected, unselect it
  if { $DirList($w:$fn:selected) } {
    gen_log:log D "\"$fn\" was selected - unselecting"
    set DirList($w:$fn:selected) 0
    set idx [lsearch -exact $DirList($w:selection) "$fn"]
    if {$idx > -1} {
      gen_log:log D "found \"$fn\" - removing from selection list"
      set DirList($w:selection) [lreplace $DirList($w:selection) $idx $idx]
      gen_log:log D "$DirList($w:selection)"
      DirCanvas:clearTextHBox $w $w.filecol.list.tx$y
    }
  } else {
    gen_log:log D "adding \"$fn\""
    DirCanvas:setTextHBox $w $w.filecol.list.tx$y
    set DirList($w:$fn:selected) 1
    lappend DirList($w:selection) "$fn"
  }
  set cvsglb(current_selection) $DirList($w:selection)
  gen_log:log D "selection is \"$cvsglb(current_selection)\""
  gen_log:log T "LEAVE"
}


# clear any text highlight box (used by set/clearselection)
proc DirCanvas:clearTextHBox {w id} {
  global cvsglb

  # clear the tag corresponding to the text label
  foreach column [$w.pw panes] {
    catch {$column.list delete HBox$id}
    $column.list itemconfigure $id -fill $cvsglb(fg)
  }
}

# set a text highligh box (used by set/clearselection)
proc DirCanvas:setTextHBox {w id} {
  global cvsglb

  # get the bounding box for the text id
  set bbox [$w.filecol.list bbox $id]
  if {[llength $bbox] != 4} {
    return
  }
  set lx [lindex $bbox 0]
  #set uy [lindex $bbox 1]
  set ly [lindex $bbox 3]
  set ly [expr {$ly +1}]
  set uy [expr {$ly -16}]
  set i [eval $w.filecol.list create rectangle \
    $lx $ly [winfo width $w.filecol] $uy \
    -fill $cvsglb(hlbg) -tag HBox$id -outline \"\"]
  $w.filecol.list itemconfigure $id -fill $cvsglb(hlfg)
  $w.filecol.list lower $i
  foreach column [lrange [$w.pw panes] 1 end] {
    # create rectangle with fill, tagged with the same ID as the text,
    # so we can delete it later
    set i [eval $column.list create rectangle \
      0 $ly [winfo width $column] $uy \
      -fill $cvsglb(hlbg) -tag HBox$id -outline \"\"]
    $column.list itemconfigure $id -fill $cvsglb(hlfg)
    $column.list lower $i
  }
}

proc DirCanvas:addrange {w y f} {
  global DirList
  global cvsglb

  gen_log:log T "ENTER ($w $y $f)"
  if {! [info exists DirList($w:selection)] || [llength $DirList($w:selection)] < 1} {
    DirCanvas:clearTextHBox $w $w.filecol.list.tx$y
    set DirList($w:$f:selected) 1
    lappend DirList($w:selection) "$f"
    set cvsglb(current_selection) $DirList($w:selection)
    return
  }
  set sel1 [lindex $DirList($w:selection) 0]

  set iy $DirList($w:$sel1:y)
  gen_log:log D "Selection 1  :  $sel1 y=$iy"
  gen_log:log D "New Selection:  $f y=$y\n"

  if { $y > $iy } {
    foreach item [array names DirList $w:*:name] {
      set j $DirList($item)
      set jy $DirList($w:$j:y)
      if { $jy > $iy && $y > $jy} {
        gen_log:log D "$j y=$jy"
        DirCanvas:setTextHBox $w $w.filecol.list.tx$jy
        set DirList($w:$j:selected) 1
        if {$j ni $DirList($w:selection)} {
          lappend DirList($w:selection) "$j"
        }
      }
    }
  } elseif {$y < $iy } {
    foreach item [array names DirList $w:*:name] {
      set j $DirList($item)
      set jy $DirList($w:$j:y)
      if { $jy < $iy && $y < $jy} {
        gen_log:log D "$j y=$jy"
        DirCanvas:setTextHBox $w $w.filecol.list.tx$jy
        set DirList($w:$j:selected) 1
        if {$j ni $DirList($w:selection)} {
          lappend DirList($w:selection) "$j"
        }
      }
    }
  }

  DirCanvas:setTextHBox $w $w.filecol.list.tx$y
  set DirList($w:$f:selected) 1
  if {$f ni $DirList($w:selection)} {
    lappend DirList($w:selection) "$f"
  }

  set cvsglb(current_selection) $DirList($w:selection)
  gen_log:log D "selection is \"$cvsglb(current_selection)\""
  gen_log:log T "LEAVE"
}

proc DirCanvas:unselectall {w force} {
  global DirList
  global cvsglb

  gen_log:log T "ENTER ($w)"
  # Don't clear unless we aren't over anything
  if { $force || [ $w.filecol.list gettags current ] == "" } {
    foreach s [array names DirList $w:*:name] {
      set f $DirList($s)
      set y $DirList($w:$f:y)
      set DirList($w:$f:selected) 0
      DirCanvas:clearTextHBox $w $w.filecol.list.tx$y
    }
    set DirList($w:selection) {}
    set cvsglb(current_selection) {}
  }
  gen_log:log T "LEAVE"
}

# Internal use only.
# Draw the files on the canvas
proc DirCanvas:build {w} {
  global DirList
  global Filelist
  global cvscfg
  global cvsglb
  global incvs insvn inrcs ingit

  gen_log:log T "ENTER ($w)"
  foreach b [winfo children $w.filecol.list] {
    destroy $b
  }
  foreach column [$w.pw panes] {
    $column.list delete all
  }
  catch {unset DirList($w:buildpending)}

  set x 3
  set lblx 21
  set y 20
  set imy [expr {[image height paper] + 2}]
  set fy [font metrics $cvscfg(listboxfont) -displayof $w.filecol.list -linespace]
  set fy [expr {$fy + 2}]
  if {$imy > $fy} {
    set yincr $imy
    #gen_log:log D "Y spacing: $y set from icon"
  } else {
    set yincr $fy
    #gen_log:log D "Y spacing: $y set from font"
  }

  set maxlbl 0; set longlbl ""
  set maxstat 0; set longstat ""
  set maxdate 0; set longdate ""
  set maxtag 0; set longtag ""
  set maxed 0; set longed ""

  set sortcol [lindex $cvscfg(sort_pref) 0]
  set sortsense [lindex $cvscfg(sort_pref) 1]
  if { (!($incvs || $inrcs || $insvn || $ingit)) && ( $sortcol == "editcol" || $sortcol == "wrevcol") } {
    gen_log:log T "setting sort to column \"filecol!\""
    set sortcol "filecol"
    set sortsense "-decreasing"
  }

  set rtype ""
  if {$inrcs} {
    set rtype "RCS"
  } elseif {$incvs} {
    set rtype "CVS"
  } elseif {$insvn} {
    set rtype "SVN"
  } elseif {$ingit} {
    set rtype "GIT"
  }
  gen_log:log D "Directory Type: $rtype"
  #gen_log:log D "sortcol=$sortcol  sortsense=$sortsense"

  set AllColumns {}
  foreach k [array names DirList $w:*:name] {
    set key $DirList($k)
    set DirList($w:$k:allcolumns) [list $key $DirList($w:$key:status) \
      $DirList($w:$key:date) $DirList($w:$key:sticky) $DirList($w:$key:editors)]
    lappend AllColumns $DirList($w:$k:allcolumns)
  }

  set itemlist {}
  # Always sort by name first
  set sortedlist [lsort $sortsense -index 0 $AllColumns]
  switch -- $sortcol {
   "filecol" {
    # Only by name
   }
   "statcol" {
    set sortedlist [lsort $sortsense -index 1 $sortedlist]
   }
   "datecol" {
    set sortedlist [lsort $sortsense -index 2 $sortedlist]
   }
   "wrevcol" {
    set sortedlist [lsort -dictionary $sortsense -index 3 $sortedlist]
   }
   "editcol" {
    set sortedlist [lsort $sortsense -index 4 $sortedlist]
   }
  }

  # Create items.
  foreach item $sortedlist {
    set f [lindex $item 0]
    set flen [string length $f]
    if {$flen > $maxlbl} {
      set maxlbl $flen
      set longlbl $f
    }
    incr y -$yincr
    set lblfg $cvsglb(fg)

    # Up-to-date
    #  The file is identical with the latest revision in the repository for the
    #    branch in use
    # Locally Modified
    #  You have edited the file, and not yet committed your changes.
    # Locally Added
    #  You have added the file with add, and not yet committed your changes.
    # Locally Removed
    #  You have removed the file with remove, and not yet committed your changes
    # Needs Checkout
    #  Someone else has committed a newer revision to the repository. The name
    #    is slightly misleading; you will ordinarily use update rather than
    #    checkout to get that newer revision.
    # Needs Patch
    #  Like Needs Checkout, but the CVS server will send a patch rather than the
    #    entire file. Sending a patch or sending an entire file accomplishes
    #    the same thing.
    # Needs Merge
    #  Someone else has committed a newer revision to the repository, and you
    #    have also made modifications to the file.
    # Unresolved Conflict
    #  This is like Locally Modified, except that a previous update command gave
    #    a conflict. You need to resolve the conflict as described in section
    #    Conflicts example.
    # Unknown
    #  CVS doesn't know anything about this file. For example, you have created
    #     a new file and have not run add.

    switch -glob -- $DirList($w:$f:status) {
     "<file>" {
       set DirList($w:$f:icon) paper
       set DirList($w:$f:popup) paper_pop
      }
     "<dir> " {
       set DirList($w:$f:icon) folder
       set DirList($w:$f:popup) svndir_pop
     }
     "<dir> Up-to-date" {
       set DirList($w:$f:icon) dir_ok
       set DirList($w:$f:popup) svndir_pop
     }
     "<dir> Not managed*" {
       set DirList($w:$f:icon) dir
       set DirList($w:$f:popup) svndir_pop
     }
     "<dir> Locally Added" {
       set DirList($w:$f:icon) dir_plus
       set DirList($w:$f:popup) svndir_pop
     }
     "<dir> Locally Removed" {
       set DirList($w:$f:icon) dir_minus
       set DirList($w:$f:popup) svndir_pop
     }
     "<link> " {
	 set DirList($w:$f:icon) link
	 set DirList($w:$f:popup) paper_pop
     }
     "<link> Not managed by SVN" {
	 set DirList($w:$f:icon) link
	 set DirList($w:$f:popup) paper_pop
     }
     "<link> Up-to-date" {
	 set DirList($w:$f:icon) link_ok
	 set DirList($w:$f:popup) stat_svnok_pop
     }
     "<link> Up-to-date/Locked" {
	 set DirList($w:$f:icon) link_okol
	 set DirList($w:$f:popup) stat_svnok_pop
     }
     "<link> Up-to-date/HaveLock" {
	 set DirList($w:$f:icon) link_okml
	 set DirList($w:$f:popup) stat_svnok_pop
     }
     "<link> Locally Modified" {
	 set DirList($w:$f:icon) link_mod
	 set DirList($w:$f:popup) stat_svnok_pop
     }
     "<link> Locally Modified/Locked" {
	 set DirList($w:$f:icon) link_modol
	 set DirList($w:$f:popup) stat_svnok_pop
     }
     "<link> Locally Modified/HaveLock" {
	 set DirList($w:$f:icon) link_modml
	 set DirList($w:$f:popup) stat_svnok_pop
     }
     "<link> Locally Added" {
	 set DirList($w:$f:icon) link_plus
	 set DirList($w:$f:popup) stat_svnok_pop
     }
     "<directory>" {
       set DirList($w:$f:icon) folder
       switch -- $rtype {
         "CVS" {
            set DirList($w:$f:popup) incvs_folder_pop
          }
          default {
            set DirList($w:$f:popup) folder_pop
          }
        }
      }
     "<directory:???>" {
       regexp {<directory:(...)>} $DirList($w:$f:status) null vcs
       set DirList($w:$f:icon) folder
       set DirList($w:$f:popup) folder_pop
       # What VCS controls the folder? Determines the icon
       switch -- $vcs {
         "CVS" {
            set DirList($w:$f:icon) cvsdir
            set DirList($w:$f:popup) cvsrelease_pop
          }
         "SVN" {
            set DirList($w:$f:icon) svndir
          }
         "GIT" {
            set DirList($w:$f:icon) gitdir
          }
         "RCS" {
            set DirList($w:$f:icon) rcsdir
          }
       }
       # Are we in that VCS now? Determines the popop menu
       switch -- $rtype {
         "CVS" {
            set DirList($w:$f:popup) cvsdir_pop
          }
         "SVN" {
            set DirList($w:$f:popup) svndir_pop
          }
         "GIT" {
            set DirList($w:$f:popup) gitdir_pop
          }
         "RCS" {
            set DirList($w:$f:popup) folder_pop
          }
        }
      }
     "Up-to-date" {
       set DirList($w:$f:icon) stat_ok
       switch -- $rtype {
          "CVS" {
            set DirList($w:$f:popup) stat_cvsok_pop
            if {[string match "*-kb*" $DirList($w:$f:option)]} {
              set DirList($w:$f:icon) stat_kb
            }
          }
          "SVN" {
            set DirList($w:$f:popup) stat_svnok_pop
          }
          "GIT" {
            set DirList($w:$f:popup) stat_gitok_pop
          }
          default {
            set DirList($w:$f:popup) paper_pop
          }
        }
      }
     "Up-to-date/HaveLock" {
       set DirList($w:$f:icon) stat_okml
       set DirList($w:$f:popup) stat_svnok_pop
     }
     "Up-to-date/Locked" {
       set DirList($w:$f:icon) stat_okol
       set DirList($w:$f:popup) stat_svnok_pop
     }
     "Missing*" {
        set DirList($w:$f:icon) stat_ex
       switch -- $rtype {
          "CVS" {
            set DirList($w:$f:popup) stat_cvsood_pop
          }
          "SVN" {
            set DirList($w:$f:popup) stat_svnood_pop
          }
        }
      }
     "Needs Checkout" {
       # Prepending ./ to the filename prevents tilde expansion
       if {[file exists ./$f]} {
         set DirList($w:$f:icon) stat_ood
        } else {
         set DirList($w:$f:icon) stat_ex
        }
        set DirList($w:$f:popup) stat_cvsood_pop
      }
      "Needs Patch" {
       set DirList($w:$f:icon) stat_ood
       set DirList($w:$f:popup) stat_cvsood_pop
      }
      "<dir> Out-of-date" {
       set DirList($w:$f:icon) dir_ood
       switch -- $rtype {
          "CVS" {
            set DirList($w:$f:popup) stat_cvsood_pop
          }
          "SVN" {
            set DirList($w:$f:popup) stat_svnood_pop
          }
          "GIT" {
            set DirList($w:$f:popup) stat_gitood_pop
          }
        }
      }
      "Out-of-date" {
       set DirList($w:$f:icon) stat_ood
       switch -- $rtype {
          "CVS" {
            set DirList($w:$f:popup) stat_cvsood_pop
          }
          "SVN" {
            set DirList($w:$f:popup) stat_svnood_pop
          }
          "GIT" {
            set DirList($w:$f:popup) stat_gitood_pop
          }
        }
      }
      "Needs Merge" {
       set DirList($w:$f:icon) stat_merge
       set DirList($w:$f:popup) stat_merge_pop
      }
      "Locally Modified" {
       set DirList($w:$f:icon) stat_mod
       switch -- $rtype {
          "CVS" {
             set DirList($w:$f:popup) stat_cvsmod_pop
          }
          "SVN" {
             set DirList($w:$f:popup) stat_svnmod_pop
          }
        }
      }
      "Locally Modified/HaveLock" {
       set DirList($w:$f:icon) stat_modml
       set DirList($w:$f:popup) stat_cvsmod_pop
      }
      "Locally Modified/Locked" {
       set DirList($w:$f:icon) stat_modol
       set DirList($w:$f:popup) stat_cvsmod_pop
      }
       "Locally Added" {
       set DirList($w:$f:icon) stat_plus
       switch -- $rtype {
          "CVS" {
             if {[string match "*-kb*" $DirList($w:$f:option)]} {
               set DirList($w:$f:icon) stat_cvsplus_kb
             }
             set DirList($w:$f:popup) stat_cvsplus_pop
          }
          "SVN" {
             set DirList($w:$f:popup) stat_svnplus_pop
          }
        }
      }
      "Added" {
       set DirList($w:$f:icon) stat_plus
       set DirList($w:$f:popup) stat_gitplus_pop
      }
      "Added, missing" {
       set DirList($w:$f:icon) stat_ex
       set DirList($w:$f:popup) stat_gitplus_pop
      }
      "Modified, unstaged" {
       set DirList($w:$f:icon) stat_mod_red
       set DirList($w:$f:popup) stat_gitmod_pop
      }
      "Modified, staged" {
       set DirList($w:$f:icon) stat_mod_green
       set DirList($w:$f:popup) stat_gitmod_pop
      }
      "Removed" {
       set DirList($w:$f:icon) stat_minus
       set DirList($w:$f:popup) stat_gitminus_pop
      }
      "Locally Removed" {
       set DirList($w:$f:icon) stat_minus
       switch -- $rtype {
          "CVS" {
             set DirList($w:$f:popup) stat_cvsminus_pop
          }
          "SVN" {
             set DirList($w:$f:popup) stat_svnminus_pop
          }
          "GIT" {
             set DirList($w:$f:popup) stat_gitminus_pop
          }
       }
      }
      "*onflict*" {
       set DirList($w:$f:icon) stat_conf
       switch -- $rtype {
          "CVS" {
            set DirList($w:$f:popup) cvs_conf_pop
          }
          "SVN" {
            set DirList($w:$f:popup) svn_conf_pop
          }
          "GIT" {
            set DirList($w:$f:popup) git_conf_pop
          }
        }
      }
      "Not managed*" {
       set DirList($w:$f:icon) stat_ques
       set DirList($w:$f:popup) stat_local_pop
      }
      "RCS Up-to-date" {
       set DirList($w:$f:icon) stat_ok
       set DirList($w:$f:popup) rcs_pop
      }
      "RCS Up-to-date/HaveLock" {
       set DirList($w:$f:icon) stat_okml
       set DirList($w:$f:popup) rcs_pop
      }
      "RCS Up-to-date/Locked" {
       set DirList($w:$f:icon) stat_okol
       set DirList($w:$f:popup) rcs_pop
      }
      "RCS Modified" {
       set DirList($w:$f:icon) stat_mod
       set DirList($w:$f:popup) rcs_pop
      }
      "RCS Modified/HaveLock" {
       set DirList($w:$f:icon) stat_modml
       set DirList($w:$f:popup) rcs_pop
      }
      "RCS Modified/Locked" {
       set DirList($w:$f:icon) stat_modol
       set DirList($w:$f:popup) rcs_pop
      }
      "RCS Needs Checkout" {
       set DirList($w:$f:icon) stat_ex
       set DirList($w:$f:popup) rcs_pop
      }
      default {
       set DirList($w:$f:icon) paper
       set DirList($w:$f:popup) paper_pop
      }
    }

    # Easy way to unselect everything by clicking in a blank area
    bind $w.filecol.list <1> "DirCanvas:unselectall $w 0"
    bind $w.filecol.list <Shift-1> " "
    # For columns except filecol, this breaks selecting the text item.  Why??
    #bind $w.datecol.list <1> "DirCanvas:unselectall $w 0"

    # In the bindings, filenames need any single percents replaced with
    # double to avoid interpretation as an event field
    regsub -all {\%} $f {%%} fn
    regsub -all {\$} $fn {\$} fn

    # Draw the icon
    set k [$w.filecol.list create image $x $y -image $DirList($w:$f:icon) \
      -anchor w -tags [list $y] ]
    $w.filecol.list bind $k <1> "DirCanvas:setselection $w $y \"$fn\""
    $w.filecol.list bind $k <Shift-1> "DirCanvas:addrange $w $y \"$fn\""
    $w.filecol.list bind $k <Control-1> "DirCanvas:addselection $w $y \"$fn\""
    $w.filecol.list bind $k <Double-1> {workdir_edit_file [workdir_list_files]}

    # Draw the label
    $w.filecol.list create text $lblx $y  -text $f -font $cvscfg(listboxfont) \
      -anchor w -tags [list $w.filecol.list.tx$y $y $fn] -fill $lblfg
    $w.filecol.list bind $w.filecol.list.tx$y <1> "DirCanvas:setselection $w $y \"$fn\""
    $w.filecol.list bind $w.filecol.list.tx$y <Shift-1> "DirCanvas:addrange $w $y \"$fn\""
    $w.filecol.list bind $w.filecol.list.tx$y <Enter> "DirCanvas:flash $w $y"
    $w.filecol.list bind $w.filecol.list.tx$y <Leave> "DirCanvas:unflash $w $y"
    $w.filecol.list bind $w.filecol.list.tx$y <Control-1> "DirCanvas:addselection $w $y \"$fn\""
    $w.filecol.list bind $w.filecol.list.tx$y <Double-1> {workdir_edit_file [workdir_list_files]}
    $w.filecol.list bind $w.filecol.list.tx$y <2> " DirCanvas:popup $w.filecol.list $y %X %Y \"$fn\""
    $w.filecol.list bind $w.filecol.list.tx$y <3> " DirCanvas:popup $w.filecol.list $y %X %Y \"$fn\""

    set DirList($w:$f:y) $y
    set DirList($w.filecol.list:$y) $f

    set status $DirList($w:$f:status)
    set k [$w.statcol.list create text 8 $y -text $status \
      -font $cvscfg(listboxfont) -fill $cvsglb(fg) -anchor w \
      -tags [list $w.filecol.list.tx$y $y $fn]]
    $w.statcol.list bind $k <1> "DirCanvas:setselection $w $y \"$fn\""
    $w.statcol.list bind $k <Shift-1> "DirCanvas:addrange $w $y \"$fn\""
    $w.statcol.list bind $k <Enter> "DirCanvas:flash $w $y"
    $w.statcol.list bind $k <Leave> "DirCanvas:unflash $w $y"
    $w.statcol.list bind $k <Control-1> "DirCanvas:addselection $w $y \"$fn\""
    set slen [string length $status]
    if {$slen > $maxstat} {
      set maxstat $slen
      set longstat $status
    }

    set date $DirList($w:$f:date)
    set k [$w.datecol.list create text 4 $y -text $date \
      -font $cvscfg(listboxfont) -fill $cvsglb(fg) -anchor w \
      -tags [list $w.filecol.list.tx$y $y $fn]]
    $w.datecol.list bind $k <1> "DirCanvas:setselection $w $y \"$fn\""
    $w.datecol.list bind $k <Shift-1> "DirCanvas:addrange $w $y \"$fn\""
    $w.datecol.list bind $k <Enter> "DirCanvas:flash $w $y"
    $w.datecol.list bind $k <Leave> "DirCanvas:unflash $w $y"
    $w.datecol.list bind $k <Control-1> "DirCanvas:addselection $w $y \"$fn\""
    set dlen [string length $date]
    if {$dlen > $maxdate} {
      set maxdate $dlen
      set longdate $date
    }

    if {[info exists DirList($w:$f:sticky)]} {
      set tag $DirList($w:$f:sticky)
      set k [$w.wrevcol.list create text 4 $y -text $tag \
        -font $cvscfg(listboxfont) -fill $cvsglb(fg) -anchor w \
        -tags [list $w.filecol.list.tx$y $y $fn]]
      $w.wrevcol.list bind $k <1> "DirCanvas:setselection $w $y \"$fn\""
      $w.wrevcol.list bind $k <Shift-1> "DirCanvas:addrange $w $y \"$fn\""
      $w.wrevcol.list bind $k <Enter> "DirCanvas:flash $w $y"
      $w.wrevcol.list bind $k <Leave> "DirCanvas:unflash $w $y"
      $w.wrevcol.list bind $k <Control-1> "DirCanvas:addselection $w $y \"$fn\""
      set tlen [string length $tag]
      if {$tlen > $maxtag} {
        set maxtag $tlen
        set longtag $tag
      }
    }

    set editors $DirList($w:$f:editors)
    set k [$w.editcol.list create text 4 $y -text $editors \
      -font $cvscfg(listboxfont) -fill $cvsglb(fg) -anchor w \
      -tags [list $w.filecol.list.tx$y $y $fn]]
    $w.editcol.list bind $k <1> "DirCanvas:setselection $w $y \"$fn\""
    $w.editcol.list bind $k <Shift-1> "DirCanvas:addrange $w $y \"$fn\""
    $w.editcol.list bind $k <Enter> "DirCanvas:flash $w $y"
    $w.editcol.list bind $k <Leave> "DirCanvas:unflash $w $y"
    $w.editcol.list bind $k <Control-1> "DirCanvas:addselection $w $y \"$fn\""
    set edlen [string length $editors]
    if {$edlen > $maxed} {
      set maxed $edlen
      set longed $editors
    }
  }

  # Set a minimum width for the labels.  Otherwise ".." can be hard to select.
  set minlabel 6
  foreach labl [$w.filecol.list find withtag lbl] {
    set itags [$w.filecol.list gettags $labl]
    set iy [lindex $itags 1]
    if {[string length $DirList($w.filecol.list:$iy)] < $minlabel} {
      $w.filecol.list.tx$iy configure -width $minlabel
    }
  }

  # Scroll to the top of the lists
  set fbbox [$w.filecol.list bbox all]
  #gen_log:log D "fbbox   \"$fbbox\""
  if {[llength $fbbox] == 4} {
    set ylen [expr {[lindex $fbbox 3] - [lindex $fbbox 1]}]

    set wview [winfo height $w.filecol.list]
    $w.yscroll set 0 [expr ($wview * 1.0) / ($ylen * 1.0)]
    update idletasks

    $w.filecol.list config -scrollregion $fbbox
    $w.filecol.list yview moveto 0

    if {$cvscfg(showdatecol)} {
      $w.datecol.list config -scrollregion [$w.datecol.list bbox all]
      $w.datecol.list yview moveto 0
    }

    if {$incvs || $insvn || $inrcs || $ingit} {
      $w.wrevcol.list config -scrollregion [$w.wrevcol.list bbox all]
      $w.wrevcol.list yview moveto 0

      if {$cvscfg(showstatcol)} {
        $w.statcol.list config -scrollregion [$w.statcol.list bbox all]
        $w.statcol.list yview moveto 0
      }

      if {$cvscfg(showeditcol)} {
        $w.editcol.list config -scrollregion [$w.editcol.list bbox all]
        $w.editcol.list yview moveto 0
      }
    }
  }
  #gen_log:log D "[array names DirList $w:*:selected]"
  gen_log:log T "LEAVE"
}

# Internal use only
# Call DirCanvas:build the next time we're idle
proc DirCanvas:buildwhenidle {w} {
  global DirList

  if {![info exists DirList($w:buildpending)]} {
    set DirList($w:buildpending) 1
    after idle "DirCanvas:build $w"
  }
}

# For restoring the scroll positions after re-scanning the directory
proc DirCanvas:yview_windows {w yview} {
  global cvscfg

  gen_log:log T "ENTER YVIEW $yview"
  eval $w.filecol.list yview moveto $yview
  if {[winfo exists  $w.datecol.list]} {
    eval $w.datecol.list yview moveto $yview
  }
  if {[winfo exists $w.revcol.list]} {
    eval $w.wrevcol.list yview moveto $yview
  }
  if {[winfo exists $w.statcol.list]} {
    eval $w.statcol.list yview moveto $yview
  }
  if {[winfo exists $w.editcol.list]} {
    eval $w.editcol.list yview moveto $yview
  }
}

proc DirCanvas:scroll_windows {w args} {
  global cvscfg
  global incvs insvn inrcs ingit

  #gen_log:log T "ENTER ($w $args)"
  set way [lindex $args 1]
  set units [lindex $args 2]
  set yget [$w.yscroll get]
  set first [lindex $yget 0]
  set last [lindex $yget 1]

  eval $w.filecol.list yview $args
  if {$cvscfg(showdatecol)} {
    eval $w.datecol.list yview $args
  }
  if {$incvs || $insvn || $inrcs || $ingit} {
    eval $w.wrevcol.list yview $args
    if {$cvscfg(showstatcol)} {
      eval $w.statcol.list yview $args
    }
    if {$cvscfg(showeditcol)} {
      eval $w.editcol.list yview $args
    }
  }
}

proc DirCanvas:drag_windows {w W y} {
#Scrolling caused by dragging
  global cvscfg
  global cvsglb
  global incvs insvn inrcs ingit

  set height [$W cget -height]
  #gen_log:log D "$w %y $height"
  if {$y < 0} {set y 0}
  if {$y > $height} {set y $height}
  set yfrac [expr {double($y) / $height}]

  eval $w.filecol.list yview moveto $yfrac
  if {$cvscfg(showdatecol)} {
    eval $w.datecol.list yview moveto $yfrac
  }
  if {$incvs || $insvn || $inrcs || $ingit} {
    eval $w.wrevcol.list yview moveto $yfrac
    if {$cvscfg(showstatcol)} {
      eval $w.statcol.list yview moveto $yfrac
    }
    if {$cvscfg(showeditcol)} {
      eval $w.editcol.list yview moveto $yfrac
    }
  }
}

proc DirCanvas:sort_by_col {w col sense} {
  global DirList
  global cvscfg
  global arr

  gen_log:log T "ENTER ($w $col $sense)"
  foreach a [array names arr] {
    catch "$arr($a) configure -image arr_dn"
  }
  set cvscfg(sort_pref) [list $col $sense]

  if {[string match "-inc*" $sense]} {
    gen_log:log D "sort column $col -increasing"
    $arr($col) configure -image arh_up
    if {$col == "statcol"} {$arr(filestatcol) configure -image arh_up}
  } else {
    gen_log:log D "sort column $col -decreasing"
    $arr($col) configure -image arh_dn
    if {$col == "statcol"} {$arr(filestatcol) configure -image arh_dn}
  }
  if {$col != "statcol"} {
    $arr(filestatcol) configure -image arr_dn
  }

  DirCanvas:build $w
  gen_log:log T "LEAVE"
}

proc DirCanvas:toggle_col {w col} {
  global cvscfg

  gen_log:log T "ENTER ($col)"
  set cur_col [lindex $cvscfg(sort_pref) 0]
  set cur_sense [lindex $cvscfg(sort_pref) 1]

  if {$col == $cur_col} {
    # if it's the currently sorted column, reverse the direction.
    if {[string match "-incr*" $cur_sense]} {
      set sense "-decreasing"
    } else {
      set sense "-increasing"
    }
  } else {
    # Otherwise, default to decreasing (down)
    set sense "-decreasing"
  }

  gen_log:log D "sort column $col $sense"
  DirCanvas:sort_by_col $w $col $sense

  gen_log:log T "LEAVE"
}

# Context-sensitive popups for list items
# We build them all at once here, then bind canvas items to them as appropriate
proc DirCanvas:makepopup {w} {
  gen_log:log T "ENTER ($w)"

  # For plain files in an un-versioned directory
  menu $w.paper_pop
  $w.paper_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.paper_pop add command -label "Delete" \
    -command { workdir_delete_file [workdir_list_files] }

  # For plain directories in an un-versioned directory
  menu $w.folder_pop
  $w.folder_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.folder_pop add command -label "Delete" \
    -command { workdir_delete_file [workdir_list_files] }

  # For plain, unmanaged files in a versioned directory
  menu $w.stat_local_pop
  $w.stat_local_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_local_pop add command -label "Delete" \
    -command { workdir_delete_file [workdir_list_files] }
  $w.stat_local_pop add command -label "Add" \
    -command { add_dialog [workdir_list_files] }

  # For CVS directories when cwd isn't in CVS
  menu $w.cvsrelease_pop
  $w.cvsrelease_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.cvsrelease_pop add command -label "CVS Release" \
    -command { release_dialog [workdir_list_files] }

  # For plain directories in CVS
  menu $w.incvs_folder_pop
  $w.incvs_folder_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.incvs_folder_pop add command -label "CVS Add Recursively" \
    -command { addir_dialog [workdir_list_files] }
  $w.incvs_folder_pop add command -label "Delete" \
    -command { workdir_delete_file [workdir_list_files] }

  # For CVS subdirectories
  menu $w.cvsdir_pop
  $w.cvsdir_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.cvsdir_pop add command -label "CVS Remove Recursively" \
    -command { subtractdir_dialog [workdir_list_files] }

  # For SVN subdirectories
  menu $w.svndir_pop
  $w.svndir_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.svndir_pop add command -label "SVN Log" \
    -command { svn_log $cvscfg(ldetail) [workdir_list_files] }
  $w.svndir_pop add command -label "SVN Info" \
    -command { svn_info [workdir_list_files] }
  $w.svndir_pop add command -label "Browse the Log Diagram" \
    -command { svn_branches [workdir_list_files] }
  $w.svndir_pop add command -label "SVN Remove" \
    -command { subtract_dialog [workdir_list_files] }

  # For Git subdirectories
  menu $w.gitdir_pop
  $w.gitdir_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.gitdir_pop add command -label "Git Remove Recursively" \
    -command { subtractdir_dialog [workdir_list_files] }

  # For RCS files
  menu $w.rcs_pop
  $w.rcs_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.rcs_pop add command -label "Browse the Log Diagram" \
    -command { rcs_branches [workdir_list_files] }
  $w.rcs_pop add command -label "RCS Lock" \
    -command { rcs_lock lock [workdir_list_files] }
  $w.rcs_pop add command -label "RCS Unlock" \
    -command { rcs_lock unlock [workdir_list_files] }
  $w.rcs_pop add command -label "RCS Revert" \
    -command { rcs_revert [workdir_list_files] }
  $w.rcs_pop add command -label "Delete Locally" \
    -command { workdir_delete_file [workdir_list_files] }

  # For CVS files
  menu $w.stat_cvsok_pop
  $w.stat_cvsok_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "CVS Log" \
    -command { cvs_log $cvscfg(ldetail) [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "Browse the Log Diagram" \
    -command { cvs_branches [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "CVS Annotate/Blame" \
    -command { cvs_annotate $current_tagname [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "CVS Remove" \
    -command { subtract_dialog [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "Set Edit Flag" \
     -command { cvs_edit [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "Unset Edit Flag" \
     -command { cvs_unedit [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "Set Binary Flag" \
     -command { cvs_binary [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "Unset Binary Flag" \
     -command { cvs_ascii [workdir_list_files] }

  # For SVN files
  menu $w.stat_svnok_pop
  $w.stat_svnok_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_svnok_pop add command -label "SVN Log" \
    -command { svn_log $cvscfg(ldetail) [workdir_list_files] }
  $w.stat_svnok_pop add command -label "SVN Info" \
    -command { svn_info [workdir_list_files] }
  $w.stat_svnok_pop add command -label "Browse the Log Diagram" \
    -command { svn_branches [workdir_list_files] }
  $w.stat_svnok_pop add command -label "SVN Annotate/Blame" \
    -command { svn_annotate "" [workdir_list_files] }
  $w.stat_svnok_pop add command -label "SVN Rename" \
    -command { svn_rename_ask [workdir_list_files] }
  $w.stat_svnok_pop add command -label "SVN Remove" \
    -command { subtract_dialog [workdir_list_files] }

  # For Git files
  menu $w.stat_gitok_pop
  $w.stat_gitok_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_gitok_pop add command -label "Git Log" \
    -command { git_log $cvscfg(ldetail) [workdir_list_files] }
  $w.stat_gitok_pop add command -label "Browse the Log Diagram" \
    -command { git_branches [workdir_list_files] }
  $w.stat_gitok_pop add command -label "Git Annotate/Blame" \
    -command { git_annotate "" [workdir_list_files] }
  $w.stat_gitok_pop add command -label "Git Rename" \
    -command { git_rename_ask [workdir_list_files] }
  $w.stat_gitok_pop add command -label "Git Remove" \
    -command { subtract_dialog [workdir_list_files] }

  # For CVS files that are out of date
  menu $w.stat_cvsood_pop
  $w.stat_cvsood_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_cvsood_pop add command -label "Update" \
    -command { \
        cvs_update {BASE} {Normal} {Remove} {recurse} {prune} {No} { } [workdir_list_files] }
  $w.stat_cvsood_pop add command -label "Update with Options" \
    -command cvs_update_options

  # For SVN files that are out of date
  menu $w.stat_svnood_pop
  $w.stat_svnood_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_svnood_pop add command -label "Update" \
    -command { svn_update [workdir_list_files] }

  # For Git files that are out of date
  menu $w.stat_gitood_pop
  $w.stat_gitood_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_gitood_pop add command -label "Update" \
    -command { git_checkout [workdir_list_files] }

  # For CVS files that need merging
  menu $w.stat_merge_pop
  $w.stat_merge_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_merge_pop add command -label "Diff" \
    -command { comparediff [workdir_list_files] }
  $w.stat_merge_pop add command -label "CVS Annotate/Blame" \
    -command { cvs_annotate $current_tagname [workdir_list_files] }
  $w.stat_merge_pop add command -label "Browse the Log Diagram" \
    -command { cvs_branches [workdir_list_files] }

  # For CVS files that are modified
  menu $w.stat_cvsmod_pop
  $w.stat_cvsmod_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_cvsmod_pop add command -label "Diff" \
    -command { comparediff [workdir_list_files] }
  $w.stat_cvsmod_pop add command -label "CVS Commit" \
    -command { cvs_commit_dialog }
  $w.stat_cvsmod_pop add command -label "CVS Revert" \
    -command { cvs_revert [workdir_list_files] }

  # For SVN files that are modified
  menu $w.stat_svnmod_pop
  $w.stat_svnmod_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_svnmod_pop add command -label "Diff" \
    -command { comparediff [workdir_list_files] }
  $w.stat_svnmod_pop add command -label "SVN Commit" \
    -command { svn_commit_dialog }
  $w.stat_svnmod_pop add command -label "SVN Revert" \
    -command { svn_revert [workdir_list_files] }

  # For Git files that are modified
  menu $w.stat_gitmod_pop
  $w.stat_gitmod_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_gitmod_pop add command -label "Diff" \
    -command { comparediff [workdir_list_files] }
  $w.stat_gitmod_pop add command -label "Git Commit" \
    -command { git_commit_dialog }
  #$w.stat_gitmod_pop add command -label "Git Reset (Revert)" \
    -command { git_reset [workdir_list_files] }

  # For CVS files that have been added but not commited
  menu $w.stat_cvsplus_pop
  $w.stat_cvsplus_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_cvsplus_pop add command -label "CVS Commit" \
    -command { cvs_commit_dialog }

  # For SVN files that have been added but not commited
  menu $w.stat_svnplus_pop
  $w.stat_svnplus_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_svnplus_pop add command -label "SVN Commit" \
    -command { svn_commit_dialog }

  # For Git files that have been added but not commited
  menu $w.stat_gitplus_pop
  $w.stat_gitplus_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_gitplus_pop add command -label "Git Commit" \
    -command { git_commit_dialog }

  # For CVS files that have been removed but not commited
  menu $w.stat_cvsminus_pop
  $w.stat_cvsminus_pop add command -label "CVS Commit" \
    -command { cvs_commit_dialog }

  # For SVN files that have been removed but not commited
  menu $w.stat_svnminus_pop
  $w.stat_svnminus_pop add command -label "SVN Commit" \
    -command { svn_commit_dialog }

  # For Git files that have been removed but not commited
  menu $w.stat_gitminus_pop
  $w.stat_gitminus_pop add command -label "Git Commit" \
    -command { git_commit_dialog }

  # For CVS unmanaged files
  menu $w.stat_cvslocal_pop
  $w.stat_cvslocal_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_cvslocal_pop add command -label "Delete" \
    -command { workdir_delete_file [workdir_list_files] }
  $w.stat_cvslocal_pop add command -label "CVS Add" \
    -command { cvs_add [workdir_list_files] }

  # For CVS files with conflicts
  menu $w.cvs_conf_pop
  $w.cvs_conf_pop add command -label "Merge using TkDiff" \
    -command { cvs_merge_conflict [workdir_list_files] }
  $w.cvs_conf_pop add command -label "CVS Annotate/Blame" \
    -command { cvs_annotate $current_tagname [workdir_list_files] }
  $w.cvs_conf_pop add command -label "Browse the Log Diagram" \
    -command { cvs_branches [workdir_list_files] }

  # For SVN files with conflicts
  menu $w.svn_conf_pop
  $w.svn_conf_pop add command -label "Merge using TkDiff" \
    -command { svn_merge_conflict [workdir_list_files] }
  $w.svn_conf_pop add command -label "Mark resolved" \
    -command { svn_resolve [workdir_list_files] }
  $w.svn_conf_pop add command -label "CVS Annotate/Blame" \
    -command { svn_annotate $current_tagname [workdir_list_files] }
  $w.svn_conf_pop add command -label "Browse the Log Diagram" \
    -command { svn_branches [workdir_list_files] }

  # For Git files with conflicts
  menu $w.git_conf_pop
  $w.git_conf_pop add command -label "Merge using TkDiff" \
    -command { git_merge_conflict [workdir_list_files] }
  $w.git_conf_pop add command -label "Stage resolved conflict" \
    -command { git_add [workdir_list_files] }

  gen_log:log T "LEAVE"
}

proc DirCanvas:popup {w y X Y f} {
  global DirList

  gen_log:log T "ENTER ($w $y $X $Y $f)"
  set parent [winfo parent [winfo parent $w]]
  DirCanvas:setselection $parent $y $f
  tk_popup $parent.$DirList($parent:$f:popup) $X $Y
  gen_log:log T "LEAVE"
}

proc DirCanvas:destroy {w} {
  foreach u [winfo children $w] {
    catch {destroy $u}
  }
}


