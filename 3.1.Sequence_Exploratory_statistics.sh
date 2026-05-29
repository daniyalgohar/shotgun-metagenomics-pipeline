#!/bin/bash
#SBATCH --job-name=seqkit_stats
#SBATCH --partition=work1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=12:00:00
#SBATCH --output=seqkit_stats_%j.out
#SBATCH --error=seqkit_stats_%j.err

set -euo pipefail

# Load seqkit if needed
module load anaconda3/2023.09-0 

source $(conda info --base)/etc/profile.d/conda.sh 
conda activate kraken_tools 
conda install -c bioconda seqkit -y 


OUTDIR="/home/dgohar/Prabh_P1/seqkit_read_stats"
mkdir -p "$OUTDIR"

RAW_DIR="/scratch/dgohar/Prabh/raw_seqs"
TRIM_DIR="/scratch/dgohar/Prabh/trimmed_reads"
BACT_FUNG_DIR="/scratch/dgohar/Prabh/bact_fung_filtered_reads"

SUMMARY="$OUTDIR/all_batches_per_sample_read_counts.tsv"

echo -e "batch\tsample_id\tR1_file\tR1_num_seqs\tR1_sum_len\tR2_file\tR2_num_seqs\tR2_sum_len\tpair_status\tsample_read_pairs\ttotal_sequences_R1_plus_R2" > "$SUMMARY"

run_batch () {
    BATCH_NAME="$1"
    R1_PATTERN="$2"
    R2_FROM_R1_CMD="$3"

    echo "Processing batch: $BATCH_NAME"

    BATCH_FILE="$OUTDIR/${BATCH_NAME}_seqkit_file_stats.tsv"
    echo -e "file\tformat\ttype\tnum_seqs\tsum_len\tmin_len\tavg_len\tmax_len" > "$BATCH_FILE"

    while IFS= read -r R1; do
        R2=$(eval "$R2_FROM_R1_CMD")

        if [[ ! -f "$R2" ]]; then
            echo "WARNING: R2 missing for $R1"
            continue
        fi

        SAMPLE=$(basename "$R1")
        SAMPLE=${SAMPLE%%_R1*}

        TMP="$OUTDIR/tmp_${BATCH_NAME}_${SAMPLE}.tsv"

        seqkit stats -T "$R1" "$R2" > "$TMP"

        tail -n +2 "$TMP" >> "$BATCH_FILE"

        R1_NUM=$(awk -F'\t' 'NR==2 {print $4}' "$TMP")
        R1_LEN=$(awk -F'\t' 'NR==2 {print $5}' "$TMP")
        R2_NUM=$(awk -F'\t' 'NR==3 {print $4}' "$TMP")
        R2_LEN=$(awk -F'\t' 'NR==3 {print $5}' "$TMP")

        if [[ "$R1_NUM" == "$R2_NUM" ]]; then
            STATUS="OK"
        else
            STATUS="R1_R2_MISMATCH"
        fi

        TOTAL_SEQ=$((R1_NUM + R2_NUM))

        echo -e "${BATCH_NAME}\t${SAMPLE}\t${R1}\t${R1_NUM}\t${R1_LEN}\t${R2}\t${R2_NUM}\t${R2_LEN}\t${STATUS}\t${R1_NUM}\t${TOTAL_SEQ}" >> "$SUMMARY"

        rm -f "$TMP"

    done < <(find $(dirname "$R1_PATTERN") -name "$(basename "$R1_PATTERN")" | sort)
}

# 1. Raw reads
run_batch \
  "raw_reads" \
  "$RAW_DIR/*_R1.fastq.gz" \
  'echo "$R1" | sed "s/_R1.fastq.gz/_R2.fastq.gz/"'

# 2. Trimmed filtered reads after tag removal
run_batch \
  "trimmed_filtered_reads" \
  "$TRIM_DIR/*_R1_paired_trimmed.fastq.gz" \
  'echo "$R1" | sed "s/_R1_paired_trimmed.fastq.gz/_R2_paired_trimmed.fastq.gz/"'

# 3. Bacterial and fungal reads
run_batch \
  "bact_fung_reads" \
  "$BACT_FUNG_DIR/*/*_bact_fungi_R1.fastq.gz" \
  'echo "$R1" | sed "s/_bact_fungi_R1.fastq.gz/_bact_fungi_R2.fastq.gz/"'

# Total summary
TOTALS="$OUTDIR/all_batches_total_read_counts.tsv"

awk -F'\t' '
BEGIN {
    OFS="\t";
    print "batch", "n_samples", "total_read_pairs", "total_sequences_R1_plus_R2"
}
NR > 1 {
    samples[$1]++;
    pairs[$1] += $10;
    seqs[$1] += $11;
}
END {
    for (b in samples) {
        print b, samples[b], pairs[b], seqs[b]
    }
}
' "$SUMMARY" | sort > "$TOTALS"

echo "Done."
echo "Per-sample summary: $SUMMARY"
echo "Batch totals: $TOTALS"
echo "Detailed seqkit file stats are in: $OUTDIR"