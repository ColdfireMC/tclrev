#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" -- ${1+"$@"}


proc cleanup_old {root} {
  if {[ file isdirectory $root ]} {
    puts "Deleting $root"
    file delete -force $root
  }
  set oldirs [glob -nocomplain -- git_test*]
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
  set exec_cmd "git init --separate-git-dir $Root git_test_master"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  if {$ret} {
    puts $out
    puts "COULD NOT CREATE REPOSITORY $Root"
    exit 1
  }
  puts "CREATED $Root"

  # Git needs to know our email or else it won't commit
  cd $topdir
  set exec_cmd "whoami"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} myname]
  if {$ret} {
    puts $myname
  }
  set exec_cmd "hostname"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} host]
  if {$ret} {
    puts $host
  }
  set mymail "$myname@$host"
  set exec_cmd "git config user.name $myname"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  if {$ret} {
    puts $out
  }
  set exec_cmd "git config user.email $mymail"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  if {$ret} {
    puts $out
  }
  puts "==============================="
  puts "IMPORTING FILETREE"
  # Import it
  set wd [pwd]
  foreach dir {. Dir1 "Dir 2"} {
    cd $dir
    set exec_cmd "git add --verbose ."
    puts "$exec_cmd"
    set ret [catch {eval "exec $exec_cmd"} out]
    puts $out
    cd $wd
  }
  # See what we did
  set exec_cmd "git status"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  puts "IMPORT FINISHED"
  cd $WD
}

proc checkout_branch {proj tag} {
  global Root
  puts "==============================="
  puts "CHECKING OUT $tag"
  # Check out 
  #if {$tag eq "master"} {
    set exec_cmd "git clone -v $Root git_test_$tag"
  #} else {
    #set exec_cmd "git clone $Root co -d git_test_$tag $proj"
  #}
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  puts "CHECKOUT FINISHED"
}

proc newbranch {proj oldtag newtag} {
  set exec_cmd "cvs -d $Root rtag -r $oldtag -b $newtag $proj"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out

  puts "CHECKING OUT BRANCH"
  set exec_cmd "cvs -d $Root co -r $newtag -d ${proj}_$newtag git_test"
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
  #set exec_cmd "git add $filename"
  #puts "$exec_cmd"
  #set ret [catch {eval "exec $exec_cmd"} out]
  #puts $out
}

proc addfile {filename branch} {
  puts "Add $filename on $branch"
  set exec_cmd "git add --verbose $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

proc stage {filename} {
  puts "Stage $filename"
  set exec_cmd "git add --verbose $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

proc delfile {filename branch} {
  puts "Delete $filename on $branch"
  file delete $filename
  set exec_cmd "git rm -r $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

proc commit {comment} {
  # It seems to need the email all over again in a cloned directory
  set exec_cmd "whoami"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} myname]
  if {$ret} {
    puts $myname
  }
  set exec_cmd "hostname"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} host]
  if {$ret} {
    puts $host
  }
  set mymail "$myname@$host"
  set exec_cmd "git config user.name $myname"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  if {$ret} {
    puts $out
  }
  set exec_cmd "git config user.email $mymail"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  if {$ret} {
    puts $out
  }

  # Finally, do it
  set exec_cmd "git commit -m \"$comment\""
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

##############################################
# Branching isn't implemented yet
set branching_desired 0

for {set i 0} {$i < [llength $argv]} {incr i} {
  set arg [lindex $argv $i]

  switch -regexp -- $arg {
    {^--*nobranch.*} {
      set branching_desired 0; incr i
    }
  }
}

if [file isdirectory .git] {
  puts "Please don't do that here.  There's already a .git directory."
  exit 1
}

set WD [pwd]
set Root [file join $WD "GIT_REPOSITORY"]

cleanup_old $Root

mkfiles "git_test_master"
repository $Root "git_test_master"

# So far so good
cd git_test_master
commit "Commit the staged tree"
cd $WD

puts "==============================="
puts "First revision on trunk"
cd git_test_master
modfiles
writefile Ftrunk.txt 2
addfile Ftrunk.txt trunk
commit "First revision on trunk"
cd $WD

if {$branching_desired} {
puts "==============================="
puts "MAKING BRANCH A"
newbranch git_test HEAD branchA
cd $WD/git_test_branchA
writefile FbranchA.txt 2
addfile FbranchA.txt branchA
commit "Add file FbranchA.txt on branchA"
cd $WD
}

puts "==============================="
puts "Second revision on trunk"
cd $WD/git_test_master
modfiles
stage .
cd $WD

if {$branching_desired} {
puts "==============================="
puts "First revision on Branch A"
cd $WD/git_test_branchA
modfiles
commit "First revision on branchA"
cd $WD
}

puts "==============================="
# Make another modification on each
puts "Third revision on trunk"
cd $WD/git_test_master
modfiles
commit "Third revision on trunk"
cd $WD

if {$branching_desired} {
puts "==============================="
puts "Second revision on Branch A"
cd $WD/git_test_branchA
modfiles
commit "Second revision on branchA"
cd $WD

# Branch off of the branch
puts "==============================="
puts "MAKING BRANCH AA"
newbranch git_test branchA branchAA
cd $WD/git_test_branchAA
modfiles
writefile FbranchAA.txt 2
addfile FbranchAA.txt branchAA
delfile Ftrunk.txt branchAA
commit "Changes on Branch AA"
cd $WD

# Branch B
puts "==============================="
puts "MAKING BRANCH B"
newbranch git_test HEAD branchB
cd $WD/git_test_branchB
modfiles
writefile FbranchB.txt 1
addfile FbranchB.txt branchB
commit "Add file FB on BranchB"
cd $WD
}

# Leave the trunk with uncommitted changes
puts "==============================="
puts "Uncommitted changes on trunk"
cd $WD/git_test_master
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
#conflict Ftrunk.txt
cd $WD


