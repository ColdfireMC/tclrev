#
# TCL Library for TkCVS
#

#
# $Id: modules.tcl,v 1.27 2002/11/10 05:56:14 dorothyr Exp $
#
# Procedures to parse the CVS modules file and store whatever is
# read into various associative arrays, sorted, and unsorted lists.
#

#
# Global variables:
#
# modval
#   The string that specifies or defines the module.
# modtitle
#   The descriptive title of the module.  If not specified, modval is used.
# cvscfg
#   General configuration variables (array)
# filenames
#   For each module, the list of files that it contains.

proc gather_mod_index {} {
#
# Creates a new global list called modlist for the report printouts
#
  global cvscfg
  global modtitle
  global dcontents
  global dparent
  global modlist
  global modlist_sorted

  gen_log:log T "ENTER ()"
  set modlist {}
  set dlist {}
  if {! [info exists modtitle]} {
    gen_log:log T "LEAVE (no modtitle array)"
    return
  }
  foreach d [array names dcontents] {
    #gen_log:log D "dcontents($d) is $dcontents($d)"
    foreach i $dcontents($d) {
      lappend dlist $i
      set path [file join $d $i]
      set dparent($path) $d
      #gen_log:log D "dparent($path) is $d"
    }
  }
  foreach mcode [array names modtitle] {
    # Skip aliases
    if {[string match "-a *" $modtitle($mcode)]} {
      continue
    }
    # Dont add subdirs to the list
    set match 0
    foreach i $dlist {
      if {$i == $mcode} {
        set match 1
      }
    }
    if {! $match} {
      lappend modlist "$mcode\t$modtitle($mcode)"
    }
  }

  set modlist_sorted [lsort $modlist]
  if {$cvscfg(logging) && [regexp -nocase {d} $cvscfg(log_classes)]} {
    foreach idx $modlist_sorted {
      gen_log:log D "$idx"
      set dname [lindex $idx 0]
      if {[info exists dparent($dname)]} {
        gen_log:log D "   PARENT: $dparent($dname)"
      }
      if {[info exists dcontents($dname)]} {
        gen_log:log D "   CHILDREN: $dcontents($dname)"
      }
      set desc [find_subdirs $dname 0]
      if {$desc != ""} {
        gen_log:log D "   SUBDIRS: $desc"
      }
    }
  }
  gen_log:log T "LEAVE"
}

proc find_filenames {mcode} {
#
# This does the work of setting up the filenames array for a module,
# containing the list of file names within it.
#
  global filenames
  global cwd
  global cvs
  global cvsglb
  global cvscfg
  global checkout_version
  global feedback

  gen_log:log T "ENTER ($mcode)"

  if {[info exists filenames($mcode)]} {
    set filenames($mcode) ""
  }

  # Trick of using rdiff to list files without checking them out
  # derived from "cvsls" by Eugene Kramer
  # cvs 1.9:
  #  Need to use -f with pserver, or it skips files that havent
  #  changed.  With local repository, it reports them as new.
  # But without pserver, it skips them with -f but not without!
  # cvs 1.10.8:
  #  Both pserver and local act like 1.9 local, that is, -f makes
  #  it skip new files.
  set commandline \
     "$cvs -d $cvscfg(cvsroot) rdiff -s -D 01/01/1971 $mcode"
  gen_log:log C  $commandline
  catch {eval "exec $commandline"} view_this
   
  set view_lines [split $view_this "\n"]
  foreach line $view_lines {
    gen_log:log D "$line"
    if {[string match "File *" $line]} {
      set lst [split $line]
      set cut [expr {[llength $lst] - 6}]
      set dname [join [lrange $lst 1 $cut]]
      gen_log:log D "$dname"
      lappend filenames($mcode) $dname
    }
  }
  gen_log:log T "LEAVE"
}

proc find_subdirs {mname level} {
  global dcontents
  global subdirs

  #gen_log:log T "ENTER ($mname $level)"
  if {$level == 0} {
    set subdirs {}
  }
  if {[info exists dcontents($mname)]} {
    #gen_log:log D "$mname contents: {$dcontents($mname)}"
    foreach d $dcontents($mname) {
      set path [file join $mname $d]
      if {[info exists dcontents($path)]} {
        lappend subdirs $path
      }
      find_subdirs $path 1
    }
  }
  #gen_log:log T "LEAVE ($subdirs)"
  return $subdirs
}
