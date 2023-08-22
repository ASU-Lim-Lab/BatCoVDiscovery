#!/bin/bash

manifest="${1:?ERROR -- must pass a manifest file}"
fasta=$(getline $manifest)
base=$(basename -s .fasta $fasta)
out="/mnt/storage/bat_CoV_Prescreen/workflow_v2/coronaSPAdes_contigs/"${base}"/"

args=(
  -o $out
  --12 $fasta
  -t 64
)
coronaspades.py "${args[@]}"
