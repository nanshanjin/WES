soft/jdk1.8.0_20/bin/java -Xmx32G -jar soft/gatk-3.6/GenomeAnalysisTK.jar -T GenotypeGVCFs --variant combine.vcf --variant human_gvcf/BC150584.combine.vcf -R hg19/ucsc.hg19.fasta -nt 6 -o out.raw.vcf
