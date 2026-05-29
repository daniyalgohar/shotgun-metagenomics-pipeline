#!/bin/bash
#SBATCH --job-name=03_extraction
#SBATCH --partition=work1
#SBATCH --output=logs/extract_kraken_%A_%a.out
#SBATCH --error=logs/extract_kraken_%A_%a.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH --time=48:00:00
#SBATCH --array=1-44

set -euo pipefail

# -----------------------------
# USER SETTINGS
# -----------------------------
KRAKEN_DIR="/scratch/dgohar/Prabh/kraken2_results"
READS_DIR="/scratch/dgohar/Prabh/trimmed_reads"
OUT_DIR="/scratch/dgohar/Prabh/bact_fung_filtered_reads"
KRAKEN_TOOL="/home/dgohar/KrakenTools/extract_kraken_reads.py"
SAMPLE_LIST="/home/dgohar/samples.txt"

mkdir -p "$OUT_DIR"

module load anaconda3/2023.09-0
source $(conda info --base)/etc/profile.d/conda.sh
conda activate kraken_tools

# Get sample from array index
SAMPLE_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

echo "Kraken dir : $KRAKEN_DIR"
echo "Reads dir  : $READS_DIR"
echo "Output dir : $OUT_DIR"
echo

KFILE="$KRAKEN_DIR/${SAMPLE_ID}.output.txt"
REPORT_FILE="$KRAKEN_DIR/${SAMPLE_ID}.report.txt"
R1_FILE="$READS_DIR/${SAMPLE_ID}_R1_paired_trimmed.fastq.gz"
R2_FILE="$READS_DIR/${SAMPLE_ID}_R2_paired_trimmed.fastq.gz"

SAMPLE_OUT_DIR="$OUT_DIR/$SAMPLE_ID"
mkdir -p "$SAMPLE_OUT_DIR"

OUT_R1="$SAMPLE_OUT_DIR/${SAMPLE_ID}_bact_fungi_R1.fastq"
OUT_R2="$SAMPLE_OUT_DIR/${SAMPLE_ID}_bact_fungi_R2.fastq"

echo "======================================"
echo "Processing sample: $SAMPLE_ID"
echo "Kraken output : $KFILE"
echo "Report file   : $REPORT_FILE"
echo "R1 file       : $R1_FILE"
echo "R2 file       : $R2_FILE"
echo "Output dir    : $SAMPLE_OUT_DIR"
echo "======================================"

if [[ ! -f "$KFILE" ]]; then
    echo "Skipping $SAMPLE_ID: Kraken output file not found"
    exit 1
fi

if [[ ! -f "$REPORT_FILE" ]]; then
    echo "Skipping $SAMPLE_ID: report file not found"
    exit 1
fi

if [[ ! -f "$R1_FILE" ]]; then
    echo "Skipping $SAMPLE_ID: R1 file not found"
    exit 1
fi

if [[ ! -f "$R2_FILE" ]]; then
    echo "Skipping $SAMPLE_ID: R2 file not found"
    exit 1
fi

python3 "$KRAKEN_TOOL" \
    -k "$KFILE" \
    -r "$REPORT_FILE" \
    -s "$R1_FILE" \
    -s2 "$R2_FILE" \
    -t 2 4751 \
    --include-children \
    --fastq-output \
    -o "$OUT_R1" \
    -o2 "$OUT_R2"

gzip -f "$OUT_R1"
gzip -f "$OUT_R2"

echo "Finished sample: $SAMPLE_ID"