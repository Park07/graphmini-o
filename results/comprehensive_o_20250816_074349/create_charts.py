import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os

# --- Configuration ---
# CORRECTED: Changed the filename to match your actual results file
RESULTS_CSV_PATH = "comprehensive_results.csv"
CHART_OUTPUT_DIR = "charts"

def create_speedup_barchart(df, max_threads):
    """
    Creates a bar chart comparing the average speedup of each algorithm
    at the maximum thread count for each query category.
    """
    print(f"📈 Generating Speedup Comparison Bar Chart for {max_threads} threads...")

    # Filter for the max thread count and successful runs
    # Note: Assumes your final CSV will have an 'Algorithm' column
    if 'Algorithm' not in df.columns:
        df['Algorithm'] = 'graphmini' # Placeholder if running on single-algo results

    df_max_threads = df[(df['Threads'] == max_threads) & (df['Status'] == 'SUCCESS')].copy()

    if df_max_threads.empty:
        print(f"⚠️  WARNING: No successful runs found for {max_threads} threads. Skipping bar chart.")
        return

    plt.style.use('seaborn-v0_8-whitegrid')
    fig, ax = plt.subplots(figsize=(14, 8))

    # This will work even with one algorithm, and will be ready for when you add SLF
    sns.barplot(
        data=df_max_threads,
        x='PatternCategory',
        y='Speedup',
        hue='Algorithm',
        ax=ax,
        palette='viridis'
    )

    ax.set_title(f'Average Speedup at {max_threads} Threads by Query Category', fontsize=18, fontweight='bold')
    ax.set_xlabel('Query Category', fontsize=12)
    ax.set_ylabel('Average Speedup (Factor)', fontsize=12)
    ax.tick_params(axis='x', rotation=45, labelsize=10)
    ax.legend(title='Algorithm', fontsize=10)

    for container in ax.containers:
        ax.bar_label(container, fmt='%.1fx', fontsize=9, padding=3)

    plt.tight_layout()
    output_path = os.path.join(CHART_OUTPUT_DIR, "speedup_comparison_barchart.png")
    plt.savefig(output_path, dpi=300)
    print(f"   ✅ Chart saved to: {output_path}")
    plt.close()

def create_scalability_linechart(df, category_to_plot):
    """
    Creates a line chart showing raw execution time vs. thread count
    for a specific query category to analyze scalability.
    """
    print(f"📈 Generating Scalability Line Chart for category: '{category_to_plot}'...")

    # Note: Assumes your final CSV will have an 'Algorithm' column
    if 'Algorithm' not in df.columns:
        df['Algorithm'] = 'graphmini' # Placeholder

    df_category = df[df['PatternCategory'] == category_to_plot].copy()

    if df_category.empty:
        print(f"⚠️  WARNING: No data found for category '{category_to_plot}'. Skipping line chart.")
        return

    plt.style.use('seaborn-v0_8-whitegrid')
    fig, ax = plt.subplots(figsize=(12, 7))

    sns.lineplot(
        data=df_category,
        x='Threads',
        y='ExecutionTime_s',
        hue='Algorithm',
        style='Algorithm',
        markers=True,
        dashes=False,
        ax=ax,
        palette='plasma',
        linewidth=2.5
    )

    ax.set_title(f'Scalability on "{category_to_plot}" Queries', fontsize=18, fontweight='bold')
    ax.set_xlabel('Number of Threads', fontsize=12)
    ax.set_ylabel('Average Execution Time (seconds)', fontsize=12)
    ax.set_xscale('log', base=2)
    ax.get_xaxis().set_major_formatter(plt.ScalarFormatter())
    ax.set_xticks(sorted(df['Threads'].unique()))
    ax.legend(title='Algorithm', fontsize=10)

    plt.tight_layout()
    output_path = os.path.join(CHART_OUTPUT_DIR, f"scalability_{category_to_plot}.png")
    plt.savefig(output_path, dpi=300)
    print(f"   ✅ Chart saved to: {output_path}")
    plt.close()


def main():
    """Main function to load data and generate all charts."""
    if not os.path.exists(RESULTS_CSV_PATH):
        print(f"❌ ERROR: Results file not found at '{RESULTS_CSV_PATH}'. Please ensure it exists.")
        return

    os.makedirs(CHART_OUTPUT_DIR, exist_ok=True)

    df = pd.read_csv(RESULTS_CSV_PATH)

    # --- Data Cleaning and Metric Calculation ---
    df['ExecutionTime_s'] = pd.to_numeric(df['ExecutionTime_s'], errors='coerce')
    df_success = df.dropna(subset=['ExecutionTime_s']).copy()

    # Create a clean 'PatternCategory' column
    if 'Pattern_Name' in df_success.columns:
         df_success['PatternCategory'] = df_success['Pattern_Name'].str.extract(r'(.*)_\d+$')

    baselines = df_success[df_success['Threads'] == 1].groupby(['Dataset', 'Pattern_Name'])['ExecutionTime_s'].mean().rename('BaselineTime_s')
    df_success = pd.merge(df_success, baselines, on=['Dataset', 'Pattern_Name'], how='left')
    df_success['Speedup'] = df_success['BaselineTime_s'] / df_success['ExecutionTime_s']

    if df_success.empty:
        print("⚠️ No successful runs found to analyze. Exiting.")
        return

    # --- Generate Charts ---
    max_threads = df_success['Threads'].max()
    create_speedup_barchart(df_success, max_threads)

    # You can change this to any category you want to deep-dive into
    category_for_line_chart = "small_dense_4v"
    if not df_success[df_success['PatternCategory'] == category_for_line_chart].empty:
        create_scalability_linechart(df_success, category_for_line_chart)
    else:
        print(f"ℹ️  NOTE: No successful runs found for '{category_for_line_chart}', skipping line chart.")


if __name__ == "__main__":
    main()