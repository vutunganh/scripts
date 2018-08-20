#!/usr/bin/perl

BEGIN {
  use Cwd;
  my $dir = getcwd();
  push @INC, $dir;
}

use strict;
use warnings;
use utf8;
use Codeforces;

my %cf_users;

# cli args
my $vflag = 0;
my @contest_ids = ();

# aside from 0 assume they're all error codes
my %exit_codes = (
  ok => 0,
  http => 1,
  codeforces_api => 2,
  cli => 3,
  file_io => 4,
  invalid_contest => 5,
  invalid_contest_phase => 6
);

sub debug_print
{
  print STDERR "$_[0]\n" if $vflag;
}

sub get_cf_users
{
  my $ans = HTTP::Tiny->new->get(
    "https://raw.githubusercontent.com/" .
    "vutunganh/perl-scripts/master/resources/" .
    "interesting-users.txt");
  unless ($ans->{success}) {
    return;
  }
  my @arr = split ' ', $ans->{content};
  %cf_users = map {$_ => 1} @arr;
}

sub handle_cli_args
{
  while ($#ARGV >= 0) {
    if ($ARGV[0] eq "-h" || $ARGV[0] eq "--help") {
      print STDERR "Fetches from Codeforces API latest rating changes of",
      "relevant users.\n", 
      "\n",
      "Usage: latest-rating.pl -h|--help\n",
      "       latest-rating.pl [-v|--verbose] [CONTEST_ID...]\n",
      "  -h|--help           prints this help message\n",
      "  -v|--verbose        enables verbose mode\n",
      "\n",
      "Example:\n",
      "  ./latest-rating.pl 1016 1015\n";
      exit $exit_codes{ok};
    } elsif ($ARGV[0] eq "-v" || $ARGV[0] eq "--verbose") {
      $vflag = 1;
      $Codeforces::vflag = 1;
      debug_print "Verbose mode enabled.";
    } else {
      if ($ARGV[0] =~ /^\d+$/) {
        push @contest_ids, $ARGV[0];
      } else {
        debug_print "Unknown command line argument '$ARGV[0]'." if $vflag;
      }
    }
    shift @ARGV;
  }
}

sub rating_changes
{
  if (scalar @contest_ids < 1) {
    @contest_ids = Codeforces::get_latest_contests();
    print "Getting latest finished div. {1,2,3} contests, because contest ids weren't specified.\n\n";
  }

  foreach (@contest_ids) {
    my $current_contest = Codeforces::get_contest($_);
    unless ($current_contest) {
      print "Contest '$_' probably doesn't exist.\n";
      next;
    }
    next unless defined $current_contest;
    print "$current_contest->{name}\n";
    print "http://codeforces.com/contest/$_\n";
    my $phase = $current_contest->{phase};
    unless ($phase eq $Codeforces::contest_status{finished}) {
      if ($phase eq $Codeforces::contest_status{before}) {
        print "Contest hasn't started yet.\n";
      } elsif ($phase eq $Codeforces::contest_status{coding}) {
        print "Contest is ongoing, go get some ACs!\n";
      } elsif ($phase eq $Codeforces::contest_status{pending}) {
        print "System test hasn't started yet.\n";
      } elsif ($phase eq $Codeforces::contest_status{testing}) {
        print "Waiting for system test to finish.\n";
      } else {
        debug_print "Unknown contest phase.";
        exit $exit_codes{invalid_contest_phase};
      }
      next;
    }

    get_cf_users();
    my $all_rating_changes = Codeforces::rating_changes $_;
    unless ($all_rating_changes) {
      print "Couldn't find any rating changes, possible reasons: contest " .
            "was unrated or rating recalculation is ongoing.\n";
      next;
    }

    my @guth = grep {exists $cf_users{$_->{handle}}} @{$all_rating_changes};
    if (scalar @guth < 1) {
      print "No one competed.\n";
      next;
    }

    foreach (@guth) {
      my $new_rating = $_->{newRating};
      my $old_rating = $_->{oldRating};
      my $diff = $new_rating - $old_rating;
      my $diff_str = $diff > 0 ? "+" . $diff : $diff;
      my $smiley = $old_rating > $new_rating ? ":-(" : ":-)";
      print "$_->{handle} $old_rating -> $new_rating ($diff_str) $smiley\n";
    }
  }
}

handle_cli_args();
rating_changes();
