#!/bin/bash
#SBATCH --job-name=sourmash_array
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=48:00:00
#SBATCH --array=0-44
#SBATCH --output=sourmash_%A_%a.out
#SBATCH --error=sourmash_%A_%a.err

set -euo pipefail

module load anaconda3/2023.09-0
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate sourmash_env

# ====== CONFIG ======
SAMPLE_LIST="/home/dgohar/samples.txt"
OUT_DIR="/scratch/dgohar/Prabh/sourmash_results"

GTDB_DB="/scratch/dgohar/sourmash_db/gtdb-reps-rs226-k51.dna.zip"
FUNGI_DB="/scratch/dgohar/sourmash_db/ncbi-euks-fungi-2025.01.dna.k=51.sig.zip"

mkdir -p "${OUT_DIR}"

# ====== GET SAMPLE FOR THIS ARRAY TASK ======
SAMPLE_DIR=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "${SAMPLE_LIST}")

if [[ -z "${SAMPLE_DIR}" ]]; then
    echo "No sample found for array index ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

SAMPLE_DIR="${SAMPLE_DIR%/}"
SAMPLE_ID=$(basename "${SAMPLE_DIR}")

echo "Processing ${SAMPLE_ID}..."
echo "Sample dir: ${SAMPLE_DIR}"

R1="${SAMPLE_DIR}/${SAMPLE_ID}_bact_fungi_R1.filtered.fastq.gz"
R2="${SAMPLE_DIR}/${SAMPLE_ID}_bact_fungi_R2.filtered.fastq.gz"

if [[ ! -f "${R1}" || ! -f "${R2}" ]]; then
    echo "Skipping ${SAMPLE_ID} because read files are missing."
    echo "Expected:"
    echo "  ${R1}"
    echo "  ${R2}"
    exit 0
fi

SAMPLE_OUT="${OUT_DIR}/${SAMPLE_ID}"
mkdir -p "${SAMPLE_OUT}"

SIG="${SAMPLE_OUT}/${SAMPLE_ID}.sig"

# ====== SKETCH ======
sourmash sketch dna \
    -p k=51,scaled=1000 \
    --merge "${SAMPLE_ID}" \
    -o "${SIG}" \
    "${R1}" "${R2}"

# ====== BACTERIA ======
sourmash gather \
    "${SIG}" \
    "${GTDB_DB}" \
    --ksize 51 \
    --num-threads "$SLURM_CPUS_PER_TASK" \
    -o "${SAMPLE_OUT}/${SAMPLE_ID}_bacteria.csv"

# ====== FUNGI ======
sourmash gather \
    "${SIG}" \
    "${FUNGI_DB}" \
    --ksize 51 \
    --num-threads "$SLURM_CPUS_PER_TASK" \
    -o "${SAMPLE_OUT}/${SAMPLE_ID}_fungi.csv"

echo "Done ${SAMPLE_ID}"