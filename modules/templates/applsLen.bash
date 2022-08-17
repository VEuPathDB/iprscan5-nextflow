#!/usr/bin/env bash

set -euo pipefail
interproscan.sh \
  -i subset.fa \
  -o outputfile \
  -f TSV \
  -iprlookup \
  -goterms \
  -verbose \
  -appl $params.appls 

