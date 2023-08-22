#!/bin/bash

for filename in /mnt/storage/bat_CoV_Prescreen/*_hostRemoved.fastq:
do
  base=$(basename -s _hostRemoved.fastq $filename)
  out="/mnt/storage/bat_CoV_Prescreen/workflow_v2/coronaSPAdes_contigs/${base}"
  result="${out}/scaffold.fasta"
  new_name="/mnt/storage/bat_CoV_Prescreen/workflow_v2/coronaSPAdes_contigs/output_results/${base}_coronaSPAdes_scaffold.fasta"
  coronaspades.py -t 64 -o $out --12 $filename
  cp $result $new_name
  done

