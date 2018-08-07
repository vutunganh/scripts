#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use LWP::UserAgent;
use JSON;

my $vflag = 0;
my $contest_id = "";

# networking
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

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
  my $response = $ua->get($url);
  unless ($response->is_success) {
    print STDERR "Couldn't fetch url: '$url'.\n";
    exit $exit_codes{"http"};
  }
  return $response->decoded_content;
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
  my $status = $deserialized{'status'};
  unless (lc $status eq "ok") {
    print "Codeforces API failure.";
    print STDERR "Message:\n'$deserialized{'comment'}'." if $vflag;
    print "\n";
    exit $exit_codes{"codeforces_api"};
  }
  return $deserialized{'result'};
}

sub codeforces_api_rating_changes {
  my $cid = $_[0];
  print STDERR "Getting rating changes.\n" if $vflag;
  return codeforces_api_call "contest.ratingChanges?contestId=$cid";
}

sub codeforces_api_contest_list {
  my $cid = $_[0];
  print STDERR "Getting contest list.\n" if $vflag;
  return codeforces_api_call "contest.list";
}

# Expects contest id as an argument.
sub get_contest_info {
  my $cid = $_[0];
  print STDERR "Getting contest '$cid'.\n" if $vflag;
  my @all_contests = @{codeforces_api_contest_list()};
  my @searched_contest = grep {$_->{"id"} == $cid} @all_contests;
  unless (scalar @searched_contest == 1) {
    print STDERR "Cannot find contest with id '$cid'.\n";
    exit $exit_codes{"invalid_contest"};
  }
  return %{$searched_contest[0]};
}

sub get_user_list {
  print STDERR "Getting user list.\n" if $vflag;
  my $users_txt = user_agent_get_url "https://raw.githubusercontent.com/vutunganh/perl-scripts/latest-rating/latest-rating/interesting-users.txt";
  my @user_arr = split ' ', $users_txt;
  my %users = map {$_ => 1} @user_arr;
  return %users;
}

sub handle_cli_args {
  my $required_amount_of_args = 1;
  while ($#ARGV >= 0) {
    if ($ARGV[0] eq "-h" || $ARGV[0] eq "--help") {
      print STDERR "Fetches from Codeforces API latest rating changes of",
      "relevant users.\n", 
      "\n",
      "Usage: latest-rating.pl [-h|--help]\n",
      "       latest-rating.pl [-v|--verbose] -i|--id CONTEST_ID\n",
      "  -h|--help           prints this help message\n",
      "  -v|--verbose        enables verbose mode\n",
      "  -i|--id             id of the contest to fetch rating changes from\n",
      "  -u|--user-list      path to a text file described at USER_LIST_FILE\n",
      "\n",
      "Variables:\n",
      "  USER_LIST_FILE    a file with usernames on each line\n",
      "  CONTEST_ID        a contest id\n";
      exit $exit_codes{"ok"};
    } elsif ($ARGV[0] eq "-v" || $ARGV[0] eq "--verbose") {
      $vflag = 1;
      print "Verbose mode enabled.\n";
    } elsif ($ARGV[0] eq "-i" || $ARGV[0] eq "--id") {
      unless ($#ARGV > 0) {
        print STDERR "Missing contest id parameter.\n";
        exit $exit_codes{"cli"};
      }
      $contest_id = $ARGV[1];
      shift @ARGV;
    } else {
      print STDERR "Unknown command line argument '$ARGV[0]'.\n" if $vflag;
    }
    shift @ARGV;
  }

  if ($contest_id eq "") {
    print STDERR "Unspecified contest id.\n";
    exit $exit_codes{"cli"};
  }
}

sub rating_changes {
  my %current_contest = get_contest_info $contest_id;
  my $phase = $current_contest{"phase"};
  unless ($phase eq $contest_status{"finished"}) {
    if ($phase eq $contest_status{"before"}) {
      print "Contest hasn't started yet.\n";
    } elsif ($phase eq $contest_status{"coding"}) {
      print "Contest is ongoing, go get some ACs!\n";
    } elsif ($phase eq $contest_status{"pending"}) {
      print "System test hasn't started yet.\n";
    } elsif ($phase eq $contest_status{"testing"}) {
      print "Waiting for system test to finish.\n";
    } else {
      print STDERR "Unknown contest phase.\n";
      exit $exit_codes{"invalid_contest_phase"};
    }
    return;
  }

  my %users = get_user_list();
  my @rating_changes = @{codeforces_api_rating_changes $contest_id};
  my @relevant_users = grep {exists($users{$_->{handle}})} @rating_changes;

  if (scalar @relevant_users < 1) {
    print "No one competed!\n";
    return;
  }

  foreach(@relevant_users) {
    my %cur = %{$_};
    my $smiley = $cur{oldRating} > $cur{newRating} ? ":(" : ":)";
    print "$cur{handle}", " ", $cur{oldRating}, " -> ", $cur{newRating}, " $smiley", "\n";
  }
}

handle_cli_args();
rating_changes();

