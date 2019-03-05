soft/jdk1.8.0_20/bin/java -Xmx32G -jar soft/gatk-3.6/GenomeAnalysisTK.jar -T HaplotypeCaller -R hg19/ucsc.hg19.fasta -I fq.recalibrated.bam -L human_v6/trim_S07604514_Regions.bed -ip 100 --emitRefConfidence GVCF --variant_index_type LINEAR --variant_index_parameter 128000 -o fq.recalibrated.bam.g.vcf.gz