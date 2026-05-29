#!/bin/bash
#SBATCH --job-name=collectIDs_
#SBATCH --partition=work1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=12:00:00
#SBATCH --output=logs/collectIDs_%j.out
#SBATCH --error=logs/collectIDs_%j.err

set -euo pipefail

INPUT_DIR="/scratch/dgohar/Prabh/sourmash_results"
OUT_DIR="/scratch/dgohar/Prabh/sourmash_results/combined_genomes"

mkdir -p "$OUT_DIR"

echo "Collecting genome IDs + sample mapping..."

python3 <<EOF
import csv, re
from pathlib import Path
from collections import defaultdict

base = Path("$INPUT_DIR")
out_file = Path("$OUT_DIR") / "genome_ids_with_samples.tsv"

acc_re = re.compile(r"(GC[AF]_\\d+\\.\\d+)")

genome_to_samples = defaultdict(set)

for csv_file in base.rglob("*.csv"):
    if not (csv_file.name.endswith("_bacteria.csv") or csv_file.name.endswith("_fungi.csv")):
        continue

    sample_id = csv_file.parent.name

    with open(csv_file, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row.get("name", "")
            m = acc_re.search(name)
            if m:
                genome = m.group(1)
                genome_to_samples[genome].add(sample_id)

with open(out_file, "w") as out:
    out.write("genome_id\tsamples\n")
    for genome in sorted(genome_to_samples):
        samples = ",".join(sorted(genome_to_samples[genome]))
        out.write(f"{genome}\t{samples}\n")

print(f"Total genomes: {len(genome_to_samples)}")
print(f"Wrote: {out_file}")
EOF

echo "Done."