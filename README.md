> 本流程采用了经典的 Best Practices流程，即bwa+GATK的方法，适用于human WGS/WES，参考了黄树嘉的基因组实战([链接1](https://www.jianshu.com/p/859c0345624c)、[链接2](https://www.jianshu.com/p/0b0c4ab4c38a)、[链接3](https://www.jianshu.com/p/ff8204ae7ebf)、[链接4](https://www.jianshu.com/p/66361e7e2340)，流程采用了最新的GATK4


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
## 2 比对
比对就是把测序数据定位到参考基因组上，确定每一个read在基因组中的位置
常用的比对软件就是bwa了
```shell
##构建索引
bwa index ref.fa
##bwa比对，用samtools完成BAM格式转换
bwa mem -t 4 \
    -R '@RG\tID:foo\tPL:illumina\tSM:sample' \
    ref.fa sample_1.fastq.gz sample_2.fastq.gz \
    |samtools view -Sb - > sample.bam
##-R 设置Read Group信息，它是read数据的组别标识，并且其中的ID，PL和SM信息在正式的项目中是不能缺少的
(如果样本包含多个测序文库的话，LB信息也不要省略)，另外由于考虑到与GATK的兼容关系，PL（测序平台）信
息不能随意指定，必须是：ILLUMINA，SLX，SOLEXA，SOLID，454，LS454，COMPLETE，PACBIO，IONTORRENT，
CAPILLARY，HELICOS或UNKNOWN这12个中的一个。
```
## 3 排序(samtools)
用samtools对原始的比对结果按照参考序列位置从小到大进行排序
```shell
samtools sort -@ 4 -m 4G -O bam -o sample.sorted.bam sample.bam
```
## 4 标记PCR重复
使用GATK标记出排完序的数据中的PCR重复序列
```shell
gatk/4.0.1.2/gatk MarkDuplicates -I sample.sorted.bam \
    -O --sample.sorted.markdup.bam \
    -M sample.sorted.markdup_metrics.txt
```
## 5 比对索引
创建比对索引文件，它可以让我们快速地访问基因组上任意位置的比对情况，这一点非常有助于我们随时了解数据
当有bam文件时，都可以创建索引
```shell
samtools index sample.sorted.markdup.bam
```
## 6 局部重比对(RealignerTargetCreator、IndelRealigner)
这一步在GATK3中，GATK4已经取消，应该是加入到HaplotypeCaller中，老版本的GATK可以加入这一步

## 7 BQSR 碱基质量校正(BaseRecalibrator ApplyBQSR)
这里计算出了所有需要进行重校正的read和特征值，然后把这些信息输出为一份校准表文件（wes.recal_data.table）
```shell
gatk/4.0.1.2/gatk BaseRecalibrator \
  -R ref.fa\
  -I sample.sorted.markdup.bam \
  --known-sites 1000G_phase1.indels.hg19.vcf \
  --known-sites Mills_and_1000G_gold_standard.indels.hg19.sites.vcf.gz \
  --known-sites dbsnp_138.hg19.vcf.gz \
  -O sample.sorted.markdup.recal_data.table
```
ApplyBQSR这一步利用第一步得到的校准表文件（wes.recal_data.table）重新调整原来BAM文件中的碱基质量值，并使用这个新
的质量值重新输出一份新的BAM>文件。
```shell
gatk/4.0.1.2/gatk ApplyBQSR \
   --bqsr-recal-file sample.sorted.markdup.recal_data.table \
   -R ref.fa \
   -I sample.sorted.markdup.bam \
   -O sample.sorted.markdup.BQSR.bam
```
**注意：此步骤以及后面几个步骤中外显子数据要加上外显子捕获区域的bed文件，并把-ip设为reads长，全基因组数据则不需要加-L 和 -ip**

## 8 HaplotypeCaller(HaplotypeCaller CombineGVCFs GenotypeGVCFs)
```shell
#HaplotypeCaller
gatk/4.0.1.2/gatk HaplotypeCaller \
  -R ref.fa \
  --emit-ref-confidence GVCF \
  -I sample.sorted.markdup.BQSR.bam \
  -O sample.g.vcf
#combine gvcf
gatk/4.0.1.2/gatk CombineGVCFs \
  -R ref.fa \
  -V sample1.g.vcf -V sample2.g.vcf ....\
  -O all.g.vcf.gz \
#通过gvcf检测变异
gatk/4.0.1.2/gatk GenotypeGVCFs \
  -R ref.fa \
  -V all.g.vcf.gz \
  -O sample.vcf.gz
```
## 9 变异质控和过滤(VariantRecalibrator ApplyVQSR)

质控的含义和目的是指通过一定的标准，最大可能地剔除假阳性的结果，并尽可能地保留最多的正确数据。
第一种方法 GATK VQSR，它通过机器学习的方法利用多个不同的数据特征训练一个模型（高斯混合模型）对变异数据进行质控，使用VQSR需要具备以下两个条件：
第一，需要一个精心准备的已知变异集，它将作为训练质控模型的真集。比如，Hapmap、OMNI，1000G和dbsnp等这些国际性项目的数据，这些可以作为高质量的已知变异集。
第二，要求新检测的结果中有足够多的变异，不然VQSR在进行模型训练的时候会因为可用的变异位点数目不足而无法进行。适合全基因组分析。
此方法要求新检测的结果中有足够多的变异，不然VQSR在进行模型训练的时候会因为可用的变异位点数目不足而无法进行。可能很多非人的物种在完成变异检测之后没法使用GATK VQSR的方法进行质控，一些小panel、外显子测序，由于最后的变异位点不够，也无法使用VQSR。全基因组分析或多个样本的全外显子组分析适合用此方法。
```shell
#SNP
gatk/4.0.1.2/gatk VariantRecalibrator \
  -R ref.fa \
  -V sample.vcf.gz \
  -resource:hapmap,know=false,training=true,truth=true,prior=15.0 hapmap_3.3.hg19.vcf \
  -resource:omini,know=false,training=true,truth=false,prior=12.0 1000G_omni2.5.hg19.vcf \
  -resource:1000G,know=false,training=true,truth=false,prior=10.0 1000G_phase1.snps.high_confidence.hg19.sites.vcf.gz \
  -resource:1000G,know=true,training=false,truth=false,prior=6.0 dbsnp_138.hg19.vcf.gz \
  -an DP #适用于WGS，不适用于WES\
  -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum \
  -mode SNP \
  -tranche 100.0 -tranche 99.99 -tranche 99.0  -tranche  95.0 -tranche 90.0 \
  -rscriptFile sample.snps.plot.R
  --tranches-file sample.snps.tranches
  -O sample.snps.recal
gatk/4.0.1.2/gatk ApplyVQSR \
  -R ref.fa \
  -V sample.vcf.gz
  --tranches-file sample.snps.tranches \
  --recal-file sample.snps.recal \
  -mode SNP \
  -O sample.snps.VQSR.vcf.gz \
#INDEL
gatk/4.0.1.2/gatk VariantRecalibrator \
  -R ref.fa \
  -V sample.vcf.gz \
  -resource:mills,know=true,training=true,truth=true,prior=12.0  Mills_and_1000G_gold_standard.indels.hg19.sites.vcf.gz \
  -an DP -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum \
  -mode INDEL \
  --max-gaussians 6 \
  --tranches-file sample.indel.tranches
  -O sample.indel.recal
gatk/4.0.1.2/gatk ApplyVQSR \
  -R ref.fa \
  -V sample.vcf.gz  \
  --tranches-file sample.indel.tranches \
  --recal-file sample.indel.recal \
  -mode INDEL \
  -O sample.indel.VQSR.vcf.gz \
```
但是似乎mode模式还是没有区分SNP和INDEL，那只能再SelectVariants一下了
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
