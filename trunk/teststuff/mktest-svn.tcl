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
  set ret [catch {eval "exec svnadmin create $Root"} out]
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
  set ret [catch {eval "exec svn import $topdir file:///$Root -m \"Imported\""} out]
  puts $out
  puts "IMPORT FINISHED"
}

proc checkout_branch {Root tag} {
  global taghead

  puts "==============================="
  puts "CHECKING OUT $tag"
  # Check out 
  if {$tag eq $taghead(trunk)} {
    set ret [catch {eval "exec svn co file:///$Root/$taghead(trunk) svn_test_$tag"} out]
  } else {
    set ret [catch {eval "exec svn co file:///$Root/$taghead(branch)/$tag svn_test_$tag"} out]
  }
  puts $out
  puts "CHECKOUT FINISHED"
}

proc newbranch {Root oldtag newtag} {
  global taghead

  set ret [catch {eval "exec svn copy file:///$Root/$oldtag file:///$Root/$taghead(branch)/$newtag  -m \"Branch $newtag\""} out]
  puts $out
  puts "CHECKING OUT BRANCH"
  set ret [catch {eval exec "svn co file:///$Root/$taghead(branch)/$newtag"} out]
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
  set ret [catch {eval "exec svn add $filename"} out]
  puts $out
}

proc delfile {filename branch} {
  global env

  puts "Delete $filename on $branch"
  file delete $filename
  set ret [catch {eval "exec cvs delete $filename"} out]
  puts $out
}

proc commit {comment} {
  set ret [catch {eval "exec svn commit -m \"$comment\""} out]
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
    set ret [catch {eval "exec find . -name 'F*.txt' -o -name CVS -prune -a -type f > $tmpfile"} out]
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

##############################################

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
# When commit, get "svn: '/home/dorothyr/tksvn/teststuff' has no ancestry information"
# This is because tkstuff itself is in a (different) .svn root.
commit "First revision on $taghead(trunk)"
cd $WD

exit

puts "==============================="
puts "MAKING BRANCH A"
newbranch svn_test HEAD branchA
cd $WD/svn_test_branchA
writefile FbranchA.txt 2
addfile FbranchA.txt branchA
commit "Add file FbranchA.txt on branchA"
cd $WD

puts "==============================="
puts "Second revision on $taghead(trunk)"
cd $WD/svn_test_trunk
modfiles
commit "Second revision on $taghead(trunk)"
cd $WD

puts "==============================="
puts "First revision on Branch A"
cd $WD/svn_test_branchA
modfiles
commit "First revision on branchA"
cd $WD

puts "==============================="
# Make another modification on each
puts "Third revision on $taghead(trunk)"
cd $WD/svn_test_trunk
modfiles
commit "Third revision on $taghead(trunk)"
cd $WD

puts "==============================="
puts "Second revision on Branch A"
cd $WD/svn_test_branchA
modfiles
commit "Second revision on branchA"
cd $WD

# Branch off of the branch
puts "==============================="
puts "MAKING BRANCH AA"
newbranch svn_test branchA branchAA
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
newbranch svn_test HEAD branchB
cd $WD/cvs_test_branchB
modfiles
writefile FbranchB.txt 1
addfile FbranchB.txt branchB
commit "Add file FB on BranchB"
cd $WD

