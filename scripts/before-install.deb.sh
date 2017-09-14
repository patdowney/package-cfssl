#!/bin/sh
addgroup --system <%= name %>
adduser --system --home /var/lib/<%= name %> --ingroup <%= name %> <%= name %> 
