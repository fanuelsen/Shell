#!/usr/bin/env sh

# Acknowledgement:
# Most of this file was derived from https://github.com/ironPeakServices/iron-alpine/blob/master/post-install.sh

# fail if a command fails
set -e
set -o pipefail

# remove apk package manager
find / -type f -iname '*apk*' -xdev -delete
find / -type d -iname '*apk*' -print0 -xdev | xargs -0 rm -r --

# set rx to all directories
find "$APP_DIR" -type d -exec chmod 500 {} +

if [ -z "$1" ]
then
  # set r to all files
  find "$APP_DIR" -type f -exec chmod 400 {} +
else
  # set r to all files excluding executable binary
  find "$APP_DIR" ! -name $1 -type f -exec chmod 400 {} +
fi

# Finally remove chmod
find /bin /etc /lib /sbin /usr -xdev \( \
  -name chmod \
  \) -delete
