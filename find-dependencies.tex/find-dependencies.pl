#!/usr/bin/env perl
# Script similar to gcc -MM, but for .tex files.
# Only works for plainTeX.

use strict;
use warnings;

my %EXTENSION_MAP = (
  'tex' => 'pdf'
);

my @INCLUDE_SYNTAX = (qr/\\input\s+(\S+)/);

# TODO: check if the included file exists, otherwise it's most likely a system
#   dependency, which doesn't need to be included
sub find_dependencies {
  my $filename = $_[0];
  my @result = ();

  open my $fh, "<", $filename or die "Couldn't open file $filename.\n";
  while (my $line = <$fh>) {
    chomp $line;
    foreach my $regex (@INCLUDE_SYNTAX) {
      if ($line =~ $regex) {
        push @result, $1;
        last;
      }
    }
  }
  return @result;
}

# TODO: break lines
sub print_dependencies {
  my $filename = $_[0];
  my @dependencies = find_dependencies($filename);
  my $to_print = join ' ', @dependencies;
  my ($basename, $extension) = split '\.', $filename, 2;
  print "$basename.$EXTENSION_MAP{$extension}: $filename $to_print\n";
}

# TODO: user specified file extensions  
sub custom_file_extensions {
}

# TODO: custom "include" syntax
sub custom_include_syntax {
}

foreach (@ARGV) {
  print_dependencies($_);
}
print "\n";

