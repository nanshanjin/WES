soft/jdk1.8.0_20/bin/java -Xmx32G -jar soft/gatk-3.6/GenomeAnalysisTK.jar -T CombineGVCFs -R hg19/ucsc.hg19.fasta -V fq.recalibrated.bam.g.vcf.gz -V fq.recalibrated.bam.g.vcf.gz -V fq.recalibrated.bam.g.vcf.gz  -o combine.vcf
