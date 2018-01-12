# Moka Picard v1.0

## What does this app do?
This app runs modules from the Picard Tools suite to generate quality-control (QC) statistics from mapped/aligned reads. Specifically, this app:
* Calculates multiple summary statistic metrics for mapped reads (paired or unpaired) using Picard [CollectMultipleMetrics](https://broadinstitute.github.io/picard/command-line-overview.html#CollectMultipleMetrics).
* Calculates mappings metrics to determine the performance of the capture kit by assessing the coverage across all targets in the kit, using Picard [CalculateHsMetrics](https://broadinstitute.github.io/picard/command-line-overview.html#CollectHsMetrics).

For more information on the Picard Tools suite see: http://broadinstitute.github.io/picard/

## What are typical use cases for this app?
This app is designed to be run on aligned sequencing data, either as a standalone app or as part of a DNA Nexus workflow. For an example workflow, search for 'MokaWES' in DNA Nexus. 

Note: *This app combines the moka_vendor and picard_collect_multiple_metrics DNA Nexus apps*

The QC metrics calculated by Picard tools and output by this app are informative of the quality of the sequence alignments produced by read mapping software such as BWA and Bowtie2.

The outputs of this app are to be displayed visually using [MultiQC](http://multiqc.info/), and assessed for inconsistencies accross the alignment summary. This summary contains the per-cycle base distribution, target enrichment and read duplication statistics.

## What data are required for this app to run?
The following files are required for this app to run:

**sorted_bam**:
A coordinate-sorted mapping file in BAM format (`*.bam`). BAM files generated by commonly used mappers such as BWA, BWA-MEM, Bowtie, TopHat, HISAT and NovoAlign are acceptable as input. 

**fasta_index**:
A reference genome sequence index generated by "FASTA indexer (with Picard and Samtools)". This should be provided as a gzipped tar archive file (`*.fasta-index.tar.gz`).

**vendor_exome_bedfile**:
A BED file defining the regions designed to be captured. BED files can be found in 001_ToolsReferenceData:Data/BED. BED files for custom panels are created using the MokaBED app, using a list of gene symbols or accessions. BED files for WES samples can be found in the public project 'Apps Data'.

## What does this app output?
All Picard statistics files produced by this app are uploaded to a 'QC/' directory in the DNA Nexus project or working directory from which the app was called.

Picard CollectMultipleMetrics output files:
* `*.base_distribution_by_cycle*` - the base distribution per cycle
* `*.alignment_summary*` - a summary of the alignment
* `*.quality_by_cycle*` - the base quality per cycle
* `*.insert_size*` - metrics for validating library construction including the insert size distribution and read orientation of paired-end libraries
* `*.quality_distribution*` - the range of quality scores and the total numbers of bases corresponding to those scores

Picard CalculateHsMetrics output files:
* `*.hsmetrics.tsv` - general statistics about the enrichment process. 
* `*.pertarget_coverage.tsv` - the GC content and average coverage of each target in the kit.

Detailed information about the metrics reported by all Picard suites can be found at the following page:
https://broadinstitute.github.io/picard/picard-metric-definitions.html

## How does this app work?
This app downloads the given input files, then calls Picard CollectMultipleMetrics and Picard CalculateHsMetrics using the sorted BAM file as input. Finally, all output files produced by both Picard modules are uploaded to a 'QC/' directory.
