#!/bin/bash
#SBATCH --job-name=Build_per_sample_ref
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=128G
#SBATCH --time=48:00:00
#SBATCH --output=logs/Build_per_sample_ref%j.out
#SBATCH --error=logs/Build_per_sample_ref%j.err

module load anaconda3/2023.09-0
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate ncbi_datasets

set -euo pipefail

IN_DIR="/scratch/dgohar/NCBI_hits_prabh_P1/assemblies"
MAP_FILE="/scratch/dgohar/Prabh/sourmash_results/combined_genomes/genome_ids_with_samples.tsv"
OUT_DIR="/scratch/dgohar/NCBI_hits_prabh_P1/reference/per_sample"

mkdir -p "$OUT_DIR"/{tmp,logs}

echo "Building per-sample references..."

# =========================
# 1. Make sample-genome pairs
# =========================
tail -n +2 "$MAP_FILE" | awk '{print $2 "\t" $1}' | sort -u > "$OUT_DIR/tmp/sample_genome_pairs.tsv"

cut -f1 "$OUT_DIR/tmp/sample_genome_pairs.tsv" | sort -u > "$OUT_DIR/tmp/sample_ids.txt"

echo "Samples found:"
wc -l "$OUT_DIR/tmp/sample_ids.txt"

# =========================
# 2. Build one reference per sample
# =========================
while read -r SAMPLE; do
    [[ -z "$SAMPLE" ]] && continue

    echo "[Processing sample] $SAMPLE"

    SAMPLE_DIR="$OUT_DIR/$SAMPLE"
    RENAMED_DIR="$SAMPLE_DIR/renamed"

    mkdir -p "$RENAMED_DIR"

    awk -v s="$SAMPLE" '$1==s {print $2}' "$OUT_DIR/tmp/sample_genome_pairs.tsv" > "$SAMPLE_DIR/genome_ids.txt"

    : > "$SAMPLE_DIR/missing_genomes.txt"
    : > "$SAMPLE_DIR/fasta_paths.txt"

    while read -r GENOME; do
        [[ -z "$GENOME" ]] && continue

        # FIXED: recursive search inside genome folder
        FASTA=$(find "$IN_DIR/$GENOME" -type f \( -name "*.fna" -o -name "*.fa" -o -name "*.fasta" \) | head -n 1 || true)

        if [[ -z "$FASTA" ]]; then
            echo "$GENOME" >> "$SAMPLE_DIR/missing_genomes.txt"
            continue
        fi

        echo "$FASTA" >> "$SAMPLE_DIR/fasta_paths.txt"

        OUT_FASTA="$RENAMED_DIR/${GENOME}.fna"

        awk -v acc="$GENOME" '
            /^>/{
                sub(/^>/, "", $0)
                print ">" acc "|" $0
                next
            }
            {print}
        ' "$FASTA" > "$OUT_FASTA"

    done < "$SAMPLE_DIR/genome_ids.txt"

    if ls "$RENAMED_DIR"/*.fna >/dev/null 2>&1; then
        cat "$RENAMED_DIR"/*.fna > "$SAMPLE_DIR/${SAMPLE}_combined_reference.fna"

        echo "Indexing $SAMPLE with BWA..."
        bwa index "$SAMPLE_DIR/${SAMPLE}_combined_reference.fna"

        echo "$SAMPLE done"
    else
        echo "No FASTA files found for $SAMPLE" | tee -a "$OUT_DIR/logs/empty_samples.log"
    fi

done < "$OUT_DIR/tmp/sample_ids.txt"

echo "All per-sample references completed."