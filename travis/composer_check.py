import argparse
import json


def main(orig_file, new_file):
    """
    Reads / parses content from the `original_file` and the `new_file`. For each
    section that we care about ( 'require', 'require-dev', 'extra ), determine whether
    anything has been added, removed or modified in `new_file`. If there have
    been changes then we exit w/ a non-zero exit code to indicate that additional
    validation may be required. If there are no changes detected then we exit w/
    a zero exit code.
    """
    orig_content = read_json(orig_file)
    new_content = read_json(new_file)

    for key in ['require', 'require-dev', 'extra']:
        left = orig_content.get(key, {})
        right = new_content.get(key, {})

        if left != right:
            exit(1)


def read_json(path):
    """
    Helper method that opens / parses a json file, returning its contents.
    :param str path:
    :return:
    """
    with open(path, 'r') as fh:
        return json.load(fh)


if __name__ == '__main__':
    # Setup the arg parser for this script
    parser = argparse.ArgumentParser(
        description="Determines whether or not composer.json changes require an associated composer.lock change.")
    parser.add_argument('original_file', type=str, nargs="?",
                        default="composer.orig.json",
                        help="The original version of composer.json")
    parser.add_argument('new_file', type=str, nargs="?",
                        default="composer.json")

    args = parser.parse_args()

    main(args.original_file, args.new_file)
