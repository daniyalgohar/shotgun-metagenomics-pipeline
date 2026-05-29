#!/bin/bash
#SBATCH --job-name=sdust_batch
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=128G
#SBATCH --time=48:00:00
#SBATCH --output=logs/sdust_batch_%A_%a.out
#SBATCH --error=logs/sdust_batch_%A_%a.err
#SBATCH --array=1-44

set -euo pipefail

module load anaconda3/2023.09-0
source $(conda info --base)/etc/profile.d/conda.sh
conda activate kraken_tools

INDIR="/scratch/dgohar/Prabh/bact_fung_filtered_reads"
OUTDIR="/scratch/dgohar/Prabh/bact_fung_filtered_reads_sdust"
SDUST_BIN="$HOME/sdust/sdust"
SAMPLE_LIST="/home/dgohar/samples.txt"

mkdir -p "$OUTDIR" logs

[[ -x "$SDUST_BIN" ]] || { 
    echo "ERROR: sdust binary not found: $SDUST_BIN"
    exit 1
}

command -v seqkit >/dev/null 2>&1 || { 
    echo "ERROR: seqkit not found in kraken_tools env"
    exit 1
}

# Get sample from array index
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

SAMPLE_DIR="$INDIR/$SAMPLE"
R1="$SAMPLE_DIR/${SAMPLE}_bact_fungi_R1.fastq.gz"
R2="$SAMPLE_DIR/${SAMPLE}_bact_fungi_R2.fastq.gz"

if [[ ! -f "$R1" || ! -f "$R2" ]]; then
    echo "Skipping $SAMPLE, missing R1 or R2"
    exit 1
fi

SAMPLE_OUT="$OUTDIR/$SAMPLE"
mkdir -p "$SAMPLE_OUT"

echo "=============================="
echo "Processing $SAMPLE"
echo "=============================="

for READ in R1 R2
do
    FILE="$SAMPLE_DIR/${SAMPLE}_bact_fungi_${READ}.fastq.gz"

    echo "Running sdust on $FILE"

    "$SDUST_BIN" "$FILE" > "$SAMPLE_OUT/${READ}.sdust.tsv"
done

cat "$SAMPLE_OUT"/R1.sdust.tsv "$SAMPLE_OUT"/R2.sdust.tsv \
    | cut -f1 \
    | sort -u \
    > "$SAMPLE_OUT/low_complexity_ids.txt"

for READ in R1 R2
do
    INFILE="$SAMPLE_DIR/${SAMPLE}_bact_fungi_${READ}.fastq.gz"
    OUTFILE="$SAMPLE_OUT/${SAMPLE}_bact_fungi_${READ}.filtered.fastq.gz"

    echo "Filtering $INFILE"

    seqkit grep -v \
        -f "$SAMPLE_OUT/low_complexity_ids.txt" \
        "$INFILE" \
        -o "$OUTFILE"
done

echo "Finished $SAMPLE"