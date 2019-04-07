"""Expands templates with workspace_status_command variables %LIKE_THIS%. We
parse Bazel stable-status.txt to extract the workspace variables.

E.g.
/usr/local/bin/python tools/build_rules/template_stamper.py \
--stamp-info-file './bazel-out/stable-status.txt' \
"""

import argparse
import subprocess
import re

parser = argparse.ArgumentParser(
    description='Replace workspace status variables with their values.')

parser.add_argument(
    '--input',
    action='store',
    required=True,
    help='The input file to read from, mandatory')

parser.add_argument(
    '--output',
    action='store',
    required=True,
    help='The output file to write to, mandatory')

parser.add_argument(
    '--stamp-info-file',
    action='append',
    required=True,
    help=('If stamping these layers, the list of files from '
          'which to obtain workspace information'))


def main():
    args = parser.parse_args()

    stamp_info = {}
    for infofile in args.stamp_info_file:
        with open(infofile) as info:
            for line in info:
                key, value = line.strip("\n").split(" ", 1)
                if key in stamp_info:
                    print(
                        "WARNING: Duplicate value for workspace status key '%s': "
                        "using '%s'" % (key, value))
                stamp_info[key] = value

    dynamic_arg_placeholders = []
    with open(args.input, 'r') as input_fd:
        for line in input_fd:
            dynamic_arg_placeholders += re.findall("%([0-9A-Z_]+)%", line)
    dynamic_arg_placeholders = sorted(set(dynamic_arg_placeholders))

    try:
        {k: stamp_info[k] for k in dynamic_arg_placeholders}
    except KeyError as e:
        arg = e.args[0]
        raise Exception(
            "ERROR: no dynamic arg {lower} is defined (via {upper} or {upper} workspace status variable, available: {all})".
            format(
                lower=arg, upper=arg.upper(), all=", ".join(stamp_info.keys())))

    with open(args.output, 'w') as output_fd:
        with open(args.input) as input_fd:
            for line in input_fd:
                for arg in dynamic_arg_placeholders:
                    line = line.replace("%" + arg + "%", stamp_info[arg])
                output_fd.write(line)


if __name__ == '__main__':
    main()
