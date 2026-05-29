#!/bin/bash
#SBATCH --job-name=kraken_meta
#SBATCH --partition=work1
#SBATCH --output=kraken_%A_%a.out
#SBATCH --error=kraken_%A_%a.err
#SBATCH --cpus-per-task=32
#SBATCH --mem=200G
#SBATCH --time=07:00:00
#SBATCH --array=1-44

set -euo pipefail

module load biocontainers
module load kraken2/2.14

# DB
KRAKEN2_DB="/datasets/kraken2/standard"

# Sample list
SAMPLE_LIST="/home/dgohar/samples.txt"

# Get sample from array index
SAMPLE_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

# Input reads directory
READS_DIR="/scratch/dgohar/Prabh/trimmed_reads"

# Output dir
OUT_DIR="/scratch/dgohar/Prabh/kraken2_results"
mkdir -p "$OUT_DIR"

echo "======================================"
echo "Running sample: $SAMPLE_ID"
echo "======================================"

# Define reads
R1="${READS_DIR}/${SAMPLE_ID}_R1_paired_trimmed.fastq.gz"
R2="${READS_DIR}/${SAMPLE_ID}_R2_paired_trimmed.fastq.gz"

# Check files
if [[ ! -f "$R1" || ! -f "$R2" ]]; then
    echo "Missing reads for sample: $SAMPLE_ID"
    exit 1
fi

# Output files
REPORT="${OUT_DIR}/${SAMPLE_ID}.report.txt"
OUTPUT="${OUT_DIR}/${SAMPLE_ID}.output.txt"

# Run Kraken2
kraken2 \
    --db "$KRAKEN2_DB" \
    --threads $SLURM_CPUS_PER_TASK \
    --paired \
    --gzip-compressed \
    --report "$REPORT" \
    --output "$OUTPUT" \
    "$R1" "$R2"

echo "Finished sample: $SAMPLE_ID"
echo "--------------------------------------"