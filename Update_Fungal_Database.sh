#!/bin/bash
#SBATCH --job-name=ncbi_fungi_update
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --time=72:00:00
#SBATCH --output=logs/ncbi_fungi_update_%j.out
#SBATCH --error=logs/ncbi_fungi_update_%j.err

set -euo pipefail

module load anaconda3/2023.09-0
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate ncbi_datasets

BASE=/scratch/dgohar/NCBI_ref_genomes_chunked
mkdir -p "$BASE"/{lists,chunks,downloads,logs}

cd "$BASE"

# Input: new fungal genomes to add
UPDATED_LIST="/home/dgohar/DB/fungi_db_new_genomes_to_add.txt"

# Copy your updated list here first, or change this path if it is elsewhere
if [ ! -s "$UPDATED_LIST" ]; then
  echo "ERROR: Missing or empty file: $UPDATED_LIST"
  echo "Copy fungi_db_new_genomes_to_add.txt into $UPDATED_LIST first."
  exit 1
fi

# Clean and deduplicate updated fungal accessions
grep -oE 'GC[AF]_[0-9]+\.[0-9]+' "$UPDATED_LIST" \
| sort -u \
> lists/fungi_update_accessions.txt

echo "Updated fungal genomes to download:"
wc -l lists/fungi_update_accessions.txt

# Make new update chunks only
rm -f chunks/fungi_update_*
split -d -a 3 -l 200 lists/fungi_update_accessions.txt chunks/fungi_update_

# Download update chunks with retry
for f in chunks/fungi_update_*; do
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

echo "Done."