#!/usr/bin/env bash

interproscan.sh \
  -i subset.fa \
  -o outputfile \
  -f TSV \
  -iprlookup \
  -goterms \
  -verbose
