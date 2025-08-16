#!/usr/bin/env python3
import pandas as pd
import numpy as np
import glob
import os

def analyze_comprehensive_results(results_dir):
    """
    Reads all dataset-specific CSVs from a results directory,
    merges them, and produces a comprehensive, publication-quality summary.
    """
    print(f"📈 Analyzing all results in: {results_dir}...")

    # --- 1. Load and Merge All Data ---
    all_csv_files = glob.glob(f"{results_dir}/*/*.csv")
    if not all_csv_files:
        print(f"❌ ERROR: No CSV files found in any subdirectories of {results_dir}")
        return

    df = pd.concat((pd.read_csv(f) for f in all_csv_files), ignore_index=True)
    print(f"   Found {len(df)} total test records across {len(all_csv_files)} files.")

    # --- 2. Data Cleaning and Metric Calculation ---
    df['ExecutionTime_s'] = pd.to_numeric(df['ExecutionTime_s'], errors='coerce')
    df['Memory_MB'] = pd.to_numeric(df['Memory_MB'], errors='coerce')

    # Separate successful runs from failures for different analyses
    df_success = df[df['Status'] == 'SUCCESS'].copy()

    # Calculate Speedup and Efficiency for successful runs
    baselines = df_success[df_success['Threads'] == 1].groupby(['Dataset', 'QueryFile'])['ExecutionTime_s'].mean().rename('BaselineTime_s')
    df_success = pd.merge(df_success, baselines, on=['Dataset', 'QueryFile'], how='left')
    df_success['Speedup'] = df_success['BaselineTime_s'] / df_success['ExecutionTime_s']
    df_success['Efficiency'] = (df_success['Speedup'] / df_success['Threads']) * 100

    # --- 3. Generate and Print the Final Summary Report ---
    print("\n" + "="*85)
    print("✅ Comprehensive Performance Analysis Report")
    print("="*85)

    # Group by both Dataset and Pattern Category for a detailed breakdown
    for (dataset, category), group in df.groupby(['Dataset', 'PatternCategory']):

        num_queries = group['QueryFile'].nunique()
        total_runs = len(group)

        # --- Completion Rate ---
        successful_runs = len(group[group['Status'] == 'SUCCESS'])
        completion_rate = (successful_runs / total_runs) * 100 if total_runs > 0 else 0

        print(f"\n--- Dataset: {dataset} | Category: {category} ---")
        print(f"  Queries Tested: {num_queries}")
        print(f"  Completion Rate: {completion_rate:.1f}% ({successful_runs} / {total_runs} successful runs)")

        # --- Performance Metrics (only for successful runs) ---
        category_success_df = df_success[(df_success['Dataset'] == dataset) & (df_success['PatternCategory'] == category)]
        if not category_success_df.empty:

            # --- Execution Time & Memory Usage ---
            perf_summary = category_success_df.groupby('Threads').agg(
                AvgTime_s=('ExecutionTime_s', 'mean'),
                StdTime_s=('ExecutionTime_s', 'std'),
                AvgMem_MB=('Memory_MB', 'mean')
            ).fillna(0)

            # --- Scalability ---
            scalability_summary = category_success_df.groupby('Threads').agg(
                AvgSpeedup=('Speedup', 'mean'),
                StdSpeedup=('Speedup', 'std')
            ).fillna(0)

            print("\n  Performance Summary (Mean ± Std Dev):")
            print("  ---------------------------------------")
            for threads, row in perf_summary.iterrows():
                print(f"    {threads}-Threads: {row['AvgTime_s']:.3f} ± {row['StdTime_s']:.3f} s  |  Avg. Memory: {row['AvgMem_MB']:.1f} MB")

            print("\n  Scalability Summary (Mean ± Std Dev):")
            print("  -------------------------------------")
            for threads, row in scalability_summary.iterrows():
                if threads > 1:
                    print(f"    {threads}-Threads: {row['AvgSpeedup']:.2f}x ± {row['StdSpeedup']:.2f}x Speedup")

    print("\n" + "="*85)


if __name__ == "__main__":
    # Get the parent directory of the script's location
    current_dir = os.path.dirname(os.path.realpath(__file__))
    analyze_comprehensive_results(current_dir)