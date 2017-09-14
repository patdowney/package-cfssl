#!/bin/sh

if [ -f /usr/bin/systemctl ]; then
  systemctl daemon-reload
fi

exit 0
