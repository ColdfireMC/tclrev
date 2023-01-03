#!/usr/bin/env tclsh 
  # tclrev entry
lappend auto_path [pwd]
#auto_mkindex ./
array set repo ""   
array set cvsglb ""
array set cvscfg ""
set repotype_default ""
set repotype ""  
if {[info exists argv]} {
    tclrevinit
    parse_args argv
    srcctrlchk    
} else {   
    usgprint
}
exit                                        
