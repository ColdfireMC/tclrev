#! /usr/bin/perl

use strict;
use warnings;

use AtExit;
use Getopt::Std;

# Temporary working directory
use constant TMP_DIR => '/tmp';

# Array of the file name in a file information array
use constant FILE_NAME => 0;

# Array of the file display title in a file information array
use constant FILE_TITLE => 1;

# SVN text base prefix
use constant SVN_TEXT_BASE_PREFIX => '.svn/text-base';

# SVN text base suffix
use constant SVN_TEXT_BASE_SUFFIX => '.svn-base';

# Binary Compare executable
use constant BCOMPARE_EXE => 'bcompare';

# Display differences between two files
#
# Parameters:
#   - file_info_new: Reference to information array for new file
#   - file_info_old: Reference to information array for old file
#   - verbose:       Verbose mode flag
sub displayDiffs
{
  my ($file_info_new, $file_info_old, $verbose) = @_;
  
  # extract all the necessary file information
  my $file_loc_old   = $file_info_old->[FILE_NAME];
  my $file_title_old = $file_info_old->[FILE_TITLE];
  my $file_loc_new   = $file_info_new->[FILE_NAME];
  my $file_title_new = $file_info_new->[FILE_TITLE];
  
  # construct the diff command
  my $bcompare_cmd = BCOMPARE_EXE . " '$file_loc_old' '$file_loc_new' -title1='$file_title_old' -title2='$file_title_new'";

  # if we're in verbose mode
  if($verbose)
  {
    print "Executing Binary Compare: $bcompare_cmd\n";
  }
  
  # display the difference
  `$bcompare_cmd`;
}

# Remove a file
#
# Parameters:
#   - fname:   Name of file to remove
#   - verbose: Verbose mode flag
sub removeFile
{
  my ($fname, $verbose) = @_;
  
  # if we're in verbose mode
  if($verbose)
  {
    print "Deleting temporary file: $fname\n";
  }
  
  # remove the given file
  unlink $fname;
}

# Get the file information array for a given file
#
# Parameters:
#   - file_rem: Remote file
#   - verbose:  Verbose mode flag
#
# Returns: Array to file information array
sub getFileInfo
{
  my ($file_rem, $verbose) = @_;
  
  # file information array
  my @file_info;
  
  # if the file does not contain '://', we assume the file is local
  if(! ($file_rem =~ /:\/\//))
  {
    # if the local file does not exist
    if(! -f $file_rem)
    {
      print STDERR "Error: Local file does not exist: $file_rem\n";
      
      # error, the local file must exist in order to diff
      exit 1;
    }
    
    # copy the SVN text base prefix/suffix to local variables so we can use
    # them in the regex pattern
    my $svn_text_base_prefix = SVN_TEXT_BASE_PREFIX;
    my $svn_text_base_suffix = SVN_TEXT_BASE_SUFFIX;
    
    # save the filename directly
    $file_info[FILE_NAME] = $file_rem;
    
    # if this is not a file from the SVN text base directory
    if(! ($file_rem =~ /^$svn_text_base_prefix\/(.+)$svn_text_base_suffix$/))
    {    
      # construct the display title
      $file_info[FILE_TITLE] = "$file_rem : Working Copy";
    }
    else
    {
      # construct the display title
      $file_info[FILE_TITLE] = "$1 : Working Base";
    }
    
    # return a reference to the file information array
    return \@file_info;
  }
  
  # extract the file basename from the URL
  die if(! ($file_rem =~ /^.+\/(.+)$/));
  
  # save the file basename
  my $file_base = $1;
  
  # sanity check the file basename
  die if(!defined($file_base));
  die if(length($file_base) == 0);
  
  # compute the local file to save to
  my $file_loc = TMP_DIR . "/$file_base";
  
  # construct the SVN command to download the file
  my $svn_cmd = "svn cat $file_rem > $file_loc";
  
  # if we're in verbose mode
  if($verbose)
  {
    print "Executing SVN command to download file: $svn_cmd\n";
  }
  
  # execute SVN
  if(0 != system($svn_cmd))
  {
     print STDERR "Error: Unable to save file from SVN: $file_rem\n";
     
     # error, unable to save file from SVN
     exit 1;
  }
  
  # make sure the temporary file gets removed when the program exits
  atexit(\&removeFile, $file_loc, $verbose);
  
  # save the name of the temporary local file
  $file_info[FILE_NAME] = $file_loc;
  
  # parse the filename and revision from the base of the temporary filename base
  die if(! ($file_base =~ /^(.+)@(.+)$/));
  
  # save the filename and revision number
  my ($fname, $rev) = ($1, $2);
  
  # make sure the split worked as expected
  die if(!defined($fname));
  die if(!defined($rev));
  die if(length($fname) == 0);
  die if(length($rev) == 0);
  
  # construct the display title
  $file_info[FILE_TITLE] = "$fname Revision $rev";
  
  # return a reference to the file information array
  return \@file_info;
}

# Print program usage instructions
sub printUsage
{
  print <<EOF;
Usage: $0 [ -v -h ] FILE1 [ FILE2 ]
 -v: Enable verbose mode
 -h: Display this message
EOF
}

# command-line options
my %options;

# parse the command-line options
getopts('vh', \%options);

# check the command-line options
if(defined($options{h}))
{
  # print program usage instructions
  printUsage();
  
  # nothing else to do, so exit
  exit 0;
}

# compute the number of command-line arguments
my $num_args = $#ARGV + 1;

# if the number of arguments is not correct
if(($num_args == 0) || ($num_args > 2))
{
  # print program usage instructions
  printUsage();
  
  # error, user did not provide correct arguments
  exit 1;
}

# determine whether or not we're in verbose mode
my $verbose = defined($options{v});

# get the first file
my $file1_rem = $ARGV[0];

# second file
my $file2_rem;

# if both files were specified
if($num_args == 2)
{
  # get the second file
  $file2_rem = $ARGV[1];
}
else
{
  # otherwise the second file is in the SVN text base directory
  $file2_rem = SVN_TEXT_BASE_PREFIX . "/$file1_rem" . SVN_TEXT_BASE_SUFFIX;
}

# if the two filenames are the same
if($file1_rem eq $file2_rem)
{
  print STDERR "Error: Cannot compare file with itself!\n";
  
  # error, cannot compare file with itself
  exit 1;
}

# get the file information arrays for both files
my $file1_info = getFileInfo($file1_rem, $verbose);
my $file2_info = getFileInfo($file2_rem, $verbose);

# display the differences
displayDiffs($file1_info, $file2_info, $verbose);

# all done!
exit 0;

