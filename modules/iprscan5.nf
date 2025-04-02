#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process RemoveAsterisk {
  container = 'veupathdb/iprscan5:1.0.0'

  input:
    path subsetFasta

  output:
    path 'subsetNoAsterisk.fa', emit: fasta
  script:
    """
    sed -e 's/*/X/g' $subsetFasta > subsetNoAsterisk.fa
    """
}

process Iprscan {
  container = 'veupathdb/iprscan5:1.0.0'

  input:
    path subsetNoAsterisk
    val appls

  output:
    path 'iprscan_out.tsv', emit: tsv
    path 'iprscan_out.gff3', emit: gff
  script:
    if(params.appls.length() > 0 )
      template 'applsLen.bash'
    else
      template 'noApplsLen.bash'
}

process indexResults {
  container = 'biocontainers/tabix:v1.9-11-deb_cv1'

  publishDir params.outputDir, mode: 'copy'

  input:
    path gff
    val outputFileName

  output:
    path '*.gz'
    path '*.gz.tbi'

  script:
  """
  grep -P "\t" $gff > formatted.gff3
  sort -k1,1 -k4,4n formatted.gff3 > $outputFileName
  bgzip ${outputFileName}
  tabix -p gff ${outputFileName}.gz
  """
}

workflow iprscan5 {
  take:
    seqs

  main:
      fastaNoAsterisk = RemoveAsterisk(seqs)
      iprscanResults = Iprscan(fastaNoAsterisk,params.appls) 
      iprscanResults.tsv.collectFile(storeDir: params.outputDir, name: 'iprscan_out.tsv')
      index = indexResults(iprscanResults.gff.collectFile(),'iprscan_out.gff')
}