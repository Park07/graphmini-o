#!/usr/bin/env python3
import pandas as pd
import numpy as np
import glob
import os

def analyze_comprehensive_results(results_dir):
    """
    Reads all CSVs, merges them, and produces a comprehensive,
    publication-quality summary with separate tables for performance and efficiency.
    """
    print(f"📈 Analyzing all results in: {results_dir}...")

    all_csv_files = glob.glob(f"{results_dir}/**/*.csv", recursive=True)
    if not all_csv_files:
        all_csv_files = glob.glob(f"{results_dir}/*.csv")
        if not all_csv_files:
            print(f"❌ ERROR: No CSV files found in {results_dir} or its subdirectories.")
            return

    df = pd.concat((pd.read_csv(f) for f in all_csv_files), ignore_index=True)
    print(f"   Found {len(df)} total test records across {len(all_csv_files)} files.")

    # --- 1. Data Cleaning and Metric Calculation ---
    df['ExecutionTime_s'] = pd.to_numeric(df['ExecutionTime_s'], errors='coerce')
    df_success = df.dropna(subset=['ExecutionTime_s']).copy()

    if df_success.empty:
        print("⚠️ WARNING: No successful runs found. Cannot generate summary.")
        return

    # Create a clean 'PatternCategory' column if it doesn't exist
    if 'PatternCategory' not in df_success.columns and 'Pattern_Name' in df_success.columns:
         df_success['PatternCategory'] = df_success['Pattern_Name'].str.extract(r'(.*)_\d+$')

    # Calculate baselines (mean and std of 1-thread runs)
    baselines = df_success[df_success['Threads'] == 1].groupby(['Dataset', 'Pattern_Name'])['ExecutionTime_s'].agg(['mean', 'std']).rename(columns={'mean': 'BaselineTime_s', 'std': 'BaselineStd_s'})
    df_success = pd.merge(df_success, baselines, on=['Dataset', 'Pattern_Name'], how='left')

    df_success['Speedup'] = df_success['BaselineTime_s'] / df_success['ExecutionTime_s']
    df_success['Efficiency'] = (df_success['Speedup'] / df_success['Threads']) * 100

    # --- 2. Create the Main Performance Table (Time + Speedup) ---
    baseline_summary = df_success[df_success['Threads'] == 1].groupby('PatternCategory')['ExecutionTime_s'].agg(['mean', 'std']).fillna(0)
    baseline_summary['Baseline Time (s)'] = baseline_summary.apply(lambda r: f"{r['mean']:.2f} ± {r['std']:.2f}", axis=1)

    speedup_summary = df_success[df_success['Threads'] > 1].groupby(['PatternCategory', 'Threads'])['Speedup'].agg(['mean', 'std']).unstack().fillna(0)

    # Format speedup columns
    for threads in speedup_summary.columns.get_level_values(1):
        speedup_summary[(f'Speedup @ {threads}T', '')] = speedup_summary.apply(lambda r: f"{r[('mean', threads)]:.2f}x ± {r[('std', threads)]:.2f}x", axis=1)

    final_perf_table = pd.concat([baseline_summary['Baseline Time (s)'], speedup_summary.xs('', axis=1, level=1)], axis=1)

    # --- 3. Create the Parallel Efficiency Table ---
    efficiency_summary = df_success[df_success['Threads'] > 1].groupby(['PatternCategory', 'Threads'])['Efficiency'].agg(['mean', 'std']).unstack().fillna(0)

    # Format efficiency columns
    for threads in efficiency_summary.columns.get_level_values(1):
        efficiency_summary[(f'Efficiency @ {threads}T (%)', '')] = efficiency_summary.apply(lambda r: f"{r[('mean', threads)]:.1f}% ± {r[('std', threads)]:.1f}%", axis=1)

    final_efficiency_table = efficiency_summary.xs('', axis=1, level=1)

    # --- 4. Print Reports ---
    all_categories = sorted(df_success['PatternCategory'].unique())
    final_perf_table = final_perf_table.reindex(all_categories).fillna("DNF")
    final_efficiency_table = final_efficiency_table.reindex(all_categories).fillna("DNF")

    print("\n" + "="*95)
    print("✅ Final Performance Summary (Execution Time & Speedup)")
    print("="*95)
    print(final_perf_table.to_string())
    print("="*95)

    print("\n" + "="*95)
    print("✅ Parallel Efficiency Summary")
    print("="*95)
    print(final_efficiency_table.to_string())
    print("="*95)
    print("\n'DNF' (Did Not Finish) indicates categories where all tests failed or timed out.")

if __name__ == "__main__":
    current_dir = os.getcwd()
    analyze_comprehensive_results(current_dir)