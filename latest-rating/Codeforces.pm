#!/usr/bin/env perl

package Codeforces;
use strict;
use warnings;
use utf8;

use HTTP::Tiny;
use JSON;
use List::Util qw(max uniq);

our $vflag = 0;
my $contests = undef; # a reference to a hash contest id's to contests

our %contest_status = (
  before => "BEFORE", 
  coding => "CODING", 
  pending => "PENDING_SYSTEM_TEST",
  testing => "SYSTEM_TEST", 
  finished => "FINISHED"
);

sub debug_print
{
  print STDERR "$_[0]\n" if $vflag;
}

# Parameters:
#   - A reference to an url.
# Returns the result as a value.
sub http_get
{
  my $url = $_[0];
  debug_print "Trying to get url: '$$url'.";
  my $response = HTTP::Tiny->new->get($$url);
  unless ($response->{success}) {
    print "Network failure.\n";
    debug_print "Couldn't fetch url '$$url'.";
    return;
  }
  return $response->{content};
}

# Parameters:
#   - A method name.
# Returns the result.
sub codeforces_api_call
{
  my $url = "http://codeforces.com/api/". $_[0];
  debug_print "Trying to call '$url'.";
  my $raw_response = http_get \$url;
  return unless ($raw_response);
  my $deserialized = decode_json($raw_response);
  unless (lc $deserialized->{status} eq "ok") {
    print "Codeforces API failure.";
    debug_print "Message:\n'$deserialized->{comment}'.";
    print "\n";
    return;
  }
  return $deserialized->{result};
}

# Returns a reference to a hash of contest id -> contest.
sub contest_list
{
  debug_print "Getting all contests.";
  my $tmp = codeforces_api_call "contest.list";
  return unless ($tmp);
  my $result = {};
  foreach (@{$tmp}) {
    $result->{$_->{id}} = $_;
  }
  return $result;
}

# A safe way to access all contests.
sub access_contests
{
  $contests = contest_list() unless ($contests);
  return unless ($contests);
  return $contests;
}

# Arguments:
#   - contest id.
# Returns an array of references to RatingChange objects.
sub rating_changes
{
  debug_print "Getting all rating changes.";
  my $result = codeforces_api_call "contest.ratingChanges?contestId=$_[0]";
  return unless ($result);
  return $result;
}

# Arguments:
#   - contest id.
# Returns a contest.
sub get_contest
{
  my $cid = $_[0];
  return access_contests()->{$cid};
}

sub get_latest_contests
{
  my %divs = ();
  my $max_id = max keys %{access_contests()};
  debug_print "Max id: '$max_id'.";
  for (my $i = $max_id; $i >= 0; --$i) {
    my $cur = get_contest $i;
    next unless ($cur);
    next if ($cur->{phase} ne $contest_status{finished});
    my $name = $cur->{name};
    my (@div) = $name =~ /div\. (\d)/gi;
    foreach (@div) {
      next if defined $divs{$_};
      $divs{$_} = $i;
    }
    last if scalar values %divs > 2;
  }
  return uniq values %divs;
}

# Pass a contest id.
# Returns a reference to an array of RatingChange objects.
sub rating_changes_single_contest
{
  my $cid = $_[0];
  my $users = $_[1]; # reference to an array of usernames

  my $rating_changes = rating_changes $cid;
  my @relevant = grep {exists $users->{$_->{handle}}} @{$rating_changes};
  return \@relevant;
}
