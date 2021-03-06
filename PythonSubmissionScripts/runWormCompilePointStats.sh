#!/bin/sh
#
# File:   RunWormCompilePointStats.sh
# Author: jnguyen
#
#compiles pointStats results that come out of the straightening part of the algorithm 

# Created on May 26, 2015, 11:56:37 AM
# tell the scheduler which version of matlab to use, put it before $PATH so that it takes precedence
export PATH=/usr/local/matlab-R2013a/bin/:$PATH
# This path is for Della
export PATH=/tigress/LICENSED/matlab-R2017a/bin/:$PATH

# parse matlab paths
FILES=$CODE_HOME/3dbrain/PythonSubmissionScripts/*.path
#echo $FILES
for input in $FILES
do
  #echo "Processing $input file..."  
  while read file
  do
      export MATLABPATH="$MATLABPATH:$CODE_HOME/$file"
  done  < "$input"
done

export MATLABPATH="$MATLABPATH;"

# make sure that the matlab path is full/correct
echo $MATLABPATH
echo $1
# run the job
matlab -nosplash -nodesktop -nodisplay -singleCompThread -r "combinePointStatsFiles('$1');exit;"
