#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process runEDirect {
  container = 'veupathdb/edirect:1.0.0'
  input:
    path interproResults
    val taxonId    

  output:
    path interproResults  
    path 'lineage.txt'

  script:
    """
    efetch -db taxonomy -id $taxonId -format xml \
    | xtract -pattern Taxon -block LineageEx -sep "\n" -element TaxId > taxonIds.txt
    # Adds our input id to the file, as it is not
    echo "$taxonId" >> taxonIds.txt
    tac taxonIds.txt > lineage.txt
    """
}

process assignArbaNames {
  container = 'veupathdb/iprscan5:1.3.0'
  input:
    path interproResults
    path lineage

  output:
    path 'names.tsv'

  script:
    """
    assignArbaNames.pl --iprscan $interproResults --arbaRules /bin/rulesheet.tsv --lineage $lineage --outputFile names.tsv
    """
}

process formatResults {
  container = 'veupathdb/iprscan5:1.3.0'
  input:
    path arbaNames
    
  output:
    path 'arbaAnnotation.tsv'

  script:
    """
    formatArbaOutput.pl --arbaOutput $arbaNames --outputFile arbaAnnotation.tsv
    """
}

workflow arbaAssign {
  take:
    interproResults

  main:
      lineage = runEDirect(interproResults,params.taxonId)
      arbaNames = assignArbaNames(lineage)
      formatResults(arbaNames) | collectFile(storeDir: params.outputDir, name: 'arbaAnnotation.tsv')
      
}