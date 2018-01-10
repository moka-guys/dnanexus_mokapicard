#!/bin/bash

# The following line causes bash to exit at any point if there is any error
# and to output each line as it is executed -- useful for debugging
set -e -x -o pipefail

collect_multiple_metrics() {
	# Call Picard CollectMultipleMetrics
	$java -jar /picard.jar CollectMultipleMetrics I="$sorted_bam_path" R=genome.fa \
	    PROGRAM=CollectAlignmentSummaryMetrics PROGRAM=CollectInsertSizeMetrics \
	    PROGRAM=QualityScoreDistribution PROGRAM=MeanQualityByCycle \
	    PROGRAM=CollectBaseDistributionByCycle O="out/moka_picard_stats/QC/$sorted_bam_prefix"
}

calculate_hs_metrics() {
	# Give genome reconstruction script permissions to run
	chmod +x /usr/bin/reconstruct-human-genome.sh 

	# Set prefix for file containing geneome target regions using names of input files
	targets=${vendor_exome_bedfile_prefix}_${fasta_index_prefix}_targets
	# Prepare genome regions from input bam file
	samtools view -H "$sorted_bam_path" | grep '^@SQ' > $targets.picard

	# Recreate the vendor bedfile format from mokabed files
	cat $vendor_exome_bedfile_path | grep -v '^#' | sed 's/chr//' | awk -F '\t' '{print $1,$2,$3}' >  tidied.bed
	awk '{print $1 "\t" $2+1 "\t" $3 "\t+\t" $1 ":" $2+1 "-" $3}' < tidied.bed >> $targets.picard

	# Run Picard CalculateHsMetrics
	$java -jar /picard.jar CalculateHsMetrics BI=$targets.picard TI=$targets.picard \
	   I="$sorted_bam_path" O=hsmetrics.tsv R=genome.fa PER_TARGET_COVERAGE=pertarget_coverage.tsv
}

main() {

##### SETUP #####

# Download input files from inputSpec to ~/in/. Allows the use of DNA Nexus bash helper variables.
dx download-all-inputs

# Calculate 90% of memory size for java
mem_in_mb=`head -n1 /proc/meminfo | awk '{print int($2*0.9/1024)}'`
# Set java command with the calculated maximum memory usage
java="java -Xmx${mem_in_mb}m"

# Unpack the reference genome for Picard. Produces genome.fa, genome.fa.fai, and genome.dict files.
tar zxvf $fasta_index_path

# Create directory for Picard stats files to be uploaded from the worker
output_dir="~/out/moka_picard_stats/QC/"
mkdir -p $output_dir

##### MAIN #####

# Call Picard Tools modules
collect_multiple_metrics
calculate_hs_metrics

##### CLEAN UP #####

# Move results files to output directory
	mv hsmetrics.tsv $output_dir/"${sorted_bam_prefix}.hsmetrics.tsv"
	mv pertarget_coverage.tsv $output_dir/"$sorted_bam_prefix.pertarget_coverage.tsv"

# Upload results
dx-upload-all-outputs --parallel
}
