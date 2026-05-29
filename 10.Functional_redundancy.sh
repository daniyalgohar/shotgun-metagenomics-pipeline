#!/usr/bin/env bash
#SBATCH --job-name=gene_all_hits
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH --time=24:00:00
#SBATCH --array=0-44
#SBATCH --output=logs/gene_all_hits_%A_%a.out
#SBATCH --error=logs/gene_all_hits_%A_%a.err

set -euo pipefail

mkdir -p logs

module load anaconda3/2023.09-0
source $(conda info --base)/etc/profile.d/conda.sh
conda activate ncbi_datasets

THREADS="${SLURM_CPUS_PER_TASK:-16}"

GENE_BASE="/scratch/mgoyal/Assembly/prodigal_results"
REF_BASE="/scratch/mgoyal/NCBI_hits/reference/per_sample"

OUT_BASE="/scratch/mgoyal/Funct_redundancy/GeneGenomeRedundancy_all_filters"
TMP_BASE="/scratch/mgoyal/tmp_gene_genome_redundancy"

SAMPLES=(zr24632_17 zr24632_18 zr24632_19 zr24632_20 zr24632_21)

SAMPLE="${SAMPLES[$SLURM_ARRAY_TASK_ID]}"

#mkdir -p "$OUT_BASE" "$TMP_BASE"

if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: No sample found for array task $SLURM_ARRAY_TASK_ID"
    exit 1
fi

REF="${REF_BASE}/${SAMPLE}/${SAMPLE}_combined_reference.fna"
GENES_FNA="${GENE_BASE}/${SAMPLE}/${SAMPLE}.genes.fna"

OUT_DIR="${OUT_BASE}/${SAMPLE}"
TMP_DIR="${TMP_BASE}/${SAMPLE}"

mkdir -p "$OUT_DIR" "$TMP_DIR"

echo "=========================================="
echo "Sample: $SAMPLE"
echo "Reference: $REF"
echo "Genes: $GENES_FNA"
echo "=========================================="

[[ -f "$REF" ]] || { echo "ERROR: reference not found: $REF"; exit 1; }
[[ -f "$GENES_FNA" ]] || { echo "ERROR: genes file not found: $GENES_FNA"; exit 1; }

INPUT_GENE_COUNT=$(grep -c "^>" "$GENES_FNA")
echo "Input predicted genes: $INPUT_GENE_COUNT"

# -------------------------
# Map predicted genes to sample-specific genome database
# -------------------------
PAF="${TMP_DIR}/${SAMPLE}.genes_vs_genomes.paf"

if [[ ! -s "$PAF" ]]; then
    minimap2 -t "$THREADS" -x asm10 "$REF" "$GENES_FNA" > "$PAF"
else
    echo "PAF already exists, using existing file: $PAF"
fi

TOTAL_PAF_HITS=$(wc -l < "$PAF")
UNIQUE_GENES_WITH_ANY_HIT=$(cut -f1 "$PAF" | sort -u | wc -l)

echo "Total minimap2 alignments: $TOTAL_PAF_HITS"
echo "Unique genes with any minimap2 hit: $UNIQUE_GENES_WITH_ANY_HIT"

# -------------------------
# Filter hits at 3 levels
# For duplicate gene-genome hits, keep highest:
# identity > coverage > MAPQ > alignment length
# -------------------------
python3 <<EOF
from pathlib import Path
from collections import defaultdict

sample = "${SAMPLE}"
paf = Path("${PAF}")
out_dir = Path("${OUT_DIR}")

input_gene_count = int("${INPUT_GENE_COUNT}")
total_paf_hits = int("${TOTAL_PAF_HITS}")
unique_genes_with_any_hit = int("${UNIQUE_GENES_WITH_ANY_HIT}")

out_hits = out_dir / f"{sample}.all_gene_genome_hits.tsv"
out_counts = out_dir / f"{sample}.genome_gene_hit_counts.tsv"
out_report = out_dir / f"{sample}.mapping_report.tsv"

# ----------------------------------------
# Keep only BEST alignment per gene-genome pair
# based on:
# identity > coverage > MAPQ > alignment length
# ----------------------------------------

best_pair = {}

