#!/usr/bin/env bash
set -euo pipefail

SAMPLE="${1}"
R1="${2}"
R2="${3}"

THREADS="${THREADS:-16}"
MAPQ="${MAPQ:-30}"

SOURMASH_BASE="/scratch/dgohar/Prabh/sourmash_results"
REF="/scratch/dgohar/Prabh/NCBI_hits_prabh_P1/reference/per_sample/${SAMPLE}/${SAMPLE}_combined_reference.fna"
TAXDIR="/scratch/dgohar/Prabh/NCBI_hits_prabh_P1"

OUT_DIR="/scratch/dgohar/Prabh/GenomeMatchinfo"
TMP_DIR="/scratch/dgohar/tmp_${SAMPLE}"

mkdir -p "$OUT_DIR" "$TMP_DIR"

echo "Processing $SAMPLE"
echo "Output: $OUT_DIR/${SAMPLE}.tsv"

[[ -f "$R1" ]] || { echo "ERROR: R1 not found: $R1"; exit 1; }
[[ -f "$R2" ]] || { echo "ERROR: R2 not found: $R2"; exit 1; }
[[ -f "$REF" ]] || { echo "ERROR: Reference not found: $REF"; exit 1; }
[[ -f "$TAXDIR/nodes.dmp" ]] || { echo "ERROR: nodes.dmp not found"; exit 1; }
[[ -f "$TAXDIR/names.dmp" ]] || { echo "ERROR: names.dmp not found"; exit 1; }
[[ -f "$TAXDIR/assembly_summary_refseq.txt" ]] || { echo "ERROR: assembly_summary_refseq.txt not found"; exit 1; }
[[ -f "$TAXDIR/assembly_summary_genbank.txt" ]] || { echo "ERROR: assembly_summary_genbank.txt not found"; exit 1; }

# =========================
# 1. Extract sourmash abundances
# =========================
python3 <<EOF
import csv, re
from pathlib import Path

sample = "${SAMPLE}"
base = Path("${SOURMASH_BASE}") / sample
out_file = Path("${TMP_DIR}") / "sourmash.tsv"

acc_re = re.compile(r"(GC[AF]_\\d+\\.\\d+)")
rows = {}

