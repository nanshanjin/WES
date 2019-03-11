> 本流程采用了经典的best practice流程，即bwa+GATK的方法，适用于human WGS/WES，参考了黄树嘉的基因组实战([链接1](https://www.jianshu.com/p/859c0345624c)、[链接2](https://www.jianshu.com/p/0b0c4ab4c38a)、[链接3](https://www.jianshu.com/p/ff8204ae7ebf)、[链接4](https://www.jianshu.com/p/66361e7e2340)，流程采用了最新的GATK4

流程包括
1、比对(bwa)

2、排序(samtools)

3、标记PCR重复(MarkDuplicates)

4、BQSR 碱基质量校正(BaseRecalibrator ApplyBQSR)

5、局部重比对(RealignerTargetCreator、IndelRealigner)

如果变异检测是GATK而且是HaplotypeCaller模块的话，这一步可以省略，因为GATK的HaplotypeCaller中，会对潜在的变异区域进行相同的局部重比对，但是其它的变异检测工具或者GATK的其它模块就没有这样做
6、HaplotypeCaller(HaplotypeCaller CombineGVCFs GenotypeGVCFs)

7、变异质控和过滤

质控的含义和目的是指通过一定的标准，最大可能地剔除假阳性的结果，并尽可能地保留最多的正确数据。
第一种方法 GATK VQSR，它通过机器学习的方法利用多个不同的数据特征训练一个模型（高斯混合模型）对变异数据进行质控，使用VQSR需要具备以下两个条件：
第一，需要一个精心准备的已知变异集，它将作为训练质控模型的真集。比如，Hapmap、OMNI，1000G和dbsnp等这些国际性项目的数据，这些可以作为高质量的已知变异集。
第二，要求新检测的结果中有足够多的变异，不然VQSR在进行模型训练的时候会因为可用的变异位点数目不足而无法进行。适合全基因组分析。
此方法要求新检测的结果中有足够多的变异，不然VQSR在进行模型训练的时候会因为可用的变异位点数目不足而无法进行。可能很多非人的物种在完成变异检测之后没法使用GATK VQSR的方法进行质控，一些小panel、外显子测序，由于最后的变异位点不够，也无法使用VQSR。全基因组分析或多个样本的全外显子组分析适合用此方法。

8、VariantRecalibrator ApplyVQSR
