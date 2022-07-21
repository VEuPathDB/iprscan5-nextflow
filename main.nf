nextflow.enable.dsl=2

process Iprscan {
  input:
  path 'subset.fa'
  output:
  path 'outputfile'
  script:
  if(params.appls.length() > 0 )
  """
  interproscan.sh \
    -i subset.fa \
    -o outputfile \
    -f TSV \
    -iprlookup \
    -goterms \
    -verbose \
    -appl $params.appls 
  """
  else
  """
  interproscan.sh \
    -i subset.fa \
    -o outputfile \
    -f TSV \
    -iprlookup \
    -goterms \
    -verbose
  """
}

workflow {
  channel
    .fromPath(params.seqFile)
    .splitFasta(by:params.fastaSubsetSize, file:true) | Iprscan | collectFile(storeDir: params.outputDir, name: params.outputFile)
}