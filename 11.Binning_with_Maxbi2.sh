#!/bin/bash
#SBATCH --job-name=maxbin_array
#SBATCH --output=logs/maxbin_%A_%a.out
#SBATCH --error=logs/maxbin_%A_%a.err
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=80G
#SBATCH --partition=work1
#SBATCH --array=0-15

# Load conda
module load anaconda3/2023.09-0
source $(conda info --base)/etc/profile.d/conda.sh
# Activate MaxBin environment
source activate maxbin

# Sample list: 
SAMPLES=(
zr24632_17
zr24632_18
zr24632_19
zr24632_20
zr24632_21
zr24632_22
zr24632_23
zr24632_24
zr24632_25
zr24632_26
zr24632_27
zr24632_28
zr24632_29
zr24632_30
zr24632_31
zr24632_32
)

SAMPLE="${SAMPLES[$SLURM_ARRAY_TASK_ID]}"

BASE_DIR="/scratch/mgoyal/Assembly"
OUT_BASE="/scratch/mgoyal/binning"

INPUT="${BASE_DIR}/${SAMPLE}_assembly/${SAMPLE}_spades.fasta"
OUT_DIR="${OUT_BASE}/${SAMPLE}"

mkdir -p "$OUT_DIR"

echo "Running MaxBin for sample: $SAMPLE"
echo "Input assembly: $INPUT"
echo "Output directory: $OUT_DIR"

run_MaxBin.pl \
  -contig "$INPUT" \
  -out "${OUT_DIR}/${SAMPLE}_maxbin" \
  -min_contig_length 1000 \
  -thread 16

echo "Finished MaxBin for sample: $SAMPLE"