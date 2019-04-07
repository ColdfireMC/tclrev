#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" -- ${1+"$@"}


proc cleanup_old {root} {
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

# Make something that uses the CVSROOT/modules functionality
proc module_file {} {
  global env
  global WD

  puts "==============================="
  puts "EDITING MODULE FILE"

  set exec_cmd "cvs -d $env(CVSROOT) co CVSROOT/modules"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  if {$ret} {
    puts $out
    puts "COULD NOT CHECK OUT CVSROOT/modules"
    exit 1
  }
  cd CVSROOT
  set mf [open "modules" a]
  puts $mf "#D\tcvs_test\tSome files under CVS control"
  puts $mf "cvs_test\tcvs_test"
  close $mf
  set exec_cmd "cvs ci -m\"Add\\\ a\\\ module\\\ and\\\ a\\\ #D\\\ line\" modules"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  if {$ret} {
    puts $out
    puts "COULD NOT CHECK IN CVSROOT/modules"
    cd $WD
    exit 1
  }
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

proc merge {fromtag totag} {
  global WD

  cd cvs_test_$totag
  # This will fail if there are conflicts
  set exec_cmd "cvs update -d -j$fromtag ."
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  commit "Merge $fromtag to $totag"
  set date  [clock format [clock seconds] -format "%H-%M-%S"]
  # First, the "from" file that's not in this branch (needs -r)
  set exec_cmd "cvs tag -F -r$fromtag mergeto_${totag}_$date ."
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # Now, the version that's in the current branch
  set exec_cmd "cvs tag -F mergefrom_${fromtag}_$date ."
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # Clean up the merge files
  file delete [glob -nocomplain -- .#* */.#*]

  cd $WD
}

proc writefile {filename string} {
  puts " append \"$string\" to $filename"
  set fp [open "$filename" a]
  puts $fp $string
  close $fp
}

proc addfile {filename branch} {
  puts "Add $filename on $branch"
  set exec_cmd "cvs add $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

proc delfile {filename branch} {
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

  # Make some text files
  foreach n {1 2 3} {
    writefile "File$n.txt" "Initial"
  }
  foreach D {Dir1 "Dir 2"} {
    puts $D
    file mkdir $D
    foreach n {1 2 " 3"} {
      set subf [file join $D "F$n.txt"]
      writefile $subf "Initial"
    }
  }
  cd $WD
}

proc modfiles {string} {
  global tcl_platform

  set tmpfile "list.tmp"

  file delete -force $tmpfile
  if {$tcl_platform(platform) eq "windows"} {
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
    writefile $item $string
  }
  close $fl
  file delete -force $tmpfile
}

proc getrev {filename} {
  # Find out current revision

  set exec_cmd "cvs log -b $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  foreach logline [split $out "\n"] {
    if {[string match "revision *" $logline]} {
      set latest [lindex $logline 1]
      break
    }
  }
  return $latest
}

proc conflict {filename} {
  # Create a conflict

  set latest [getrev $filename]
  # Save a copy
  file copy $filename Ftmp.txt
  # Make a change
  writefile $filename "conflict A"
  set exec_cmd "cvs commit -m \"change1\" $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # Check out latest revision
  set exec_cmd "cvs update -r $latest $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # Make a different change (we hope)
  file delete -force -- $filename
  file rename Ftmp.txt $filename
  writefile $filename "conflict B"
  # Check out head, which now conflicts with our change
  set exec_cmd "cvs update -r HEAD $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

##############################################
set branching_desired 1
set leave_a_mess 1

for {set i 0} {$i < [llength $argv]} {incr i} {
  set arg [lindex $argv $i]

  switch -regexp -- $arg {
    {^--*nobranch.*} {
      set branching_desired 0; incr i
    }
    {^--*nomess.*} {
      set leave_a_mess 0; incr i
    }
  }
}

if [file isdirectory CVS] {
  puts "Please don't do that here. There's already a CVS directory."
  exit 1
}

set WD [pwd]
set Root [file join $WD "CVS_REPOSITORY"]
set env(CVSROOT) ":local:$Root"

cleanup_old $Root

mkfiles "cvs_test"
repository $Root "cvs_test"
module_file
checkout_branch "cvs_test" "trunk"

puts "==============================="
puts "First revision on trunk"
cd cvs_test_trunk
modfiles "Main 1"
writefile Ftrunk.txt "Main 1"
addfile Ftrunk.txt trunk
commit "First revision on trunk"
cd $WD

if {$branching_desired} {
  puts "==============================="
  puts "MAKING BRANCH A"
  newbranch cvs_test HEAD branchA
  cd $WD/cvs_test_branchA
  writefile FbranchA.txt "BranchA 1"
  addfile FbranchA.txt branchA
  commit "Add file FbranchA.txt on branch A"
  cd $WD

  puts "==============================="
  puts "First revision on Branch A"
  cd $WD/cvs_test_branchA
  modfiles "BranchA 1"
  commit "First revision on branch A"
  cd $WD

  puts "==============================="
  puts "Second revision on Branch A"
  cd $WD/cvs_test_branchA
  modfiles "BranchA 2"
  commit "Second revision on branch A"
  cd $WD

  # Branch C
  puts "==============================="
  puts "MAKING BRANCH C FROM SAME ROOT"
  newbranch cvs_test HEAD branchC
  cd $WD/cvs_test_branchC
  modfiles "BranchC 1"
  writefile FbranchC.txt "BranchC 1"
  addfile FbranchC.txt branchC
  commit "Add file FC on Branch B"
  cd $WD

  puts "==============================="
  puts "Merging BranchA to trunk"
  merge branchA trunk
  cd $WD
}

# Make more modifications on trunk
puts "==============================="
puts "Second revision on trunk"
cd $WD/cvs_test_trunk
modfiles "Main 2"
commit "Second revision on trunk"
cd $WD

puts "==============================="
puts "Third revision on trunk"
cd $WD/cvs_test_trunk
modfiles "Main 3"
commit "Third revision on trunk"
cd $WD

if {$branching_desired} {
  # Branch off of the branch
  puts "==============================="
  puts "MAKING BRANCH AA"
  newbranch cvs_test branchA branchAA
  cd $WD/cvs_test_branchAA
  modfiles "BranchAA 1"
  writefile FbranchAA.txt "BranchAA 1"
  addfile FbranchAA.txt branchAA
  delfile Ftrunk.txt branchAA
  commit "Changes on Branch AA"
  cd $WD

  # Branch B
  puts "==============================="
  puts "MAKING BRANCH B"
  newbranch cvs_test HEAD branchB
  cd $WD/cvs_test_branchB
  modfiles "BranchB 1"
  writefile FbranchB.txt "BranchB 1"
  addfile FbranchB.txt branchB
  commit "Add file FB on Branch B"
  cd $WD
}

if {$leave_a_mess} {
  # Leave the trunk with uncommitted changes
  puts "==============================="
  puts "Making Uncommitted changes on trunk"
  cd $WD/cvs_test_trunk
  # Local only
  writefile FileLocal.txt "Pending"
  # Newly added
  writefile FileAdd.txt "Pending"
  addfile FileAdd.txt trunk
  # Deleted
  delfile File3.txt trunk
  # Modify
  writefile File2.txt "Pending"
  writefile "Dir1/F 3.txt" "Pending"
  writefile "Dir1/F2.txt" "Pending"
  writefile "Dir 2/F1.txt" "Pending"
  # Conflict
  conflict Ftrunk.txt
  cd $WD
}

# Remove the source
file delete -force -- cvs_test

