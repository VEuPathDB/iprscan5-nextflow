# Nextflow Conversion of Iprscan5Task.pm

### Get Started
  * Install Nextflow
    
    `curl https://get.nextflow.io | bash`
  
  * Run the script
    
    `nextflow run VEuPathDB/Iprscan5 -with-trace -c  <config_file> -r main`

Decription of nextflow configuration parameters:

| param         | value type        | description  |
| ------------- | ------------- | ------------ |
| seqFile  | string | Path to input file |
| outputDir | string | Path to where you would like output files stored |
| outputFile | string | How you would like the outputFile to be named |
| appls | string | Comma separated list of analyses (options are PANTHER, SMART, TIGRFAM, Gene3D, PIRSF, CDD, Pfam, SUPERFAMILY, ProSiteProfiles, MobiDBLite, PRINTS, Coils, ProSitePatterns), if none are specified, all will be run. |
