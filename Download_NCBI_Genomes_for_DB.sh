#!/bin/bash
#SBATCH --job-name=ncbi_ref_chunked
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --time=72:00:00
#SBATCH --output=logs/ncbi_ref_chunked_%j.out
#SBATCH --error=logs/ncbi_ref_chunked_%j.err

set -euo pipefail

module load anaconda3/2023.09-0
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate ncbi_datasets

BASE=/scratch/dgohar/NCBI_ref_genomes_chunked
mkdir -p "$BASE"/{lists,chunks,downloads}

cd "$BASE"

# 1. Get metadata only first
datasets summary genome taxon Bacteria --reference --as-json-lines > lists/bacteria.jsonl
datasets summary genome taxon Fungi --reference --as-json-lines > lists/fungi.jsonl

# 2. Convert metadata to accession lists
dataformat tsv genome \
  --force \
  --inputfile lists/bacteria.jsonl \
  --fields accession > lists/bacteria_accessions.tsv

dataformat tsv genome \
  --force \
  --inputfile lists/fungi.jsonl \
  --fields accession > lists/fungi_accessions.tsv

tail -n +2 lists/bacteria_accessions.tsv > lists/bacteria_accessions.txt
tail -n +2 lists/fungi_accessions.tsv > lists/fungi_accessions.txt

# 3. Split into smaller batches
split -l 200 lists/bacteria_accessions.txt chunks/bacteria_
split -l 200 lists/fungi_accessions.txt chunks/fungi_

# 4. Download each chunk with retry
download_chunks () {
  PREFIX=$1

  for f in chunks/${PREFIX}_*; do
    name=$(basename "$f")
    out="downloads/${name}.zip"

    if [ -s "$out" ]; then
      echo "Already exists: $out"
      continue
    fi

    echo "Downloading $name"

    for attempt in 1 2 3 4 5; do
      datasets download genome accession \
        --inputfile "$f" \
        --include genome,gff3,protein,cds,seq-report \
        --filename "$out" && break

      echo "Failed attempt $attempt for $name"
      sleep 60
    done
  done
}

download_chunks bacteria
download_chunks fungi

echo "Done."