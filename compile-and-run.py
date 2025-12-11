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
import pathlib

REPO_DIR = os.path.dirname(__file__)
REPO_PATH = pathlib.Path(REPO_DIR).resolve()

def no_err(callback, d_val=None):
  try:
    return callback()
  except:
    return d_val

def run(*cmd):
    print(f"> {' '.join(cmd)}")
    subprocess.run(cmd, check=True)

def output_of(*cmd):
    print(f"> {' '.join(cmd)}")
    r = None
    try:
      r = subprocess.run(cmd, stdout=subprocess.PIPE, check=True, text=True)
    except:
      if 'SIGSEGV' in traceback.format_exc():
        # Run with gdbbin to dump a stack trace... as helpful as assembly stack trace can be!
        try:
          run('gdbbin', *cmd)
        except:
          return ''

    if r is not None:
      return r.stdout.strip()
    else:
      return ''

def rpath(path_s):
  global REPO_PATH
  p = pathlib.Path(path_s).resolve()
  return p.relative_to(REPO_PATH)


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
    run(
      'zig', 'build-exe', main_asm,
        '-target', 'x86_64-linux',
        f'-femit-bin={bin_file}'
    )
    for io_i in range(0,99):
      input_file = os.path.join(directory, f'input{io_i}.txt')
      output_file = os.path.join(directory, f'output{io_i}.txt')
      if os.path.exists(input_file) and os.path.exists(output_file):
        with open(input_file, 'r') as fd:
          input_txt = fd.read().strip()
        with open(output_file, 'r') as fd:
          output_txt = fd.read().strip()

        cmd_output = output_of(bin_file, input_file)
        if cmd_output != output_txt:
          print(f'FAILED input {io_i}')
          print(f'Expected ({rpath(output_file)})')
          print(f'{output_txt}')
          print(f'Observed ({rpath(bin_file)} {rpath(input_file)})')
          print(f'{cmd_output}')
          print()
        else:
          print(f'PASSED {rpath(bin_file)} {rpath(input_file)} => {rpath(output_file)}')




if __name__ == '__main__':
  main()

