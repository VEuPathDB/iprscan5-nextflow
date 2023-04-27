#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process Iprscan {

  input:
    path subsetFasta
    val appls

  output:
    path 'iprscan_out.tsv'
  script:
    if(params.appls.length() > 0 )
      template 'applsLen.bash'
    else
      template 'noApplsLen.bash'
}

workflow iprscan5 {
  take:
    seqs

  main:
      Iprscan(seqs,params.appls) \
        | collectFile(storeDir: params.outputDir, name: 'iprscan_out.tsv') 
}