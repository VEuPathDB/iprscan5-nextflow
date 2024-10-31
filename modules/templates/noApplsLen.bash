#!/usr/bin/env bash

set -euo pipefail
cp /opt/interproscan/interproscan.properties .
python3 /opt/interproscan/initial_setup.py

interproscan.sh \
  -i $subsetFasta \
  -f TSV,GFF3 \
  -iprlookup \
  -goterms \
  -verbose

mv *.gff3 iprscan_out.gff3
mv *.tsv iprscan_out.tsv
