#!/bin/bash
#SBATCH -c 8            # number of "cores"
#SBATCH -t 24:00:00     # time in d-hh:mm:ss
#SBATCH -p serial       # partition
#SBATCH --mem=100G      # bbduk may need more memory
#SBATCH -q normal       # QOS
#SBATCH -o slurm.%j.err # file to save job's STDOUT & STDERR (%j = JobId)
#SBATCH --export=NONE   # Purge the job-submitting shell environment
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=tianche5@asu.edu
module purge
module load anaconda/py3
source activate bat

# read manifest file
manifest="${1:?ERROR -- must pass the path to a manifest file in 1st pos. arg}"
taskid=$SLURM_ARRAY_TASK_ID

# path/to/sample/without_R[12]_001.fastq.gz
sample_path=$(getline $taskid $manifest)
path_prefix=${sample_path%R*}
path_prefix=${path_prefix%_*}

# raw input file pair
in1="${path_prefix}_R1_001.fastq.gz"
in2="${path_prefix}_R2_001.fastq.gz"

# IXXXXX
sample=$(basename "${path_prefix}")
sample=${sample%_*}

# base working directory
bwd="/scratch/tianche5/bat"

# output working directory
owd="${bwd}/QC_result/${sample}"
bat_ref="${bwd}/bat_genome_ncbi/ncbi_dataset/data/refseq/bbmap_index"
illumina_adapter="${bwd}/contaminants/illumina_dna_prep_abcd.fa"
phix_ref="${bwd}/contaminants/phix174_ill.ref.fa.gz"
split="${bwd}/QC_result/${sample}/${sample}_split"

# SIAB25 primers
SIB25="GTTTCCCAGTCACGATC"
SIB25_rc="GATCGTGACTGGGAAAC"


# if output writing directory doesn't exist, then create a new folder
! [[ -d "$owd" ]] && mkdir -pv "$owd" || :
! [[ -d "$split" ]] && mkdir -pv "$split" || :

# output files
illumina_out1="${owd}/${sample}_cutadapt_adaptTrim_R1.fastq"
illumina_out2="${owd}/${sample}_cutadapt_adaptTrim_R2.fastq"
illumina_log="${owd}/${sample}_cutadapt_adaptTrim.log.txt"

SIB_out1="${owd}/${sample}_cutadapt_primerTrimR_R1.fastq"
SIB_out2="${owd}/${sample}_cutadapt_primerTrimR_R2.fastq"
SIB_log="${owd}/${sample}_cutadapt_primerTrimR.log.txt"

SIB_rc_out1="${owd}/${sample}_cutadapt_primerTrimRL_R1.fastq"
SIB_rc_out2="${owd}/${sample}_cutadapt_primerTrimRL_R2.fastq"
SIB_rc_log="${owd}/${sample}_cutadapt_primerTrimRL.log.txt"

bbduk_out1="${owd}/${sample}_bbduk_qc_R1.fastq"
bbduk_out2="${owd}/${sample}_bbduk_qc_R2.fastq"
bbduk_log="${owd}/${sample}_bbduk_qc.log.txt"

phix_out1="${owd}/${sample}_phixRemoved_R1.fastq"
phix_out2="${owd}/${sample}_phixRemoved_R2.fastq"
phix_log="${owd}/${sample}_phixRemoved.log.txt"

host_out1="${owd}/${sample}_hostRemoved.fastq"
host_out2="${owd}/${sample}_hostMatched.fastq"
host_log="${owd}/${sample}_hostRemoved.log.txt"

firstDedupe_out1="${owd}/${sample}_firstDedupe.fastq"
firstDedupe_out2="${owd}/${sample}_firstDupe_dupes.fastq"
firstDedupe_log="${owd}/${sample}_firstDedupe.log.txt"

merge_out1="${owd}/${sample}_Merged.fastq"
merge_out2="${owd}/${sample}_unMerged.fastq"
merge_log="${owd}/${sample}_Merged.log.txt"
cat_out="${owd}/${sample}_Merged_and_UnMerged.fastq"

secondDedupe_out1="${owd}/${sample}_secondDedupe.fastq"
secondDedupe_out2="${owd}/${sample}_secondDupe_dupes.fastq"
secondDedupe_log="${owd}/${sample}_secondDedupe.log.txt"

