#!/bin/bash
#SBATCH --job-name=soil_meta_assembly
#SBATCH --output=logs/soil_meta_assembly_%A_%a.out
#SBATCH --error=logs/soil_meta_assembly_%A_%a.err
#SBATCH --cpus-per-task=12
#SBATCH --partition=work1
#SBATCH --mem=200G
#SBATCH --array=1-44
#SBATCH --time=24:00:00

module load biocontainers
module load spades/3.15.5
module load quast/5.2.0
THREADS=${SLURM_CPUS_PER_TASK}

BASE_DIR="/scratch/dgohar/Prabh/"
READS_DIR="/scratch/dgohar/Prabh/bact_fung_filtered_reads_sdust"
ASSEMBLY_DIR="${BASE_DIR}/Assembly"
QUAST_DIR="${BASE_DIR}/QUAST_Results"

mkdir -p "$ASSEMBLY_DIR" "$QUAST_DIR" logs

# get sample names from subdirectories
SAMPLES=($(find "$READS_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort))

SAMPLE=${SAMPLES[$SLURM_ARRAY_TASK_ID-1]}

echo "Running sample: $SAMPLE"

R1="${READS_DIR}/${SAMPLE}/${SAMPLE}_bact_fungi_R1.filtered.fastq.gz"
R2="${READS_DIR}/${SAMPLE}/${SAMPLE}_bact_fungi_R2.filtered.fastq.gz"

if [[ ! -f "$R1" || ! -f "$R2" ]]; then
    echo "Missing reads for sample $SAMPLE"
    echo "$R1"
    echo "$R2"
    exit 1
fi

OUTPUT_DIR="${ASSEMBLY_DIR}/${SAMPLE}_assembly"
mkdir -p "$OUTPUT_DIR"

spades.py -t "$THREADS" -m 110 --meta --only-assembler \
    -1 "$R1" \
    -2 "$R2" \
    -k 21,33,55,77,99,127 \
    -o "$OUTPUT_DIR/spades_output"

cp "$OUTPUT_DIR/spades_output/contigs.fasta" "$OUTPUT_DIR/${SAMPLE}_spades.fasta"

quast.py -t "$THREADS" \
    -o "${QUAST_DIR}/${SAMPLE}" \
    "$OUTPUT_DIR/${SAMPLE}_spades.fasta" \
    --silent