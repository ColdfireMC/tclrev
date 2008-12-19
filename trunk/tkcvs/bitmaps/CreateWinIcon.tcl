#! /usr/bin/env wish

package require Tk

lappend auto_path "/usr/local/tcllib1.11.1" "/usr/local/tcl/tklib0.4.1" "." "lib"
package require ico

# the original graphics file must be a GIF with dimen 48x48
# (PNG doesn't work, for tk doesn't know about it)
set orig [lindex $argv end]
set icoFile tclkit.ico

image create photo temp48 -file $orig
::ico::writeIcon $icoFile 0 8 temp48

if {[image width temp48] != 48 || [image height temp48] != 48} {
  puts stderr "'$orig' is not an 48x48 image file"
  exit
}

pack [label .i -image temp48]
pack [label .l -textvariable state -width 18]

set pos -1
foreach s {48 32 16} {
  set name [format "temp%s" $s]
  set geom [format %dx%d $s $s]
  set state "$geom @ 256"; update idle;

  exec convert -geometry $geom -colors 256 $orig $name.gif
  image create photo $name -file $name.gif
  ::ico::writeIcon $icoFile [incr pos] 8 $name

  set state "$geom @ 16"; update idle;
  exec convert -geometry $geom -colors 16 $orig r$name.gif
  image create photo r$name -file r$name.gif
  ::ico::writeIcon $icoFile [incr pos] 4 r$name
  file delete $name.gif r$name.gif
}

set state "DONE\nIcon file is $icoFile"
pack [button .b -text "EXIT" -command exit]
