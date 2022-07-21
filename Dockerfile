FROM interpro/interproscan:5.51-85.0

Label maintainer="rdemko2332@gmail.com"

WORKDIR /opt/interproscan/

RUN  wget ftp://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/5.51-85.0/alt/interproscan-data-5.51-85.0.tar.gz \
  && wget ftp://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/5.51-85.0/alt/interproscan-data-5.51-85.0.tar.gz.md5 \
  && wget https://ftp.ncbi.nlm.nih.gov/pub/mmdb/cdd/rpsbproc/RpsbProc-x64-linux.tar.gz \
  && md5sum -c interproscan-data-5.51-85.0.tar.gz.md5 \
  && tar -pxzf interproscan-data-5.51-85.0.tar.gz \
  && tar -pxzf RpsbProc-x64-linux.tar.gz \
  && rm interproscan-data-5.51-85.0.tar.gz \
  && rm RpsbProc-x64-linux.tar.gz \
  && mv /opt/interproscan/interproscan-5.51-85.0/data/ /opt/interproscan/ \
  && cd /bin/ \
  && wget https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.10.1/ncbi-blast-2.10.1+-x64-linux.tar.gz \
  && tar -zxvf ncbi-blast-2.10.1+-x64-linux.tar.gz \
  && rm ncbi-blast-2.10.1+-x64-linux.tar.gz

ENV PATH=/opt/interproscan/:/opt/interproscan/interproscan-5.51-85.0/:/opt/interproscan/interproscan-5.51-85.0/data/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/interproscan/bin/:/lib/jvm/java-11-openjdk-amd64/bin

ENV JAVA_HOME=/lib/jvm/java-11-openjdk-amd64

RUN python3 initial_setup.py

WORKDIR /work



