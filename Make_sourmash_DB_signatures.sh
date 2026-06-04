#!/bin/bash
#SBATCH --job-name=sourmash_ref_db
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=200G
#SBATCH --time=72:00:00
#SBATCH --output=logs/sourmash_ref_db_%j.out
#SBATCH --error=logs/sourmash_ref_db_%j.err

set -euo pipefail

module load anaconda3/2023.09-0
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate sourmash_env

BASE=/scratch/dgohar/NCBI_ref_genomes_chunked
DBDIR=/scratch/dgohar/sourmash_ncbi_ref_db

mkdir -p "$DBDIR"/{sigs,db}

echo "Checking tools..."
which sourmash
sourmash --version

echo "Building clean genome file list..."

find "$DBDIR/unzipped" \
    -type f \( -name "GCF_*_genomic.fna" -o -name "GCA_*_genomic.fna" \) \
    | sort \
    > "$DBDIR/genome_files.clean.txt"

echo "Number of genome assemblies being used:"
GENOME_COUNT=$(wc -l < "$DBDIR/genome_files.clean.txt")
echo "$GENOME_COUNT"

echo "First few genomes:"
head "$DBDIR/genome_files.clean.txt"

if [ "$GENOME_COUNT" -eq 0 ]; then
    echo "ERROR: No genome FASTA files found."
    exit 1
fi

echo "Making sourmash signatures for k=21,31,51..."

sourmash sketch dna \
    -p k=21,k=31,k=51,scaled=1000,abund \
    --name-from-first \
    --from-file "$DBDIR/genome_files.clean.txt" \
    --output "$DBDIR/sigs/ncbi_ref_bacteria_fungi_clean_k21_k31_k51.sig.zip"

echo "Creating separate databases..."

for k in 21 31 51; do

    echo "Processing k=$k"

    sourmash sig cat \
        --ksize "$k" \
        "$DBDIR/sigs/ncbi_ref_bacteria_fungi_clean_k21_k31_k51.sig.zip" \
        -o "$DBDIR/db/ncbi_ref_bacteria_fungi_clean_k${k}.sig.zip"

    echo "Summary for k=$k:"
    sourmash sig summarize "$DBDIR/db/ncbi_ref_bacteria_fungi_clean_k${k}.sig.zip"

done

echo "Done."
echo "Databases created in:"
echo "$DBDIR/db"