#!/bin/bash
#SBATCH --job-name=NCBI_download
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=36:00:00
#SBATCH --output=logs/NCBI_download%j.out
#SBATCH --error=logs/NCBI_download%j.err

set -euo pipefail
module load anaconda3/2023.09-0
source activate ncbi_datasets
# =========================
# INPUT / OUTPUT
# =========================
INPUT_TSV="/home/dgohar/Prabh/sourmash_results/combined_genomes/genome_ids_with_samples.tsv"
OUT_DIR="/scratch/dgohar/NCBI_hits_prabh_P1"

mkdir -p "$OUT_DIR"/{zips,assemblies,logs}

echo "Input TSV:  $INPUT_TSV"
echo "Output dir: $OUT_DIR"

# =========================
# CHECK TOOL
# =========================
if ! command -v datasets >/dev/null 2>&1; then
    echo "ERROR: NCBI datasets CLI not found in PATH"
    echo "Install it first or load the module/env that has 'datasets'"
    exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
    echo "ERROR: unzip not found in PATH"
    exit 1
fi

# =========================
# EXTRACT UNIQUE ACCESSIONS
# =========================
ACC_LIST="$OUT_DIR/logs/genome_ids.txt"

awk -F'\t' 'NR>1 && $1 != "" {print $1}' "$INPUT_TSV" | sort -u > "$ACC_LIST"

N=$(wc -l < "$ACC_LIST")
echo "Found $N genome IDs to download"

# =========================
# DOWNLOAD LOOP
# =========================
while read -r ACC; do
    [ -z "$ACC" ] && continue

    ZIP="$OUT_DIR/zips/${ACC}.zip"
    DEST="$OUT_DIR/assemblies/${ACC}"

    # skip if already downloaded and extracted
    if [ -d "$DEST" ] && find "$DEST" -type f \( -name "*.fna" -o -name "*.fa" -o -name "*.fasta" \) | grep -q .; then
        echo "[SKIP] $ACC already present"
        continue
    fi

    echo "[DOWNLOAD] $ACC"

    rm -f "$ZIP"
    rm -rf "$DEST"

    if datasets download genome accession "$ACC" --filename "$ZIP" >"$OUT_DIR/logs/${ACC}.download.log" 2>&1; then
        mkdir -p "$DEST"
        unzip -oq "$ZIP" -d "$DEST"
        echo "[OK] $ACC"
    else
        echo "[FAIL] $ACC" | tee -a "$OUT_DIR/logs/failed_downloads.txt"
        rm -f "$ZIP"
        rm -rf "$DEST"
    fi

done < "$ACC_LIST"

echo
echo "Done."
echo "Downloaded assemblies are under:"
echo "$OUT_DIR/assemblies"
echo
echo "Failed downloads list (if any):"
echo "$OUT_DIR/logs/failed_downloads.txt"