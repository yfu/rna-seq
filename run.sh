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
	    output_dir=$OPTARG;;
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
        echo "$*"
        return 0
    fi
    eval "$@"
}

# Find the longest common prefix of two filenames
# prefix=$(echo -e "$left\n$right" | sed -e 'N;s/^\(.*\).*\n\1.*$/\1/')
# prefix=${prefix%.*}
# if [ -z "$prefix" ]; then 
#    echo "I cannot find a common "   
#    then prefix=${left%.f[aq]}
# fi

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
if [[ -z "$output_dir" ]]; then
    output_dir=$PWD/"$left_filename"_"$right_filename"
fi

Run mkdir -p "$output_dir"

phred=$(phred_guesser.py < "$left_full_path")
phred="phred33\n"
if [[ $phred =~ "phred33" ]]; then
    phred_option='--phred33'
else
    phred_option='--phred64'
fi

# rRNAx = rRNA excluded
output_dir1=$output_dir/rRNAx

if [[ -z "$common_prefix" ]]; then do
    output_rrnax=$output_dir1/"$left_filename"."$right_filename".rRNAx.fq
else
    output_rrnax=$output_dir1/"$common_prefix".rRNAx.fq
done;


Run mkdir -p "$output_dir1"
command1="bowtie2 -x ~/storage/PE_Pipeline/common_files/dm3/rRNA -1 $left_full_path -2 $right_full_path -q $phred_option --very-fast -k 1 --no-mixed --no-discordant --un-conc $output_rrnax -S /dev/null -p $cpu"
echo "I will run the following command $command1"

Run "$command1"

# Mapping to the genome using STAR

