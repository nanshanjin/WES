soft/jdk1.8.0_20/bin/java -Xmx32G -jar  soft/picard-2.18.0/picard.jar MarkDuplicates INPUT=fq.bam OUTPUT=fq.mkdp.bam METRICS_FILE=fq.mkdp.bam.metrics.txt  OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 CREATE_INDEX=true
