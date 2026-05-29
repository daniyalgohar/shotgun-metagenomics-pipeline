#!/bin/bash
#SBATCH --job-name=test
#SBATCH --partition=work1
#SBATCH --output=test%j.out
#SBATCH --error=test%j.err
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=01:00:00

python3 <<'EOF'
from pathlib import Path

taxdir = Path("/scratch/dgohar/NCBI_hits")

test_ids = [
    "GCA_000016765.1",
    "GCF_000016765.1",
]

# load taxonomy tree
parent = {}
rank = {}
name = {}

with open(taxdir / "nodes.dmp") as f:
    for line in f:
        p = [x.strip() for x in line.split("|")]
        parent[p[0]] = p[1]
        rank[p[0]] = p[2]

with open(taxdir / "names.dmp") as f:
    for line in f:
        p = [x.strip() for x in line.split("|")]
        if p[3] == "scientific name":
            name[p[0]] = p[1]

wanted = ["superkingdom", "kingdom", "phylum", "class", "order", "family", "genus", "species"]

def get_lineage(taxid):
    out = {k: "NA" for k in wanted}
    seen = set()
    cur = taxid
    lineage_names = []

    while cur in parent and cur not in seen:
        seen.add(cur)
        nm = name.get(cur, "NA")
        lineage_names.append(nm)

        r = rank.get(cur, "")
        if r in out and out[r] == "NA":
            out[r] = nm

        if cur == parent[cur]:
            break
        cur = parent[cur]

    out["_lineage_names"] = lineage_names
    return out

# load accession -> taxid from both files
acc2tax = {}
acc_source = {}

for fname, source in [
    ("assembly_summary_refseq.txt", "RefSeq"),
    ("assembly_summary_genbank.txt", "GenBank"),
]:
    fp = taxdir / fname
    if not fp.exists():
        continue
    with open(fp) as f:
        for line in f:
            if line.startswith("#"):
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) > 5:
                acc2tax[parts[0]] = parts[5]
                acc_source[parts[0]] = source

for gid in test_ids:
    print("\n" + "=" * 80)
    print("Genome:", gid)

    taxid = acc2tax.get(gid)
    if not taxid:
        print("NOT FOUND in assembly_summary files")
        continue

    print("Source:", acc_source[gid])
    print("TaxID :", taxid)

    lin = get_lineage(taxid)
    lineage_names = set(lin["_lineage_names"])

    if "Fungi" in lineage_names:
        domain_group = "Fungi"
    elif "Bacteria" in lineage_names:
        domain_group = "Bacteria"
    elif "Archaea" in lineage_names:
        domain_group = "Archaea"
    else:
        domain_group = lin["superkingdom"] if lin["superkingdom"] != "NA" else lin["kingdom"]

    for k in wanted:
        print(f"{k:13s}: {lin[k]}")
    print(f"{'domain_group':13s}: {domain_group}")
EOF