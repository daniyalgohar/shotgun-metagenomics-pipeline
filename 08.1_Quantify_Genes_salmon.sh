#!/bin/bash
#SBATCH --job-name=salmon_quant
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=24:00:00
#SBATCH --array=1-44
#SBATCH --output=logs/salmon_%A_%a.out
#SBATCH --error=logs/salmon_%A_%a.err

set -euo pipefail

module load anaconda3/2023.09-0
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate salmon_env

BASE=/scratch/dgohar/Prabh
READS=/scratch/dgohar/Prabh/raw_seqs
PRODIGAL=/scratch/dgohar/Prabh/Assembly/prodigal_results
OUTDIR=/scratch/dgohar/Prabh/salmon_quant

mkdir -p "$OUTDIR" "$BASE/logs"

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" /home/dgohar/samples.txt)

GENES="$PRODIGAL/$SAMPLE/$SAMPLE.genes.fna"
INDEX="$OUTDIR/${SAMPLE}_salmon_index"
QUANT="$OUTDIR/${SAMPLE}_quant"

R1="$READS/${SAMPLE}_R1.fastq.gz"
R2="$READS/${SAMPLE}_R2.fastq.gz"

echo "Sample: $SAMPLE"
echo "Genes: $GENES"
echo "R1: $R1"
echo "R2: $R2"

if [ ! -s "$GENES" ]; then
  echo "Missing genes file: $GENES"
  exit 1
fi

if [ ! -s "$R1" ] || [ ! -s "$R2" ]; then
  echo "Missing reads for $SAMPLE"
  exit 1
fi

if [ ! -d "$INDEX" ]; then
  salmon index \
    -t "$GENES" \
    -i "$INDEX" \
    -k 31 \
    -p "$SLURM_CPUS_PER_TASK"
fi

salmon quant \
  -i "$INDEX" \
  -l A \
  -1 "$R1" \
  -2 "$R2" \
  -p "$SLURM_CPUS_PER_TASK" \
  --validateMappings \
  -o "$QUANT"

echo "Done: $SAMPLE"