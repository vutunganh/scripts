#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use HTTP::Tiny;
use JSON;
use List::Util qw(max);

# cli args
my $vflag = 0;
my @contest_ids = ();

# all contests "singleton"
my %all_contests = ();

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

my %contest_status = (
  before => "BEFORE", 
  coding => "CODING", 
  pending => "PENDING_SYSTEM_TEST",
  testing => "SYSTEM_TEST", 
  finished => "FINISHED"
);

# Expects a complete url to be called as an argument.
# Returns the expected result.
sub user_agent_get_url {
  my $url = $_[0];
  print STDERR "Trying to get url: '$url'.\n" if $vflag;
  my $response = HTTP::Tiny->new->get($url);
  unless ($response->{success}) {
    print STDERR "Couldn't fetch url: '$url'.\n";
    exit $exit_codes{http};
  }
  return $response->{content};
}

# Expects a REST method with parameters from Codeforces API as an argument.
# Example: codeforces_api_call("user.info?handles=tourist");
# Returns a deserialized response.
sub codeforces_api_call {
  my $codeforces_base_url = "http://codeforces.com/api/";
  my $method = $_[0];
  my $url = $codeforces_base_url . $method;
  print STDERR "Trying to call '$url'.\n" if $vflag;
  my $raw_response = user_agent_get_url($url);
  my %deserialized = %{decode_json($raw_response)};
  my $status = $deserialized{status};
  unless (lc $status eq "ok") {
    print "Codeforces API failure.";
    print STDERR "Message:\n'$deserialized{comment}'." if $vflag;
    print "\n";
    exit $exit_codes{codeforces_api};
  }
  return $deserialized{result};
}

sub codeforces_api_rating_changes {
  my $cid = $_[0];
  print STDERR "Getting rating changes.\n" if $vflag;
  return codeforces_api_call "contest.ratingChanges?contestId=$cid";
}

sub codeforces_api_contest_list {
  return %all_contests if (%all_contests);
  print STDERR "Getting contest list.\n" if $vflag;
  my @contests = @{codeforces_api_call "contest.list"};
  %all_contests = map {$_->{id} => $_} @contests;
  return codeforces_api_contest_list();
}

# Expects contest id as an argument.
sub get_contest_info {
  my $cid = $_[0];
  print STDERR "Getting contest '$cid'.\n" if $vflag;
  my %contests = codeforces_api_contest_list();
  unless (exists $contests{$cid}) {
    print STDERR "Cannot find contest with id '$cid'.\n";
    exit $exit_codes{invalid_contest};
  }
  return %{$contests{$cid}};
}

sub get_user_list {
  print STDERR "Getting user list.\n" if $vflag;
  my $users_txt = user_agent_get_url "https://raw.githubusercontent.com/" . 
                  "vutunganh/perl-scripts/master/resources/" . 
                  "interesting-users.txt";
  my @user_arr = split ' ', $users_txt;
  my %users = map {$_ => 1} @user_arr;
  return %users;
}

sub get_latest_contests {
  my %contests = codeforces_api_contest_list();
  my %divs = ();
  my $cur_id = max keys %contests;
  for (my $i = $cur_id; $i >= 0; --$i) {
    next unless (defined $contests{$i} && $contests{$i}->{phase} eq
                 $contest_status{finished});
    my $name = $contests{$i}->{name};
    my (@div) = $name =~ /div\. (\d)/gi;
    foreach (@div) {
      $divs{$_} = $i;
    }
    last if scalar values %divs > 2;
  }
  return values %divs;
}

sub handle_cli_args {
  my $required_amount_of_args = 1;
  while ($#ARGV >= 0) {
    if ($ARGV[0] eq "-h" || $ARGV[0] eq "--help") {
      print STDERR "Fetches from Codeforces API latest rating changes of",
      "relevant users.\n", 
      "\n",
      "Usage: latest-rating.pl [-h|--help]\n",
      "       latest-rating.pl [-v|--verbose] CONTEST_ID...\n",
      "  -h|--help           prints this help message\n",
      "  -v|--verbose        enables verbose mode\n",
      "\n",
      "Example:\n",
      "  ./latest-rating.pl 1016 1015\n";
      exit $exit_codes{ok};
    } elsif ($ARGV[0] eq "-v" || $ARGV[0] eq "--verbose") {
      $vflag = 1;
      print STDERR "Verbose mode enabled.\n";
    } else {
      if ($ARGV[0] =~ /^\d+$/) {
        push @contest_ids, $ARGV[0];
      }
      print STDERR "Unknown command line argument '$ARGV[0]'.\n" if $vflag;
    }
    shift @ARGV;
  }

  if (scalar @contest_ids < 1) {
    @contest_ids = get_latest_contests();
    print "Getting last div. {1,2,3} contests, because id's weren't specified.\n";
  }
}

sub rating_change_single_contest {
  my $cid = $_[0];
  my %current_contest = get_contest_info $cid;
  my $phase = $current_contest{phase};
  unless ($phase eq $contest_status{finished}) {
    if ($phase eq $contest_status{before}) {
      print "Contest hasn't started yet.\n";
    } elsif ($phase eq $contest_status{coding}) {
      print "Contest is ongoing, go get some ACs!\n";
    } elsif ($phase eq $contest_status{pending}) {
      print "System test hasn't started yet.\n";
    } elsif ($phase eq $contest_status{testing}) {
      print "Waiting for system test to finish.\n";
    } else {
      print STDERR "Unknown contest phase.\n";
      exit $exit_codes{invalid_contest_phase};
    }
    return;
  }

  my %users = get_user_list();
  my @rating_changes = @{codeforces_api_rating_changes $cid};
  my @relevant_users = grep {exists($users{$_->{handle}})} @rating_changes;

  if (scalar @relevant_users < 1) {
    print "No one competed or contest was unrated!\n";
    return;
  }

  foreach(@relevant_users) {
    my %cur = %{$_};
    my $newRating = $cur{newRating};
    my $oldRating = $cur{oldRating};
    my $diff = $newRating - $oldRating;
    my $diffString = $diff > 0 ? "+" . $diff : $diff;
    my $smiley = $oldRating > $newRating ? ":-(" : ":-)";
    print "$cur{handle} $oldRating -> $newRating ($diffString) $smiley\n";
  }
}

sub rating_changes {
  my %all_contests = codeforces_api_contest_list;
  foreach(@contest_ids) {
    next unless defined $all_contests{$_};
    print "$all_contests{$_}->{name}", "\n";
    print "http://codeforces.com/contest/$_\n";
    rating_change_single_contest($_);
    print "\n";
  }
}

handle_cli_args();
rating_changes();

