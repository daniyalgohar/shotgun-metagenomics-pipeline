#!/bin/bash
#SBATCH --job-name=prodigal_array
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --array=0-1
#SBATCH --output=logs/prodigal_%A_%a.log

module load anaconda3/2023.09-0
source $(conda info --base)/etc/profile.d/conda.sh
conda activate metagenome_func

# Sample list
SAMPLE_LIST="/home/dgohar/samples1.txt"

# Get sample from array index
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

BASE_DIR="/scratch/dgohar/Prabh/Assembly"
OUT_BASE="/scratch/dgohar/Prabh/Assembly/prodigal_results"

INPUT="${BASE_DIR}/${SAMPLE}_assembly/${SAMPLE}_spades.fasta"
OUT_DIR="${OUT_BASE}/${SAMPLE}"

mkdir -p "$OUT_DIR"

FILTERED="${OUT_DIR}/${SAMPLE}_500bp.fa"

if [ ! -f "$INPUT" ]; then
    echo "ERROR: input file not found for $SAMPLE"
    exit 1
fi

awk '
/^>/ {
    if (seqlen >= 500) print header "\n" seq
    header = $0
    seq = ""
    seqlen = 0
    next
}
{
    seq = seq $0
    seqlen += length($0)
}
END {
    if (seqlen >= 500) print header "\n" seq
}
' "$INPUT" > "$FILTERED"

prodigal \
  -i "$FILTERED" \
  -a "${OUT_DIR}/${SAMPLE}.proteins.faa" \
  -d "${OUT_DIR}/${SAMPLE}.genes.fna" \
  -o "${OUT_DIR}/${SAMPLE}.gff" \
  -p meta