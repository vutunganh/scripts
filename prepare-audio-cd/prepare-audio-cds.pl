#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use File::Copy;
use File::Path qw(make_path);

my $cd_duration = 80 * 60; # in seconds
my $cd_dir_prefix = "CD";
GetOptions("cd-duration=i" => \$cd_duration,
           "folder-prefix" => \$cd_dir_prefix);

my $current_cd_dir = 1;
create_cd_dir($current_cd_dir);
my $current_cd_duration = 0;
foreach my $audio_file (@ARGV) {
  my $duration = calc_audio_file_duration($audio_file);
  if ($current_cd_duration + $duration >= $cd_duration) {
    $current_cd_dir += 1;
    $current_cd_duration = 0;
    create_cd_dir($current_cd_dir);
  }

  $current_cd_duration += $duration;
  my $dest = $cd_dir_prefix . $current_cd_dir;

  copy($audio_file, $dest) or die "Could not move $audio_file to $dest";
}

sub calc_audio_file_duration {
  my ($audio_file) = @_;

  return qx(ffprobe -i "$audio_file" -show_entries format=duration -v quiet -of csv="p=0");
}

sub create_cd_dir {
  my ($cd_no) = @_;
  my $to_create = $cd_dir_prefix . $cd_no;
  make_path($to_create) or die "Could not create CD directory with name '$to_create'";
}
