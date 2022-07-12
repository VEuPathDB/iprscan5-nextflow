FROM interpro/interproscan:5.51-85.0

WORKDIR /opt/interproscan/

RUN  wget ftp://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/5.51-85.0/alt/interproscan-data-5.51-85.0.tar.gz \
  && wget ftp://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/5.51-85.0/alt/interproscan-data-5.51-85.0.tar.gz.md5 \
  && md5sum -c interproscan-data-5.51-85.0.tar.gz.md5 \
  && tar -pxzf interproscan-data-5.51-85.0.tar.gz \
  && rm interproscan-data-5.51-85.0.tar.gz \
  && mv /opt/interproscan/interproscan-5.51-85.0/data/ /opt/interproscan/

RUN cd /bin/ \
  && wget https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.10.1/ncbi-blast-2.10.1+-x64-linux.tar.gz \
  && tar -zxvf ncbi-blast-2.10.1+-x64-linux.tar.gz \
  && rm ncbi-blast-2.10.1+-x64-linux.tar.gz 
  
ENV PATH=/opt/interproscan/:/opt/interproscan/interproscan-5.51-85.0/:/opt/interproscan/interproscan-5.51-85.0/data/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/interproscan/bin/

WORKDIR /work



