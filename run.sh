#!/bin/bash

#BSUB -n 4
#BSUB -R rusage[mem=2048] # ask for memory
#BSUB -W 1:00
#BSUB -q short # which queue we want to run in
##BSUB -R "select[chassisno>0] same[chassisno]" # All hosts on the same chassis
#BSUB -o /home/yf60w/logs/%J.%I.out
#BSUB -e /home/yf60w/logs/%J.%I.err

while getopts "l:r:c:o:dp:" OPTION
do
    case $OPTION in
	l)
	    left_full_path=$(readlink -f $OPTARG);;
	r)
	    right_full_path=$(readlink -f $OPTARG);;
	c)
	    cpu=$OPTARG;;
	o)
	    output_common=$OPTARG;;
	d)
	    # If $dry_run==1, then run.sh will only output instead of executing
	    # anything
	    dry_run=1;;
	p)
	    # In case the user would like to give a name for all the output files
	    common_prefix=$OPTARG;;
    esac
done

if [[ -z "$cpu" ]]; then
    cpu=8
fi

Run () {
    if [[ "$dry_run" == 1 ]]; then
	echo "************************************************************************"
	echo "Dry-run:"
        echo "$*"
	echo "************************************************************************"
        return 0
    fi
    eval "$@"
}

# TODO: Think of a better way of naming
# e.g. "abc.r1.fq" and "def.r2.fq" would result in "abc.r1.def.r2.fq"

left_basename=$(basename $left_full_path)
left_filename=${left_basename%.*}
# echo $left_filename

right_basename=$(basename $right_full_path)
right_filename=${right_basename%.*}
# echo $right_filename

# If no output dir (-o) is given, the dafault is using $PWD/left.right, 
# since the user may not have write permissions on the dir containing the data.
# Output_common is the parent dir for all results
if [[ -z "$output_common" ]]; then
    output_common=$PWD/"$left_filename"_"$right_filename"
fi

echo "output_common is $output_common"

# PWD is where all outputs lie
Run mkdir -p "$output_common"
cd $output_common

phred=$(phred_guesser.py < "$left_full_path")
phred="phred33\n"
if [[ $phred =~ "phred33" ]]; then
    phred_option='--phred33'
else
    phred_option='--phred64'
fi

# rRNAx = rRNA excluded
output_dir_rrnax=$output_common/rRNAx

if [[ -z "$common_prefix" ]]; then
    # $output_prefix is the common part of all output file names
    $common_prefix="$left_filename"."$right_filename"
fi

Run mkdir -p rRNAx
command_rrnax="bowtie2 -x ~/storage/PE_Pipeline/common_files/dm3/rRNA -1 $left_full_path -2 $right_full_path -q $phred_option --very-fast -k 1 --no-mixed --no-discordant --un-conc rRNAx/${common_prefix}.rRNAx.fq -S /dev/null -p $cpu"
echo "I will run the following: $command_rrnax"
Run $command_rrnax

# Mapping to the genome using STAR
# STAR reference
# Determine the length of the reads
read_lenth=$(head -n2 $left_full_path | awk 'NR==2 {print length($0)} ')
echo "Read length is ${read_length}"
# Generate STAR reference
Run mkdir star_genome
Run mkdir genome_mapping
# "From the manual: --sjdbOverhang <N>: the length of the overhang on each side of a splice junctions. Ideally it should be equal to (MateLength - 1)."

# STAR has the nasty behavior of generating a Log.out. To make things less messy,
# and cd to the star_genome dir and later cd back
cwd=$(pwd)
cd star_genome
# Uncommment the following line when in production
# Run STAR --runMode genomeGenerate --genomeDir . --genomeFastaFiles ~/storage/genomes/dm3/STARgenomeIndex/genome.fa --sjdbOverhang $((read_length-1)) --runThreadN $cpu
cd $cwd
# Run STAR
# TODO: Tweak outFilterScoreMinOverLread, outFilterMatchNminOverLread. Bo uses 0.72
# TODO: Tweak outFilterMultimapNmax. Bo uses -1
# TODO: Tweak outFilterMismatchNoverLmax. Bo uses 0.05
# TODO: Understand outFilterIntronMotifs: RemoveNoncanonicalUnannotated
# alignIntronMax: maximum intron size, if 0, max intron size will be determined by (2^winBinNbits)*winAnchorDistNbins
# TODO: Do I need to set outReadsUnmapped to None?
# TODO: outSAMunmapped: Within or None
# TODO: chimSegmentMin 20, 0, or other values?

Run STAR --genomeDir star_genome --readFilesIn rRNAx/${common_prefix}.rRNAx.1.fq rRNAx/${common_prefix}.rRNAx.2.fq --runThreadN $cpu \
    --outFilterScoreMin 0 --outFilterScoreMinOverLread 0.66 \
    --outFilterMatchNmin 0 --outFilterMatchNminOverLread 0.66 \
    --outFilterMultimapScoreRange 1 --outFilterMultimapNmax 10 \
    --outFilterMismatchNmax 10 --outFilterMismatchNoverLmax 0.3 \
    --outFilterIntronMotifs RemoveNoncanonicalUnannotated \
    --alignIntronMax 0 --alignIntronMin 21 \
    --genomeLoad NoSharedMemory \
    --outFileNamePrefix genome_mapping/$common_prefix.rRNAx. \
    --outSAMunmapped Within --outReadsUnmapped Fastx --outSJfilterReads Unique \
    --seedSearchStartLmax 20 --seedSearchStartLmaxOverLread 1.0 \
    --chimSegmentMin 20 --chimScoreMin 1

