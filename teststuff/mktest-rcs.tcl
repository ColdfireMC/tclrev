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
    set exec_cmd "ci -u -i -t-small_text_file -m\"Initial\\\ checkin\" $filename $rcsfile"
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
      set exec_cmd "ci -u -i -t-small_text_file -m\"Initial\\\ checkin\" F$n.txt $rcsfile"
      puts "$exec_cmd"
      set ret [catch {eval "exec $exec_cmd"} out]
      puts $out
    }
    cd $topdir
  }
}

proc checkout_files {topdir} {
  global WD

  cd $topdir
  puts "==============================="
  puts "CHECKING OUT"

  set globpat "RCS/*,v"
  regsub -all { } $globpat {\ } globpat
  set exec_cmd "co -f -l [glob $globpat]"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out

  foreach D {Dir1 "Dir 2"} {
    cd $D
    set globpat "RCS/*,v"
    regsub -all { } $globpat {\ } globpat
    set exec_cmd "co -f -l [glob $globpat]"
    puts "$exec_cmd"
    set ret [catch {eval "exec $exec_cmd"} out]
    puts $out
    cd $topdir
  }
  puts "CHECKOUT FINISHED"
}

proc writefile {filename string} {
  puts " append \"$string\" to $filename"
  set fp [open "$filename" a]
  puts $fp $string
  close $fp
}

proc addfile {filename} {

  puts "Add $filename"
  set exec_cmd "ci -u -i -t-small_text_file -m\"Initial\\\ checkin\" $filename"
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

proc lock {filename} {

  puts "Lock $filename"
  set exec_cmd "rcs -l $filename"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
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
  writefile $filename "Conflict A"
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
  writefile $filename "Conflict B"
  # When we check in a conflicting version, it creates
  # a branch
  set exec_cmd "ci -m\"change2\\\ conflicting\" $filename"
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
    regsub -all { } $comment {\\\ } comment
    #set exec_cmd "ci -u -t-small_text_file -m\"$comment\" $filename"
    set exec_cmd "ci -u -m\"$comment\" $filename"
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
    writefile File$n.txt "Initial"
  }
  foreach D {Dir1 "Dir 2"} {
    puts $D
    file mkdir $D
    cd $D
    foreach n {1 2 " 3"} {
      writefile F$n.txt "Initial"
    }
    cd $topdir
  }
}

proc modfiles {string} {
  global tcl_platform

  puts "MODIFYING FILES"
  set tmpfile "list.tmp"
  file delete -force $tmpfile

  puts "Finding RCS files"
  if {$tcl_platform(platform) eq "windows"} {
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
    writefile $item "$string"
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
modfiles "Main 1"
puts "** commit"
commit "First Revision"
puts "** writefile"
writefile Fnew.txt "Main 1"
puts "** addfile"
addfile Fnew.txt

puts "==============================="
puts "Second revision"
checkout_files $testdir
modfiles "Main 2"
commit "Second revision"

puts "==============================="
puts "Making Uncommitted changes"
#Local only
writefile FileLocal.txt "Pending"
# Deleted
delfile File3.txt
# Modify
file attributes File2.txt -permissions u+w
writefile File2.txt "Pending"
lock File2.txt
# Conflict
puts "** conflict"
conflict Fnew.txt
cd $WD

