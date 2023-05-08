#!/usr/bin/env bash

set -euo pipefail
cp /opt/interproscan/interproscan.properties .
python3 /opt/interproscan/initial_setup.py

interproscan.sh \
  -i $subsetFasta \
  -o hold.tsv \
  -f TSV \
  -iprlookup \
  -goterms \
  -verbose 

if grep -q "GO:"  hold.tsv;
then
    grep "GO:" hold.tsv > iprscan_out.tsv
    rm hold.tsv
else
    mv hold.tsv iprscan_out.tsv
fi

