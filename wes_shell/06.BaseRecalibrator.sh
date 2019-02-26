soft/jdk1.8.0_20/bin/java -Xmx32G -jar soft/gatk-3.6/GenomeAnalysisTK.jar -T BaseRecalibrator -I fq.realign.bam -R hg19/ucsc.hg19.fasta -L human_v6/trim_S07604514_Regions.bed -ip 100 -nct 6  --knownSites hg19/dbsnp_138.hg19.vcf --knownSites hg19/Mills_and_1000G_gold_standard.indels.hg19.sites.vcf --knownSites hg19/1000G_phase1.indels.hg19.sites.vcf -o fq.recalibrated.bam.grp && soft/jdk1.8.0_20/bin/java -Xmx32G -jar soft/gatk-3.6/GenomeAnalysisTK.jar -T PrintReads -I fq.realign.bam -R hg19/ucsc.hg19.fasta -nct 6  -BQSR fq.recalibrated.bam.grp -o fq.recalibrated.bam
