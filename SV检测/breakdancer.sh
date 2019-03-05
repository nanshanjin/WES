##step1
perl bam2cfg.pl -g -h T.final.bam N.final.bam > breakdancer.cfg
##step2
software/breakdancer/breakdancer-max  -h  -d breakdancer.SV-supporting  breakdancer.bed  breakdancer.cfg  breakdancer.txt
var_sv_breakdancer.filter.pl  -g M -n 6  -a breakdancer.txt  > breakdancer.flt.txt && \
var_sv_breakdancer.toGff.pl  breakdancer.flt.txt   > breakdancer.somatic.sv.gff
