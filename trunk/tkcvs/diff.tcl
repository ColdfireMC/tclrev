# NOTE: tkdiff exit status is nonzero if there are differences, so we
# can't take it to mean failure

proc comparediff {args} {
#
# This diffs a file with the repository (tkdiff <file>)
#
  global cvscfg

  gen_log:log T "ENTER ($args)"

  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select one or more files to compare!" .workdir
  } else {
    foreach file $filelist {
      regsub -all {\$} $file {\$} file
      gen_log:log C "$cvscfg(tkdiff) $file"
      set ret [catch {eval "exec $cvscfg(tkdiff) \"$file\" &"} view_this]
      if {$ret} { cvsfail $view_this .workdir }
    }
  }
  gen_log:log T "LEAVE"
}

# Two files or two SVN URLs
proc comparediff_files {parent file1 file2} {
  global cvscfg

  gen_log:log T "ENTER ($file1 $file2)"
  gen_log:log C "$cvscfg(tkdiff) \"$file1\" \"$file2\""
  set ret [catch {eval "exec $cvscfg(tkdiff) \"$file1\" \"$file2\" &"} view_this]
  if {$ret} { cvsfail $view_this $parent }
  gen_log:log T "LEAVE"
}

proc comparediff_r {rev1 rev2 parent filename} {
#
# This diffs versions of a file, using one or two revisions (tkdiff -r1 [-r2] file)
#
  global cvscfg
  global insvn
 
  gen_log:log T "ENTER (\"$rev1\" \"$rev2\" $filename)"

  if {$rev1 == {} && $rev2 == {}} {
    cvsfail "Must have at least one revision number or tag for this function!" $parent
    return 1
  }

  if {$rev1 != {}} {
    if {$insvn} {
      set rev1 [string trimleft $rev1 {r}]
    }
    set rev1 "-r $rev1"
  }
  if {$rev2 != {}} {
    if {$insvn} {
      set rev2 [string trimleft $rev2 {r}]
    }
    set rev2 "-r $rev2"
  }
 
  set commandline "$cvscfg(tkdiff) $rev1 $rev2 $filename"
  gen_log:log C "$commandline"
  set ret [catch {eval "exec $commandline &"} view_this]
  if {$ret} { cvsfail $view_this $parent }
  gen_log:log T "LEAVE"
}

proc comparediff_sandbox {rev1 rev2 parent filename} {
#
# This diffs two revisions of a file that's not checked out
#
  global cvscfg
 
  gen_log:log T "ENTER (\"$rev1\" \"$rev2\" $filename)"

  if {$rev1 == {} && $rev2 == {}} {
    cvsfail "Must have at least one revision number or tag for this function!" $parent
    return 1
  }

  if {$rev1 != {}} {
    set rev1 [string trimleft $rev1 {r}]
    set rev1 "-r \"$rev1\""
  }
  if {$rev2 != {}} {
    set rev2 [string trimleft $rev2 {r}]
    set rev2 "-r \"$rev2\""
  }
 
  set commandline "$cvscfg(tkdiff) $rev1 $rev2 $filename"
  gen_log:log C "$commandline"
  cvs_sandbox_runcmd $commandline view_this

  gen_log:log T "LEAVE"
}
