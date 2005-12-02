proc comparediff {args} {
#
# This diffs a file with the repository.
#
  global cvscfg

  gen_log:log T "ENTER ($args)"

  set filelist [join $args]
  if {$filelist == ""} {
    cvsfail "Please select one or more files to compare!" .workdir
  } else {
    foreach file $filelist {
      regsub -all {\$} $file {\$} file
      gen_log:log C "$cvscfg(tkdiff) \"$file\""
      catch {eval "exec $cvscfg(tkdiff) \"$file\" &"} view_this
    }
  }
  gen_log:log T "LEAVE"
}

proc comparediff_r {rev1 rev2 parent args} {
#
# This diffs a file with the repository, using two revisions or tags.
#
  global cvscfg
 
  gen_log:log T "ENTER ($rev1 $rev2 $args)"

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
 
  # dont join args because we dont get them from workdir_list_files
  foreach file $args {
    set commandline "$cvscfg(tkdiff) $rev1 $rev2 \"$file\""
    gen_log:log C "$commandline"
    catch {eval "exec $commandline &"} view_this
  }
  gen_log:log T "LEAVE"
}

proc comparediff_sandbox {rev1 rev2 parent file} {
#
# This diffs two revisions of a file that's not checked out
#
  global cvscfg
 
  gen_log:log T "ENTER ($rev1 $rev2 $file)"

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
 
  set commandline "$cvscfg(tkdiff) $rev1 $rev2 \"$file\""
  gen_log:log C "$commandline"
  cvs_sandbox_runcmd $commandline view_this

  gen_log:log T "LEAVE"
}
