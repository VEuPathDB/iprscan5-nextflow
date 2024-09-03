#!/usr/bin/env bash

set -euo pipefail

interproscan.sh \
  -i $subsetFasta \
  -o iprscan_out.tsv \
  -f TSV \
  -iprlookup \
  -goterms \
  -verbose \
  -appl $appls
