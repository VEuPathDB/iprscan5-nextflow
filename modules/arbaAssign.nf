#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process filterInterproByLongestProteinPerGene {
  container = 'veupathdb/iprscan5:1.3.0'
  input:
    path interproResults
    path proteome    

  output:
    path 'filteredInterproResults.tsv'

  script:
    """
    filterInterproByLongest.pl --fasta $proteome \
                                    --interpro $interproResults \
                                    --output filteredInterproResults.tsv
    """
}

process runEDirect {
  container = 'veupathdb/edirect:1.0.0'
  input:
    path filteredInterproResults
    val taxonId    

  output:
    path 'lineage.txt'  
    path filteredInterproResults

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
    path filteredInterproResults

  output:
    path 'names.tsv'
    path filteredInterproResults    

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
    
  output:
    path 'arbaAnnotation.tsv'
    path filteredInterproResults      

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

  output:
    path 'pfam.tsv'
    path arbaAnnotations    

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
      filteredInterproResults = filterInterproByLongestProteinPerGene(interproResults,params.proteome) 
      lineage = runEDirect(filteredInterproResults,params.taxonId)
      arbaAnnotation = assignArbaAnnotation(lineage)
      formattedArba = formatArbaOutput(arbaAnnotation)
      pfamAndArba = pfam(formattedArba)
      formatPFamAndArba(pfamAndArba)
      
}