soft/jdk1.8.0_20/bin/java -Xmx32G -jar soft/picard-2.18.0/picard.jar FastqToSam F1=fq_1.fastq.gz F2=fq_2.fastq.gz O=fq.ubam RG=fq LB=fq SM=fq  PL=ILLUMINA R=hg19/ucsc.hg19.fasta
