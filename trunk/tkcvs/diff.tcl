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

proc comparediff_r {rev1 rev2 dir parent args} {
#
# This diffs a file with the repository, using two revisions or tags.
#
  global cvscfg
 
  gen_log:log T "ENTER ($rev1 $rev2 $dir $args)"

  if {$rev1 == {} && $rev2 == {}} {
    cvsfail "Must have at least one revision number or tag for this function!" $parent
    return 1
  }

  if {$rev1 != {}} { set rev1 "-r \"$rev1\"" }
  if {$rev2 != {}} { set rev2 "-r \"$rev2\"" }
 
  # dont join args because we dont get them from workdir_list_files
  foreach file $args {
    set cwd [pwd]
    if {[catch {cd $dir}]} {
        cvsfail "unable to access $dir" $parent
        gen_log:log T "LEAVE unable to access $dir"
        return
    }

    #this should already be done when we get here
    #regsub -all {\$} $file {\$} file
    set commandline "$cvscfg(tkdiff) $rev1 $rev2 \"$file\""
    gen_log:log C "$commandline"
    catch {eval "exec $commandline &"} view_this
  }
  gen_log:log T "LEAVE"

  if {[catch {cd $cwd}]} {
      # FIXME: WTF do we do now?!?
      gen_log:log T "LEAVE unable to return to $cwd"
      return
  }
  
}

