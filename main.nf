#!/usr/bin/env nextflow
nextflow.enable.dsl=2


//---------------------------------------------------------------
// Param Checking 
//---------------------------------------------------------------

if(!params.fastaSubsetSize) {
  throw new Exception("Missing params.fastaSubsetSize")
}

if(params.seqFile) {
  seqs = Channel.fromPath( params.seqFile )
           .splitFasta( by:params.fastaSubsetSize, file:true  )
}
else {
  throw new Exception("Missing params.seqFile")
}

//---------------------------------------------------------------
// Includes
//---------------------------------------------------------------

include { iprscan5 } from './modules/iprscan5.nf'

//---------------------------------------------------------------
// Main Workflow
//---------------------------------------------------------------

workflow {
  iprscan5(seqs)
}