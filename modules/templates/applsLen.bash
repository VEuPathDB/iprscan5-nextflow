#!/usr/bin/env bash

set -euo pipefail
cp /opt/interproscan/interproscan.properties .
python3 /opt/interproscan/initial_setup.py

interproscan.sh \
  -i $subsetFasta \
  -o iprscan_out.tsv \
  -f TSV \
  -iprlookup \
  -goterms \
  -verbose \
  -appl $appls 

