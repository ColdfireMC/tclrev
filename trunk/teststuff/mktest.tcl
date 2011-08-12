#!/bin/sh
# the next line restarts using wish \
exec tclsh "$0" -- ${1+"$@"}

proc cleanup_old {} {
  global env

  #set oldfiles [glob -nocomplain -- Dir* File*]
  #if {$oldfiles ne ""} {
  #  puts "Deleting [llength $oldfiles] files -- $oldfiles"
  #  eval file delete -force $oldfiles
  #}

  if {[ file isdirectory $env(CVSROOT) ]} {
    if {[ info exists env(SystemDrive) ]} {
      puts "Must be a PC"
      file attributes -permissions u+w $env(CVSROOT)
    }
    file delete -force $env(CVSROOT)
  }
  set oldirs [glob -nocomplain -- cvs_test*]
  foreach od $oldirs {
    puts "Deleting $od"
    file delete -force-force  $od
  }
}

proc mkfiles {} {
  set wordlist {barcode braid greynetic maze mountain pacman triangle vidwhacker wander}
  foreach n {1 2 3} {
    # Make some files each containing a random word
    set ind [expr {int(rand()*[llength $wordlist])}]
    set word [lindex $wordlist $ind]
    set fp [open "File$n" w]
    puts $fp $word
    close $fp
  }
  foreach D {Dir1 "Dir 2"} {
    puts $D
    file mkdir $D
    foreach n {1 2} {
      set subf [file join $D "F$n"]
      set ind [expr {int(rand()*[llength $wordlist])}]
      set word [lindex $wordlist $ind]
      set fp [open $subf w]
      puts $fp $word
      close $fp
    }
    set subf [file join $D "F 4"]
    set fp [open $subf w]
    puts $fp $word
    close $fp
  }
}

set WD [pwd]
set env(CVSROOT) [file join $WD "CVS_REPOSITORY"]

cleanup_old

puts "MAKING FILETREE"
# Make some files to put in the repository
file mkdir "cvs_test"
cd cvs_test
mkfiles
cd $WD

# Create the repository
puts "MAKING REPOSITORY $env(CVSROOT)"
file mkdir $env(CVSROOT)
set ret [catch {eval "exec cvs -d $env(CVSROOT) init"} out]
if {$ret} {
  puts "COULD NOT CREATE REPOSITORY $env(CVSROOT)"
  puts $out
  exit 1
}
puts "CREATED $env(CVSROOT)"

puts "IMPORTING FILETREE"
cd cvs_test
# Import it
set ret [catch {eval "exec cvs -d $env(CVSROOT) import -m \"Imported\" cvs_test BEGIN baseline-1_1_1"} out]
if {$ret} {
  puts "Import failed"
  puts $out
  exit 1
}
puts "IMPORT FINISHED"
cd $WD
# clean up import directory
file delete -force cvs_test

puts "CHECKING OUT TRUNK"
# Check out the trunk
set ret [catch {eval "exec cvs -d $env(CVSROOT) co -d cvs_test_trunk cvs_test"} out]
if {$ret} {
  puts "Checout failed"
  puts $out
  exit 1
}
puts "CHECKOUT FINISHED"

exit


puts "First revision on trunk"
# Make a modification on trunk
cd cvs_test_trunk
$WD/modtest
# Random
R=`puts $WORDLIST | gawk '{print $((systime()%NF)+1)}'`
puts $R > FT
cvs add FT
cvs commit -m "First revision on trunk"
cd $WD

# Branch
puts "MAKING BRANCH A"
cvs -d $env(CVSROOT) rtag -b BranchA cvs_test
puts "CHECKING OUT BRANCH"
cvs -d $env(CVSROOT) co -r BranchA -d cvs_test_branchA cvs_test
cd cvs_test_branchA
# Random
R=`puts $WORDLIST | gawk '{print $((systime()%NF)+1)}'`
puts $R > FA
cvs add FA
cvs commit -m "Add file F3 on BranchA"
cd $WD

# Make modifications on branch and trunk
puts "Second revision on trunk"
cd cvs_test_trunk
$WD/modtest
cvs commit -m "Second revision on trunk"

puts "First revision on Branch A"
cd $WD/cvs_test_branchA
$WD/modtest
cvs commit -m "First revision on Branch A"
cd $WD

# Make another modification on each
puts "Third revision on trunk"
cd cvs_test_trunk
$WD/modtest
cvs commit -m "Third revision on trunk"

puts "Second revision on Branch A"
cd $WD/cvs_test_branchA
$WD/modtest
cvs commit -m "Second revision on Branch A"
cd $WD

# Branch off of the branch
puts "MAKING BRANCH AA"
cvs -d $env(CVSROOT) rtag -r BranchA -b BranchAA cvs_test
puts "CHECKING OUT BRANCH AA"
cvs -d $env(CVSROOT) co -r BranchAA -d cvs_test_branchAA cvs_test

# Make a change on that branch
cd cvs_test_branchAA
$WD/modtest
# Random
R=`puts $WORDLIST | gawk '{print $((systime()%NF)+1)}'`
puts $R > FAA
cvs add FAA
rm FT; cvs delete FT
cvs commit -m "Changes on Branch AA"
cd $WD

# Branch
puts "MAKING BRANCH B"
cvs rtag -b BranchB cvs_test
puts "CHECKING OUT BRANCH B"
cvs -d $env(CVSROOT) co -r BranchB -d cvs_test_branchB cvs_test
cd cvs_test_branchB
$WD/modtest
# Random
R=`puts $WORDLIST | gawk '{print $((systime()%NF)+1)}'`
puts $R > FB
cvs add FB
cvs commit -m "Add file FB on BranchB"
cd $WD

#### Stop here if you don't want the merges ####
exit 

cd $WD/cvs_test_trunk
puts "MERGING A -> trunk for file File1"
cvs update -j BranchA File1
# Resolve conflicts
sed -n '/^[a-z]/p' File1 > tmp; mv -f tmp File1
cvs ci -m "Merged to trunk from BranchA" File1

cd $WD/cvs_test_branchB
puts "Merging trunk -> BranchB for file File1"
cvs update -j HEAD File1
# Resolve conflicts
sed -n '/^[a-z]/p' File1 > tmp; mv -f tmp File1
cvs ci -m "Merged from trunk to BranchB" File1

# Make tags for tag-based merge arrow
cd $WD/cvs_test_trunk
cvs tag -r 1.2.2.2.2.1 mergeto_BranchA_20Nov08 File1
cvs tag -r 1.2.2.2 mergefrom_BranchAA_20Nov08 File1
cd $WD

