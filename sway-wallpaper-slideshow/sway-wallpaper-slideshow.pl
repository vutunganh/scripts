#!/usr/bin/env perl

use strict;
use warnings;
use Socket qw(PF_UNIX SOCK_STREAM sockaddr_un);
use JSON::PP qw(decode_json);
use File::Find::Rule;

use constant SWAY_SOCKET_PATH => $ENV{SWAYSOCK};
die "SWAYSOCK is not set, are you running swaywm?\n" unless SWAY_SOCKET_PATH;

# TODO: Support for multiple wallpaper folders.
use constant HELP_MESSAGE => <<"HELP_MESSAGE";
Usage: $0 wallpaper_directory
HELP_MESSAGE
my $WALLPAPER_DIRECTORY = shift || die HELP_MESSAGE;

socket(my $SWAY_SOCKET, PF_UNIX, SOCK_STREAM, 0) ||
  die "Could not open a socket, reason: '$!'\n";

# FIXME:              Are we doing it right?
connect($SWAY_SOCKET, sockaddr_un(SWAY_SOCKET_PATH)) ||
  die "Could not connect to the socket, reason: '$!'\n";


use constant IPC_MAGIC => 'i3-ipc';
use constant MESSAGE_TYPE_NUMBER => {
  RUN_COMMAND => 0,
  GET_OUTPUTS => 3,
};
use constant IPC_HEADER_FORMAT => 'A' . length(IPC_MAGIC) . 'LL';

sub send_message {
  my ($message_type, $payload) = @_;

  my $msg_to_send = pack(
    IPC_HEADER_FORMAT,
    IPC_MAGIC,
    length($payload),
    $message_type
  ) . $payload;

  send($SWAY_SOCKET, $msg_to_send, 0) ||
    die "Error sending a message, reason: '$!'\n";
  recv($SWAY_SOCKET, my $resp_header_raw, length pack(IPC_HEADER_FORMAT), 0) ||
    die "Error receiving a message, reason: '$!'\n";
  my (undef, $resp_length, $resp_type) =
    unpack(IPC_HEADER_FORMAT, $resp_header_raw);
  recv($SWAY_SOCKET, my $resp_body, $resp_length, 0) ||
    die "Error receiving response, reason: '$!'\n";
  return $resp_body;
}

# Returns an array of names of outputs.
sub get_outputs {
  my $sway_outputs_raw = send_message(MESSAGE_TYPE_NUMBER->{GET_OUTPUTS}, '');
  my $sway_outputs = decode_json($sway_outputs_raw);
  return (map { ($_->{name}) } @$sway_outputs);
}

sub set_wallpaper {
  my ($wallpaper_path, $output) = @_;

  my $payload = "output $output bg $wallpaper_path fit";
  send_message(MESSAGE_TYPE_NUMBER->{RUN_COMMAND}, $payload);
}

# TODO: Test if found files are images.
sub get_wallpapers {
  return File::Find::Rule->file->in($WALLPAPER_DIRECTORY);
}

my @outputs = get_outputs();
my @wallpapers = get_wallpapers();
if (@wallpapers < 1) {
  die "No wallpapers were found in '$WALLPAPER_DIRECTORY'\n";
}

foreach my $output (@outputs) {
  my $idx = int(rand(@wallpapers));
  set_wallpaper($wallpapers[$idx], $output);
}

close $SWAY_SOCKET;
