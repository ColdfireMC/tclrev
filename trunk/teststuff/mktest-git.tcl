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

proc clone {Root Clone} {
  puts "==============================="
  puts "CLONING"
  #set exec_cmd "git clone --bare $Root $Clone"
  set exec_cmd "git clone $Root $Clone"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  # For some reason catch returns 1 even though it succeeded
  puts $out
  if {! [file exists $Clone/.git] && ! [file exists $Clone/config]} {
    puts "COULD NOT CLONE REPOSITORY $Root to $Clone"
    exit 1
  }
}

proc repository {Root} {
  global WD

  puts "==============================="
  puts "MAKING REPOSITORY $Root"

  # Create the repository
  #file mkdir $Root
  set exec_cmd "git init $Root"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  if {$ret} {
    puts "COULD NOT CREATE REPOSITORY $Root"
    exit 1
  }
  puts "CREATED $Root"

  # Git needs to know our email or else it won't commit
  cd $Root
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
  #set wd [pwd]
  #foreach dir {. Dir1 "Dir 2"} {
    #cd $dir
    set exec_cmd "git add --verbose ."
    puts "$exec_cmd"
    set ret [catch {eval "exec $exec_cmd"} out]
    puts $out
    #cd $wd
  #}
  # See what we did
  set exec_cmd "git status"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  puts "IMPORT FINISHED"
  cd $WD
}

proc newbranch {oldtag newtag} {
  global WD

  set exec_cmd "git clone -v $WD/$Root git_test_$newtag"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out

  cd git_test_$newtag
  set exec_cmd "git branch $newtag"
  cd $WD

  commit "commit for branchA"

  puts "CHECKING OUT BRANCH"
  cd git_test_$newtag
  set exec_cmd "git checkout $newtag"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  if {$ret} {
    exit 1
  }
  puts "CHECKOUT FINISHED"
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

proc push {branch} {
  #global WD

  #cd git_test_$branch
  set exec_cmd "git push --set-upstream origin master"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  if {$ret} {
    puts "PUSH FAILED"
    exit 1
  }
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
# Branching isn't working yet
set branching_desired 0

for {set i 0} {$i < [llength $argv]} {incr i} {
  set arg [lindex $argv $i]

  switch -regexp -- $arg {
    {^--*nobranch.*} {
      set branching_desired 0; incr i
    }
  }
}

if [file exists .git] {
  puts "Please don't do that here.  There's already a .git directory."
  exit 1
}

set WD [pwd]
set Root [file join $WD "GIT_REPOSITORY"]
set Clone "git_test_master"

cleanup_old $Root

mkfiles $Root
repository $Root

# So far so good
cd $Root
commit "Commit the imported files"
cd $WD

# Clone it
clone $Root $Clone

# Make some changes
puts "==============================="
puts "First revision on trunk"
cd $Clone
modfiles
writefile Ftrunk.txt 2
addfile Ftrunk.txt master
commit "First revision on trunk"
cd $WD

exit

puts "==============================="
puts "MAKING BRANCH A"
newbranch clone_master branchA
cd $WD/git_test_branchA
writefile FbranchA.txt 2
addfile FbranchA.txt branchA
commit "Add file FbranchA.txt on branchA"
cd $WD

exit

puts "==============================="
puts "Second revision on trunk"
cd $WD/$Clone
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
cd $WD/$Clone
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
cd $WD/$Clone
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