filter_out="${owd}/${sample}_secondDedupe_filtered.fastq"
filter_log="${owd}/${sample}_secondDedupe_filtered.log.txt"
fasta_out="${owd}/${sample}_secondDedupe_filtered.fasta"


# cut illumina adapters from R1&R2
# -j run on the given number of CPU cores
opts=(
  -a "file:$illumina_adapter"
  -A "file:$illumina_adapter"
  -o "$illumina_out1"
  -p "$illumina_out2"
  $in1
  $in2
  -j $(nproc)
)
cutadapt "${opts[@]}" &> "$illumina_log"


# cut SIA_SIB25 primers from both end of R1&R2
opts=(
  -a "$SIB25"
  -a "$SIB25_rc"
  -A "$SIB25"
  -A "$SIB25_rc"
  -o "$SIB_out1"
  -p "$SIB_out2"
  "$illumina_out1"
  "$illumina_out2"
  -j $(nproc)
)
cutadapt "${opts[@]}" &> "$SIB_log"


opts=(
  -g "$SIB25"
  -g "$SIB25_rc"
  -G "$SIB25"
  -G "$SIB25_rc"
  -o "$SIB_rc_out1"
  -p "$SIB_rc_out2"
  "$SIB_out1"
  "$SIB_out2"
  -j $(nproc)
)
cutadapt "${opts[@]}" &> "$SIB_rc_log"


# QC trim and length filtering for R1&R2
opts=(
  in="$SIB_rc_out1"
  in2="$SIB_rc_out2"
  ref="${refs['phix']}"
  out="$bbduk_out1"
  out2="$bbduk_out2"
  qtrim=rl
  trimq=20
  minlength=75
  minavgquality=20
  removeifeitherbad=f
  tpe=t
  overwrite=t
)
bbduk.sh "${opts[@]}" &> "$bbduk_log"


# trim PhiX from R1&R2
opts=(
  in="$bbduk_out1"
  in2="$bbduk_out2"
  ref="$phix_ref"
  out="$phix_out1"
  out2="$phix_out2"
  k=31
  hdist=1
  overwrite=t
)
bbduk.sh "${opts[@]}" &> "$phix_log"


# trim bat genome from R1&R2, ref index built forehand
opts=(
  in="$phix_out1"
  in2="$phix_out2"
  outu="$host_out1"  # host genome removed
  outm="$host_out2"  # host genome matched
  path="$bat_ref"
  minid=.95
  maxindel=3
  bwr=0.16
  bw=12
  quickmatch
  fast
  minhits=2
  -Xmx64g
)
bbmap.sh "${opts[@]}" &> "$host_log"


# read deduplication at 99% identity
opts=(
  in="$host_out1"
  out="$firstDedupe_out1"
  outd="$firstDedupe_out2"  # duplicated sequences
  csf=dedupe.cluster.stats
  minidentity=99
  overwrite=t
)
dedupe.sh "${opts[@]}" &> "$firstDedupe_log"


# merge overlapping paired reads
opts=(
  in="$firstDedupe_out1"
  out="$merge_out1"
  outu="$merge_out2"  # unMerged sequences
)
bbmerge.sh "${opts[@]}" &> "$merge_log"
# concatenate the merged and unmerged reads
cat "$merge_out1" "$merge_out2" > "$cat_out"


# read deduplication at 100% identity
opts=(
  in="$cat_out"
  out="$secondDedupe_out1"
  outd="$secondDedupe_out2"  # duplicated sequences
  csf=dedupe.cluster.stats
  minidentity=100
  ac=f
  overwrite=t
)
dedupe.sh "${opts[@]}" &> "$secondDedupe_log"


# length filter
opts=(
  in="$secondDedupe_out1"
  out="$filter_out"
  minlength=75
  overwrite=t
)
bbduk.sh "${opts[@]}" &> "$filter_log"

# convert fastq to fasta
sed -n '1~4s/^@/>/p;2~4p' "$filter_out" > "$fasta_out"

# split the after_qc sequence to small reads groups
# pass the filename from shell to python
python split_tool.py $fasta_out $split $sample


