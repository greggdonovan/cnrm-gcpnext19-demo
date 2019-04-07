"""Calls a k8s resource templating binary with the correct arguments
for the (namespace + cluster).

Namespace and cluster are specified in workspace_status_command variables. We
parse Bazel stable-status.txt to extract them.

We then use those values to lookup (namespace + cluster) specific variables.

E.g.
/usr/local/bin/python tools/build_rules/k8s_templater.py \
--binary-target-path foo  \
--stamp-info-file './bazel-out/stable-status.txt' \
--dynamic_args 'namespace' \
--dynamic_args 'image_chroot' \
--constant_args 'service=spellcorrection;cats=cute'

"""

import argparse
import subprocess

parser = argparse.ArgumentParser(
    description='Template a kubernetes resource for the cluster and namespace.')

parser.add_argument(
    '--binary-target-path',
    action='store',
    required=True,
    help='The binary templater to call, mandatory')

parser.add_argument(
    '--output',
    action='store',
    required=True,
    help='The output file to write to, mandatory')

parser.add_argument(
    '--dynamic_args',
    action='append',
    default=[],
    required=False,
    help=('A list of arguments to the binary '
          'to be resolved dynamically from configuration'))

parser.add_argument(
    '--constant_args',
    action='append',
    default=[],
    required=False,
    help=('An associative list of statically defined arguments. '
          'e.g. service=slv2,bundle=mmx'))

parser.add_argument(
    '--stamp-info-file',
    action='append',
    required=False,
    help=('If stamping these layers, the list of files from '
          'which to obtain workspace information'))


def merge(d1, d2):
    d3 = d1.copy()
    d3.update(d2)
    return d3


def main():
    args = parser.parse_args()

    binary_target_args = [args.binary_target_path]

    constant_args = {}
    for arg in args.constant_args or []:
        parts = arg.split(';')
        kwargs = dict([x.split('=', 2) for x in parts])
        constant_args.update(kwargs)

    for key, value in constant_args.items():
        binary_target_args += ["--%s" % key, value]

    if args.dynamic_args:
        stamp_info = {}
        for infofile in args.stamp_info_file:
            with open(infofile) as info:
                for line in info:
                    key, value = line.strip("\n").split(" ", 1)
                    key = key[7:] if key.startswith("STABLE_") else key
                    key = key.lower()
                    if key in stamp_info:
                        print(
                            "WARNING: Duplicate value for workspace status key '%s': "
                            "using '%s'" % (key, value))
                    stamp_info[key] = value

        dynamic_args = {}
        for k in args.dynamic_args:
            stripped_key = k.rstrip('?')
            # If k ends in a ?, it's an optional argument
            optional = len(stripped_key) < len(k)
            if stripped_key not in stamp_info:
                if optional:
                    print("Optional argument %s not found. Continuing." % k)
                    continue
                raise Exception(
                    "ERROR: no dynamic arg {lower} is defined (via STABLE_{upper} or {upper} workspace status variable)".
                    format(lower=stripped_key, upper=stripped_key.upper()))
            dynamic_args[stripped_key] = stamp_info[stripped_key]

        for key, value in dynamic_args.items():
            binary_target_args += ["--%s" % key, value]

    binary_target_args += ["--output", args.output]

    # Run the binary target that does the actual templating
    popen = subprocess.Popen(
        binary_target_args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    popen.wait()
    output = popen.stdout.read()
    # The YAML is generated to the --output file, so we don't expect anything on stdout/stderr, but print
    # if there are any errors or anything logged unexpectedly:
    if output:
        print output


if __name__ == '__main__':
    main()
