#!/bin/bash

# The following line causes bash to exit at any point if there is any error
# and to output each line as it is executed -- useful for debugging
set -e -x -o pipefail

create_interval_file(){
	# Prepare the genome regions from input bam file header. This appends every header line beginning with '@SQ' to the
	# targets.picard file. These lines contain the regions of the reference genome to which the sample was aligned
	docker run -v /home/dnanexus:/home/dnanexus quay.io/biocontainers/samtools:1.13--h8c37831_0 samtools view \
	  -H "$sorted_bam_path" | grep '^@SQ' > targets.picard

	# Recreate the vendor bedfile format from mokabed files. The final output (targets.picard) contains the BED file of
	# genome targets required as input for the Bait Intervals (-BI) and Target Intervals (-TI) arguments in the Picard
	# commands below. If remove chr is false skip the sed step
	if [ "$remove_chr" == "true" ]; then
		grep -v '^#' "$vendor_exome_bedfile_path"  | sed 's/chr//' | awk -F '\t' '{print $1,$2,$3}' >  tidied.bed
	else
		grep -v '^#' "$vendor_exome_bedfile_path" | awk -F '\t' '{print $1,$2,$3}' >  tidied.bed
	fi
	awk '{print $1 "\t" $2+1 "\t" $3 "\t+\t" $1 ":" $2+1 "-" $3}' < tidied.bed >> targets.picard
	}

collect_targeted_pcr_metrics() {
	# Call Picard CollectMultipleMetrics. Requires the co-ordinate sorted BAM file given to the app as input. The file is
	# referenced in this command with the option 'I=<input_file>'. Here, the downloaded BAM file path is accessed using
	# the DNA Nexus helper variable $sorted_bam_path. All outputs are saved to $output_dir (defined in main()) for upload
	# to DNA Nexus.
	docker run -v /home/dnanexus:/home/dnanexus broadinstitute/picard:2.22.8 java -jar /usr/picard/picard.jar \
	  CollectTargetedPcrMetrics I="$sorted_bam_path" R=/home/dnanexus/genome.fa \
	  O="$output_dir/$sorted_bam_prefix.targetPCRmetrics.txt" AI=/home/dnanexus/targets.picard \
	  TI=/home/dnanexus/targets.picard PER_TARGET_COVERAGE="$output_dir/$sorted_bam_prefix.perTargetCov.txt"
	  }

collect_multiple_metrics() {
	# Call Picard CollectMultipleMetrics. Requires the co-ordinate sorted BAM file given to the appas input. The file is
	# referenced in this command with the option 'I=<input_file>'. Here, the downloaded BAM file path is accessed using
	# the DNA Nexus helper variable $sorted_bam_path. All outputs are saved to $output_dir (defined in main()) for upload
	# to DNA Nexus.
	docker run -v /home/dnanexus:/home/dnanexus broadinstitute/picard:2.22.8 java -jar /usr/picard/picard.jar \
	  CollectMultipleMetrics I="$sorted_bam_path" R=/home/dnanexus/genome.fa PROGRAM=CollectAlignmentSummaryMetrics \
	  PROGRAM=CollectInsertSizeMetrics PROGRAM=QualityScoreDistribution PROGRAM=MeanQualityByCycle \
	  PROGRAM=CollectBaseDistributionByCycle O="$output_dir/$sorted_bam_prefix"
	  }

collect_hs_metrics() {
	# Call Picard CollectHsMetrics. Requires the co-ordinate sorted BAM file given to the app as input (I). Outputs the
	# hsmetrics.tsv and pertarget_coverage.tsv files to $output_dir (defined in main()) for upload to DNA Nexus.
	docker run -v /home/dnanexus:/home/dnanexus broadinstitute/picard:2.22.8 java -jar /usr/picard/picard.jar \
	 CollectHsMetrics BI=/home/dnanexus/targets.picard TI=/home/dnanexus/targets.picard I="$sorted_bam_path" \
	  O="$output_dir/${sorted_bam_prefix}.hsmetrics.tsv" R=/home/dnanexus/genome.fa \
	  PER_TARGET_COVERAGE="$output_dir/${sorted_bam_prefix}.pertarget_coverage.tsv"
	  }

main() {
  ##### SETUP #####

  # Download input files from inputSpec to ~/in/. Allows the use of DNA Nexus bash helper variables.
  dx-download-all-inputs

  # Load picard and samtools images
  docker load < /usr/bin/picard.tar.gz
  docker load < /usr/bin/samtools.tar.gz

  # Unpack the reference genome for Picard. Produces genome.fa, genome.fa.fai, and genome.dict files.
  tar zxvf "$fasta_index_path"

  # Create directory for Picard stats files to be uploaded from the worker
  output_dir=$HOME/out/moka_picard_stats/QC
  mkdir -p "$output_dir"

  ##### MAIN #####

  # Create the interval file
  create_interval_file

  # if it's a capture panel call the relevant modules
  if [[ "$Capture_panel" == "Hybridisation" ]]; then
  # Call Picard CollectMultipleMetrics
  collect_multiple_metrics
  # Call Picard CollectHSMetrics
  collect_hs_metrics

  # if it's a amplicon panel call the relevant modules
  elif [[ "$Capture_panel" == "Amplicon" ]]; then
  collect_targeted_pcr_metrics
  else
  echo "unknown capture type"
  fi

  ##### CLEAN UP #####

  # Upload all results files and directories in $HOME/out/moka_picard_stats/
  dx-upload-all-outputs --parallel
  }
