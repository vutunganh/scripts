#!/usr/bin/env bash

set -eu -o pipefail

printf_to_stderr() {
  1>&2 printf "$@"
}

check_command() {
  # Check if $1 is a command.
  if ! type "$1" > /dev/null; then
    printf_to_stderr "%s not found\n" "$1"
    exit -1
  fi
}

check_command curl
check_command pdfbook
check_command lp

if [ $# -lt 2 ]; then
  printf_to_stderr "Usage: %s <printer_name> <url>\n" "$0"
  exit 1
fi

printer_name="$1"
url="$2"
slug=`sha256sum - <<< "$url" | awk '{print $1}'`
dest="/tmp/$slug.pdf"

curl -f "$url" | pdfbook --outfile "$dest" --

lp -d "$printer_name" -o Duplex=DuplexNoTumble -o XRFold=BiFoldStaple "$dest"
rm "$dest"
