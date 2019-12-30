> 本流程采用了经典的 Best Practices流程，即bwa+GATK的方法，适用于human WGS/WES

流程包括
## 1 质控
```shell
# fastp,version 0.19.5
fastp -i sample_1.fastq.gz -I sample_2.fastq.gz \
    -o sample_clean_1.fastq.gz -O sample_clean_2.fastq.gz \
    -q 15 \
    -u 40 \
    -n 5 \
    -l 60 \ #reads shorter than length_required will be discarded, default is 15 目前测序平台双端基本都是150bp，保留60bp以上进入后续分析
    -W 4 \
    -M 20 \
    -h sample_fastp.html -j sample_fastp.json
```
## 2 picard FastqToSam
GATK的Best Practices流程中，有一步骤是把bam转成ubam格式，然后再用ubam去做markadapter和mapping。uBAM就是非比对的BAM文件，fastq可以通过picard这个工具将其转为这个格式。它有不少优于fastq格式的地方，比如：同一个read的数据都在同一行；拓展性强，可以添加丰富的metadata；方便维护，同一个样本的测序数据甚至可以只通过一份uBAM来存储就行了等。但是除了GATK的官方，其他机构使用ubam格式的很少，但是在这里我还是把ubam的整个使用放在流程中。
```shell
####picard FastqToSam
/home/Group/dna/soft/jdk1.8.0_20/bin/java -Xmx32G \
    -Djava.io.tmpdir=/tmp/ \
    -jar /home/Group/dna/soft/picard-2.18.0/picard.jar \
    FastqToSam \
    F1=sample_1.fastq.gz \
    F2=sample_2.fastq.gz \
    O=sample.ubam \
    RG=sample LB=sample SM=sample PL=ILLUMINA \
    R=/gatk_resource_bundle/hg19/ucsc.hg19.fasta
####ubam markadapter
/home/Group/dna/soft/jdk1.8.0_20/bin/java -Xmx32G \
    -Djava.io.tmpdir=/tmp/ \
    -jar /home/Group/dna/soft/picard-2.18.0/picard.jar \
    MarkIlluminaAdapters \
    I=sample.ubam \
    O=sample.markadapter.ubam \
    M=sample.markadapter.ubam_metrics.txt 
```
## 3 比对
比对就是把测序数据定位到参考基因组上，确定每一个read在基因组中的位置
常用的比对软件就是bwa了
```shell
##构建索引
bwa index ref.fa

/home/Group/dna/soft/jdk1.8.0_20/bin/java -Xmx32G \
    -Djava.io.tmpdir=/tmp/ \
    -jar /home/Group/dna/soft/picard-2.18.0/picard.jar \
    SamToFastq \
    I=sample.markadapter.ubam \
    F=/dev/stdout \
    CLIPPING_ATTRIBUTE=XT CLIPPING_ACTION=2 INTERLEAVE=true NON_PF=true \
    |/home/Group/dna/soft/bwa-0.7.17/bwa mem \
    -M -t 6 \
    -p /gatk_resource_bundle/hg19/ucsc.hg19.fasta - \
    |/home/Group/dna/soft/jdk1.8.0_20/bin/java -Xmx32G \
    -Djava.io.tmpdir=/tmp/ \
    -jar /home/Group/dna/soft/picard-2.18.0/picard.jar \
    MergeBamAlignment \
    ALIGNED_BAM=/dev/stdin \
    UNMAPPED_BAM=sample.ubam O=sample.bam \
    R=/home/Group/dna/data/gatk_resource_bundle/hg19/ucsc.hg19.fasta \
    CREATE_INDEX=true ADD_MATE_CIGAR=true CLIP_ADAPTERS=false \
    CLIP_OVERLAPPING_READS=true INCLUDE_SECONDARY_ALIGNMENTS=true \
    MAX_INSERTIONS_OR_DELETIONS=-1 \
    PRIMARY_ALIGNMENT_STRATEGY=MostDistant ATTRIBUTES_TO_RETAIN=XS

##bwa比对中还可以加入read数据信息，如
bwa mem -t 4 \
    -R '@RG\tID:foo\tPL:illumina\tSM:sample' \
    ref.fa sample_1.fastq.gz sample_2.fastq.gz \
    |samtools view -Sb - > sample.bam
##-R 设置Read Group信息，它是read数据的组别标识，并且其中的ID，PL和SM信息在正式的项目中是不能缺少的
(如果样本包含多个测序文库的话，LB信息也不要省略)，另外由于考虑到与GATK的兼容关系，PL（测序平台）信
息不能随意指定，必须是：ILLUMINA，SLX，SOLEXA，SOLID，454，LS454，COMPLETE，PACBIO，IONTORRENT，
CAPILLARY，HELICOS或UNKNOWN这12个中的一个。
```
## 4 MarkDuplicates
```shell
/home/Group/dna/soft/jdk1.8.0_20/bin/java -Xmx32G \
    -Djava.io.tmpdir=/tmp/ \
    -jar /home/Group/dna/soft/picard-2.18.0/picard.jar \
    MarkDuplicates \
    INPUT=sample.bam \
    OUTPUT=sample.markdup.bam \
    METRICS_FILE=sample.markdup.bam.metrics.txt \
    MAX_FILE_HANDLES=824 \ #Maximum number of file handles to keep open when spilling read ends to disk. Set this number a little lower than the per-process maximum number of file that may be open.This number can be found by executing the 'ulimit -n' command on a Unix system.This option can be set to 'null' to clear the default value.Default value 8000；ulimit -n查看linux最大文件链接数，我们是1024，并在此基础上减200，以减少服务器载荷
    OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 \ #The maximum offset between two duplicate clusters in order to consider them optical duplicates. The default is appropriate for unpatterned versions of the Illumina platform. For the patterned flowcell models, 2500 is moreappropriate. For other platforms and models, users should experiment to find what works best.  Default value: 100. This option can be set to 'null' to clear the default value. 对于patterned flowcell models，2500更合适，参考GATK最佳实践
    CREATE_INDEX=true
```
## 5 BaseRecalibrator ApplyBQSR
```shell
/home/Group/dna/soft/gatk-4.1.0.0/gatk --java-options \
    '-Xmx32G -DGATK_STACKTRACE_ON_USER_EXCEPTION=true' \
    BaseRecalibrator \
    -I sample.markdup.bam \
    -R /gatk_resource_bundle/hg19/ucsc.hg19.fasta \
    -L /Sureselect_hg19/human_v6/trim_S07604514_Regions.bed \
    -ip 100 \ #IntegerAmount of padding (in bp) to add to each interval you are including.  Default value: 0. 外显子区间两边延长100bp
    --known-sites /gatk_resource_bundle/hg19/dbsnp_138.hg19.vcf \
    --known-sites /gatk_resource_bundle/hg19/Mills_and_1000G_gold_standard.indels.hg19.sites.vcf \
    --known-sites /gatk_resource_bundle/hg19/1000G_phase1.indels.hg19.sites.vcf \
    -O sample.recalibrated.bam.grp \
    && /home/Group/dna/soft/gatk-4.1.0.0/gatk --java-options \
    '-Xmx32G -DGATK_STACKTRACE_ON_USER_EXCEPTION=true' \
    ApplyBQSR \
    -bqsr sample.recalibrated.bam.grp \
    -I sample.markdup.bam \
    -R /gatk_resource_bundle/hg19/ucsc.hg19.fasta \
    -O sample.recalibrated.bam
```
## 6 HaplotypeCaller
```shell
/home/Group/dna/soft/gatk-4.1.0.0/gatk --java-options \
    '-Xmx32G -DGATK_STACKTRACE_ON_USER_EXCEPTION=true' \
    HaplotypeCaller \
    -R /gatk_resource_bundle/hg19/ucsc.hg19.fasta \
    -I sample.recalibrated.bam \
    -L /Sureselect_hg19/human_v6/trim_S07604514_Regions.bed \
    -ip 100 \
    --emit-ref-confidence GVCF \
    -O sample.recalibrated.bam.g.vcf.gz
```
## 7 combine gvcf 
```shell
/home/Group/dna/soft/gatk-4.1.0.0/gatk --java-options \
    '-Xmx32G -DGATK_STACKTRACE_ON_USER_EXCEPTION=true' \
    CombineGVCFs \
    -R /gatk_resource_bundle/hg19/ucsc.hg19.fasta \
    -V C29.recalibrated.bam.g.vcf.gz \
    -V C55.recalibrated.bam.g.vcf.gz \
    -V C69.recalibrated.bam.g.vcf.gz \
    -V N1.recalibrated.bam.g.vcf.gz \
    -V N2.recalibrated.bam.g.vcf.gz \
    -V N4.recalibrated.bam.g.vcf.gz \
    -V /gatk_resource_bundle/human_gvcf/BC150584.combine.vcf \#当样本数量少于30，加正常样本数量，然后去做VQSR，最后通过SelectVariants保留客户样本
    -O all.combine.vcf
```
## 8 GenotypeGVCFs
```shell
/home/Group/dna/soft/gatk-4.1.0.0/gatk --java-options \
    '-Xmx32G -DGATK_STACKTRACE_ON_USER_EXCEPTION=true' \
    GenotypeGVCFs \
    --variant all.combine.vcf \
    -R /gatk_resource_bundle/hg19/ucsc.hg19.fasta \
    -O all.raw.vcf
```
## 9 VariantRecalibrator ApplyVQSR
```shell
/home/Group/dna/soft/gatk-4.1.0.0/gatk --java-options \
    '-Xmx32G -DGATK_STACKTRACE_ON_USER_EXCEPTION=true' \
    VariantRecalibrator \
    -R /home/Group/dna/data/gatk_resource_bundle/hg19/ucsc.hg19.fasta \
    -V all.raw.vcf \
    -resource:hapmap,known=false,training=true,truth=true,prior=15.0 /gatk_resource_bundle/hg19/hapmap_3.3.hg19.sites.vcf \    -resource:omni,known=false,training=true,truth=true,prior=12.0 /home/Group/dna/data/gatk_resource_bundle/hg19/1000G_omni2.5.hg19.sites.vcf \
    -resource:1000G,known=false,training=true,truth=false,prior=10.0 /gatk_resource_bundle/hg19/1000G_phase1.snps.high_confidence.hg19.sites.vcf \
    -resource:dbsnp,known=true,training=false,truth=false,prior=7.0 /gatk_resource_bundle/hg19/dbsnp_138.hg19.vcf \    
    -an QD -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum \
    -mode SNP -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
    --max-gaussians 4 \ # Max number of Gaussians for the positive model  Default value: 8. 参考GATK最佳实践
    -tranches-file recalibrate_SNP.tranches \
    -O recalibrate_SNP.recal \
    && /home/Group/dna/soft/gatk-4.1.0.0/gatk --java-options \
    '-Xmx32G -DGATK_STACKTRACE_ON_USER_EXCEPTION=true' \
    ApplyVQSR \
    -R /gatk_resource_bundle/hg19/ucsc.hg19.fasta \
    -V all.raw.vcf \
    -mode SNP \
    --recal-file recalibrate_SNP.recal \
    --tranches-file recalibrate_SNP.tranches \
    -O all.recalibrated_snps_raw_indels.vcf
###
/home/Group/dna/soft/gatk-4.1.0.0/gatk --java-options \
    '-Xmx32G -DGATK_STACKTRACE_ON_USER_EXCEPTION=true' \
    VariantRecalibrator \
    -R /home/Group/dna/data/gatk_resource_bundle/hg19/ucsc.hg19.fasta \
    -V all.recalibrated_snps_raw_indels.vcf \
    -resource:mills,known=true,training=true,truth=true,prior=12.0 /gatk_resource_bundle/hg19/Mills_and_1000G_gold_standard.indels.hg19.sites.vcf \
    -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 /gatk_resource_bundle/hg19/dbsnp_138.hg19.vcf \
    -an QD -an FS -an SOR -an MQRankSum -an ReadPosRankSum \
    -mode INDEL \
    -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
    --max-gaussians 4 \
    -tranches-file recalibrate_INDEL.tranches -O recalibrate_INDEL.recal \
    && /home/Group/dna/soft/gatk-4.1.0.0/gatk --java-options \
    '-Xmx32G -DGATK_STACKTRACE_ON_USER_EXCEPTION=true' \
    ApplyVQSR \
    -R /gatk_resource_bundle/hg19/ucsc.hg19.fasta \
    -V all.recalibrated_snps_raw_indels.vcf \
    -mode INDEL \
    --recal-file recalibrate_INDEL.recal \
    --tranches-file recalibrate_INDEL.tranches \
    -O all.recalibrated_variants.vcf
###
/home/Group/dna/soft/gatk-4.1.0.0/gatk --java-options \
    '-Xmx32G -DGATK_STACKTRACE_ON_USER_EXCEPTION=true' \
    SelectVariants \
    -R /gatk_resource_bundle/hg19/ucsc.hg19.fasta \
    -V all.recalibrated_variants.vcf \
    -sn sample1 -sn sample2 -sn sample3 \
    -O all.final.vcf
```
## 10 annovar 
```shell
/home/SoftWare/perl-5.26/bin/perl /home/Group/dna/soft/annovar20170717/table_annovar.pl \
    --outfile annotation.final \
    --vcfinput all.final.vcf \
    --buildver hg19 /home/Group/dna/data/humandb/hg19db \
    --otherinfo --remove \
    --protocol refGene,ensGene,snp138,avsnp150,snp138NonFlagged,kaviar_20150923,popfreq_all_20150413,dbnsfp33a,cosmic70,clinvar_20170905,intervar_20180118,gnomad_exome,gwascatalog,phastConsElements46way,genomicSuperDups,tfbs,wgRna,targetScanS \
    --operation g,g,f,f,f,f,f,f,f,f,f,f,r,r,r,r,r,r \
    --thread 6
```


