#!/usr/bin/env python
# coding=utf-8

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import sys
import os

from absl import app
from absl import flags

FLAGS = flags.FLAGS

# e.g., /home/eduardo/proj/DBN/data/raw/ADNI
flags.DEFINE_string('data_path', None, 'Path to the data folder')
# e.g., /home/eduardo/proj/DBN/data/raw/ADNI/subjects.txt
flags.DEFINE_string('out_file',  None, 'Path to the output file')


def walklevel(some_path, level=1):
    some_dir = some_path.rstrip(os.path.sep)
    assert os.path.isdir(some_dir)
    num_sep = some_dir.count(os.path.sep)
    for root, dirs, files in os.walk(some_dir):
        num_sep_this = root.count(os.path.sep)
        if num_sep + level <= num_sep_this:
            return
        yield (root, dirs, files)


def run_main(argv):
    del argv
    kwargs = {'data_path': FLAGS.data_path, 'out_file': FLAGS.out_file}
    main(**kwargs)


def main(data_path, out_file):
    # x = (root, dirs, files)
    IDList = [x[1] for x in walklevel(data_path, level=1)]
    # Flattening the list of IDs
    IDList = sorted([x for ID in IDList for x in ID])
    if not os.path.exists(out_file):
        os.remove(out_file)
    with open(out_file, 'w+') as outFile:
        outFile.writelines("%s\n" % ID for ID in IDList)


if __name__ == '__main__':
    app.run(run_main)
