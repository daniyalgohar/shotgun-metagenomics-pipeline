#!/bin/bash
#SBATCH --job-name=read_counts
#SBATCH --partition=work1
#SBATCH --cpus-per-task=8
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=read_counts_%j.out
#SBATCH --error=read_counts_%j.err

set -euo pipefail

module load anaconda3/2023.09-0
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate kraken_tools

OUTDIR="/home/dgohar/Prabh_P1/seqkit_read_stats"
mkdir -p "$OUTDIR"

SUMMARY="$OUTDIR/read_counts_only.tsv"

echo -e "batch\tsample_id\tR1_file\tread_pairs\tR1_plus_R2_sequences" > "$SUMMARY"

count_batch () {
    local BATCH="$1"
    local PATTERN="$2"

    find $(dirname "$PATTERN") -name "$(basename "$PATTERN")" | sort -V | while read -r R1; do
        SAMPLE=$(basename "$R1")
        SAMPLE=${SAMPLE%%_R1*}

        N=$(seqkit stats -T "$R1" | awk 'NR==2 {gsub(/,/, "", $4); print $4}')

        echo -e "${BATCH}\t${SAMPLE}\t${R1}\t${N}\t$((N*2))"
    done >> "$SUMMARY"
}

RAW_DIR="/scratch/dgohar/Prabh/raw_seqs"
TRIM_DIR="/scratch/dgohar/Prabh/trimmed_reads"
BACT_FUNG_DIR="/scratch/dgohar/Prabh/bact_fung_filtered_reads"
SDUST_DIR="/scratch/dgohar/Prabh/bact_fung_filtered_reads_sdust"

count_batch "raw_reads" "$RAW_DIR/*_R1.fastq.gz"
count_batch "trimmed_reads" "$TRIM_DIR/*_R1_paired_trimmed.fastq.gz"
count_batch "bact_fung_reads" "$BACT_FUNG_DIR/*/*_bact_fungi_R1.fastq.gz"
count_batch "bact_fung_sdust_reads" "$SDUST_DIR/*/*_bact_fungi_R1.filtered.fastq.gz"

awk -F'\t' '
BEGIN {OFS="\t"; print "batch","n_samples","total_read_pairs","total_R1_plus_R2_sequences"}
NR>1 {samples[$1]++; pairs[$1]+=$4; seqs[$1]+=$5}
END {for (b in samples) print b,samples[b],pairs[b],seqs[b]}
' "$SUMMARY" | sort > "$OUTDIR/read_counts_totals.tsv"

echo "Done:"
echo "$SUMMARY"
echo "$OUTDIR/read_counts_totals.tsv"