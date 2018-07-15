#!/usr/bin/perl -CS

use strict;
use warnings;
use utf8;
use LWP::UserAgent;

my $vflag = 0; # verbose
my $tflag = 0; # print restaurant name?

sub handle_cli_args {
  while ($#ARGV >= 0) {
    if ($ARGV[0] eq "-h" || $ARGV[0] eq "--help") {
      print "Displays Pod Loubim's daily menu.\n";
      print "Usage: pod-loubim.pl [-h|--help]\n";
      print "       pod-loubim.pl [-v|--verbose] [-r|--print-restaurant-name]\n";
      print "\n";
      print "  -h|--help                     prints help message\n";
      print "  -v|--verbose                  enables verbose mode\n";
      print "  -t|--print-restaurant-name    whether or not to display 'Restaurace Pod Loubim' header when printing the menu\n";
      die "\n";
    }
    elsif ($ARGV[0] eq "-v" || $ARGV[0] eq "--verbose") {
      $vflag = 1;
      print STDERR "Verbose mode on.\n";
    } elsif ($ARGV[0] eq "-t" || $ARGV[0] eq "--print-restaurant-name") {
      $tflag = 1;
      if ($vflag) {
        print STDERR "Will print restaurant name at the beginning of the menu.\n";
      }
    } else {
      if ($vflag) {
        print STDERR "Unknown command line argument '$ARGV[0]'.\n";
      }
    }
    shift @ARGV;
  }
}

sub isweekend {
  my $day = (split(' ', localtime))[0];
  my @weekend = ("sat", "sun");
  my $toreturn = grep(lc($day), @weekend);
  if ($vflag) {
    print $toreturn ? "It's weekend :(" : "It isn't weekend :)";
    print ".\n";
  }
  return $toreturn;
}

sub fetch_site {
  my %links = (
    weekday => 'http://www.podloubim.com/menu/',
    weekend => 'http://www.podloubim.com/vikendove-menu/'
  );

  my $link = isweekend() ? $links{"weekend"} : $links{"weekday"};
  if ($vflag) {
    print "Fetching '$link'.\n";
  }
  my $ua = LWP::UserAgent->new;
  $ua->timeout(10);
  $ua->env_proxy;

  my $response = $ua->get($link);
  $response->is_success or die "Couldn't fetch menu.\n";
  if ($vflag) {
    print "Successfully fetched menu.\n";
  }

  return $response->decoded_content;
}

sub print_menu {
  my $i = 0;
  my $html = fetch_site();
  my $text = "";

  foreach $a (split('\n', $html)) {
    $a =~ s/^\s+|\s+$//g; # trim leading and ending whitespace
    if ($a =~ /^\S+$/) { # skip all empty lines
      next;
    }
    $a =~ s/&nbsp;|&gt;//g; # remove all `&nbsp;`, `&gt`;
    $a =~ s/<td[^>]*><\/td>//g; # remove all empty tags
    unless ($a =~ /<\/td\>$/g) { # menu is contained inside a table, so if 
      next;                      # table cell tag isn't found, then skip
    }
    $a =~ s|<.+?>||g; # remove all html tags
    $a =~ s/^\s+|\s+$//g; # trim leading and ending whitespace
    $text .= $a . "\n";
  }

  if ($tflag) {
    print "Restaurace Pod Loubím\n"; # TODO: bold print
  }
  my @by_nl = split('\n', $text);
  my $result;
  foreach $a (@by_nl[1..($#by_nl - 1)]) { # remove misc info
    # join price with next line (=meal name)
    if ($a =~ /^\d+/) {
      $result .= "$a ";
    } else {
      $result .= "$a\n";
    }
  }
  print $result;
}

handle_cli_args();
print_menu();

