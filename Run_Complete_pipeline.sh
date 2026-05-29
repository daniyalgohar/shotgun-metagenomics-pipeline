#!/bin/bash
#SBATCH --job-name=submit_pipeline
#SBATCH --output=submit_pipeline_%j.out
#SBATCH --error=submit_pipeline_%j.err
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G

# Submit first job
#job1=$(sbatch /home/dgohar/Prabh_P1/Scripts/01_Quality_Trimming.sh | awk '{print $4}')
#echo "Submitted job1: $job1"

# Submit dependent jobs
#job2=$(sbatch /home/dgohar/Prabh_P1/Scripts/02_Karaken2_assignments.sh | awk '{print $4}')
#echo "Submitted job2: $job2"

#job3=$(sbatch --dependency=afterok:$job2 /home/dgohar/Prabh_P1/Scripts/03_extract_bact_fung_reads.sh | awk '{print $4}')
#echo "Submitted job3: $job3"

#job4=$(sbatch --dependency=afterok:$job3 /home/dgohar/Prabh_P1/Scripts/3.1.Sequence_Exploratory_statistics.sh | awk '{print $4}')
#echo "Submitted job4: $job4"

#job5=$(sbatch --dependency=afterok:$job3 /home/dgohar/Prabh_P1/Scripts/04_Remove_low_diversity_reads_sdust.sh | awk '{print $4}')
#echo "Submitted job5: $job5"

#job6=$(sbatch --dependency=afterok:$job5 /home/dgohar/Prabh_P1/Scripts/05_Taxonomy_assignment_Sourmash.sh | awk '{print $4}')
#echo "Submitted job6: $job6"

#job7=$(sbatch --dependency=afterok:$job6 /home/dgohar/Prabh_P1/Scripts/06.1_Extract_genome_hit_Ids.sh | awk '{print $4}')
#echo "Submitted job7: $job7"

#job8=$(sbatch --dependency=afterok:$job7 /home/dgohar/Prabh_P1/Scripts/06.2_Download_NCBI_HITS_Genomes.sh | awk '{print $4}')
#echo "Submitted job8: $job8"

#job9=$(sbatch --dependency=afterok:$job8 /home/dgohar/Prabh_P1/Scripts/06.3.2.Build_NCBI_Reference_per_sample.sh | awk '{print $4}')
#echo "Submitted job9: $job9"

#job10=$(sbatch --dependency=afterok:$job9 /home/dgohar/Prabh_P1/Scripts/06.4_Core_Abundance_Table.sh | awk '{print $4}')
#echo "Submitted job10: $job10"

#job11=$(sbatch --dependency=afterok:$job10 /home/dgohar/Prabh_P1/Scripts/06.4.1_Run_Core_abundance_analysis.sh | awk '{print $4}')
#echo "Submitted job11: $job11"

#job12=$(sbatch --dependency=afterok:$job5 /home/dgohar/Prabh_P1/Scripts/07_Assembly_metaSpades.sh | awk '{print $4}')
#echo "Submitted job12: $job12"

echo "Submitting Protein_prediction.sh"
job13=$(sbatch /home/dgohar/Prabh_P1/Scripts/08_Protein_prediction.sh | awk '{print $4}')
echo "Submitted job13: $job13"

echo "Completed Protein_prediction.sh"

echo "Submitting Eggnog"
job14=$(sbatch --dependency=afterok:$job13 /home/dgohar/Prabh_P1/Scripts/09_Eggnog_mapper_Functional_annotation.sh | awk '{print $4}')
echo "Submitted job14: $job14"

echo "Comleted Eggnog"

echo "Submitting functional Redundancy"
job15=$(sbatch --dependency=afterok:$job14 /home/dgohar/Prabh_P1/Scripts/10.Functional_redundancy.sh | awk '{print $4}')
echo "Submitted job15: $job15"

echo "All jobs submitted with dependencies."