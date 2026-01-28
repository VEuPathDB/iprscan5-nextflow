#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process filterInterproByLongestProteinPerGene {
  container = 'veupathdb/iprscan5:1.3.0'
  input:
    tuple val(abbrev), val(taxon_id)
    path interproResults
    path proteomes    

  output:
    path 'filteredInterproResults.tsv'
    tuple val(abbrev), val(taxon_id)    

  script:
    """
    filterInterproByLongest.pl --fasta $proteomes/${abbrev}.fsa \
                                    --interpro $interproResults/${abbrev}_iprscan_out.tsv \
                                    --output filteredInterproResults.tsv
    """
}

process runEDirect {
  container = 'veupathdb/edirect:1.0.0'
  input:
    path filteredInterproResults
    tuple val(abbrev), val(taxon_id)        

  output:
    path 'lineage.txt'  
    path filteredInterproResults
    tuple val(abbrev), val(taxon_id)    

  script:
    """
    efetch -db taxonomy -id $taxon_id -format xml \
    | xtract -pattern Taxon -block LineageEx -sep "\n" -element TaxId > taxonIds.txt
    # Adds our input id to the file, as it is not
    echo "$taxon_id" >> taxonIds.txt
    tac taxonIds.txt > lineage.txt
    """
}

process assignArbaAnnotation {
  container = 'veupathdb/iprscan5:1.3.0'
  input:
    path lineage
    path filteredInterproResults
    tuple val(abbrev), val(taxon_id)        

  output:
    path 'names.tsv'
    path filteredInterproResults
    tuple val(abbrev), val(taxon_id)        

  script:
    """
    assignArbaNames.pl --iprscan $filteredInterproResults \
                       --arbaRules /bin/rulesheet.tsv \
                       --lineage $lineage \
                       --outputFile names.tsv
    """
}

process formatArbaOutput {
  container = 'veupathdb/iprscan5:1.3.0'
  input:
    path arbaNames
    path filteredInterproResults
    tuple val(abbrev), val(taxon_id)        
    
  output:
    path 'arbaAnnotation.tsv'
    path filteredInterproResults
    tuple val(abbrev), val(taxon_id)        

  script:
    """
    formatArbaOutput.pl --arbaOutput $arbaNames --outputFile arbaAnnotation.tsv
    """
}

process pfam {
  container = 'veupathdb/iprscan5:1.3.0'
  input:
    path arbaAnnotations
    path filteredInterproResults
    tuple val(abbrev), val(taxon_id)        

  output:
    path 'pfam.tsv'
    path arbaAnnotations
    tuple val(abbrev), val(taxon_id)        

  script:
    """
    addPfamDescriptions.pl --iprscan $filteredInterproResults \
                           --arbaOutput $arbaAnnotations \
                           --outputFile pfam.tsv
    """
}

process formatPFamAndArba {
  container = 'veupathdb/iprscan5:1.3.0'
  
  publishDir "$params.outputDir", mode: "copy"
  
  input:
    path pfam  
    path arbaAnnotations
    tuple val(abbrev), val(taxon_id)        

  output:
    path '*arbaAndPfamResults.tsv'

  script:
    """
    formatAnnotationOutput.pl --arba $arbaAnnotations \
                              --pfam $pfam \
                              --output ${abbrev}_arbaAndPfamResults.tsv
    """
}

workflow arbaAssign {
  take:
    abbrevAndIds

  main:
       filteredInterproResults = filterInterproByLongestProteinPerGene(abbrevAndIds,params.interproResults,params.proteomes) 
      lineage = runEDirect(filteredInterproResults)
      arbaAnnotation = assignArbaAnnotation(lineage)
      formattedArba = formatArbaOutput(arbaAnnotation)
      pfamAndArba = pfam(formattedArba)
      formatPFamAndArba(pfamAndArba)
      
}