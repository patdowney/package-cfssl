#!/bin/sh
getent group <%= name %> >/dev/null || groupadd -r <%= name %>
getent passwd <%= name %> >/dev/null || \
  useradd -r -g <%= name %> -d /var/lib/<%= name %> -s /sbin/nologin \
  -c "<%= name %> user" <%= name %>
exit 0
