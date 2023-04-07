#!/usr/bin/env bash

set -euo pipefail
cp /opt/interproscan/interproscan.properties .
python3 /opt/interproscan/initial_setup.py

if [ "$clusterMode" = true ]; then

    interproscan.sh \
      -i $subsetFasta \
      -o iprscan_out.tsv \
      -f TSV \
      -iprlookup \
      -goterms \
      -verbose \
      -mode cluster \
      -clusterrunid uniqueName
    
else

    interproscan.sh \
      -i $subsetFasta \
      -o iprscan_out.tsv \
      -f TSV \
      -iprlookup \
      -goterms \
      -verbose 
    
fi
