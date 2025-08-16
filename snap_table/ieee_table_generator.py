import pandas as pd

def format_large_numbers(num):
    """Format large numbers with commas"""
    return f"{num:,}"

if __name__ == "__main__":
    # SNAP dataset statistics with proper grouping
    data = {
        'Category': ['Social', 'Social', 'Collaboration', 'Communication', 'Communication', 'Infrastructure'],
        'Dataset': ['Youtube', 'LiveJournal', 'DBLP', 'Enron', 'Wiki-Talk', 'roadNet-CA'],
        'Name': ['yt', 'lj', 'db', 'en', 'wt', 'ca'],
        'V': [1134890, 4847571, 317080, 36692, 2394385, 1965206],
        'E': [2987624, 68993773, 1049866, 183831, 5021410, 2766607],
        'Communities': [25, 287, 15, '-', '-', '-'],
        'd': [5.3, 28.5, 6.6, 10.0, 4.2, 2.8]
    }

    df = pd.DataFrame(data)

    # Format numbers with commas
    df['V_fmt'] = df['V'].apply(format_large_numbers)
    df['E_fmt'] = df['E'].apply(format_large_numbers)

    # Create the LaTeX table manually with multirow for grouped categories
    latex_lines = [
        "\\begin{table}[!t]",
        "\\centering",
        "\\caption{Statistics of SNAP datasets used in evaluation}",
        "\\label{tab:snap_datasets}",
        "\\begin{tabular}{|l|l|c|r|r|c|r|}",
        "\\hline",
        "\\textbf{Category} & \\textbf{Dataset} & \\textbf{Name} & \\textbf{|V|} & \\textbf{|E|} & \\textbf{|$\\Sigma$|} & \\textbf{$\\bar{d}$} \\\\",
        "\\hline"
    ]

    # Group the data and add multirow for categories
    current_category = None
    category_counts = df['Category'].value_counts()
    category_positions = {}

    for i, row in df.iterrows():
        category = row['Category']

        if category != current_category:
            current_category = category
            count = category_counts[category]
            if count > 1:
                # Use multirow for categories with multiple entries
                latex_lines.append(f"\\multirow{{{count}}}{{*}}{{{category}}} & {row['Dataset']} & {row['Name']} & {row['V_fmt']} & {row['E_fmt']} & {row['Communities']} & {row['d']} \\\\")
            else:
                # Single row category
                latex_lines.append(f"{category} & {row['Dataset']} & {row['Name']} & {row['V_fmt']} & {row['E_fmt']} & {row['Communities']} & {row['d']} \\\\")
        else:
            # Continuation of multirow category
            latex_lines.append(f" & {row['Dataset']} & {row['Name']} & {row['V_fmt']} & {row['E_fmt']} & {row['Communities']} & {row['d']} \\\\")

        latex_lines.append("\\hline")

    latex_lines.extend([
        "\\end{tabular}",
        "\\end{table}"
    ])

    # Write to file
    with open("grouped_snap_table.tex", "w") as f:
        f.write('\n'.join(latex_lines))

    print("Grouped table saved to grouped_snap_table.tex")
    print("\nRequired packages for your preamble:")
    print("\\usepackage{multirow}")
    print("\\usepackage{array}")
    print("\nTable code:")
    print('\n'.join(latex_lines))

    print("\n" + "="*60)
    print("COPY THIS FOR OVERLEAF:")
    print("="*60)
    print("Add to preamble (after \\documentclass):")
    print("\\usepackage{multirow}")
    print("\\usepackage{array}")
    print("")
    print("Table code:")
    for line in latex_lines:
        print(line)