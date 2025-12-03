#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#
# ]
# ///

import os
import sys
import subprocess
import shutil
import traceback
import shlex

REPO_DIR = os.path.dirname(__file__)

def no_err(callback, d_val=None):
  try:
    return callback()
  except:
    return d_val

def main(args=sys.argv):
  bin_dir = os.path.join(REPO_DIR, 'bin')
  os.makedirs(bin_dir, exist_ok=True)

  days_to_run = []
  for arg in args:
    for arg_int in arg.split(','):
      no_err(lambda: days_to_run.append(int(arg_int)))

  for dnum in days_to_run:
    print(f'= = = = day{dnum} = = = =')
    directory = os.path.join(REPO_DIR, f'day{dnum}')
    main_asm = os.path.join(directory, f'day{dnum}.s')
    bin_file = os.path.join(bin_dir, f'day{dnum}')
    subprocess.run([
      'zig', 'build-exe', main_asm,
        '-target', 'x86_64-linux',
        f'-femit-bin={bin_file}'
    ])
    print(f'See {bin_file}')



if __name__ == '__main__':
  main()

