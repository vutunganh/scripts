#!/usr/bin/perl -CS

# use 5.0120000;
use strict;
use warnings;
use utf8;
use LWP::UserAgent;

my $vflag = 0;

sub handle_cmd_args {
  if (0 > $#ARGV) {
    return;
  }
  if ($ARGV[0] eq "-h" || $ARGV[0] eq "--help") {
    print "Usage: pod-loubim.pl [-h|--help] [-v|--verbose]\n";
    die "\n";
  }
  while ($#ARGV >= 0) {
    if ($ARGV[0] eq "-v") {
      $vflag = 1;
      print STDERR "Verbose mode on.\n";
      shift @ARGV;
    }
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

  print "Restaurace Pod Loubím\n"; # FIXME: bold print
  my @by_nl = split('\n', $text);
  # FIXME: push into a variable and then print
  foreach $a (@by_nl[1..($#by_nl - 1)]) { # remove misc info
    # join price with next line (=meal name)
    if ($a =~ /^\d+/) {
      print $a . " ";
    } else {
      print "$a\n";
    }
  }
}

handle_cmd_args();
print_menu();

