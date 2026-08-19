# iprscan5-nextflow

Nextflow pipeline that runs [InterProScan 5](https://www.ebi.ac.uk/interpro/about/interproscan/) protein domain/family annotation over a set of protein sequences.

## Overview

InterProScan scans protein sequences against InterPro's collection of member-database signatures (Pfam, PANTHER, Gene3D, PRINTS, CDD, etc.) to identify protein domains, families, and GO term associations. This pipeline is VEuPathDB's Nextflow conversion of the legacy `Iprscan5Task.pm` workflow: it splits an input protein FASTA into subsets, runs InterProScan on each subset, and merges the results into a combined TSV and a sorted, indexed GFF3 for downstream annotation loading (including as the direct input to the `arba-nextflow` pipeline) and genome browser display.

## Requirements

- [Nextflow](https://www.nextflow.io/) (DSL2)
- [Docker](https://www.docker.com/) — `nextflow.config` sets `docker.enabled = true`; the InterProScan installation and its member-database binaries are bundled into the `veupathdb/iprscan5` image built from this repo's `Dockerfile`
- InterProScan's reference data directory, downloaded separately and bind-mounted into the container (see Notes below)

## Usage

```
nextflow run VEuPathDB/iprscan5-nextflow -r main \
  --input /path/to/proteins.fasta \
  --outputDir /path/to/output \
  --appls pfam \
  -resume -C my.config
```

The pipeline has a single, unnamed entry point (`workflow { ... }` in `main.nf`), so no `-entry` flag is needed.

Steps performed:
1. The input FASTA is split into subsets of `params.fastaSubsetSize` sequences via `splitFasta`.
2. `RemoveAsterisk` replaces `*` stop-codon characters in each subset with `X`, since InterProScan does not accept them.
3. `Iprscan` runs `interproscan.sh` on each subset (`-f TSV,GFF3,XML -iprlookup -goterms`), restricted to the analyses in `params.appls` when set, or all available analyses otherwise, producing `iprscan_out.tsv` and `iprscan_out.gff3` per subset.
4. Per-subset TSV outputs are concatenated into a single `iprscan_out.tsv`, published to `params.outputDir`.
5. `indexResults` merges the per-subset GFF3 outputs, sorts them, compresses with `bgzip`, and indexes with `tabix`, publishing `iprscan_out.gff.gz` (and its `.tbi` index) to `params.outputDir`.

## Key Parameters

| Parameter | Description | Default |
|---|---|---|
| `params.input` | Path to the input protein FASTA file | `data/large.fa` |
| `params.outputDir` | Directory the TSV and indexed GFF3 are published to | `output` (relative to launch directory) |
| `params.fastaSubsetSize` | Number of sequences per split FASTA chunk, controlling parallelism | `10000` |
| `params.appls` | Comma-separated list of InterProScan analyses to run (options include `PANTHER`, `SMART`, `TIGRFAM`, `Gene3D`, `PIRSF`, `CDD`, `Pfam`, `SUPERFAMILY`, `ProSiteProfiles`, `MobiDBLite`, `PRINTS`, `Coils`, `ProSitePatterns`); if empty, all analyses are run | `pfam` |

## Output

- `iprscan_out.tsv` — combined InterProScan TSV results across all input sequences.
- `iprscan_out.gff.gz` and `iprscan_out.gff.gz.tbi` — sorted, `bgzip`-compressed and `tabix`-indexed GFF3 of the InterProScan matches.

Both are published to `params.outputDir`.

## Notes

InterProScan requires its member-database reference data at runtime, which is not bundled in the container image and must be downloaded and bind-mounted separately, e.g.:

```
wget ftp://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/5.51-85.0/alt/interproscan-data-5.51-85.0.tar.gz
wget ftp://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/5.51-85.0/alt/interproscan-data-5.51-85.0.tar.gz.md5
wget https://ftp.ncbi.nlm.nih.gov/pub/mmdb/cdd/rpsbproc/RpsbProc-x64-linux.tar.gz
md5sum -c interproscan-data-5.51-85.0.tar.gz.md5
tar -pxzf interproscan-data-5.51-85.0.tar.gz
tar -pxzf RpsbProc-x64-linux.tar.gz
```

Then mount the resulting `data` and `RpsbProc-x64-linux` directories into the container via `docker.runOptions` in the Nextflow config, for example:

```
docker {
  enabled = true
  runOptions = "-v /path/to/interproscan-5.51-85.0/data:/opt/interproscan/data -v /path/to/RpsbProc-x64-linux/*:/opt/interproscan/RpsbProc-x64-linux/"
}
```

Some HMM-based member databases (Gene3D, PIRSF, HAMAP, PANTHER, Pfam, SFLD, SUPERFAMILY, TIGRFAM) ship as pressed HMM files that can become out of sync with the bundled HMMER version, producing an error like `File format problem in trying to open HMM file ... unrecognized`. If this occurs, re-press the affected HMM files inside the container with the bundled `hmmpress` binaries, e.g.:

```
/opt/interproscan/bin/hmmer/hmmer3/3.3/hmmpress -f data/pfam/33.1/pfam_a.hmm
```
