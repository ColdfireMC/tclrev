#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" -- ${1+"$@"}


proc cleanup_old {root} {
  if {[ file isdirectory $root ]} {
    puts "Deleting $root"
    file delete -force $root
  }
  set oldirs [glob -nocomplain -- git_test**]
  foreach od $oldirs {
    puts "Deleting $od"
    file delete -force $od
  }
}

proc clone {Root Clone} {
  puts "==============================="
  puts "CLONING"
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

proc worktree {Root Branch} {
  puts "==============================="
  puts "MAKING WORKTREE"
  cd $Root
  set exec_cmd "git worktree add --track -b branch$Branch ../git_test_wtree$Branch"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  cd ..
}

proc repository {Root} {
  puts "==============================="
  puts "MAKING REPOSITORY $Root"

  # Create the repository
  #file mkdir $Root
  set exec_cmd "git init --bare $Root"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  if {$ret} {
    puts "COULD NOT CREATE REPOSITORY $Root"
    exit 1
  }
  puts "CREATED $Root"
}

proc populate {clone} {
  global WD

  mkfiles $clone
  # Git needs to know our email or else it won't commit
  cd $clone
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
  set exec_cmd "git add --verbose ."
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
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

  puts "==============================="
  puts "Creating new $newtag"
  puts "In [pwd]"
  cd git_test_$oldtag
  puts "In [pwd]"
  set exec_cmd "git branch --track $newtag"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  if {$ret} {
    puts $out
    exit
  }
  set exec_cmd "git checkout $newtag"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out

  cd $WD
  puts "\nIn [pwd]"
  puts "Cloning $oldtag to a new directory for $newtag"
  set exec_cmd "git clone git_test_$oldtag git_test_$newtag"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out

  puts "Restoring git_test_$oldtag to $oldtag"
  cd git_test_$oldtag
  puts "In [pwd]"
  set exec_cmd "git checkout $oldtag"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out

  cd $WD
}

proc merge {fromtag totag} {
  global WD

  cd git_test_$totag
  set exec_cmd "git merge --no-ff $fromtag"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out

  # This works but isn't necessary for an arrow.
  #set date [clock format [clock seconds] -format "%H-%M-%S"]
  # First, tag the "from" file that's not in this branch
  #set exec_cmd "git tag -a mergeto_${totag}_$date -m \"Merge $fromtag to $totag\" $fromtag"
  #puts "$exec_cmd"
  #set ret [catch {eval "exec $exec_cmd"} out]
  #if {$ret} {
    #puts $out
    #exit 1
  #}
  # Now, the version that's in the current branch
  #set exec_cmd "git tag -a mergefrom_${fromtag}_$date -m \"Merge $fromtag to $totag\""
  #puts "$exec_cmd"
  #set ret [catch {eval "exec $exec_cmd"} out]
  #if {$ret} {
    #puts $out
    #exit 1
  #}
  #set exec_cmd "git push origin mergeto_${totag}_$date"
  #set ret [catch {eval "exec $exec_cmd"} out]
  #puts $out
  #set exec_cmd "git push origin mergefrom_${fromtag}_$date"
  #set ret [catch {eval "exec $exec_cmd"} out]
  #puts $out

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
  set exec_cmd "git add --verbose $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
}

proc stage {} {
  puts "Stage [pwd]"
  set exec_cmd "git add --verbose *"
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

proc push {origin} {
  puts "==============================="
  set exec_cmd "git push $origin"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  if {$ret} {
    if {[string match {fatal*} $out]} {
      exit 1
    }
  }
}

proc fetch {{origin {}}} {
  puts "Fetching from $origin"
  set exec_cmd "git fetch "
  if {$origin != ""} {
    append exec_cmd " $origin"
  }
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
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
    set ret [catch {eval "exec find . -name F*.txt -a -type f > $tmpfile"} out]
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

proc conflict {filename} {
  # Create a conflict. In Git, this is done with a temporary branch.
 
  # Check out a new branch
  set exec_cmd "git checkout -b temp_branch"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  writefile $filename "Conflict A"
  set exec_cmd "git commit -m \"change on temp_branch\" $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # Check out head, which now conflicts with our change
  set exec_cmd "git checkout master"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  # Make a different change to same line
  writefile $filename "Conflict B"
  set exec_cmd "git commit -m \"change on master\" $filename"
  puts "$exec_cmd"
  set ret [catch {eval "exec $exec_cmd"} out]
  puts $out
  set exec_cmd "git merge temp_branch"
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

if [file exists .git] {
  puts "Please don't do that here.  There's already a .git directory."
  exit 1
}

set WD [pwd]
set Root [file join $WD "GIT_REPOSITORY.git"]
set Master "git_test_master"

cleanup_old $Root

# Create the bare "server" repo
repository $Root
# Clone it to one we can work in
clone $Root $Master
# Import some files
populate $Master
cd $Master
commit "Commit the imported files"
push ""
cd $WD

# Make some changes
puts "==============================="
puts "First revision on trunk"
cd $Master
modfiles "Main 1"
writefile Ftrunk.txt "Main 1"
addfile Ftrunk.txt master
stage
commit "First revision on trunk"
push ""
cd $WD

if {$branching_desired} {
  puts "==============================="
  puts "MAKING BRANCH A"
  newbranch master branchA
  cd $WD/git_test_branchA
  writefile FbranchA.txt "BranchA 1"
  addfile FbranchA.txt branchA
  stage
  commit "Add file FbranchA.txt on branch A"

  puts "==============================="
  puts "First revision on Branch A"
  modfiles "BranchA 1"
  stage
  commit "First revision on branch A"

  puts "==============================="
  puts "Second revision on Branch A"
  modfiles "BranchA 2"
  stage
  commit "Second revision on branch A"
  push ""
  cd $WD

  # Branch C
  puts "==============================="
  puts "MAKING BRANCH C FROM SAME ROOT"
  worktree git_test_master C
  cd $WD/git_test_wtreeC
  modfiles "BranchC 1"
  writefile FbranchC.txt "BranchC 1"
  addfile FbranchC.txt branchC
  stage
  commit "First changes on Branch C"
  cd $WD

  puts "==============================="
  puts "Merging BranchA to trunk"
  merge branchA master
  cd $WD
}

# Make more modifications on trunk
puts "==============================="
puts "Second revision on trunk"
cd $WD/$Master
fetch {--all}
modfiles "Main 2"
stage
commit "Second revision on trunk"

puts "==============================="
puts "Third revision on trunk"
modfiles "Main 3"
stage
commit "Third revision on trunk"
push ""
cd $WD

if {$branching_desired} {

  # Branch off of the branch
  puts "==============================="
  puts "MAKING BRANCH AA"
  worktree git_test_branchA AA
  cd $WD/git_test_wtreeAA
  modfiles "BranchAA 1"
  writefile FbranchAA.txt "BranchAA 1"
  addfile FbranchAA.txt branchAA
  delfile Ftrunk.txt branchAA
  stage
  commit "First changes on Branch AA"

  puts "==============================="
  puts "Revision on Branch AA"
  modfiles "BranchAA 2"
  stage
  commit "Second changes on Branch AA"
  #push ""
  #push $Root
  cd $WD

  # Branch B
  puts "==============================="
  puts "MAKING BRANCH B"
  worktree git_test_master B
  cd $WD/git_test_wtreeB
  modfiles "BranchB 1"
  writefile FbranchB.txt "BranchB 1"
  addfile FbranchB.txt branchB
  stage
  commit "First changes on Branch B"

  puts "==============================="
  puts "Revision on Branch B"
  modfiles "BranchB 2"
  stage
  commit "Second changes on Branch B"
  #push ""
  #push $Root
  cd $WD

  # Update the clones
  foreach branch {branchA master} {
    cd $WD/git_test_$branch
    push {--all}
    fetch {--all}
    cd $WD
  }
}

if {$leave_a_mess} {
  # Leave the trunk with uncommitted changes
  puts "==============================="
  puts "Making Uncommitted changes on trunk"
  cd $WD/$Master
  # Local only
  writefile FileLocal.txt "Pending"
  # Conflict. Have to do this before the add and delete,
  # or the merge will fail before you get to the conflicted file
  conflict Ftrunk.txt
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
  cd $WD
}