**注意：外显子数据要加上外显子捕获区域的bed文件，并把-ip设为reads长，全基因组数据则不需要加-L 和 -ip**

**质控的含义和目的是指通过一定的标准，最大可能地剔除假阳性的结果，并尽可能地保留最多的正确数据。
第一种方法 GATK VQSR，它通过机器学习的方法利用多个不同的数据特征训练一个模型（高斯混合模型）对变异数据进行质控，使用VQSR需要具备以下两个条件：
第一，需要一个精心准备的已知变异集，它将作为训练质控模型的真集。比如，Hapmap、OMNI，1000G和dbsnp等这些国际性项目的数据，这些可以作为高质量的已知变异集。
第二，要求新检测的结果中有足够多的变异，不然VQSR在进行模型训练的时候会因为可用的变异位点数目不足而无法进行。适合全基因组分析。
此方法要求新检测的结果中有足够多的变异，不然VQSR在进行模型训练的时候会因为可用的变异位点数目不足而无法进行。可能很多非人的物种在完成变异检测之后没法使用GATK VQSR的方法进行质控，一些小panel、外显子测序，由于最后的变异位点不够，也无法使用VQSR。全基因组分析或多个样本的全外显子组分析适合用此方法。**

## SelectVariants
```shell
gatk-4.1.0.0/gatk SelectVariants \
   -V NPC15F.snps.VQSR.vcf.gz \
   -O NPC15F.final.snp.vcf.gz \
   -select-type SNP \
   -R ucsc.hg19.fasta \
   -L hg19/trim_S07604514_Regions.bed -ip 100 \
   --tmp-dir ./
gatk-4.1.0.0/gatk SelectVariants \
   -V sample.indel.VQSR.vcf.gz \
   -O sample.final.indel.vcf.gz \
   -select-type INDEL \
   -R ucsc.hg19.fasta \
   -L hg19/trim_S07604514_Regions.bed -ip 100 \
   --tmp-dir ./
```
