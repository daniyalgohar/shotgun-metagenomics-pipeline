#!/bin/bash
#SBATCH --job-name=merge_eggnog
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --output=logs/merge_eggnog_%j.out
#SBATCH --error=logs/merge_eggnog_%j.err

set -euo pipefail

INDIR=/scratch/dgohar/mohit_coverCrop/eggnong_annotations/
OUTFILE=$INDIR/merged_emapper_annotations_Covercrop.tsv

cd "$INDIR"

first=1

for file in zr30102_*.emapper.annotations; do
    sample_id=$(basename "$file" .emapper.annotations)

    echo "Processing $sample_id"

    if [ "$first" -eq 1 ]; then
        awk -v sample="$sample_id" '
        BEGIN{OFS="\t"}
        /^##/ {next}
        /^#/ {
            sub(/^#/, "", $0)
            print "sample_id", $0
            next
        }
        {
            print sample, $0
        }' "$file" > "$OUTFILE"

        first=0
    else
        awk -v sample="$sample_id" '
        BEGIN{OFS="\t"}
        /^#/ {next}
        {
            print sample, $0
        }' "$file" >> "$OUTFILE"
    fi
done

echo "Merged file created:"
echo "$OUTFILE"