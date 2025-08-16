# Makefile for generating SNAP datasets table
PYTHON_SOURCES = snap_table_generator.py
TABLE_FILES = $(PYTHON_SOURCES:.py=.tbl)
PNG_FILES = snap_datasets_table.png
PDF_FILES = snap_datasets_table.pdf

PYTHON = python3
LATEX = pdflatex

.PHONY: all clean

all: $(PNG_FILES) $(PDF_FILES)

# Generate .tbl file from Python script
%.tbl: %.py
	$(PYTHON) $<

# Generate PDF and PNG from LaTeX
snap_datasets_table.pdf snap_datasets_table.png: latex_table_document.tex snap_datasets_table.tbl
	$(LATEX) -shell-escape -jobname=snap_datasets_table latex_table_document.tex
	@if [ -f snap_datasets_table-0.png ]; then \
		convert snap_datasets_table-0.png -flatten -trim +repage snap_datasets_table.png; \
	fi

clean:
	-rm -f *.tbl *.aux *.log *.pdf *.png *.fdb_latexmk *.fls
	-rm -f snap_datasets_table-0.png

# For development - just generate the table file
table: snap_datasets_table.tbl
	@echo "Table file generated: snap_datasets_table.tbl"