#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process Iprscan {
  publishDir "$params.outputDir"

  input:
    path subsetFasta
    val clusterMode
    val appls

  output:
    path 'iprscan_out.tsv'
  script:
    if(params.appls.length() > 0 )
      template 'applsLen.bash'
    else
      template 'noApplsLen.bash'
}

process separateByAbbrev {
  publishDir "$params.outputDir"

  input:
    path input

  output:
    path 'iprscan*'
  script:
    template 'separateByAbbrev.bash'
}

workflow iprscan5 {
  take:
    seqs

  main:
    Iprscan(seqs,params.isCluster,params.appls) \
      | collectFile() \
        | separateByAbbrev
}