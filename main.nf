nextflow.enable.dsl=2

process Iprscan {
  input:
  path 'subset.fa'
  output:
  path ''
  """
  interproscan.sh -i subset.fa -o . -f TSV -iprlookup -goterms -verbose -appl $params.applParams -trlen $params.trlen $params.crcNoCrc 
  """
}

workflow {
  seqs = channel.fromPath(params.seqFile).splitFasta( by:params.fastaSubsetSize, file:true  )
  results = Iprscan(seqs)
  results[0] | collectFile(storeDir: params.outputDir, name: params.dataFile)
  results[1] | collectFile(storeDir: params.outputDir, name: params.logFile)
  results[2] | collectFile(storeDir: params.outputDir)
}