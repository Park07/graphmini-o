#!/bin/bash
# Wrapper to test with prof_runner instead of run

dataset="$1"
dataset_dir="$2" 
pattern_name="$3"
pattern_binary="$4"

mkdir -p ../results/temp
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-4}

# prof_runner expects: [exp_id] [dataset_dir] [aggr_path] [loop_path]
./bin/prof_runner 1 "$dataset_dir" "../results/temp/aggr" "../results/temp/loop"
