#!/bin/bash
#SBATCH --job-name=abundance
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH --time=36:00:00
#SBATCH --array=0-0
#SBATCH --partition=work1
#SBATCH --output=logs/abundance_table%j.out
#SBATCH --error=logs/abundance_table%j.err

module load anaconda3/2023.09-0
source $(conda info --base)/etc/profile.d/conda.sh
conda activate ncbi_datasets

SAMPLES=(zr24632_17)

SAMPLE=${SAMPLES[$SLURM_ARRAY_TASK_ID-1]}

bash 06.4_Core_Abundance_Table.sh \
  $SAMPLE \
  /scratch/dgohar/Prabh/bact_fung_filtered_reads_sdust/$SAMPLE/${SAMPLE}_bact_fungi_R1.filtered.fastq.gz \
  /scratch/dgohar/Prabh/bact_fung_filtered_reads_sdust/$SAMPLE/${SAMPLE}_bact_fungi_R2.filtered.fastq.gz