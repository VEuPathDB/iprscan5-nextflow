#!/usr/bin/env nextflow
nextflow.enable.dsl=2

//---------------------------------------------------------------
// Includes
//---------------------------------------------------------------

include { iprscan5 } from './modules/iprscan5.nf'
include { arbaAssign } from './modules/arbaAssign.nf'

//---------------------------------------------------------------
// interpro 
//---------------------------------------------------------------
workflow interpro {

    if(!params.fastaSubsetSize) {
        throw new Exception("Missing params.fastaSubsetSize")
    }

    if(params.input) {
        seqs = Channel.fromPath(params.input).splitFasta( by:params.fastaSubsetSize, file:true  )
    }
    else {
        throw new Exception("Missing params.input")
    }
    iprscan5(seqs)    
}

//---------------------------------------------------------------
// arba
//---------------------------------------------------------------
workflow arba {

    if(params.interproResults) {
        interproResults = Channel.fromPath(params.interproResults)
    }
    else {
        throw new Exception("Missing params.interproResults")
    }
    if(!params.taxonId) {
        throw new Exception("Missing params.taxonId")
    }
    arbaAssign(interproResults)        
}

//---------------------------------------------------------------
// DEFAULT - interpro
//---------------------------------------------------------------

workflow {
    iprscan5(seqs)    
}
