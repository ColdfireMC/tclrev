#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" -- ${1+"$@"}


proc cleanup_old {root} {
  global env

  if {[ file isdirectory $root ]} {
    puts "Deleting $root"
    file delete -force $root
  }
  set oldirs [glob -nocomplain -- cvs_test*]
  foreach od $oldirs {
    puts "Deleting $od"
    file delete -force $od
  }
  puts "==============================="
}

proc repository {Root topdir} {
  global env
  global WD

  puts "==============================="
  puts "MAKING REPOSITORY $env(CVSROOT)"

  # Create the repository
  file mkdir $Root
  set exec_cmd "cvs -d $env(CVSROOT) init"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  if {$ret} {
    puts $out
    puts "COULD NOT CREATE REPOSITORY $env(CVSROOT)"
    exit 1
  }
  puts "CREATED $env(CVSROOT)"

  puts "==============================="
  puts "IMPORTING FILETREE"
  cd $topdir
  # Import it
  set exec_cmd "cvs -d $env(CVSROOT) import -m \"Imported\" $topdir BEGIN baseline-1_1_1"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  puts "IMPORT FINISHED"
  cd $WD
}

proc checkout_branch {proj tag} {
  global env

  puts "==============================="
  puts "CHECKING OUT $tag"
  # Check out 
  if {$tag eq "trunk"} {
    set exec_cmd "cvs -d $env(CVSROOT) co -d cvs_test_$tag $proj"
  } else {
    set exec_cmd "cvs -d $env(CVSROOT) co -d cvs_test_$tag -r $tag $proj"
  }
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  puts "CHECKOUT FINISHED"
}

proc newbranch {proj oldtag newtag} {
  global env

  set exec_cmd "cvs -d $env(CVSROOT) rtag -r $oldtag -b $newtag $proj"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out

  puts "CHECKING OUT BRANCH"
  set exec_cmd "cvs -d $env(CVSROOT) co -r $newtag -d ${proj}_$newtag cvs_test"
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
  set exec_cmd "cvs add $filename"
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
  set exec_cmd "cvs commit -m \"$comment\""
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
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
    set ret [catch {eval "exec find . -name F*.txt -o -name CVS -prune -a -type f > $tmpfile"} out]
  }
  if {$ret} {
    puts "Find failed"
    puts $out
    exit 1
  }
  set fl [open $tmpfile r]
  while { [gets $fl item] >= 0} {
    writefile $item 2
  }
  close $fl
  file delete -force $tmpfile
}

proc conflict {filename} {
  # Create a conflict

  # Find out current revision
  set exec_cmd "cvs log -b $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  foreach logline [split $out "\n"] {
    if {[string match "revision *" $logline]} {
      set previous [lindex $logline 1]
      break
    }
  }

  # Save a copy
  file copy $filename Ftmp.txt
  # Make a change
  writefile $filename 1
  set exec_cmd "cvs commit -m \"change1\" $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # Check out previous revision
  set exec_cmd "cvs update -r $previous $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # Make a different change (we hope)
  file delete -force -- $filename
  file rename Ftmp.txt $filename
  writefile $filename 2
  # Check out head, which now conflicts with our change
  set exec_cmd "cvs update -r HEAD $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

##############################################
set branching_desired 1

for {set i 0} {$i < [llength $argv]} {incr i} {
  set arg [lindex $argv $i]

  switch -regexp -- $arg {
    {^--*nobranch.*} {
      set branching_desired 0; incr i
    }
  }
}

if [file isdirectory CVS] {
  puts "Please don't do that here.  There's already a CVS directory."
  exit 1
}

set WD [pwd]
set Root [file join $WD "CVS_REPOSITORY"]
set env(CVSROOT) ":local:$Root"

cleanup_old $Root

mkfiles "cvs_test"
repository $Root "cvs_test"
checkout_branch "cvs_test" "trunk"

puts "==============================="
puts "First revision on trunk"
cd cvs_test_trunk
modfiles
writefile Ftrunk.txt 2
addfile Ftrunk.txt trunk
commit "First revision on trunk"
cd $WD

if {$branching_desired} {
puts "==============================="
puts "MAKING BRANCH A"
newbranch cvs_test HEAD branchA
cd $WD/cvs_test_branchA
writefile FbranchA.txt 2
addfile FbranchA.txt branchA
commit "Add file FbranchA.txt on branchA"
cd $WD
}

puts "==============================="
puts "Second revision on trunk"
cd $WD/cvs_test_trunk
modfiles
commit "Second revision on trunk"
cd $WD

if {$branching_desired} {
puts "==============================="
puts "First revision on Branch A"
cd $WD/cvs_test_branchA
modfiles
commit "First revision on branchA"
cd $WD
}

puts "==============================="
# Make another modification on each
puts "Third revision on trunk"
cd $WD/cvs_test_trunk
modfiles
commit "Third revision on trunk"
cd $WD

if {$branching_desired} {
puts "==============================="
puts "Second revision on Branch A"
cd $WD/cvs_test_branchA
modfiles
commit "Second revision on branchA"
cd $WD

# Branch off of the branch
puts "==============================="
puts "MAKING BRANCH AA"
newbranch cvs_test branchA branchAA
cd $WD/cvs_test_branchAA
modfiles
writefile FbranchAA.txt 2
addfile FbranchAA.txt branchAA
delfile Ftrunk.txt branchAA
commit "Changes on Branch AA"
cd $WD

# Branch B
puts "==============================="
puts "MAKING BRANCH B"
newbranch cvs_test HEAD branchB
cd $WD/cvs_test_branchB
modfiles
writefile FbranchB.txt 1
addfile FbranchB.txt branchB
commit "Add file FB on BranchB"
cd $WD
}
# Leave the trunk with uncommitted changes
puts "==============================="
puts "Uncommitted changes on trunk"
cd $WD/cvs_test_trunk
# Local only
writefile FileLocal.txt 1
# Newly added
writefile FileAdd.txt 2
addfile FileAdd.txt trunk
# Deleted
delfile File3.txt trunk
# Modify
writefile File2.txt 2
# Conflict
conflict Ftrunk.txt
cd $WD

# Remove the source
file delete -force -- cvs_test

