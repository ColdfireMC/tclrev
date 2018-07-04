#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" -- ${1+"$@"}


proc cleanup_old {root} {
  global env

  if {[ file isdirectory $root ]} {
    puts "Deleting $root"
    file delete -force $root
  }
  set oldirs [glob -nocomplain -- svn_test*]
  foreach od $oldirs {
    puts "Deleting $od"
    file delete -force $od
  }
  puts "==============================="
}

proc repository {Root topdir} {
  global taghead

  puts "==============================="
  puts "MAKING REPOSITORY $Root"

  # Create the repository
  file mkdir $Root
  set exec_cmd "svnadmin create $Root"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  if {$ret} {
    puts $out
    puts "COULD NOT CREATE REPOSITORY $Root"
    exit 1
  }
  puts "CREATED $Root"

  file mkdir [file join $topdir $taghead(trunk)]
  file mkdir [file join $topdir $taghead(branch)]
  file mkdir [file join $topdir $taghead(tag)]
  puts "==============================="
  puts "IMPORTING FILETREE"
  set exec_cmd "svn import $topdir file:///$Root -m \"Imported\""
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  puts "IMPORT FINISHED"
}

proc checkout_branch {Root tag} {
  global taghead

  puts "==============================="
  puts "CHECKING OUT $tag"
  # Check out 
  if {$tag eq $taghead(trunk)} {
    set exec_cmd "svn co file:///$Root/$taghead(trunk) svn_test_$tag"
  } else {
    set exec_cmd "svn co file:///$Root/$taghead(branch)/$tag svn_test_$tag"
  }
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  puts "CHECKOUT FINISHED"
}

proc newbranch {Root oldtag newtag} {
  global taghead

  if {$oldtag eq $taghead(trunk)} {
    set exec_cmd "svn copy file:///$Root/$oldtag file:///$Root/$taghead(branch)/$newtag -m \"Branch $newtag\""
  } else {
    set exec_cmd "svn copy file:///$Root/$taghead(branch)/$oldtag file:///$Root/$taghead(branch)/$newtag -m \"Branch $newtag\""
  }
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  puts "CHECKING OUT BRANCH"
  set exec_cmd "svn co file:///$Root/$taghead(branch)/$newtag svn_test_$newtag"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
}

proc merge {fromtag totag} {
  global WD

  cd svn_test_$totag
  set exec_cmd "svn update"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # This puts mergeinfo only into .
  # --- Recording mergeinfo for merge between repository URLs into '.'
  set exec_cmd "svn merge --reintegrate ^/branches/$fromtag"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  commit "Merge branchA to trunk"
  cd $WD
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
  set exec_cmd "svn add $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

proc delfile {filename branch} {
  global env

  puts "Delete $filename on $branch"
  file delete $filename
  set exec_cmd "svn delete $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

proc commit {comment} {
  set exec_cmd "svn commit -m \"$comment\""
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

proc mkfiles {topdir} {
  global WD
  global taghead

  puts "MAKING FILETREE"
  # Make some files to put in the repository
  set trunkhead [file join $topdir $taghead(trunk)]
  file mkdir $trunkhead

  cd $trunkhead

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
    set ret [catch {eval "exec find . -name F*.txt -o -name .svn -prune -a -type f > $tmpfile"} out]
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

proc getrev {filename} {
  # Find out current revision

  set exec_cmd "svn log -q $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  foreach logline [split $out "\n"] {
    if {[string match "r*" $logline]} {
      set latest [lindex $logline 0]
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
  writefile $filename 1
  set exec_cmd "svn commit -m \"change1\" $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # Check out latest revision
  set exec_cmd "svn update -r $latest $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # Make a different change (we hope)
  file delete -force -- $filename
  file rename Ftmp.txt $filename
  writefile $filename 2
  # Check out head, which now conflicts with our change
  set exec_cmd "svn update --non-interactive -r HEAD $filename"
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

if [file isdirectory .svn] {
  puts "Please don't do that here.  There's already a .svn directory."
  exit 1
}

set WD [pwd]
set SVNROOT [file join $WD "SVN_REPOSITORY"]
set taghead(trunk) "trunk"
set taghead(branch) "branches"
set taghead(tag) "tags"

cleanup_old $SVNROOT

mkfiles "svn_test"
repository $SVNROOT "svn_test"
checkout_branch "$SVNROOT" "$taghead(trunk)"

puts "==============================="
puts "First revision on $taghead(trunk)"
cd svn_test_$taghead(trunk)
modfiles
writefile Ftrunk.txt 2
addfile Ftrunk.txt $taghead(trunk)
commit "First revision on $taghead(trunk)"
cd $WD

if {$branching_desired} {
  puts "==============================="
  puts "MAKING BRANCH A"
  newbranch $SVNROOT $taghead(trunk) branchA
  cd $WD/svn_test_branchA
  writefile FbranchA.txt 2
  addfile FbranchA.txt branchA
  commit "Add file FbranchA.txt on branchA"
  cd $WD

  puts "==============================="
  puts "First revision on Branch A"
  cd $WD/svn_test_branchA
  modfiles
  commit "First revision on branchA"
  cd $WD

  puts "==============================="
  puts "Second revision on Branch A"
  cd $WD/svn_test_branchA
  modfiles
  commit "Second revision on branchA"
  cd $WD

  puts "==============================="
  puts "Merging BranchA to trunk"
  merge branchA trunk
  cd $WD
}

# Make more modifications on trunk
puts "==============================="
puts "Second revision on $taghead(trunk)"
cd $WD/svn_test_trunk
modfiles
commit "Second revision on $taghead(trunk)"
cd $WD

puts "==============================="
puts "Third revision on $taghead(trunk)"
cd $WD/svn_test_trunk
modfiles
commit "Third revision on $taghead(trunk)"
cd $WD

if {$branching_desired} {
  # Branch off of the branch
  puts "==============================="
  puts "MAKING BRANCH AA"
  newbranch $SVNROOT branchA branchAA
  cd $WD/svn_test_branchAA
  modfiles
  writefile FbranchAA.txt 2
  addfile FbranchAA.txt branchAA
  delfile Ftrunk.txt branchAA
  commit "Changes on Branch AA"
  cd $WD

  # Branch B
  puts "==============================="
  puts "MAKING BRANCH B"
  newbranch $SVNROOT $taghead(trunk) branchB
  cd $WD/svn_test_branchB
  modfiles
  writefile FbranchB.txt 1
  addfile FbranchB.txt branchB
  commit "Add file FB on BranchB"
}

# Leave the trunk with uncommitted changes
puts "==============================="
puts "Making Uncommitted changes on trunk"
cd $WD/svn_test_trunk
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
file delete -force -- svn_test

