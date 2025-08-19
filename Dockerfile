FROM ubuntu:focal

Label maintainer="rdemko2332@gmail.com"

RUN apt-get update && apt-get install -y wget && apt install -y default-jre-headless   && apt install -y python3.8   && apt install -y libdw1 libdw-dev   && apt-get install -y libgomp1   && apt-get install -y perl-doc   && apt-get clean   && apt-get purge   && apt-get autoclean   && apt-get autoremove   && cp /usr/bin/python3.8 /usr/bin/python3   && cp /usr/bin/python3.8 /usr/bin/python   && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN cd /bin/ \
  && wget https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.10.1/ncbi-blast-2.10.1+-x64-linux.tar.gz \
  && tar -zxvf ncbi-blast-2.10.1+-x64-linux.tar.gz \
  && rm ncbi-blast-2.10.1+-x64-linux.tar.gz

WORKDIR /opt/interproscan

ADD bin/interproscan/*.sh /opt/interproscan/
ADD bin/interproscan/*.py /opt/interproscan/
ADD bin/interproscan/interpro* /opt/interproscan/
ADD bin/interproscan/bin /opt/interproscan/bin
ADD bin/interproscan/lib /opt/interproscan/lib
ADD bin/interproscan/src /opt/interproscan/src
ADD bin/interproscan/work /opt/interproscan/work

ENV PATH=/opt/interproscan/:/opt/interproscan/bin/:/opt/interproscan/data/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/lib/jvm/java-11-openjdk-amd64/bin

ENV JAVA_HOME=/lib/jvm/java-11-openjdk-amd64

RUN python3 setup.py -f /opt/interproscan/interproscan.properties

ADD bin/*.pl /usr/bin/
ADD bin/*.py /usr/bin/

WORKDIR /work




