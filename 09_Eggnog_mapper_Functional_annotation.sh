#!/bin/bash
#SBATCH --job-name=eggnog_array
#SBATCH --partition=work1
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --time=72:00:00

#SBATCH --output=logs/eggnog_%A_%a.out
#SBATCH --error=logs/eggnog_%A_%a.err

# Activate environment
module load anaconda3/2023.09-0
source $(conda info --base)/etc/profile.d/conda.sh
conda activate metagenome_func

# Paths
INPUT_DIR="/scratch/dgohar/Prabh/Assembly/prodigal_results"
DB_DIR="/scratch/dgohar/eggnog_db"
OUT_DIR="/scratch/dgohar/Prabh/eggnog_results_functional_annotation"

mkdir -p $OUT_DIR

# Sample list
#SAMPLE_LIST="/home/dgohar/samples1.txt"

# Get sample from array index
#SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")
# Single sample
SAMPLE="zr30098_44"
# Input file
PROT_FILE="$INPUT_DIR/$SAMPLE/${SAMPLE}.proteins.faa"

# Output prefix
OUT_PREFIX="$OUT_DIR/$SAMPLE"

echo "Running eggNOG for $SAMPLE"

emapper.py \
  -i $PROT_FILE \
  -o $SAMPLE \
  --output_dir $OUT_DIR \
  --data_dir $DB_DIR \
  --cpu $SLURM_CPUS_PER_TASK \
  --itype proteins \
  --override \
  --dmnd_db $DB_DIR/eggnog_proteins.dmnd

echo "Done $SAMPLE"