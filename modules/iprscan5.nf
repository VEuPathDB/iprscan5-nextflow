#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process Iprscan {
  input:
    path subsetFasta
    val clusterMode
    val appls

  output:
    path 'outputfile'
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
    Iprscan(seqs,params.isCluster,params.appls) \
      | collectFile(storeDir: params.outputDir, name: params.outputFile)
}