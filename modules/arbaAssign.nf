#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process runEDirect {
  container = 'veupathdb/edirect:1.0.0'
  input:
    path interproResults
    val taxonId    

  output:
    path 'lineage.txt'  
    path interproResults

  script:
    """
    efetch -db taxonomy -id $taxonId -format xml \
    | xtract -pattern Taxon -block LineageEx -sep "\n" -element TaxId > taxonIds.txt
    # Adds our input id to the file, as it is not
    echo "$taxonId" >> taxonIds.txt
    tac taxonIds.txt > lineage.txt
    """
}

process assignArbaAnnotation {
  container = 'veupathdb/iprscan5:1.3.0'
  input:
    path lineage
    path interproResults

  output:
    path 'names.tsv'
    path interproResults

  script:
    """
    assignArbaNames.pl --iprscan $interproResults \
                       --arbaRules /bin/rulesheet.tsv \
                       --lineage $lineage \
                       --outputFile names.tsv
    """
}

process formatArbaOutput {
  container = 'veupathdb/iprscan5:1.3.0'
  input:
    path arbaNames
    path interproResults    
    
  output:
    path 'arbaAnnotation.tsv'
    path interproResults, emit: interproResults    

  script:
    """
    formatArbaOutput.pl --arbaOutput $arbaNames --outputFile arbaAnnotation.tsv
    """
}

process pfam {
  container = 'veupathdb/iprscan5:1.3.0'
  input:
    path arbaAnnotations
    path interproResults

  output:
    path 'pfam.tsv'
    path arbaAnnotations    

  script:
    """
    addPfamDescriptions.pl --iprscan $interproResults \
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

  output:
    path 'arbaAndPfamResults.tsv'

  script:
    """
    formatAnnotationOutput.pl --arba $arbaAnnotations \
                              --pfam $pfam \
                              --output arbaAndPfamResults.tsv
    """
}

workflow arbaAssign {
  take:
    interproResults

  main:
      lineage = runEDirect(interproResults,params.taxonId)
      arbaAnnotation = assignArbaAnnotation(lineage)
      formattedArba = formatArbaOutput(arbaAnnotation)
      pfamAndArba = pfam(formattedArba)
      formatPFamAndArba(pfamAndArba)
      
}