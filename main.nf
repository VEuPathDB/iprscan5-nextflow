#!/usr/bin/env nextflow
nextflow.enable.dsl=2


//---------------------------------------------------------------
// Includes
//---------------------------------------------------------------

include { iprscan5 } from './modules/iprscan5.nf'

//---------------------------------------------------------------
// Main Workflow
//---------------------------------------------------------------

workflow {
  if(!params.fastaSubsetSize) {
    error "Missing params.fastaSubsetSize"
  }

  if(params.input) {
    seqs = channel.fromPath(params.input).splitFasta( by:params.fastaSubsetSize, file:true  )
  }
  else {
    error "Missing params.input"
  }

  iprscan5(seqs)
}