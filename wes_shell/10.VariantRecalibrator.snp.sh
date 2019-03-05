soft/jdk1.8.0_20/bin/java -Xmx32G -jar soft/gatk-3.6/GenomeAnalysisTK.jar -T VariantRecalibrator -R hg19/ucsc.hg19.fasta -input out.raw.vcf -resource:hapmap,known=false,training=true,truth=true,prior=15.0 hg19/hapmap_3.3.hg19.sites.vcf -resource:omni,known=false,training=true,truth=true,prior=12.0 hg19/1000G_omni2.5.hg19.sites.vcf -resource:1000G,known=false,training=true,truth=false,prior=10.0 hg19/1000G_phase1.snps.high_confidence.hg19.sites.vcf -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 hg19/dbsnp_138.hg19.vcf -an QD -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum  -mode SNP -nt 6 -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 -recalFile out.recalibrate_SNP.recal -tranchesFile out.recalibrate_SNP.tranches -rscriptFile out.recalibrate_SNP_plots.R && soft/jdk1.8.0_20/bin/java -Xmx32G -jar soft/gatk-3.6/GenomeAnalysisTK.jar -T ApplyRecalibration -R hg19/ucsc.hg19.fasta -input out.raw.vcf -mode SNP --ts_filter_level 99.0 -recalFile out.recalibrate_SNP.recal -tranchesFile out.recalibrate_SNP.tranches -o out.recalibrated_snps_raw_indels.vcf