#!/usr/bin/env bash

set -euo pipefail

interproscan.sh \
  -i $subsetFasta \
  -o hold.tsv \
  -f TSV \
  -iprlookup \
  -goterms \
  -verbose \
  -appl $appls 

if grep -q "GO:"  hold.tsv;
then
    grep "GO:" hold.tsv > iprscan_out.tsv
    rm hold.tsv
else
    mv hold.tsv iprscan_out.tsv
fi


