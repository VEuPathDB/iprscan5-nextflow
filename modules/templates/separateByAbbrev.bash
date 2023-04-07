#!/usr/bin/env bash

set -euo pipefail

perl /usr/bin/separateByAbbrev.pl \
     --input $input
