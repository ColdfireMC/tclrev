#!/usr/bin/perl -w

open(HELP, "help.tcl") || die("Can't open helpl.tcl");
  
print ".TH TkCVS 1 Release 8.0.4+\n";
print ".SH NAME\n";
print "TkCVS \- a Tk/Tcl Graphical Interface to CVS and Subversion\n";
print ".SH SYNOPSIS\n";
print ".B tkcvs\n";
print "[\\-dir directory] [\\-root cvsroot] [\\-win workdir|module|merge] [\\-log file]\n";

while(<HELP>) {
  if (/^\s+do_help.*{/) {
    while(<HELP>) {
      chomp;
      if (/\s+}/) {
        print ".SP\n";
        last;
      }
      if (/^\s*$/) { next; }
      # Turn h1 into Section Head
      s/<h1>(.*)<\/h1>/.SH $1/;
      # Turn h2 into Section Subhead
      s/<h2>(.*)<\/h2>/.SS $1/;
      # Make h3 start a hanging indent
      s/<h3>(.*)<\/h3>/.TP\n.B $1/;
      if (/<itl>/) {
        if ($` =~ /^.TP/) {
          s/\.B /.BI /;
          s/<itl>(.*)<\/itl>/" $1"/;
        } else {
          s/<itl>(.*)<\/itl>/.TP\n.I $1/;
        }
        #print STDERR "$_\n";
      }
        #print STDERR "$` + $& + $'\n";
        #print STDERR "$_\n";
      if ($& =~ /do_help/) {
        # This decides whether its a free paragraph, in which case
        # it needs a space above it.
        print ".LP\n";
      }
      s/<bld>(.*)<\/bld>/\\fB$1\\fR/;
      s/<cmp>(.*)<\/cmp>/.RS\n$1\n.RE/;
      print;
      print "\n";
    }
  }
}

print ".SH SEE ALSO\n";
print "cvs(1), svn(1)\n";
print ".SH AUTHOR\n";
print "Del (del\@babel.babel.com.au): Maintenance and Subversion support: Dorothy Robinson\n";

close HELP;
