#
# Columns for listing CVS files and their status
#

proc DirCanvas:create {w args} {
  global cvscfg
  global cvsglb
  global arr
  global incvs
  global insvn
  global inrcs

  gen_log:log T "ENTER ($w $args)"

  if {[catch "image type folder"]} {
    DirCanvas:loadimages
  }

  frame $w.filecol -relief sunken -bd 2
  frame $w.statcol -relief sunken -bd 2
  frame $w.datecol -relief sunken -bd 2
  frame $w.wrevcol -relief sunken -bd 2
  frame $w.editcol -relief sunken -bd 2

  eval canvas $w.filecol.list $args
  eval canvas $w.statcol.list $args
  eval canvas $w.datecol.list $args
  eval canvas $w.wrevcol.list $args
  eval canvas $w.editcol.list $args
  scrollbar $w.yscroll -orient vertical -command "DirCanvas:scroll_windows $w" \
    -highlightthickness 0

  pack $w.yscroll -side right -fill y

  set cvsglb(fmbg) [lindex [$w.filecol configure -background] 4]
  if {[winfo exists .workdir]} {
    set cvsglb(fg) [lindex [.workdir.top.bmodbrowse configure -foreground] 4]
    set cvsglb(dfg) [lindex [.workdir.top.bmodbrowse configure -disabledforeground] 4]
    set buttonhilite [lindex [.workdir.top.bmodbrowse configure -highlightbackground] 4]
  }
  #set cvsglb(canvbg) [lindex [$w.filecol.list configure -background] 4]
  set selcolor [option get . selectColor selectColor]
  if {[string length $selcolor]} {
    set cvsglb(hlbg) $selcolor
  }
  if {$cvsglb(hlbg) == $cvsglb(canvbg)} {
    set cvsglb(hlbg) $buttonhilite
  }
  if {! [info exists cvsglb(glb_highlight)]} {
    set cvsglb(glb_highlight) $cvsglb(hlbg)
  }

  DirCanvas:column $w filecol "file"
  DirCanvas:column $w statcol "status"
  DirCanvas:column $w datecol "date"
  gen_log:log D "incvs=$incvs insvn=$insvn inrcs=$inrcs"
  if {$incvs || $insvn || $inrcs} {
    gen_log:log D "**** going to make wrevcol ****"
    DirCanvas:column $w wrevcol "revision"
    DirCanvas:column $w editcol "editors"
  }

  # Put an extra arrow on the file column for sorting by status
  set statusbutton $w.filecol.head.statbut
  button $statusbutton -image arr_dn -bg $cvsglb(fmbg) \
    -relief raised -bd 1 -highlightthickness 0
  set arr(filestatcol) $statusbutton
  pack $statusbutton -side left
  bind $statusbutton <ButtonPress-1> \
    "DirCanvas:toggle_col $w statcol"
  bind $statusbutton <ButtonPress-2> \
    "DirCanvas:sort_by_col $w statcol -decreasing"
  bind $statusbutton <ButtonPress-3> \
    "DirCanvas:sort_by_col $w statcol -increasing"

  gen_log:log D "sort_pref:  $cvsglb(sort_pref)"
  set col [lindex $cvsglb(sort_pref) 0]
  set sense [lindex $cvsglb(sort_pref) 1]
  gen_log:log D "$incvs  $col"
  if { (! ($incvs || $inrcs))  && ( $col == "editcol" || $col == "wrevcol") } {
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

proc DirCanvas:headtext {w lbltext} {
  $w.editcol.head.lbl configure -text "$lbltext"
}

proc DirCanvas:column {w column headtext} {
  global cvscfg
  global cvsglb
  global incvs
  global insvn
  global inrcs
  global arr

  #gen_log:log T "ENTER ($w $column headtext)"
  #gen_log:log T "showstatcol $cvscfg(showstatcol) showdatecol $cvscfg(showdatecol) showeditcol $cvscfg(showeditcol)"

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
    -highlightthickness 0 -bg $cvsglb(fmbg)
  set arr($column) $w.$column.head.sbut
  gen_log:log D "$w.$column.head.sbut"


  bind $w.$column.head.sbut <ButtonPress-1> "DirCanvas:toggle_col $w $column"
  bind $w.$column.head.sbut <ButtonPress-2> "DirCanvas:sort_by_col $w $column -decreasing"
  bind $w.$column.head.sbut <ButtonPress-3> "DirCanvas:sort_by_col $w $column -increasing"

  scrollbar $w.$column.xscroll -orient horizontal -width 10 \
     -command "$w.$column.list xview"
  pack $w.$column.xscroll -side bottom -fill x

  if {$column == "datecol"} {
    if {$cvscfg(showdatecol)} {
      DirCanvas:map_column $w datecol
    } else {
      gen_log:log T "LEAVE (skipping datecol)"
    }
    return
  }
  if {$column == "statcol"} {
    if {($incvs || $insvn || $inrcs) && $cvscfg(showstatcol)} {
      DirCanvas:map_column $w statcol
    } else {
      gen_log:log T "LEAVE (skipping statcol)"
    }
    return
  }
  if {$column == "editcol"} {
    if {($incvs || $insvn || $inrcs) && $cvscfg(showeditcol)} {
      DirCanvas:map_column $w editcol
    } else {
      gen_log:log T "LEAVE (skipping editcol)"
    }
    return
  }
  DirCanvas:map_column $w $column
}

proc DirCanvas:map_column {w column} {

  #gen_log:log T "ENTER ($w $column)"
  set mapped_columns [pack slaves $w]
  gen_log:log D "$mapped_columns"

  if {[lsearch -exact $mapped_columns "$w.statcol"] > -1} {
    set leftcol "$w.statcol"
  } else {
    set leftcol "$w.filecol"
  }

  if {$column == "datecol"} {
    pack $w.$column -after $leftcol -side left -fill both -expand yes
  } elseif {$column == "statcol"} {
    pack $w.$column -after $w.filecol -side left -fill both -expand yes
  } elseif {$column == "editcol"} {
    pack $w.$column -after $w.wrevcol -side left -fill both -expand yes
  } else {
    pack $w.$column -side left -fill both -expand yes
  }
  pack $w.$column.head -side top -fill x -expand no
  pack $w.$column.head.sbut -side right
  pack $w.$column.head.lbl -side right -fill x -expand yes
  pack $w.$column.list -side top -fill both -ipadx 2 -expand yes

  #gen_log:log T "LEAVE"
}

#
# Pass configuration options to the list widget
#
proc DirCanvas:config {w args} {
  gen_log:log T "ENTER ($w $args)"
  eval $w.filecol.list config $args
  eval $w.statcol config $args
  eval $w.datecol config $args
  eval $w.wrevcol config $args
  eval $w.editcol config $args
  gen_log:log T "LEAVE"
}

#
# Insert a new element $v into the list $w.
#
proc DirCanvas:newitem {w f} {
  global DirList
  global Filelist
  global cvsglb

  #gen_log:log T "ENTER ($w $f)"

  set DirList($w:$f:name) $f
  #gen_log:log D "Newitem $f status $Filelist($f:status)"
  set DirList($w:$f:status) $Filelist($f:status)
  set DirList($w:$f:date) $Filelist($f:date)
  set DirList($w:$f:sticky) $Filelist($f:stickytag)
  set DirList($w:$f:option) $Filelist($f:option)
  #gen_log:log D "Newitem $f option $Filelist($f:option)"
  # Why did I do this?
  #set DirList($w:$f:option) ""
  if { [info exists Filelist($f:editors)]} {
    set DirList($w:$f:editors) $Filelist($f:editors)
  } else {
    set DirList($w:$f:editors) ""
  }
  set DirList($w:$f:selected) 0

  DirCanvas:buildwhenidle $w
  #gen_log:log T "LEAVE"
}

proc DirCanvas:loadimages { } {
  global cvscfg

  image create photo paper \
    -format gif -file [file join $cvscfg(bitmapdir) paper.gif]
  image create photo cvsdir \
    -format gif -file [file join $cvscfg(bitmapdir) cvsdir.gif]
  image create photo svndir \
    -format gif -file [file join $cvscfg(bitmapdir) svndir.gif]
  image create photo rcsdir \
    -format gif -file [file join $cvscfg(bitmapdir) rcsdir.gif]
  image create photo folder \
    -format gif -file [file join $cvscfg(bitmapdir) folder.gif]
  image create photo dir_ok \
    -format gif -file [file join $cvscfg(bitmapdir) dir_ok.gif]
  image create photo dir_ques \
    -format gif -file [file join $cvscfg(bitmapdir) dir_ques.gif]
  image create photo dir_plus \
    -format gif -file [file join $cvscfg(bitmapdir) dir_plus.gif]
  image create photo dir_minus \
    -format gif -file [file join $cvscfg(bitmapdir) dir_minus.gif]

  image create photo stat_ques \
    -format gif -file [file join $cvscfg(bitmapdir) stat_ques.gif]
  image create photo stat_ex \
    -format gif -file [file join $cvscfg(bitmapdir) stat_ex.gif]
  image create photo stat_kb \
    -format gif -file [file join $cvscfg(bitmapdir) stat_kb.gif]
  image create photo stat_plus_kb \
    -format gif -file [file join $cvscfg(bitmapdir) stat_plus_kb.gif]
  image create photo stat_ok \
    -format gif -file [file join $cvscfg(bitmapdir) stat_ok.gif]
  image create photo stat_ood \
    -format gif -file [file join $cvscfg(bitmapdir) stat_ood.gif]
  image create photo stat_merge \
    -format gif -file [file join $cvscfg(bitmapdir) stat_merge.gif]
  image create photo stat_mod \
    -format gif -file [file join $cvscfg(bitmapdir) stat_mod.gif]
  image create photo stat_plus \
    -format gif -file [file join $cvscfg(bitmapdir) stat_plus.gif]
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

  catch {destroy $w.filecol}
  catch {destroy $w.statcol}
  catch {destroy $w.datecol}
  catch {destroy $w.wrevcol}
  catch {destroy $w.editcol}
  catch {destroy $w.yscroll}
  foreach t [array names DirList $w:*] {
    unset DirList($t)
  }
}

proc DirCanvas:flash {w y} {
  global cvsglb

  DirCanvas:setTextHBox $w $w.filecol.list.tx$y
}

proc DirCanvas:unflash {w y f} {
  global DirList
  #global cvsglb

  # Don't unflash if this is one that is selected:
  if { ! $DirList($w:$f:selected) } {
    DirCanvas:clearTextHBox $w $w.filecol.list.tx$y
    #if {! [file exists ./$f]} {
      # If a file CVS knows about doesn't exist, write its name in light ink
      #$w.filecol.list itemconfigure $w.filecol.list.tx$y -fill $cvsglb(dfg)
    #}
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

  # This seems to be necessary to enable some OS's (esp. Mandrake)
  # to get a double-click
  after 250

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
    catch {$w.filecol.list delete HBox$id}
    $w.filecol.list itemconfigure $id -fill $cvsglb(fg)
}

# set a text highligh box (used by set/clearselection)
proc DirCanvas:setTextHBox {w id} {
   global cvsglb

   # get the bounding box for the text id
   set bbox [$w.filecol.list bbox $id]
   if {[llength $bbox]==4} {
    # create rectangle with fill, tagged with the same ID as the text, so we can delete it later
    set i [eval $w.filecol.list create rectangle $bbox -fill $cvsglb(hlbg) -tag HBox$id -outline \"\"]

    $w.filecol.list itemconfigure $id -fill $cvsglb(hlfg)
    $w.filecol.list lower $i
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
        if {[lsearch -exact $DirList($w:selection) $j] == -1} {
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
        if {[lsearch -exact $DirList($w:selection) $j] == -1} {
          lappend DirList($w:selection) "$j"
        }
      }
    }
  }

  DirCanvas:setTextHBox $w $w.filecol.list.tx$y
  set DirList($w:$f:selected) 1
  if {[lsearch -exact $DirList($w:selection) $f] == -1} {
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
      # Prepending ./ to the filename prevents tilde expansion
      #if {! [file exists ./$f]} {
        # If a file CVS knows about doesn't exist, write its name in light ink
        #$w.filecol.list itemconfigure $w.filecol.list.tx$y -fill $cvsglb(dfg)
      #}
    }
    set DirList($w:selection) {}
    set cvsglb(current_selection) {}
  }
  gen_log:log T "LEAVE"
}

proc DirCanvas:areaStart {w x y} {
  global areaX1 areaY1
  global areaX2 areaY2

  gen_log:log T "ENTER ($w $x $y)"
  $w delete area
  set areaX1 [$w canvasx $x]
  set areaY1 [$w canvasy $y]
  set areaX2 $areaX1
  set areaY2 $areaY1
}

proc DirCanvas:areaStroke {w x y} {
  global areaX1 areaY1
  global areaX2 areaY2
  global cvsglb
  global cvscfg

  set x [$w canvasx $x]
  set y [$w canvasy $y]
  if {$areaY1 != $y && $areaX1 != $x} {
    $w delete area
    $w addtag area withtag \
      [$w create rect $areaX1 $areaY1 $x $y -outline $cvsglb(glb_highlight)]
    set areaX2 $x
    set areaY2 $y
  }
}

proc DirCanvas:areaFind {w} {
  global areaX1 areaY1
  global areaX2 areaY2
  global DirList

  gen_log:log T "ENTER ($w)"
  gen_log:log D "$areaX1 $areaY1 $areaX2 $areaY2"
  set items {}
  foreach i [$w find enclosed $areaX1 $areaY1 $areaX2 $areaY2] {
    lappend items $i
  }
  foreach i [$w find overlapping $areaX1 $areaY1 $areaX2 $areaY2] {
      lappend items $i
  }
  gen_log:log D "Items in area: $items"
  set parent [winfo parent [winfo parent $w]]
  foreach i $items {
    set itags [$w gettags $i]
    if { [string match .workdir* [lindex $itags 0]]  } {
      set iy [lindex $itags 1]
      gen_log:log D "$w tx$iy"
      DirCanvas:addselection $parent $iy [lindex $itags 2]
    }
  }
  $w delete area
}

# Internal use only.
# Draw the files on the canvas
proc DirCanvas:build {w} {
  global DirList
  global Filelist
  global cvscfg
  global cvsglb
  global incvs
  global insvn
  global inrcs

  gen_log:log T "ENTER ($w)"
  set flist $w.filecol.list
  foreach b [winfo children $flist] {
    destroy $b
  }
  $flist delete all
  $w.statcol.list delete all
  $w.datecol.list delete all
  $w.wrevcol.list delete all
  $w.editcol.list delete all
  catch {unset DirList($w:buildpending)}

  set x 3
  set lblx 21
  set y 20
  set imy [expr {[image height paper] + 2}]
  set fy [font metrics $cvscfg(listboxfont) -displayof $flist -linespace]
  set fy [expr {$fy + 2}]
  if {$imy > $fy} {
    set yincr $imy
    gen_log:log D "Y spacing: $y set from icon"
  } else {
    set yincr $fy
    gen_log:log D "Y spacing: $y set from font"
  }

  set maxlbl 0; set longlbl ""
  set maxstat 0; set longstat ""
  set maxdate 0; set longdate ""
  set maxtag 0; set longtag ""
  set maxed 0; set longed ""

  set sortcol [lindex $cvsglb(sort_pref) 0]
  set sortsense [lindex $cvsglb(sort_pref) 1]
  if { (!($incvs || $inrcs))  && ( $sortcol == "editcol" || $sortcol == "wrevcol") } {
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
  }
  gen_log:log D "Directory Type: $rtype"

  gen_log:log D "sortcol=$sortcol  sortsense=$sortsense"

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

    # Prepending ./ to the filename prevents tilde expansion
    #if {! [file exists ./$f]} {
      # If a file CVS knows about doesn't exist, write its name in light ink
      #set lblfg $cvsglb(dfg)
    #}

    switch -glob -- $DirList($w:$f:status) {
     "<file>" {
       set DirList($w:$f:icon) paper
       set DirList($w:$f:popup) paper_pop
      }
     "<dir> " {
       set DirList($w:$f:icon) folder
       set DirList($w:$f:popup) svnfolder_pop
     }
     "<dir> Up-to-date" {
       set DirList($w:$f:icon) dir_ok
       set DirList($w:$f:popup) svnfolder_pop
     }
     "<dir> Not managed*" {
       set DirList($w:$f:icon) dir_ques
       set DirList($w:$f:popup) svnfolder_pop
     }
     "<dir> Locally Added" {
       set DirList($w:$f:icon) dir_plus
       set DirList($w:$f:popup) svnfolder_pop
     }
     "<dir> Locally Removed" {
       set DirList($w:$f:icon) dir_minus
       set DirList($w:$f:popup) svnfolder_pop
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
     "<directory:CVS>" {
       set DirList($w:$f:icon) cvsdir
       switch -- $rtype {
         "CVS" {
            set DirList($w:$f:popup) cvscvs_pop
          }
          default {
            set DirList($w:$f:popup) cvsdir_pop
          }
        }
      }
     "<directory:SVN>" {
       set DirList($w:$f:icon) svndir
       set DirList($w:$f:popup) svndir_pop
      }
     "<directory:RCS>" {
       set DirList($w:$f:icon) rcsdir
       set DirList($w:$f:popup) rcsdir_pop
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
          default {
            set DirList($w:$f:popup) paper_pop
          }
        }
      }
     "Missing*" {
        set DirList($w:$f:icon) stat_ex
        set DirList($w:$f:popup) needsupdate_pop
      }
     "Needs Checkout" {
       # Prepending ./ to the filename prevents tilde expansion
       if {[file exists ./$f]} {
         set DirList($w:$f:icon) stat_ood
        } else {
         set DirList($w:$f:icon) stat_ex
        }
        set DirList($w:$f:popup) needsupdate_pop
      }
      "Needs Patch" {
       set DirList($w:$f:icon) stat_ood
       set DirList($w:$f:popup) needsupdate_pop
      }
      "Out-of-date" {
       set DirList($w:$f:icon) stat_ood
       set DirList($w:$f:popup) needsupdate_pop
      }
      "Needs Merge" {
       set DirList($w:$f:icon) stat_merge
       set DirList($w:$f:popup) stat_merge_pop
      }
      "Locally Modified" {
       set DirList($w:$f:icon) stat_mod
       set DirList($w:$f:popup) stat_mod_pop
      }
      "Locally Added" {
       set DirList($w:$f:icon) stat_plus
       set DirList($w:$f:popup) stat_plus_pop
       if {[string match "*-kb*" $DirList($w:$f:option)]} {
         set DirList($w:$f:icon) stat_plus_kb
       }
      }
      "Locally Removed" {
       set DirList($w:$f:icon) stat_minus
       set DirList($w:$f:popup) stat_plus_pop
      }
      "*onflict*" {
       set DirList($w:$f:icon) stat_conf
       set DirList($w:$f:popup) stat_conf_pop
      }
      "Not managed*" {
       set DirList($w:$f:icon) stat_ques
       set DirList($w:$f:popup) paper_pop
      }
      "RCS Up-to-date" {
       set DirList($w:$f:icon) stat_ok
       set DirList($w:$f:popup) rcs_pop
      }
      "RCS Modified" {
       set DirList($w:$f:icon) stat_mod
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
    bind $flist <1> "DirCanvas:unselectall $w 0"
    bind $flist <Shift-1> " "

    bind $flist <2> "DirCanvas:areaStart $flist %x %y"
    bind $flist <B2-Motion> "DirCanvas:areaStroke $flist %x %y; \
                             DirCanvas:drag_windows $w %W %y"
    bind $flist <B2-Motion><ButtonRelease-2> "DirCanvas:unselectall $w 1; \
                                              DirCanvas:areaFind $flist"
    bind $flist <3> "DirCanvas:areaStart $flist %x %y"
    bind $flist <Shift-3> "DirCanvas:areaStart $flist %x %y"
    bind $flist <B3-Motion> "DirCanvas:areaStroke $flist %x %y; \
                             DirCanvas:drag_windows $w %W %y"
    bind $flist <B3-Motion><ButtonRelease-3> "DirCanvas:unselectall $w 1; \
                                              DirCanvas:areaFind $flist"
    # In the bindings, filenames need any single percents replaced with
    # double to avoid interpretation as an event field
    regsub -all {\%} $f {%%} fn
    regsub -all {\$} $fn {\$} fn

    # The "x" tag is used for area selection.
    # Draw the icon
     set k [$flist create image $x $y -image $DirList($w:$f:icon) \
       -anchor w -tags [list x $y] ]
     $flist bind $k <1> "DirCanvas:setselection $w $y \"$fn\""
     $flist bind $k <Shift-1> "DirCanvas:addrange $w $y \"$fn\""
     $flist bind $k <Control-1> "DirCanvas:addselection $w $y \"$fn\""
     $flist bind $k <Double-1> {workdir_edit_file [workdir_list_files]}
     $flist bind $k <2> "DirCanvas:areaStart $flist %x %y; \
                         DirCanvas:popup $flist $y %X %Y \"$fn\""
     $flist bind $k <3> "DirCanvas:areaStart $flist %x %y; \
                         DirCanvas:popup $flist $y %X %Y \"$fn\""

    # Draw the label
     $flist create text $lblx $y  -text $f -font $cvscfg(listboxfont) \
       -anchor w -tags [list $flist.tx$y $y $fn] -fill $lblfg
     $flist bind $flist.tx$y <1> "DirCanvas:setselection $w $y \"$fn\""
     $flist bind $flist.tx$y <Shift-1> "DirCanvas:addrange $w $y \"$fn\""
     $flist bind $flist.tx$y <Enter> "DirCanvas:flash $w $y"
     $flist bind $flist.tx$y <Leave> "DirCanvas:unflash $w $y \"$fn\""
     $flist bind $flist.tx$y <Control-1> "DirCanvas:addselection $w $y \"$fn\""
     $flist bind $flist.tx$y <Double-1> {workdir_edit_file [workdir_list_files]}
     $flist bind $flist.tx$y <2> "DirCanvas:areaStart $flist %x %y; \
                                  DirCanvas:popup $flist $y %X %Y \"$fn\""
     $flist bind $flist.tx$y <3> "DirCanvas:areaStart $flist %x %y; \
                                  DirCanvas:popup $flist $y %X %Y \"$fn\""

    set DirList($w:$f:y) $y
    set DirList($flist:$y) $f

    set status $DirList($w:$f:status)
    set k [$w.statcol.list create text 8 $y -fill $cvsglb(fg) \
       -text $status -font $cvscfg(listboxfont) -anchor w]
    set slen [string length $status]
    if {$slen > $maxstat} {
      set maxstat $slen
      set longstat $status
    }

    set date $DirList($w:$f:date)
    set k [$w.datecol.list create text 4 $y -fill $cvsglb(fg) \
       -text $date -font $cvscfg(listboxfont) -anchor w]
    set dlen [string length $date]
    if {$dlen > $maxdate} {
      set maxdate $dlen
      set longdate $date
    }

    if {[info exists DirList($w:$f:sticky)]} {
      set tag $DirList($w:$f:sticky)
      set k [$w.wrevcol.list create text 4 $y -fill $cvsglb(fg) \
         -text $tag -font $cvscfg(listboxfont) -anchor w]
      set tlen [string length $tag]
      if {$tlen > $maxtag} {
        set maxtag $tlen
        set longtag $tag
      }
    }

    set editors $DirList($w:$f:editors)
    set k [$w.editcol.list create text 4 $y -fill $cvsglb(fg) \
       -text $editors -font $cvscfg(listboxfont) -anchor w]
    set edlen [string length $editors]
    if {$edlen > $maxed} {
      set maxed $edlen
      set longed $editors
    }
  }

  # See which optional columns we need to draw
  if {$incvs || $insvn || $inrcs} {
    if {$cvscfg(showstatcol)} {
      DirCanvas:map_column $w statcol
    } else {
      pack forget $w.statcol
    }
    if {$cvscfg(showeditcol)} {
      DirCanvas:map_column $w editcol
    } else {
      pack forget $w.editcol
    }
  }
  if {$cvscfg(showdatecol)} {
    DirCanvas:map_column $w datecol
  } else {
    pack forget $w.datecol
  }


  set wid [font measure $cvscfg(listboxfont) -displayof $w $longlbl]
  set DirList($w:filecolwidth) [expr {$x + $wid + $lblx + 8}]
  # Set a minimum width for the labels.  Otherwise ".." can be hard to select.
  set minlabel 6
  foreach labl [$flist find withtag lbl] {
    set itags [$flist gettags $labl]
    set iy [lindex $itags 1]
    if {[string length $DirList($flist:$iy)] < $minlabel} {
      $flist.tx$iy configure -width $minlabel
    }
  }
  # Don't let the column be too wide.
  set maxcolwid 200
  gen_log:log D "filecol width $DirList($w:filecolwidth)"
  if {$wid < $maxcolwid} {
    $flist configure -width $DirList($w:filecolwidth)
  } else {
    gen_log:log D "Reducing filecol width from $wid to $maxcolwid"
    $flist configure -width $maxcolwid
  }
  $flist configure -xscrollcommand "$w.filecol.xscroll set"

  set wid [font measure $cvscfg(listboxfont) -displayof $w $longstat]
  set DirList($w:statcolwidth) [expr {$wid + 6}]
  gen_log:log D "statcol width $DirList($w:statcolwidth)"
  if {$wid < $maxcolwid} {
    $w.statcol.list configure -width $DirList($w:statcolwidth)
  } else {
    gen_log:log D "Reducing statcol width from $wid to $maxcolwid"
    $w.statcol.list configure -width $maxcolwid
  }
  $w.statcol.list configure -xscrollcommand "$w.statcol.xscroll set"

  set wid [font measure $cvscfg(listboxfont) -displayof $w $longdate]
  set DirList($w:datecolwidth) [expr {$wid + 6}]
  if {$wid < $maxcolwid} {
    $w.datecol.list configure -width $DirList($w:datecolwidth)
  } else {
    gen_log:log D "Reducing datecol width from $wid to $maxcolwid"
    $w.datecol.list configure -width $maxcolwid
  }
  $w.datecol.list configure -xscrollcommand "$w.datecol.xscroll set"


  if {$incvs || $insvn || $inrcs} {
    set wid [font measure $cvscfg(listboxfont) -displayof $w $longtag]
    set DirList($w:revcolwidth) [expr {$wid + 6}]
    gen_log:log D "width of $w.wrevcol $maxtag chars ($wid)"
    # Don't let the column be too wide.
    if {$wid < $maxcolwid} {
      $w.wrevcol.list configure -width $DirList($w:revcolwidth)
    } else {
      gen_log:log D "Reducing wrevcol width from $wid to $maxcolwid"
      $w.wrevcol.list configure -width $maxcolwid
    }
    $w.wrevcol.list configure -xscrollcommand "$w.wrevcol.xscroll set"

    set wid [font measure $cvscfg(listboxfont) -displayof $w $longed]
    set DirList($w:edcolwidth) [expr {$wid + 6}]
    gen_log:log D "width of $w.editcol $maxed chars ($wid)"
    if {$wid < $maxcolwid} {
      $w.editcol.list configure -width $DirList($w:edcolwidth)
    } else {
      gen_log:log D "Reducing editcol width from $wid to $maxcolwid"
      $w.editcol.list configure -width $maxcolwid
    }
    $w.editcol.list configure -xscrollcommand "$w.editcol.xscroll set"
  }

  # Scroll to the top of the lists
  set fbbox [$flist bbox all]
  #gen_log:log D "fbbox   \"$fbbox\""
  if {[llength $fbbox] == 4} {
    set ylen [expr {[lindex $fbbox 3] - [lindex $fbbox 1]}]

    set wview [winfo height $flist]
    $w.yscroll set 0 [expr ($wview * 1.0) / ($ylen * 1.0)]

    $flist config -scrollregion $fbbox
    $flist yview moveto 0

    if {$cvscfg(showdatecol)} {
      set fbbox [$w.datecol.list bbox all]
      set botx [lindex $fbbox 0]
      set boty [lindex $fbbox 1]
      $w.datecol.list config -scrollregion \
        [list $botx $boty \
          [expr {$botx + $DirList($w:datecolwidth)}] \
          [expr {$boty + $ylen}]]
      $w.datecol.list yview moveto 0
    }

    if {$incvs || $insvn || $inrcs} {
      set fbbox [$w.wrevcol.list bbox all]
      set botx [lindex $fbbox 0]
      set boty [lindex $fbbox 1]
      $w.wrevcol.list config -scrollregion \
        [list $botx $boty \
          [expr {$botx + $DirList($w:revcolwidth)}] \
          [expr {$boty + $ylen}]]
      $w.wrevcol.list yview moveto 0

      if {$cvscfg(showstatcol)} {
        set fbbox [$w.statcol.list bbox all]
        set botx [lindex $fbbox 0]
        set boty [lindex $fbbox 1]
        $w.statcol.list config -scrollregion \
          [list $botx $boty \
            [expr {$botx + $DirList($w:statcolwidth)}] \
            [expr {$boty + $ylen}]]
        $w.statcol.list yview moveto 0
      }

      if {$cvscfg(showeditcol)} {
        set fbbox [$w.editcol.list bbox all]
        set botx [lindex $fbbox 0]
        set boty [lindex $fbbox 1]
        $w.editcol.list config -scrollregion \
          [list $botx $boty \
            [expr {$botx + $DirList($w:edcolwidth)}] \
            [expr {$boty + $ylen}]]
        $w.editcol.list yview moveto 0
      }
    }
  }
  # Reset the scrollbar.  Otherwise it fills the trough
  DirCanvas:scroll_windows $w scroll 0 units
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

proc DirCanvas:scroll_windows {w args} {
  global cvscfg
  global cvsglb
  global incvs
  global insvn
  global inrcs

  #gen_log:log T "ENTER ($w $args)"
  set way [lindex $args 1]
  set units [lindex $args 2]
  set yget [$w.yscroll get]
  set first [lindex $yget 0]
  set last [lindex $yget 1]
  # If you dont do this, the scrollbar fills the whole trough when
  # you page past the top or bottom with the arrow keys
  case $units {
    {units pages} {
      if {$way < 0} {
        if {$first == 0} {
          return
        }
      } else {
        if {$last == 1} {
          return
        }
      }
    }
  }
  eval $w.filecol.list yview $args
  if {$cvscfg(showdatecol)} {
    eval $w.datecol.list yview $args
  }
  if {$incvs || $insvn || $inrcs} {
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
  global incvs
  global insvn
  global inrcs
  global cvscfg
  global cvsglb

  set height [$W cget -height]
  #gen_log:log D "$w %y $height"
  if {$y < 0} {set y 0}
  if {$y > $height} {set y $height}
  set yfrac [expr {double($y) / $height}]

  eval $w.filecol.list yview moveto $yfrac
  if {$cvscfg(showdatecol)} {
    eval $w.datecol.list yview moveto $yfrac
  }
  if {$incvs || $insvn || $inrcs} {
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
  global cvsglb
  global arr

  gen_log:log T "ENTER ($w $col $sense)"
  foreach a [array names arr] {
    catch "$arr($a) configure -image arr_dn"
  }
  set cvsglb(sort_pref) [list $col $sense]

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

  gen_log:log D "  $cvsglb(sort_pref)"

  DirCanvas:build $w
  gen_log:log T "LEAVE"
}

proc DirCanvas:toggle_col {w col} {
  global cvsglb
  global cvscfg

  gen_log:log T "ENTER ($col)"
  set cur_col [lindex $cvsglb(sort_pref) 0]
  set cur_sense [lindex $cvsglb(sort_pref) 1]

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

proc DirCanvas:makepopup {w} {
#
# Context-sensitive popups for list items
# We build them all at once here, then bind canvas items to them as appropriate
#
  gen_log:log T "ENTER ($w)"

  # For plain files in an un-versioned directory
  menu $w.paper_pop -tearoff 0
  $w.paper_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.paper_pop add command -label "Delete Locally" \
    -command { workdir_delete_file [workdir_list_files] }

  # For plain directories in an un-versioned directory
  menu $w.folder_pop -tearoff 0
  $w.folder_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.folder_pop add command -label "Delete Locally" \
    -command { workdir_delete_file [workdir_list_files] }

  # For plain directories in CVS
  menu $w.incvs_folder_pop -tearoff 0
  $w.incvs_folder_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.incvs_folder_pop add command -label "CVS Add Recursively" \
    -command { addir_dialog [workdir_list_files] }
  $w.incvs_folder_pop add command -label "Delete Locally" \
    -command { workdir_delete_file [workdir_list_files] }

  # For CVS directories when cwd is in CVS
  menu $w.cvscvs_pop -tearoff 0
  $w.cvscvs_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.cvscvs_pop add command -label "CVS Remove Recursively" \
    -command { subtractdir_dialog [workdir_list_files] }

  # For CVS directories when cwd isn't in CVS
  menu $w.cvsdir_pop -tearoff 0
  $w.cvsdir_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.cvsdir_pop add command -label "CVS Release" \
    -command { release_dialog [workdir_list_files] }

  # For CVS files
  menu $w.stat_cvsok_pop -tearoff 0
  $w.stat_cvsok_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "Browse the Log Diagram" \
    -command { cvs_branches [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "CVS Annotate/Blame" \
    -command { cvs_annotate $current_tagname [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "CVS Remove" \
    -command { subtract_dialog [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "Set Binary Flag" \
     -command { cvs_binary [workdir_list_files] }
  $w.stat_cvsok_pop add command -label "Unset Binary Flag" \
     -command { cvs_ascii [workdir_list_files] }

  # For CVS files that are not up-to-date
  menu $w.needsupdate_pop -tearoff 0
  $w.needsupdate_pop add command -label "Update" \
    -command { \
        cvs_update {BASE} {Normal} {Remove} {No} { } [workdir_list_files] }
  $w.needsupdate_pop add command -label "Update with Options" \
    -command update_run

  # For CVS files that need merging
  menu $w.stat_merge_pop -tearoff 0
  $w.stat_merge_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_merge_pop add command -label "Diff" \
    -command { comparediff [workdir_list_files] }
  $w.stat_merge_pop add command -label "CVS Annotate/Blame" \
    -command { cvs_annotate $current_tagname [workdir_list_files] }
  $w.stat_merge_pop add command -label "Browse the Log Diagram" \
    -command { cvs_branches [workdir_list_files] }

  # For CVS files that are modified
  menu $w.stat_mod_pop -tearoff 0
  $w.stat_mod_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_mod_pop add command -label "Diff" \
    -command { comparediff [workdir_list_files] }
  $w.stat_mod_pop add command -label "Commit" \
    -command { cvs_commit_dialog }
  $w.stat_mod_pop add command -label "Revert" \
    -command { cvs_revert [workdir_list_files] }

  # For CVS files that have been added or removed but not commited
  menu $w.stat_plus_pop -tearoff 0
  $w.stat_plus_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_plus_pop add command -label "Commit" \
    -command { cvs_commit_dialog }

  # For CVS files with conflicts
  menu $w.stat_conf_pop -tearoff 0
  $w.stat_conf_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_conf_pop add command -label "Merge Conflict" \
    -command { cvs_merge_conflict [workdir_list_files] }
  $w.stat_conf_pop add command -label "CVS Annotate/Blame" \
    -command { cvs_annotate $current_tagname [workdir_list_files] }
  $w.stat_conf_pop add command -label "Browse the Log Diagram" \
    -command { cvs_branches [workdir_list_files] }

  # For RCS files
  menu $w.rcs_pop -tearoff 0
  $w.rcs_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.rcs_pop add command -label "Browse the Log Diagram" \
    -command { rcs_branches [workdir_list_files] }
  $w.rcs_pop add command -label "RCS Lock" \
    -command { rcs_lock lock [workdir_list_files] }
  $w.rcs_pop add command -label "RCS Unlock" \
    -command { rcs_lock unlock [workdir_list_files] }
  $w.rcs_pop add command -label "Delete Locally" \
    -command { workdir_delete_file [workdir_list_files] }
  $w.rcs_pop add command -label "Revert" \
    -command { rcs_revert [workdir_list_files] }

  # For SVN files
  menu $w.stat_svnok_pop -tearoff 0
  $w.stat_svnok_pop add command -label "Edit" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.stat_svnok_pop add command -label "SVN Log" \
    -command { svn_log [workdir_list_files] }
  $w.stat_svnok_pop add command -label "Browse the Log Diagram" \
    -command { svn_branches [workdir_list_files] }
  $w.stat_svnok_pop add command -label "SVN Annotate/Blame" \
    -command { svn_annotate "" [workdir_list_files] }
  $w.stat_svnok_pop add command -label "Revert" \
    -command { svn_revert [workdir_list_files] }
  $w.stat_svnok_pop add command -label "SVN Remove" \
    -command { subtract_dialog [workdir_list_files] }

  # For SVN directories
  menu $w.svnfolder_pop -tearoff 0
  $w.svnfolder_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.svnfolder_pop add command -label "SVN Log" \
    -command { svn_log [workdir_list_files] }
  $w.svnfolder_pop add command -label "Browse the Log Diagram" \
    -command { svn_branches [workdir_list_files] }
  $w.svnfolder_pop add command -label "SVN Remove" \
    -command { subtract_dialog [workdir_list_files] }

  # For SVN directories
  menu $w.svndir_pop -tearoff 0
  $w.svndir_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }
  $w.svndir_pop add command -label "SVN Log" \
    -command { svn_log [workdir_list_files] }

  # For RCS directories
  menu $w.rcsdir_pop -tearoff 0
  $w.rcsdir_pop add command -label "Descend" \
    -command { workdir_edit_file [workdir_list_files] }

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

