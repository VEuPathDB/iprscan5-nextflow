nextflow.enable.dsl=2

process Iprscan {
  input:
  path 'subset.fa'
  output:
  path 'outputfile'
  script:
  if(params.appls.length() > 0 )
  """
  interproscan.sh -i subset.fa -o outputfile -f TSV -iprlookup -goterms -verbose -appl $params.appls 
  """
  else
  """
  interproscan.sh -i subset.fa -o outputfile -f TSV -iprlookup -goterms -verbose 
  """
}

workflow {
  seqs = channel.fromPath(params.seqFile).splitFasta( by:params.fastaSubsetSize, file:true  )
  results = Iprscan(seqs)
  //results[0] | collectFile(storeDir: params.outputDir, name: params.dataFile)
  //results[1] | collectFile(storeDir: params.outputDir, name: params.logFile)
  //results[2] | collectFile(storeDir: params.outputDir)
}