#!/bin/bash
#SBATCH --job-name=sourmash_array
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --array=0-0
#SBATCH --output=logs/sourmash_%A_%a.out
#SBATCH --error=logs/sourmash_%A_%a.err

set -euo pipefail

module load anaconda3/2023.09-0
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate sourmash_env

# ====== CONFIG ======
INPUT_DIR="/scratch/dgohar/Prabh/bact_fung_filtered_reads_sdust"
OUT_DIR="/scratch/dgohar/Prabh/sourmash_results_abundances"

DB_DIR="/scratch/dgohar/sourmash_ncbi_ref_db/db"
DB_K21="${DB_DIR}/ncbi_ref_bacteria_fungi_clean_k21.sig.zip"
DB_K31="${DB_DIR}/ncbi_ref_bacteria_fungi_clean_k31.sig.zip"
DB_K51="${DB_DIR}/ncbi_ref_bacteria_fungi_clean_k51.sig.zip"

mkdir -p "${OUT_DIR}"

# ====== GET SAMPLE FOR THIS ARRAY TASK ======
SAMPLE_DIR=$(find "${INPUT_DIR}" -mindepth 1 -maxdepth 1 -type d | sort -V | sed -n "$((SLURM_ARRAY_TASK_ID + 1))p")

if [[ -z "${SAMPLE_DIR}" ]]; then
    echo "No sample found for array index ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

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

for DB in "${DB_K21}" "${DB_K31}" "${DB_K51}"; do
    if [[ ! -f "${DB}" ]]; then
        echo "Missing database: ${DB}"
        exit 1
    fi
done

SAMPLE_OUT="${OUT_DIR}/${SAMPLE_ID}"
mkdir -p "${SAMPLE_OUT}"

SIG="${SAMPLE_OUT}/${SAMPLE_ID}.k21_k31_k51.sig"

# ====== SKETCH ALL THREE K-MERS ======
sourmash sketch dna \
    -p k=21,scaled=1000,abund \
    -p k=31,scaled=1000,abund \
    -p k=51,scaled=1000,abund \
    --merge "${SAMPLE_ID}" \
    -o "${SIG}" \
    "${R1}" "${R2}"

# ====== GATHER K21 ======
sourmash gather \
    "${SIG}" \
    "${DB_K21}" \
    --ksize 21 \
    -o "${SAMPLE_OUT}/${SAMPLE_ID}_ncbi_bacteria_fungi_k21.csv"

# ====== GATHER K31 ======
sourmash gather \
    "${SIG}" \
    "${DB_K31}" \
    --ksize 31 \
    -o "${SAMPLE_OUT}/${SAMPLE_ID}_ncbi_bacteria_fungi_k31.csv"

# ====== GATHER K51 ======
sourmash gather \
    "${SIG}" \
    "${DB_K51}" \
    --ksize 51 \
    -o "${SAMPLE_OUT}/${SAMPLE_ID}_ncbi_bacteria_fungi_k51.csv"

echo "Done ${SAMPLE_ID}"