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

    if(!params.interproResults) {
        throw new Exception("Missing params.interproResults")
    }
    if(!params.proteomes) {
        throw new Exception("Missing params.proteomes")
    }    
    if(params.taxonIdFile) {
        abbrevAndIds = Channel
                           .fromPath(params.taxonIdFile)
                           .splitCsv(sep: '\t', header: false)
                           .map { abbrev, id -> tuple(abbrev, id as Integer) }
    }
    else {
        throw new Exception("Missing params.taxonIdFile")
    }    
    arbaAssign(abbrevAndIds)        
}

//---------------------------------------------------------------
// DEFAULT - interpro
//---------------------------------------------------------------

workflow {
    iprscan5(seqs)    
}
