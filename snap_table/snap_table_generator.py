import pandas as pd
import os

def bold_extreme_values(data, data_max=-1):
    """Make maximum values bold for LaTeX"""
    if data == data_max:
        return "\\bfseries %s" % data
    return data

def format_large_numbers(num):
    """Format large numbers with commas for readability"""
    if num >= 1000000:
        return f"{num:,}"
    else:
        return f"{num:,}"

if __name__ == "__main__":
    # SNAP dataset statistics
    data = {
        'Category': ['Social Networks', '', 'Collaboration', 'Communication', '', 'Road Networks'],
        'Dataset': ['LiveJournal (lj)', 'Youtube (youtube)', 'DBLP (dblp)', 'Enron (enron)', 'Wikipedia Talk (wiki)', 'California Roads (roadNet-CA)'],
        'V': [4847571, 1134890, 317080, 36692, 2394385, 1965206],
        'E': [68993773, 2987624, 1049866, 183831, 5021410, 2766607],
        'Communities': [287512, 8385, 13477, '-', '-', '-'],
        'd': [28.5, 5.3, 6.6, 10.0, 4.2, 2.8]
    }

    df = pd.DataFrame(data)

    # Format large numbers with commas
    df['V'] = df['V'].apply(format_large_numbers)
    df['E'] = df['E'].apply(format_large_numbers)

    # Make maximum values bold for degree column
    numeric_d = pd.to_numeric(df['d'], errors='coerce')
    max_d = numeric_d.max()
    df['d'] = df['d'].apply(lambda x: bold_extreme_values(x, max_d) if pd.notna(pd.to_numeric(x, errors='coerce')) else x)

    # Set column headers to bold
    df.columns = ['\\textbf{Category}', '\\textbf{Dataset Name}',
                  '\\textbf{|V|}', '\\textbf{|E|}',
                  '\\textbf{|$\\Sigma$|}', '\\textbf{$\\bar{d}$}']

    # Write to file
    with open("snap_datasets_table.tbl", "w") as f:
        # Column format: left-aligned for text, centered for numbers
        column_format = "l l r r c S[table-format = 2.1]"

        latex_table = df.to_latex(
            index=False,
            escape=False,
            column_format=column_format
        )

        # Manually add booktabs formatting
        lines = latex_table.split('\n')

        # Replace the default LaTeX table formatting with booktabs
        for i, line in enumerate(lines):
            if '\\begin{tabular}' in line:
                lines.insert(i+1, '\\toprule')
            elif line.strip().startswith('\\textbf{Category}'):
                lines[i] = line + ' \\\\'
                lines.insert(i+1, '\\midrule')
            elif '\\end{tabular}' in line:
                lines.insert(i, '\\bottomrule')
                break

        # Remove default \hline commands
        lines = [line for line in lines if '\\hline' not in line]

        latex_table = '\n'.join(lines)

        f.write(latex_table)

    print("Table saved to snap_datasets_table.tbl")
    print("\nTo include in your LaTeX document:")
    print("\\begin{table}[htbp]")
    print("\\centering")
    print("\\caption{Statistics of SNAP datasets used in evaluation}")
    print("\\input{snap_datasets_table.tbl}")
    print("\\label{tab:snap_datasets}")
    print("\\end{table}")