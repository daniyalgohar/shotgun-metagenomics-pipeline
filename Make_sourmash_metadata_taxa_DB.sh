#!/bin/bash
#SBATCH --job-name=make_ncbi_metadata
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --output=logs/make_metadata_%j.out
#SBATCH --error=logs/make_metadata_%j.err

set -euo pipefail

module load anaconda3/2023.09-0
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate ncbi_datasets

DBDIR=/scratch/dgohar/sourmash_ncbi_ref_db
OUTDIR=$DBDIR/metadata

mkdir -p "$OUTDIR"

echo "Finding NCBI metadata files..."
find "$DBDIR/unzipped" -name "assembly_data_report.jsonl" > "$OUTDIR/reports.txt"

echo "Number of report files:"
wc -l "$OUTDIR/reports.txt"

echo "Making metadata table..."

echo -e "accession\torganism_name\ttaxid\tassembly_level\tassembly_name\tbioproject\tbiosample\tsubmission_date\tgroup" \
> "$OUTDIR/ncbi_bacteria_fungi_metadata.tsv"

while read report; do

    if echo "$report" | grep -q "fungi_"; then
        group="Fungi"
    else
        group="Bacteria"
    fi

    jq -r --arg group "$group" '
    [
      .accession,
      .organism.organismName,
      .organism.taxId,
      .assemblyInfo.assemblyLevel,
      .assemblyInfo.assemblyName,
      .assemblyInfo.bioprojectAccession,
      .assemblyInfo.biosampleAccession,
      .assemblyInfo.submissionDate,
      $group
    ] | @tsv
    ' "$report" >> "$OUTDIR/ncbi_bacteria_fungi_metadata.tsv"

done < "$OUTDIR/reports.txt"

echo "Done."
echo "$OUTDIR/ncbi_bacteria_fungi_metadata.tsv"