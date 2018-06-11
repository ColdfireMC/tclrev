#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" -- ${1+"$@"}


proc cleanup_old {} {

  set oldirs [glob -nocomplain -- rcs_test*]
  foreach od $oldirs {
    puts "Deleting $od"
    file delete -force $od
  }
  puts "==============================="
}

proc checkin_files {topdir} {
  global WD
  
  puts "==============================="
  file mkdir RCS

  puts "IMPORTING FILES $topdir"
  # Check in files
  foreach n {1 2 3} {
    set filename File$n.txt
    set rcsfile RCS/$filename,v
    # Escape the spaces in filenames
    regsub -all { } $filename {\ } filename
    regsub -all { } $rcsfile {\ } rcsfile
    set exec_cmd "ci -u -t-small_text_file -mInitial_checkin $filename $rcsfile"
    puts "$exec_cmd"
    set ret [catch {eval "exec $exec_cmd"} out]
    puts $out
  }
  foreach D {Dir1 "Dir 2"} {
    puts $D
    cd $D
    file mkdir RCS
    foreach n {1 2 " 3"} {
      set rcsfile RCS/F$n.txt,v
      # Escape the spaces in filenames
      regsub -all { } F$n.txt {\ } F$n.txt
      regsub -all { } $rcsfile {\ } rcsfile
      set exec_cmd "ci -u -t-small_text_file -mInitial_checkin F$n.txt $rcsfile"
      puts "$exec_cmd"
      set ret [catch {eval "exec $exec_cmd"} out]
      puts $out
    }
    cd $topdir
  }
}

proc checkout_files {topdir} {
  global WD

  puts "==============================="
  puts "CHECKING OUT"

  set globpat "RCS/*,v"
  regsub -all { } $globpat {\ } globpat
  set exec_cmd "co -l [glob $globpat]"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out

  foreach D {Dir1 "Dir 2"} {
    cd $D
    set globpat "RCS/*,v"
    regsub -all { } $globpat {\ } globpat
    set exec_cmd "co -l [glob $globpat]"
    puts "$exec_cmd"
    set ret [catch {eval "exec $exec_cmd"} out]
    puts $out
    cd $topdir
  }
  puts "CHECKOUT FINISHED"
}

proc writefile {filename wn} {
  # Assume we have write permission, we got it from the calling proc
  set wordlist(1) {capacious glower canorous spoonerism tenebrous nescience gewgaw effulgence}
  set wordlist(2) {billet willowwacks amaranthine chaptalize nervure moxie overslaugh}

  set ind [expr {int(rand()*[llength $wordlist($wn)])}]
  set word [lindex $wordlist($wn) $ind]
  puts " append \"$word\" to $filename"
  set fp [open $filename a]
  puts $fp $word
  close $fp
}

proc addfile {filename} {

  puts "Add $filename"
  set exec_cmd "ci -u -t-small_text_file -mInitial_checkin $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  set exec_cmd "co -l $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

proc delfile {filename} {

  puts "Delete $filename"
  file delete $filename
  file delete RCS/$filename,v
}

proc getrev {filename} {
  # Find out current revision

  set exec_cmd "rcs log -b $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  #puts $out
  foreach logline [split $out "\n"] {
    if {[string match "revision *" $logline]} {
      set latest [lindex $logline 1]
      break
    }
  }
  puts "latest rev is $latest"
  return $latest
}

proc conflict {filename} {
  # Create a conflict

  set latest [getrev $filename]
  # Save a copy
  file copy $filename Ftmp.txt
  # Make a change
  set exec_cmd "rcs -l $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  file attributes $filename -permissions u+w
  writefile $filename 1
  set exec_cmd "ci -m\"change1\" $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # Check out previous revision
  set exec_cmd "co -l -r$latest $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # Make a different change (we hope)
  file delete -force -- $filename
  file rename Ftmp.txt $filename
  file attributes $filename -permissions u+w
  writefile $filename 2
  # When we check in a conflicting version, it creates
  # a branch
  set exec_cmd "ci -m\"change2_conflicting\" $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # Check out the branch
  set exec_cmd "co -r1.2.1 $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

proc commit {comment} {
  puts "COMMIT"
  puts [pwd]
  set tmpfile "list.tmp"
  file delete -force $tmpfile

  puts "Finding RCS files"
  if {[ info exists env(SystemDrive) ]} {
    puts "Must be a PC"
    set ret [catch {eval "exec [auto_execok dir] /b F*.txt /s > $tmpfile"} out]
  } else {
    set ret [catch {eval "exec find . -name F*.txt -o -name RCS -prune -a -type f > $tmpfile"} out]
  }
  if {$ret} {
    puts $out
    puts "Find failed"
    exit 1
  }
  puts "CHECKING IN FILES"
  regsub -all { } $comment {_} comment
  set fl [open $tmpfile r]
  while { [gets $fl item] >= 0} {
    regsub -all { } $item {\ } filename
    set exec_cmd "ci -u -t-small_text_file -m$comment $filename"
    puts $exec_cmd
    set ret [catch {eval "exec $exec_cmd"} out]
    puts $out
  }
  close $fl
  file delete -force $tmpfile
}

proc mkfiles {topdir} {
  global WD

  puts "MAKING FILETREE"
  file mkdir "$topdir"
  cd $topdir

  # Make some files each containing a random word
  foreach n {1 2 3} {
    writefile File$n.txt 1
  }
  foreach D {Dir1 "Dir 2"} {
    puts $D
    file mkdir $D
    cd $D
    foreach n {1 2 " 3"} {
      writefile F$n.txt 1
    }
    cd $topdir
  }
}

proc modfiles {} {

  puts "MODIFYING FILES"
  set tmpfile "list.tmp"
  file delete -force $tmpfile

  puts "Finding RCS files"
  if {[ info exists env(SystemDrive) ]} {
    puts "Must be a PC"
    set ret [catch {eval "exec [auto_execok dir] /b F*.txt /s > $tmpfile"} out]
  } else {
    set ret [catch {eval "exec find . -name F*.txt -o -name RCS -prune -a -type f > $tmpfile"} out]
  }
  if {$ret} {
    puts $out
    puts "Find failed"
    exit 1
  }
  set fl [open $tmpfile r]
  while { [gets $fl item] >= 0} {
    # Why didn't co -l make it writeable?
    file attributes $item -permissions u+w
    writefile $item 2
  }
  close $fl
  file delete -force $tmpfile
}

##############################################

if [file isdirectory RCS] {
  puts "Please don't do that here.  There's already an RCS directory."
  exit 1
}

set WD [pwd]
set testdir "$WD/rcs_test"
cleanup_old
mkfiles $testdir
checkin_files $testdir
checkout_files $testdir

puts "==============================="
puts "First revision"
puts "** modfiles"
modfiles
puts "** commit"
commit "First Revision"
puts "** writefile"
writefile Fnew.txt 2
puts "** addfile"
addfile Fnew.txt

puts "==============================="
puts "Second revision"
modfiles
commit "Second revision"

puts "==============================="
puts "Uncommitted changes"
#Local only
writefile FileLocal.txt 1
# Deleted
delfile File3.txt
# Modify
writefile File2.txt 2
# Conflict
puts "** conflict"
conflict Fnew.txt
cd $WD

