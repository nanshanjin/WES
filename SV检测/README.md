# SV检测
SV 是 Structural variation 的缩写。结构变异指的是在基因组上一些大的结构性的变异，比如大片段丢失（ Deletion），大片段插入（ Insertion），大片段重复（ Duplication），拷贝数变异（ Copy number variants），倒位（ Inversion），易位（ Translocation）。一般来说结构变异涉及的序列长度在 1kb 到 3Mb 之间。结构变异普遍发生于癌变细胞中，一些癌症已经证实和结构变异导致的基因融合事件有关。我们通常采用BreakDancer、Crest对 Tumor 及 Normal成对样本进行 SV 信息检测

## BreakDancer
[documentation](http://gmt.genome.wustl.edu/packages/breakdancer/documentation.html)

[breakdancer](https://github.com/kenchen/breakdancer#readme)

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

