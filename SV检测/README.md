# SV检测
SV 是 Structural variation 的缩写。结构变异指的是在基因组上一些大的结构性的变异，比如大片段丢失（ Deletion），大片段插入（ Insertion），大片段重复（ Duplication），拷贝数变异（ Copy number variants），倒位（ Inversion），易位（ Translocation）。一般来说结构变异涉及的序列长度在 1kb 到 3Mb 之间。结构变异普遍发生于癌变细胞中，一些癌症已经证实和结构变异导致的基因融合事件有关。我们通常采用BreakDancer、Crest对 Tumor 及 Normal成对样本进行 SV 信息检测。通常全基因组测序比全外显子组测序对SV的检测更为敏感，但是基于全外显子组测序更大的数据量，使得通过全外显子组测序分析SV变得有价值。

## BreakDancer
[documentation](http://gmt.genome.wustl.edu/packages/breakdancer/documentation.html)

[breakdancer目录](https://github.com/kenchen/breakdancer#readme)

在raw-data经过质控过滤(去低值、adapter以及含N的reads)获得clean-data，与参考基因组比对(bwa)的bam经过去重和排序之后得到sorted.bam。拿到bam数之后，就可以着手进行SV的检测了。breakdancer可以进行正常样本和肿瘤配对样本的SV检测，支持多个bam同时输入，输出结果的每一行都会显示变异在哪一个样本中出现，可以用于检测共有突变和特有突变。

```shell
##step1
perl bam2cfg.pl -g -h T.final.bam N.final.bam > breakdancer.cfg
##step2
software/breakdancer/breakdancer-max  -h  -d breakdancer.SV-supporting  breakdancer.bed  breakdancer.cfg  breakdancer.txt
var_sv_breakdancer.filter.pl  -g M -n 6  -a breakdancer.txt  > breakdancer.flt.txt && \
var_sv_breakdancer.toGff.pl  breakdancer.flt.txt   > breakdancer.somatic.sv.gff
```
breakdancer结果可以用ANNOVAR进行注释

## CREST
```shell
##step1
perl software/CREST/countDiff.pl -d Mapping/T_CA.cover -g Mapping/N.cover > somatic.cover
##sub1
perl software/CREST/crest_sv_calling.pl\
    -cov somatic.cover\
    -outDir /crest\
    -tumorBam T.final.bam\
    -normalBam N.final.bam\
    -sampleID crest.somatic.sv\
    -regionList /human_B37/GRCh37.chr25Region.bed\
    -ref /human_B37/GRCh37.fasta\
    -bit /human_B37/GRCh37.fasta.2bit
##sub2

##sub3

##sub4

##sub5

##sub6

```
## Lumpy
```shell
software/HUMAN/speedseq/speedseq/bin/lumpyexpress 
        -B T.final.bam,N.final.bam \
        -S T.split.bam,N.split.bam \
        -D T.discord.bam,T.discord.bam \
        -o lumpy.somatic.sv.vcf \
        -x annotations/ceph18.b37.lumpy.exclude.2014-01-15.bed \
        -T /Somatic/lumpy \
        -K /software/HUMAN/speedseq/speedseq/bin/speedseq.config \
        -P -v -k && \
python lumpy_vcf2gff.py \
        lumpy.somatic.sv.vcf \
        lumpy.somatic.sv.gff && \
        gzip lumpy.somatic.sv.vcf
```
