#!/usr/bin/env bash

set -euo pipefail

interproscan.sh \
  -i $subsetFasta \
  -f TSV,GFF3 \
  -iprlookup \
  -goterms \
  -verbose \
  -appl $appls

mv *.gff3 iprscan_out.gff3
mv *.tsv iprscan_out.tsv
