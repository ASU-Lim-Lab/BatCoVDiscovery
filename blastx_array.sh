#!/bin/bash
#SBATCH -c 8           # number of "cores"
#SBATCH -t 48:00:00   # time in d-hh:mm:ss
#SBATCH -p serial       # partition
#SBATCH -q normal       # QOS
#SBATCH -o slurm.%j.err # file to save job's STDOUT & STDERR (%j = JobId)
#SBATCH --export=NONE   # Purge the job-submitting shell environment
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=tianche5@asu.edu

manifest="${1:?ERROR -- must pass a manifest file}"

taskid=$SLURM_ARRAY_TASK_ID
case=$(getline $taskid $manifest | cut -f 1 -d ' ')
fasta=$(getline $taskid $manifest | cut -f 2 -d ' ')

module purge
module load anaconda/py3
source activate bat
# above: setting up sbatch parameters and env

base=$(basename -s .fasta $fasta)
out1=/scratch/tianche5/"$base"_${case}_fmt11.txt
out2=/scratch/tianche5/"$base"_${case}_fmt6.txt

args=(
  -query $fasta
  -db /scratch/tianche5/bat/db/$case/$case
  -evalue 1e-3
  -num_threads $(nproc)
  -max_target_seqs 5
  -max_hsps 1
  -outfmt '11'
  -out $out1
)
blastx "${args[@]}"

blast_formatter -archive $out1 -outfmt "6 qseqid sseqid evalue bitscore score pident nident length mismatch qframe qstart qend qlen qcovs sframe sstart send slen" -out $out2
