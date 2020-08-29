#!/usr/bin/env python
# coding=utf-8

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import sys
import os
import re

from absl import app
from absl import flags

FLAGS = flags.FLAGS

# e.g., /home/eduardo/proj/DBN/data/raw/ADNI
flags.DEFINE_string('data_path', None, 'Path to the data folder')
# e.g., /home/eduardo/proj/DBN/logs/ADNI/RPP
flags.DEFINE_string('log_path', None, 'Path to the log folder')


def get_subdir_list(some_dir):
    assert os.path.isdir(some_dir)
    (_, dirs, _) = next(os.walk(some_dir))
    return sorted(dirs)


def get_logged_ID_list(log_path, regex):
    logged_ID_list = []
    for root, dirs, files in os.walk(log_path):
        for f in files:
            with open(os.path.join(root, f), 'r') as my_file:
                if re.search(regex, my_file.read()):
                    ID = os.path.splitext(f)[0]
                    logged_ID_list.append(ID)
    logged_ID_list = sorted(logged_ID_list)
    return logged_ID_list


def save_list(my_list, out_file):
    if os.path.exists(out_file):
        os.remove(out_file)
    with open(out_file, 'w+') as outFile:
        outFile.writelines("%s\n" % item for item in my_list)


def run_main(argv):
    del argv
    kwargs = {'data_path': FLAGS.data_path,
              'log_path':  FLAGS.log_path}
    main(**kwargs)


def compare_lists(first_list, second_list):
    first_set = set(first_list)
    second_set = set(second_list)
    unique_to_first = sorted(list(first_set - second_set))
    unique_to_second = sorted(list(second_set - first_set))
    common_to_both = sorted(list(first_set & second_set))
    return [unique_to_first, unique_to_second, common_to_both]


def main(data_path, log_path):
    # Get list of subject IDs in the data folder
    ID_list = get_subdir_list(data_path)
    # Save ID list in the output file
    save_list(ID_list, os.path.join(data_path, "ID_list.txt"))
    # Get ID list of RPP preprocessed subjects
    regex = re.compile(r'\bRPP Completed\b')
    logged_ID_list = get_logged_ID_list(log_path, regex)
    # Save ID list of RPP preprocessed subjects
    save_list(logged_ID_list, os.path.join(log_path, "logged_ID_list.txt"))
    # Get list of subject IDs that were not processed
    (not_preproc_ID_list,_ ,_ ) = compare_lists(ID_list, logged_ID_list)

    complete = os.path.join(log_path, "complete.txt")
    if os.path.exists(complete):
        os.remove(complete)
    # Save ID list of RPP preprocessed subjects
    not_preproc_path = os.path.join(data_path, "not_preprocessed_ID_list.txt")
    if os.path.exists(not_preproc_path):
        os.remove(not_preproc_path)

    # if list of not preprocessed IDs is empty
    if not not_preproc_ID_list:
        # Create an empty file named complete.txt
        save_list(not_preproc_ID_list, complete)
    else:
        save_list(not_preproc_ID_list, not_preproc_path)


if __name__ == '__main__':
    app.run(run_main)
