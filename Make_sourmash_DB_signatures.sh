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

mkdir -p "$DBDIR"/{unzipped,genomes,sigs,db,logs}

echo "Checking tools..."
which sourmash
sourmash --version
which unzip
unzip -v | head -n 2

cd "$BASE"

###############################################################################
# Uncomment if rebuilding from downloaded zip files
###############################################################################

# echo "Checking zip files..."
# for z in downloads/*.zip; do
#     unzip -tq "$z" > /dev/null || echo "CORRUPTED: $z"
# done

# echo "Unzipping all chunks..."
# for z in downloads/*.zip; do
#     name=$(basename "$z" .zip)
#
#     if [ ! -d "$DBDIR/unzipped/$name" ]; then
#         echo "Unzipping $name"
#         unzip -q "$z" -d "$DBDIR/unzipped/$name"
#     else
#         echo "Already unzipped: $name"
#     fi
# done

###############################################################################
# IMPORTANT: use only genomic assemblies
###############################################################################

echo "Collecting genomic FASTA files only..."

find "$DBDIR/unzipped" \
    -type f \
    -name "*_genomic.fna" \
    > "$DBDIR/genome_files.txt"

echo "Number of genomic assemblies:"
wc -l "$DBDIR/genome_files.txt"

echo "Making sourmash signatures for k=21,31,51..."

sourmash sketch dna \
    -p k=21,k=31,k=51,scaled=1000,abund \
    --name-from-first \
    --from-file "$DBDIR/genome_files.txt" \
    --output "$DBDIR/sigs/ncbi_ref_bacteria_fungi_k21_k31_k51.sig.zip"

echo "Creating separate databases..."

for k in 21 31 51; do

    echo "Processing k=$k"

    sourmash sig cat \
        --ksize "$k" \
        "$DBDIR/sigs/ncbi_ref_bacteria_fungi_k21_k31_k51.sig.zip" \
        -o "$DBDIR/db/ncbi_ref_bacteria_fungi_k${k}.sig.zip"

    # Uncomment if SBT indexes are desired
    #
    # sourmash index \
    #     "$DBDIR/db/ncbi_ref_bacteria_fungi_k${k}.sbt.zip" \
    #     "$DBDIR/db/ncbi_ref_bacteria_fungi_k${k}.sig.zip"

done

echo "Done."
echo "Databases created in:"
echo "$DBDIR/db"