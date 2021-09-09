#!/bin/bash

# The following line causes bash to exit at any point if there is any error
# and to output each line as it is executed -- useful for debugging
set -e -x -o pipefail

create_interval_file(){
	# Prepare the genome regions from input bam file header. This appends every header line beginning with '@SQ' to the
	# targets.picard file. These lines contain the regions of the reference genome to which the sample was aligned
	docker run -v /home/dnanexus:/home/dnanexus "${samtools_imageid}" samtools view -H "$sorted_bam_path" | \
	grep '^@SQ' > targets.picard

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
	# referenced in this command with the option '-I <input_file>'. Here, the downloaded BAM file path is accessed using
	# the DNA Nexus helper variable $sorted_bam_path. All outputs are saved to $output_dir (defined in main()) for upload
	# to DNA Nexus.
	docker run -v /home/dnanexus:/home/dnanexus "${gatk_imageid}" ./gatk \
	    CollectTargetedPcrMetrics -I "$sorted_bam_path" -R /home/dnanexus/genome.fa \
	    -O "$output_dir/$sorted_bam_prefix.targetPCRmetrics.txt" -AI /home/dnanexus/targets.picard -TI \
	    /home/dnanexus/targets.picard --PER_TARGET_COVERAGE "$output_dir/$sorted_bam_prefix.perTargetCov.txt"
	    }

collect_multiple_metrics() {
	# Call Picard CollectMultipleMetrics. Requires the co-ordinate sorted BAM file given to the appas input. The file is
	# referenced in this command with the option '-I <input_file>'. Here, the downloaded BAM file path is accessed using
	# the DNA Nexus helper variable $sorted_bam_path. All outputs are saved to $output_dir (defined in main()) for upload
	# to DNA Nexus.
	docker run -v /home/dnanexus:/home/dnanexus "${gatk_imageid}" ./gatk \
		  CollectMultipleMetrics -I "$sorted_bam_path" -R /home/dnanexus/genome.fa \
	    --PROGRAM CollectAlignmentSummaryMetrics --PROGRAM CollectInsertSizeMetrics \
	    --PROGRAM QualityScoreDistribution --PROGRAM MeanQualityByCycle \
	    --PROGRAM CollectBaseDistributionByCycle -O "$output_dir/$sorted_bam_prefix"
	    }

collect_hs_metrics() {
	# Call Picard CollectHsMetrics. Requires the co-ordinate sorted BAM file given to the app as input (-I). Outputs the
	# hsmetrics.tsv and pertarget_coverage.tsv files to $output_dir (defined in main()) for upload to DNA Nexus.
		docker run -v /home/dnanexus:/home/dnanexus "${gatk_imageid}" ./gatk \
	    CollectHsMetrics -BI /home/dnanexus/targets.picard -TI /home/dnanexus/targets.picard -I "$sorted_bam_path" \
	    -O "$output_dir/${sorted_bam_prefix}.hsmetrics.tsv" -R /home/dnanexus/genome.fa \
	    --PER_TARGET_COVERAGE "$output_dir/${sorted_bam_prefix}.pertarget_coverage.tsv"
	    }

main() {
  ##### SETUP #####

  # Download input files from inputSpec to ~/in/. Allows the use of DNA Nexus bash helper variables.
  dx-download-all-inputs

  # Pull GATK and samtools image by digest
  docker image pull broadinstitute/gatk@sha256:8051adab0ff725e7e9c2af5997680346f3c3799b2df3785dd51d4abdd3da747b
  docker image pull quay.io/biocontainers/samtools:1.13--h8c37831_0@sha256:04da5297386dfae2458a93613a8c60216d158ee7cb9f96188dad71c1952f7f72

  # Save image IDs as variables
  samtools_imageid=$(sudo docker image ls quay.io/biocontainers/samtools | awk 'FNR == 2 {print $3}')
  gatk_imageid=$(sudo docker image ls broadinstitute/gatk | awk 'FNR == 2 {print $3}')

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
