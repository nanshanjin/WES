> 本流程采用了经典的 Best Practices流程，即bwa+GATK的方法，适用于human WGS/WES，参考了黄树嘉的基因组实战([链接1](https://www.jianshu.com/p/859c0345624c)、[链接2](https://www.jianshu.com/p/0b0c4ab4c38a)、[链接3](https://www.jianshu.com/p/ff8204ae7ebf)、[链接4](https://www.jianshu.com/p/66361e7e2340)，流程采用了最新的GATK4

流程包括
## 1 质控
这部分流程软件很多，不再复述

## 2 比对
比对就是把测序数据定位到参考基因组上，确定每一个read在基因组中的位置
常用的比对软件就是bwa了
```shell
##构建索引
--bwa index ref.fa
##bwa比对，用samtools完成BAM格式转换
--bwa mem -t 4 -R '@RG\tID:foo\tPL:illumina\tSM:E.coli_K12' ref.fa SRR1770413_1.fastq.gz SRR1770413_2.fastq.gz |samtools view -Sb - > sample.bam
##-R 设置Read Group信息，它是read数据的组别标识，并且其中的ID，PL和SM信息在正式的项目中是不能缺少的(如果样本包含多个测序文库的话，LB信息也不要省略)，另外由于考虑到与GATK的兼容关系，PL（测序平台）信息不能随意指定，必须是：ILLUMINA，SLX，SOLEXA，SOLID，454，LS454，COMPLETE，PACBIO，IONTORRENT，CAPILLARY，HELICOS或UNKNOWN这12个中的一个。
```
2、排序(samtools)

3、标记PCR重复(MarkDuplicates)

4、局部重比对(RealignerTargetCreator、IndelRealigner)

如果变异检测是GATK而且是HaplotypeCaller模块的话，这一步可以省略，因为GATK的HaplotypeCaller中，会对潜在的变异区域进行相同的局部重比对，但是其它的变异检测工具或者GATK的其它模块就没有这样做

5、BQSR 碱基质量校正(BaseRecalibrator ApplyBQSR)

6、HaplotypeCaller(HaplotypeCaller CombineGVCFs GenotypeGVCFs)

7、变异质控和过滤

质控的含义和目的是指通过一定的标准，最大可能地剔除假阳性的结果，并尽可能地保留最多的正确数据。
第一种方法 GATK VQSR，它通过机器学习的方法利用多个不同的数据特征训练一个模型（高斯混合模型）对变异数据进行质控，使用VQSR需要具备以下两个条件：
第一，需要一个精心准备的已知变异集，它将作为训练质控模型的真集。比如，Hapmap、OMNI，1000G和dbsnp等这些国际性项目的数据，这些可以作为高质量的已知变异集。
第二，要求新检测的结果中有足够多的变异，不然VQSR在进行模型训练的时候会因为可用的变异位点数目不足而无法进行。适合全基因组分析。
此方法要求新检测的结果中有足够多的变异，不然VQSR在进行模型训练的时候会因为可用的变异位点数目不足而无法进行。可能很多非人的物种在完成变异检测之后没法使用GATK VQSR的方法进行质控，一些小panel、外显子测序，由于最后的变异位点不够，也无法使用VQSR。全基因组分析或多个样本的全外显子组分析适合用此方法。

8、VariantRecalibrator ApplyVQSR
