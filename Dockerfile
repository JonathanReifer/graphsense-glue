
# Docker file for tools needed to get graphsense up and running
# (using graphsense-transformation)
#
# Scala and sbt Dockerfile
#
# https://github.com/hseeberger/scala-sbt
#

# Pull base image
ARG BASE_IMAGE_TAG
FROM openjdk:${BASE_IMAGE_TAG:-8u212-b04-jdk-stretch}

# Env variables
ARG SCALA_VERSION
ENV SCALA_VERSION ${SCALA_VERSION:-2.11.12}
ARG SBT_VERSION
ENV SBT_VERSION ${SBT_VERSION:-1.3.0}

# Install sbt
RUN \
  curl -L -o sbt-$SBT_VERSION.deb https://dl.bintray.com/sbt/debian/sbt-$SBT_VERSION.deb && \
  dpkg -i sbt-$SBT_VERSION.deb && \
  rm sbt-$SBT_VERSION.deb && \
  apt-get update && \
  apt-get install sbt

# Add and use user sbtuser
RUN groupadd --gid 1001 sbtuser && useradd --gid 1001 --uid 1001 sbtuser --shell /bin/bash
RUN chown -R sbtuser:sbtuser /opt
RUN mkdir /home/sbtuser && chown -R sbtuser:sbtuser /home/sbtuser
RUN mkdir /logs && chown -R sbtuser:sbtuser /logs
USER sbtuser

# Switch working directory
WORKDIR /home/sbtuser  

# Install Scala
## Piping curl directly in tar
RUN \
  #curl -fsL https://downloads.typesafe.com/scala/$SCALA_VERSION/scala-$SCALA_VERSION.tgz | tar xfz - -C /home/sbtuser/ && \
  curl -fsL https://downloads.lightbend.com/scala/2.11.12/scala-2.11.12.tgz | tar xfz - -C /home/sbtuser/ && \
  echo >> /home/sbtuser/.bashrc && \
  echo "export PATH=~/scala-$SCALA_VERSION/bin:$PATH" >> /home/sbtuser/.bashrc

# Prepare sbt
RUN \
  sbt sbtVersion && \
  mkdir -p project && \
  echo "scalaVersion := \"${SCALA_VERSION}\"" > build.sbt && \
  echo "sbt.version=${SBT_VERSION}" > project/build.properties && \
  echo "case object Temp" > Temp.scala && \
  sbt compile && \
  rm -r project && rm build.sbt && rm Temp.scala && rm -r target

# Link everything into root as well
# This allows users of this container to choose, whether they want to run the container as sbtuser (non-root) or as root
USER root
RUN \
  echo "export PATH=/home/sbtuser/scala-$SCALA_VERSION/bin:$PATH" >> /root/.bashrc && \
  ln -s /home/sbtuser/.ivy2 /root/.ivy2 && \
  ln -s /home/sbtuser/.sbt /root/.sbt

# Switch working directory back to root
## Users wanting to use this container as non-root should combine the two following arguments
## -u sbtuser
## -w /home/sbtuser
WORKDIR /root 


###INSTALLL HADOOP AND SPARK
### Sourced from: https://github.com/jerowe/docker-spark/blob/master/Dockerfile-getty

# HADOOP
ENV HADOOP_VERSION 3.0.0
ENV HADOOP_HOME /usr/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV PATH $PATH:$HADOOP_HOME/bin
RUN curl -sL --retry 3 \
  "http://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz" \
  | gunzip \
  | tar -x -C /usr/ \
 && rm -rf $HADOOP_HOME/share/doc \
 && chown -R root:root $HADOOP_HOME

# SPARK
ENV SPARK_VERSION 2.4.0
ENV SPARK_PACKAGE spark-${SPARK_VERSION}-bin-without-hadoop
ENV SPARK_HOME /usr/spark-${SPARK_VERSION}
ENV SPARK_DIST_CLASSPATH="$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*"
ENV PATH $PATH:${SPARK_HOME}/bin
RUN curl -sL --retry 3 \
  "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_PACKAGE}.tgz" \
  | gunzip \
  | tar x -C /usr/ \
 && mv /usr/$SPARK_PACKAGE $SPARK_HOME \
 && chown -R root:root $SPARK_HOME

WORKDIR $SPARK_HOME

### INSTALL CASSANDRA 3.11 ####
### Sourced from: https://idroot.us/install-apache-cassandra-debian-9/

RUN echo "deb http://www.apache.org/dist/cassandra/debian 311x main" >/etc/apt/sources.list.d/cassandra.source.list && \
    apt-get update && \ 
    apt-get install  --allow-unauthenticated -y cassandra

## Need to pull graphsense-cluster
RUN  cd /root && wget https://github.com/graphsense/graphsense-clustering/archive/v0.4.1.tar.gz && \
	tar -zxf v0.4.1.tar.gz && \
	rm v0.4.1.tar.gz  && \ 
	cd graphsense-clustering-0.4.1 && \
	sbt compile && \
	sbt package && \
	sbt publishLocal

## graphsense-transformation
RUN  cd /root && wget https://github.com/graphsense/graphsense-transformation/archive/v0.4.1.tar.gz && \
	tar -zxf v0.4.1.tar.gz && \
	cd graphsense-transformation-0.4.1 && \
	sbt compile && \
	sbt package
	

#MISC PACKAGE TO HELP GET WORK DONE
RUN apt-get update && \
	apt-get install -y python3-pip less vim

### MISSING LIB FOR transformation
# wget http://mirror.cc.columbia.edu/pub/software/apache//commons/configuration/binaries/commons-configuration-1.10-bin.tar.gz
# tar -zxvf commons-configuration-1.10-bin.tar.gz
# 

## TAGPACKS
#RUN cd /graphsense-tagpacks \ 
#	pip3 install -r /graphsense-tagpacks/requirements.txt \ 
#	./scripts/tag_pack_tool.py ingest -d cassandra packs/*.yaml

#START SPARK
#WORKDIR $SPARK_HOME
#CMD ["bin/spark-class", "org.apache.spark.deploy.master.Master"]
