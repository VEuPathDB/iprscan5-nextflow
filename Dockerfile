FROM interpro/interproscan:5.51-85.0

Label maintainer="rdemko2332@gmail.com"

WORKDIR /opt/interproscan/

RUN cd /bin/ \
  && wget https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.10.1/ncbi-blast-2.10.1+-x64-linux.tar.gz \
  && tar -zxvf ncbi-blast-2.10.1+-x64-linux.tar.gz \
  && rm ncbi-blast-2.10.1+-x64-linux.tar.gz

ADD /bin/interproscan.properties /opt/interproscan
ADD /bin/* /usr/bin/
RUN cd /usr/bin/ \
  && chmod +x *.pl

ENV PATH=/opt/interproscan/:/opt/interproscan/interproscan-5.51-85.0/:/opt/interproscan/interproscan-5.51-85.0/data/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/interproscan/bin/:/lib/jvm/java-11-openjdk-amd64/bin

ENV JAVA_HOME=/lib/jvm/java-11-openjdk-amd64

RUN python3 initial_setup.py

WORKDIR /work



