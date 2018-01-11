#!/bin/bash

# Usage: reconstruct-human-genome.sh <bam_file>
#
# Sniffs chromosome names and sizes from the bam header, and creates an
# appropriate reference human genome at genome.fa.
#
# Returns, in stdout, the "flavor" of the genome ("hg19" or "b37"),
# based solely on whether there exists a chromosome whose name starts
# with the prefix "chr".


# The following line causes bash to exit at any point if there is any error -- useful for debugging
set -e -o pipefail

if [ "$#" != "1" ]
then
  echo "Usage: $0 input.bam" >/dev/stderr
  exit 1
fi

fingerprint=`samtools view -H "$1" | grep ^@SQ | cut -f1-3 | md5sum | cut -c1-32`
appdata=project-B6JG85Z2J35vb6Z7pQ9Q02j8

if dx ls "$appdata:/misc/genome_fingerprints/b37/$fingerprint.tar.gz" >& /dev/null ; then
  # Known b37-like genome
  dx download "$appdata:/misc/genome_fingerprints/b37/$fingerprint.tar.gz" -o genome.tar.gz
  tar zxf genome.tar.gz
  echo "b37"
  exit 0
elif dx ls "$appdata:/misc/genome_fingerprints/hg19/$fingerprint.tar.gz" >& /dev/null ; then
  # Known hg19-like genome
  dx download "$appdata:/misc/genome_fingerprints/b37/$fingerprint.tar.gz" -o genome.tar.gz
  tar zxf genome.tar.gz
  echo "hg19"
  exit 0
fi

#
# Custom genome; fetch an archive with all known chromosomes
#
mkdir chromosomes
dx download "$appdata:/misc/genome_fingerprints/human_chroms.tar.gz" -o chroms.tar.gz
tar zxf chroms.tar.gz -C chromosomes

# Concatenate chromosomes as they appear in the BAM header to make genome.fa
flavor="b37"
for chr in `samtools view -H "$1" | grep ^@SQ | sed 's/\t/:/g' | cut -f3,5 -d:`
do
  chr_name=`echo "$chr" | cut -f1 -d:`
  chr_size=`echo "$chr" | cut -f2 -d:`
  [ -e chromosomes/"$chr" ] || dx-jobutil-report-error "Unknown reference genome enountered in the BAM file; we do not know of any human chromosome called '$chr_name' with size '$chr_size'"
  echo ">$chr_name" >> genome.fa
  cat "chromosomes/$chr" >>genome.fa
  if [[ "$chr_name" = chr* ]]; then
    flavor="hg19"
  fi
done
echo "$flavor"