with open(paf) as f:
    for line in f:
        p = line.rstrip("\\n").split("\\t")

        gene_id = p[0]
        gene_len = int(p[1])

        qstart = int(p[2])
        qend = int(p[3])

        strand = p[4]

        ref_id = p[5]
        genome_id = ref_id.split("|")[0]

        ref_start = int(p[7])
        ref_end = int(p[8])

        matches = int(p[9])
        aln_len = int(p[10])
        mapq = int(p[11])

        if gene_len == 0 or aln_len == 0:
            continue

        percent_identity = 100 * matches / aln_len
        gene_coverage = 100 * (qend - qstart) / gene_len

        pair = (gene_id, genome_id)

        score = (
            percent_identity,
            gene_coverage,
            mapq,
            aln_len
        )

        hit = {
            "gene_id": gene_id,
            "genome_id": genome_id,
            "ref_id": ref_id,
            "strand": strand,
            "percent_identity": percent_identity,
            "gene_coverage": gene_coverage,
            "mapq": mapq,
            "aln_len": aln_len,
            "ref_start": ref_start,
            "ref_end": ref_end,
            "score": score
        }

        if pair not in best_pair or score > best_pair[pair]["score"]:
            best_pair[pair] = hit

# ----------------------------------------
# Summaries
# ----------------------------------------

genome_counts = defaultdict(int)
genes_assigned = set()

with open(out_hits, "w") as out:
    out.write(
        "sample\\tgene_id\\tgenome_id\\tref_id\\tstrand\\t"
        "percent_identity\\tgene_coverage_percent\\tmapq\\talignment_length\\t"
        "ref_start\\tref_end\\n"
    )

    for (gene_id, genome_id), h in sorted(best_pair.items()):

        genome_counts[genome_id] += 1
        genes_assigned.add(gene_id)

        out.write(
            f"{sample}\\t{gene_id}\\t{genome_id}\\t{h['ref_id']}\\t{h['strand']}\\t"
            f"{h['percent_identity']:.2f}\\t{h['gene_coverage']:.2f}\\t"
            f"{h['mapq']}\\t{h['aln_len']}\\t"
            f"{h['ref_start']}\\t{h['ref_end']}\\n"
        )

total_unique_gene_genome_hits = len(best_pair)
assigned_gene_count = len(genes_assigned)

max_genes_per_genome = max(genome_counts.values()) if genome_counts else 0
min_genes_per_genome = min(genome_counts.values()) if genome_counts else 0

max_genome = max(genome_counts, key=genome_counts.get) if genome_counts else "NA"
min_genome = min(genome_counts, key=genome_counts.get) if genome_counts else "NA"

# ----------------------------------------
# Genome counts
# ----------------------------------------

with open(out_counts, "w") as out:
    out.write(
        "sample\\tgenome_id\\tmatched_gene_count\\trelative_gene_count\\n"
    )

    for genome_id, count in sorted(
        genome_counts.items(),
        key=lambda x: x[1],
        reverse=True
    ):

        rel = (
            count / total_unique_gene_genome_hits
            if total_unique_gene_genome_hits > 0
            else 0
        )

        out.write(
            f"{sample}\\t{genome_id}\\t{count}\\t{rel:.9f}\\n"
        )

# ----------------------------------------
# Report table
# ----------------------------------------

with open(out_report, "w") as out:

    out.write(
        "sample\\tinput_genes\\ttotal_paf_hits\\t"
        "genes_with_any_hit\\tassigned_genes\\t"
        "unique_gene_genome_hits\\tn_genomes_hit\\t"
        "max_genes_per_genome\\tmax_genome\\t"
        "min_genes_per_genome\\tmin_genome\\n"
    )

    out.write(
        f"{sample}\\t"
        f"{input_gene_count}\\t"
        f"{total_paf_hits}\\t"
        f"{unique_genes_with_any_hit}\\t"
        f"{assigned_gene_count}\\t"
        f"{total_unique_gene_genome_hits}\\t"
        f"{len(genome_counts)}\\t"
        f"{max_genes_per_genome}\\t"
        f"{max_genome}\\t"
        f"{min_genes_per_genome}\\t"
        f"{min_genome}\\n"
    )

print("==========================================")
print("Input genes:", input_gene_count)
print("Total minimap2 hits:", total_paf_hits)
print("Genes with any hit:", unique_genes_with_any_hit)
print("Assigned genes:", assigned_gene_count)
print("Unique gene-genome hits:", total_unique_gene_genome_hits)
print("Genomes hit:", len(genome_counts))
print("Max genes assigned to one genome:", max_genes_per_genome, max_genome)
print("Min genes assigned to one genome:", min_genes_per_genome, min_genome)

print("Saved:", out_hits)
print("Saved:", out_counts)
print("Saved:", out_report)

print("Done:", sample)

EOF

echo "Done: $SAMPLE"