for f in [f"{sample}_bacteria.csv", f"{sample}_fungi.csv"]:
    fp = base / f
    if not fp.exists():
        continue

    with open(fp, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            name = row.get("name", "")
            m = acc_re.search(name)
            if not m:
                continue

            g = m.group(1)
            val = row.get("f_unique_weighted") or row.get("f_unique_to_query") or 0

            try:
                val = float(val)
            except Exception:
                val = 0.0

            if g not in rows or val > rows[g]:
                rows[g] = val

with open(out_file, "w") as out:
    out.write("genome_id\\tsourmash_abun\\n")
    for g in sorted(rows):
        out.write(f"{g}\\t{rows[g]:.9f}\\n")
EOF

# =========================
# 2. Total input reads
# =========================
seqkit stats -T "$R1" | awk 'NR==2 {print $4}' > "$TMP_DIR/total_reads.txt"

# =========================
# 3. Mapping with BWA-MEM
# =========================
bwa mem -t "$THREADS" "$REF" "$R1" "$R2" | \
samtools sort -@ "$THREADS" -o "$TMP_DIR/${SAMPLE}.bam"

samtools index "$TMP_DIR/${SAMPLE}.bam"

# =========================
# 4. Strict filtered BAM
# Exclude:
# 4 unmapped
# 256 secondary
# 512 QC-fail
# 1024 duplicate
# 2048 supplementary
# total = 3852
# =========================
samtools view -@ "$THREADS" -b -F 3852 -q "$MAPQ" "$TMP_DIR/${SAMPLE}.bam" > "$TMP_DIR/${SAMPLE}.filt.bam"
samtools index "$TMP_DIR/${SAMPLE}.filt.bam"

# =========================
# 5. Stats
# Raw idxstats from raw BAM
# Coverage/depth from filtered BAM
# =========================
samtools idxstats "$TMP_DIR/${SAMPLE}.bam" > "$TMP_DIR/idx.tsv"
samtools idxstats "$TMP_DIR/${SAMPLE}.filt.bam" > "$TMP_DIR/idx_filt.tsv"
samtools depth -aa "$TMP_DIR/${SAMPLE}.filt.bam" > "$TMP_DIR/depth.tsv"
samtools view -c -F 260 "$TMP_DIR/${SAMPLE}.filt.bam" > "$TMP_DIR/total_mapped_reads.txt"

# =========================
# 6. Build final table
# =========================
python3 <<EOF
from collections import defaultdict
from pathlib import Path
import pysam

tmp = Path("${TMP_DIR}")
out_file = Path("${OUT_DIR}") / "${SAMPLE}.tsv"
taxdir = Path("${TAXDIR}")

# -------------------------
# taxonomy load
# -------------------------
parent = {}
rank = {}
name = {}

with open(taxdir / "nodes.dmp") as f:
    for line in f:
        parts = [x.strip() for x in line.split("|")]
        if len(parts) >= 3:
            parent[parts[0]] = parts[1]
            rank[parts[0]] = parts[2]

with open(taxdir / "names.dmp") as f:
    for line in f:
        parts = [x.strip() for x in line.split("|")]
        if len(parts) > 3 and parts[3] == "scientific name":
            name[parts[0]] = parts[1]

acc2tax = {}
acc_source = {}
acc2strain = {}

for fname, source in [
    ("assembly_summary_refseq.txt", "RefSeq"),
    ("assembly_summary_genbank.txt", "GenBank"),
]:
    fp = taxdir / fname
    with open(fp) as f:
        for line in f:
            if line.startswith("#"):
                continue
            parts = line.rstrip("\\n").split("\\t")
            if len(parts) > 8:
                acc = parts[0]
                taxid = parts[5]
                organism_name = parts[7]
                infraspecific_name = parts[8]

                acc2tax[acc] = taxid
                acc_source[acc] = source
                acc2strain[acc] = infraspecific_name if infraspecific_name != "na" else organism_name

wanted = ["superkingdom", "kingdom", "phylum", "class", "order", "family", "genus", "species"]

def get_lineage(taxid):
    out = {k: "NA" for k in wanted}
    seen = set()
    cur = str(taxid)

    while cur in parent and cur not in seen:
        seen.add(cur)
        r = rank.get(cur, "")
        if r in out and out[r] == "NA":
            out[r] = name.get(cur, "NA")
        if cur == parent[cur]:
            break
        cur = parent[cur]

    return out

def get_full_lineage(taxid):
    lineage = []
    seen = set()
    cur = str(taxid)

    while cur in parent and cur not in seen:
        seen.add(cur)
        nm = name.get(cur, "NA")
        rk = rank.get(cur, "no rank")

        if nm != "NA":
            lineage.append(f"{nm} [{rk}]")

        if cur == parent[cur]:
            break
        cur = parent[cur]

    lineage.reverse()
    return "; ".join(lineage) if lineage else "NA"

# -------------------------
# sourmash
# -------------------------
sour = {}
with open(tmp / "sourmash.tsv") as f:
    next(f)
    for line in f:
        g, a = line.rstrip("\\n").split("\\t")
        sour[g] = float(a)

# -------------------------
# mapping stats
# -------------------------
mr = defaultdict(int)
gl = defaultdict(int)

with open(tmp / "idx.tsv") as f:
    for line in f:
        ref, length, mapped, _ = line.rstrip("\\n").split("\\t")
        if ref == "*":
            continue
        g = ref.split("|")[0]
        mr[g] += int(mapped)
        gl[g] += int(length)

filt = defaultdict(int)
with open(tmp / "idx_filt.tsv") as f:
    for line in f:
        ref, length, mapped, _ = line.rstrip("\\n").split("\\t")
        if ref == "*":
            continue
        g = ref.split("|")[0]
        filt[g] += int(mapped)

# -------------------------
# depth stats from filtered BAM
# -------------------------
sumd = defaultdict(int)
cov = defaultdict(int)
gt1 = defaultdict(int)
gt1sum = defaultdict(int)
gt1n = defaultdict(int)

with open(tmp / "depth.tsv") as f:
    for line in f:
        ref, _, d = line.rstrip("\\n").split("\\t")
        g = ref.split("|")[0]
        d = int(d)
        sumd[g] += d
        if d > 0:
            cov[g] += 1
        if d > 1:
            gt1[g] += 1
            gt1sum[g] += d
            gt1n[g] += 1

# -------------------------
# identity from filtered BAM only
# -------------------------
nm = defaultdict(int)
al = defaultdict(int)

bam = pysam.AlignmentFile(tmp / "${SAMPLE}.filt.bam", "rb")
for r in bam.fetch(until_eof=True):
    if r.is_unmapped or r.reference_name is None:
        continue
    g = r.reference_name.split("|")[0]
    l = r.query_alignment_length or 0
    if l == 0:
        continue
    try:
        n = r.get_tag("NM")
    except KeyError:
        n = 0
    nm[g] += n
    al[g] += l
bam.close()

# -------------------------
# totals
# -------------------------
with open(tmp / "total_reads.txt") as f:
    total_reads = int(f.read().strip())

with open(tmp / "total_mapped_reads.txt") as f:
    total_mapped = int(f.read().strip())

# stricter output set:
# keep sourmash hits and genomes with actual filtered mapped reads
allg = sorted(set(sour) | {g for g, v in filt.items() if v > 0})

ln_sum = 0.0
for g in allg:
    glen = gl.get(g, 0)
    if glen > 0:
        ln_sum += filt[g] / glen

# -------------------------
# write output
# -------------------------
with open(out_file, "w") as out:
    out.write(
        "genome_id\\ttaxid\\ttax_source\\tsuperkingdom\\tkingdom\\tdomain_group\\tphylum\\tclass\\torder\\tfamily\\tgenus\\tspecies\\tstrain\\tfull_lineage\\t"
        "sourmash_abun\\tmapping_reads\\tfiltered_mapped_reads\\tseq_identity(%)\\t"
        "genome_coverage(%)\\tgenome_ave_depth\\tread_depth(>1x)\\t"
        "total_mapped_reads\\tbp_distribution_ratio\\t"
        "rel_abun_total\\trel_abun_mapped\\tlen_norm_abun\\n"
    )

    for g in allg:
        taxid = acc2tax.get(g, "NA")
        source = acc_source.get(g, "NA")
        strain = acc2strain.get(g, "NA")
        lin = get_lineage(taxid) if taxid != "NA" else {k: "NA" for k in wanted}
        full_lineage = get_full_lineage(taxid) if taxid != "NA" else "NA"

        glen = gl.get(g, 0)

        seqid = 100 * (1 - (nm[g] / al[g])) if al[g] > 0 else 0
        covp = 100 * (cov[g] / glen) if glen > 0 else 0
        aved = sumd[g] / glen if glen > 0 else 0
        rd1 = gt1sum[g] / gt1n[g] if gt1n[g] > 0 else 0
        ratio = gt1[g] / cov[g] if cov[g] > 0 else 0

        superkingdom = lin["superkingdom"]
        kingdom = lin["kingdom"]

        if kingdom == "Fungi" or "Fungi [kingdom]" in full_lineage:
            domain_group = "Fungi"
        elif superkingdom == "Bacteria":
            domain_group = "Bacteria"
        elif superkingdom == "Archaea":
            domain_group = "Archaea"
        elif superkingdom == "Eukaryota":
            domain_group = "Eukaryota"
        else:
            domain_group = "NA"

        rel_total = filt[g] / total_reads if total_reads > 0 else 0
        rel_mapped = filt[g] / total_mapped if total_mapped > 0 else 0
        len_norm = ((filt[g] / glen) / ln_sum) if glen > 0 and ln_sum > 0 else 0

        out.write(
            f"{g}\\t{taxid}\\t{source}\\t{lin['superkingdom']}\\t{lin['kingdom']}\\t{domain_group}\\t"
            f"{lin['phylum']}\\t{lin['class']}\\t{lin['order']}\\t{lin['family']}\\t{lin['genus']}\\t{lin['species']}\\t{strain}\\t{full_lineage}\\t"
            f"{sour.get(g, 0):.9f}\\t{mr[g]}\\t{filt[g]}\\t"
            f"{seqid:.4f}\\t{covp:.2f}\\t{aved:.4f}\\t{rd1:.4f}\\t"
            f"{filt[g]}\\t{ratio:.4f}\\t"
            f"{rel_total:.9f}\\t{rel_mapped:.9f}\\t{len_norm:.9f}\\n"
        )

print("Saved:", out_file)
EOF

echo "Done: $SAMPLE"