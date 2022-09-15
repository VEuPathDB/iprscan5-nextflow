#!/usr/bin/env bash

set -euo pipefail
cp /opt/interproscan/interproscan.properties .
python3 /opt/interproscan/initial_setup.py
interproscan.sh \
  -i subset.fa \
  -o outputfile \
  -f TSV \
  -iprlookup \
  -goterms \
  -verbose
