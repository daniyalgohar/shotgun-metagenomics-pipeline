#!/bin/bash
#SBATCH --job-name=trimmomatic_pe
#SBATCH --output=logs/trimmomatic_%A_%a.out
#SBATCH --error=logs/trimmomatic_%A_%a.err
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --array=1-44

set -euo pipefail

# Get sample from sample list
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" /home/dgohar/samples.txt)

echo "Running sample: $SAMPLE"

# Load Trimmomatic
module load biocontainers
module load trimmomatic/0.35

# Input and output folders
INDIR="/scratch/dgohar/Prabh/raw_seqs"
OUTDIR="/scratch/dgohar/Prabh/trimmed_reads"
mkdir -p "$OUTDIR"

# Adapter file
ADAPTERS="/home/dgohar/TruSeq3-PE.fa"

# Threads
THREADS=${SLURM_CPUS_PER_TASK}

R1="$INDIR/${SAMPLE}_R1.fastq.gz"
R2="$INDIR/${SAMPLE}_R2.fastq.gz"

if [[ ! -f "$R1" ]]; then
    echo "R1 file not found: $R1"
    exit 1
fi

if [[ ! -f "$R2" ]]; then
    echo "R2 file not found: $R2"
    exit 1
fi

echo "Processing $SAMPLE"

trimmomatic PE \
    -threads "$THREADS" \
    "$R1" "$R2" \
    "$OUTDIR/${SAMPLE}_R1_paired_trimmed.fastq.gz" \
    "$OUTDIR/${SAMPLE}_R1_unpaired.fastq.gz" \
    "$OUTDIR/${SAMPLE}_R2_paired_trimmed.fastq.gz" \
    "$OUTDIR/${SAMPLE}_R2_unpaired.fastq.gz" \
    ILLUMINACLIP:${ADAPTERS}:2:30:10 \
    SLIDINGWINDOW:6:20 \
    MINLEN:70