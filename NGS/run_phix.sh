#!/bin/bash -l
#SBATCH -A uppmax2026-1-94
#SBATCH -p pelle
#SBATCH -n 1
#SBATCH -t 00:30:00
#SBATCH -J phix_ngs

echo USER = $USER
echo QOS = $SLURM_JOB_QOS
echo JOB = $SLURM_JOBID
cat $0

module load Bowtie2/2.5.4
module load SAMtools/1.22
module load BCFtools
module list

INDIR=$HOME/A1/ngs/phi
OUTDIR=$HOME/A1/ngs/phi
TMPDIR=$SNIC_TMP/phix_ngs_${SLURM_JOBID}

REFBASE=/sw/data/igenomes/PhiX/Illumina/RTA/Sequence/Bowtie2Index/genome
REFFA=/sw/data/igenomes/PhiX/Illumina/RTA/Sequence/WholeGenomeFasta/genome.fa
REFFAI=/sw/data/igenomes/PhiX/Illumina/RTA/Sequence/WholeGenomeFasta/genome.fa.fai

mkdir -p "$OUTDIR"
mkdir -p "$TMPDIR"
cd "$TMPDIR" || exit 1

cp "$REFFA" .
cp "$REFFAI" .

for f in "$INDIR"/phi_*.fq
do
    [ -e "$f" ] || continue

    fname=$(basename "$f")
    base=${fname%.fq}

    echo "Processing $fname"

    cp "$f" .

    bowtie2 -x "$REFBASE" -U "$fname" -S "${base}.sam"
    samtools sort "${base}.sam" -o "${base}.bam"
    samtools index "${base}.bam"

    bcftools mpileup -f genome.fa "${base}.bam" | bcftools call -mv -Ob -o "${base}.bcf"
    bcftools view "${base}.bcf" -o "${base}.vcf"

    cp "${base}.vcf" "$OUTDIR"/

    rm -f "$fname" "${base}.sam" "${base}.bam" "${base}.bam.bai" "${base}.bcf"
done
