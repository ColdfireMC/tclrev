#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" -- ${1+"$@"}


proc cleanup_old {root} {
  global env

  if {[ file isdirectory $root ]} {
    puts "Deleting $root"
    file delete -force $root
  }
  set oldirs [glob -nocomplain -- rcs_test*]
  foreach od $oldirs {
    puts "Deleting $od"
    file delete -force $od
  }
  puts "==============================="
}

proc repository {Root topdir} {
  global WD
  
  puts "==============================="
  puts "MAKING REPOSITORY $Root"

  # Create the repository
  #file mkdir $Root
  file mkdir $Root/RCS

  puts "IMPORTING FILES $Root"
  # Check in files
  cd $WD/$topdir
  foreach n {1 2 3} {
    set filename "File$n.txt"
    set rcsfile "$Root/RCS/$filename,v"
    regsub -all { } $filename {\ } filename
    regsub -all { } $rcsfile {\ } rcsfile
    set exec_cmd "ci -u -t-small_text_file -mInitial_checkin $filename $rcsfile"
    puts "$exec_cmd"
    set ret [catch {eval "exec $exec_cmd"} out]
    puts $out
  }
  foreach D {Dir1 "Dir 2"} {
    puts $D
    file mkdir $Root/$D/RCS
    cd $WD/$topdir/$D
    foreach n {1 2 " 3"} {
      set subf "F$n.txt"
      set rcsfile "$Root/$D/RCS/$subf,v"
      regsub -all { } $subf {\ } subf
      regsub -all { } $rcsfile {\ } rcsfile
      set exec_cmd "ci -u -t-small_text_file -mInitial_checkin $subf $rcsfile"
      puts "$exec_cmd"
      set ret [catch {eval "exec $exec_cmd"} out]
      puts $out
    }
    cd $WD/$topdir
  }
}

proc checkout_branch {proj tag} {
  global env
  global WD

  puts "==============================="
  puts "CHECKING OUT $tag"

  set co_dir "${proj}_$tag"
  file mkdir $WD/$co_dir
  cd $WD/$co_dir

  # Check out 
  set globpat "$env(RCSROOT)/RCS/*,v"
  regsub -all { } $globpat {\ } globpat
  if {$tag eq "trunk"} {
    set exec_cmd "co -u [glob $globpat]"
  } else {
    set exec_cmd "cvs -d $env(CVSROOT) co -d rcs_test_$tag -r $tag $proj"
  }
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  file link -symbolic RCS $env(RCSROOT)/RCS

  foreach D {Dir1 "Dir 2"} {
    puts $D
    file mkdir $D
    cd $D

    set globpat "$env(RCSROOT)/$D/RCS/*,v"
    regsub -all { } $globpat {\ } globpat
    if {$tag eq "trunk"} {
      set exec_cmd "co -u [glob $globpat]"
    } else {
      set exec_cmd "cvs -d $env(CVSROOT) co -d rcs_test_$tag -r $tag $proj"
    }
    puts "$exec_cmd"
    set ret [catch {eval "exec $exec_cmd"} out]
    puts $out
    file link -symbolic RCS $env(RCSROOT)/$D/RCS
    cd $WD/$co_dir
  }

  puts "CHECKOUT FINISHED"
}

proc newbranch {proj oldtag newtag} {
  global env

  set exec_cmd "cvs -d $env(CVSROOT) rtag -r $oldtag -b $newtag $proj"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out

  puts "CHECKING OUT BRANCH"
  set exec_cmd "cvs -d $env(CVSROOT) co -r $newtag -d ${proj}_$newtag rcs_test"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
}

proc writefile {filename wn} {
  set wordlist(1) {capacious glower canorous spoonerism tenebrous nescience gewgaw effulgence}
  set wordlist(2) {billet willowwacks amaranthine chaptalize nervure moxie overslaugh}

  set ind [expr {int(rand()*[llength $wordlist($wn)])}]
  set word [lindex $wordlist($wn) $ind]
  puts " append \"$word\" to $filename"
  set fp [open "$filename" a]
  puts $fp $word
  close $fp
}

proc addfile {filename branch} {
  global env

  puts "Add $filename on $branch"
  set rcsfile "$env(RCSROOT)/RCS/$filename,v"
  set exec_cmd "ci -u -t-new_text_file -mInitial_checkin $filename $rcsfile"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  set exec_cmd "co -l $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

proc delfile {filename branch} {
  global env

  puts "Delete $filename on $branch"
  file delete $filename
  set exec_cmd "cvs delete $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

proc commit {comment} {
  global env

  puts "COMMIT"
  puts [pwd]
  set tmpfile "list.tmp"
  file delete -force $tmpfile

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

  regsub -all { } $comment {_} comment
  set fl [open $tmpfile r]
  while { [gets $fl item] >= 0} {
    regsub -all { } $item {\ } filename
    set exec_cmd "ci -u -m$comment $filename"
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
  # Make some files to put in the repository
  file mkdir "$topdir"
  cd $topdir

  # Make some files each containing a random word
  foreach n {1 2 3} {
    writefile "File$n.txt" 1
  }
  foreach D {Dir1 "Dir 2"} {
    puts $D
    file mkdir $D
    foreach n {1 2 " 3"} {
      set subf [file join $D "F$n.txt"]
      writefile $subf 1
    }
  }
  cd $WD
}

proc modfiles {} {
  global env

  set tmpfile "list.tmp"
  file delete -force $tmpfile

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
    regsub -all { } $item {\ } filename
    set exec_cmd "co -l $filename"
    set ret [catch {eval "exec $exec_cmd"} out]
    puts $out
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
set Root [file join $WD "RCS_REPOSITORY"]
set env(RCSROOT) $Root

cleanup_old $Root

mkfiles "rcs_test"
repository $Root "rcs_test"
checkout_branch "rcs_test" "trunk"
cd $WD


puts "==============================="
puts "First revision on trunk"
cd rcs_test_trunk
modfiles
commit "First Revision on trunk"
writefile Ftrunk.txt 2
addfile Ftrunk.txt trunk
cd $WD

exit

puts "==============================="
puts "MAKING BRANCH A"
newbranch rcs_test HEAD branchA
cd $WD/rcs_test_branchA
writefile FbranchA.txt 2
addfile FbranchA.txt branchA
commit "Add file FbranchA.txt on branchA"
cd $WD

puts "==============================="
puts "Second revision on trunk"
cd $WD/rcs_test_trunk
modfiles
commit "Second revision on trunk"
cd $WD

puts "==============================="
puts "First revision on Branch A"
cd $WD/rcs_test_branchA
modfiles
commit "First revision on branchA"
cd $WD

puts "==============================="
# Make another modification on each
puts "Third revision on trunk"
cd $WD/rcs_test_trunk
modfiles
commit "Third revision on trunk"
cd $WD

puts "==============================="
puts "Second revision on Branch A"
cd $WD/rcs_test_branchA
modfiles
commit "Second revision on branchA"
cd $WD

# Branch off of the branch
puts "==============================="
puts "MAKING BRANCH AA"
newbranch rcs_test branchA branchAA
cd $WD/rcs_test_branchAA
modfiles
writefile FbranchAA.txt 2
addfile FbranchAA.txt branchAA
delfile Ftrunk.txt branchAA
commit "Changes on Branch AA"
cd $WD

# Branch B
puts "==============================="
puts "MAKING BRANCH B"
newbranch rcs_test HEAD branchB
cd $WD/rcs_test_branchB
modfiles
writefile FbranchB.txt 1
addfile FbranchB.txt branchB
commit "Add file FB on BranchB"
cd $WD

