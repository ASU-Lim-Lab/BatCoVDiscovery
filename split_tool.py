import sys
import os.path
from Bio import SeqIO
from contextlib import redirect_stdout

def batch_iterator(iterator, batch_size):  # adapted from https://biopython.org/wiki/Split_large_file
    """
    a generator program to save memory for processing large files:
    loads one record at a time then appends it to a list,
    repeating the process until the list contains one file’s worth of sequences
    """
    entry = True
    while entry:
        batch = []
        while len(batch) < batch_size:
            try:
                entry = next(iterator)  # new feature for python 3, replaced 'g.next()'
            except StopIteration:
                entry = None
            if entry is None:  # end of file
                break
            batch.append(entry)
        if batch:  # return a not empty list
            yield batch


after_qc_file = sys.argv[1]
output_path = sys.argv[2]
sampleID = sys.argv[3]

after_qc_fasta = SeqIO.parse(open(after_qc_file), 'fasta')

for i, batch in enumerate(batch_iterator(after_qc_fasta, 500000)):  # slice size adapted from Rabia's script
    filename = str(output_path) + '/' + str(sampleID) + '_split_group_%i.fasta' % (i + 1)
    filename = str(filename)
    logname = str(output_path) + '/' + str(sampleID) + '_split_log.txt'
    logname = str(logname)
    with open(filename, 'w') as handle:
        count = SeqIO.write(batch, handle, 'fasta')
    with open(logname, 'a') as f:  # 'a' for append option, prevent overwriting
        with redirect_stdout(f):
            print('Wrote %i reads to %s' % (count, filename))
