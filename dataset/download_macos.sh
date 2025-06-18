#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DATASET_OUTDIR=${SCRIPT_DIR}/TXT
echo "Download files into" ${DATASET_OUTDIR}

# Create output directory
mkdir -p ${DATASET_OUTDIR}

# Download Enron Email Network
if test -f "${DATASET_OUTDIR}/enron/snap.txt"; then
    echo "enron exists"
else
    echo "Enron email network"
    curl https://snap.stanford.edu/data/email-Enron.txt.gz -o enron.txt.gz
    gzip -d enron.txt.gz && mkdir -p ${DATASET_OUTDIR}/enron && mv enron.txt ${DATASET_OUTDIR}/enron/snap.txt
    echo "Enron download complete"
fi

'''
Download DBLP collaboration network
if test -f "${DATASET_OUTDIR}/dblp/snap.txt"; then
    echo "dblp exists"
else
    echo "DBLP collaboration network"
    curl https://snap.stanford.edu/data/bigdata/communities/com-dblp.ungraph.txt.gz -o dblp.txt.gz
    gzip -d dblp.txt.gz && mkdir -p ${DATASET_OUTDIR}/dblp && mv dblp.txt ${DATASET_OUTDIR}/dblp/snap.txt
    echo "DBLP download complete"
fi
'''


echo "All datasets downloaded"