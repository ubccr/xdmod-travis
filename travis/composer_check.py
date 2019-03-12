import argparse
import os
import json

# the scripts current working directory. Used in defining default values for
# this script
cwd = os.getcwd()


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
        left = value_or_else(orig_content, key)
        right = value_or_else(new_content, key)

        (added, removed, modified) = dict_compare(left, right)
        if len(added) > 0 or len(removed) > 0 or len(modified) > 0:
            exit(1)


def read_json(path):
    """
    Helper method that opens / parses a json file, returning its contents.
    :param str path:
    :return:
    """
    with open(path, 'r') as fh:
        return json.load(fh)


def value_or_else(data, key, default=None):
    """
    A helper method that retrieves the value from `data` for `key` if it exists,
    else it returns `default`.

    :param dict data:
    :param string key:
    :param default:
    :return:
    """
    if default is None:
        default = {}
    return data[key] if key in data else default


def dict_compare(left, right):
    """
    Compares two dictionaries, left to right. It returns a 3-tuple that contains
    the entries that were added, removed, and modified.

    :param dict left:
    :param dict right:
    :return: (added, removed, modified)
    """
    lkeys = set(left.keys())
    rkeys = set(right.keys())
    intersect_keys = lkeys.intersection(rkeys)
    added = lkeys - rkeys
    removed = rkeys - lkeys
    modified = {o: (left[o], right[o]) for o in intersect_keys if
                left[o] != right[o]}
    return added, removed, modified


if __name__ == '__main__':
    # Setup the arg parser for this script
    parser = argparse.ArgumentParser(
        description="Determines whether or not composer.json changes require an associated composer.lock change.")
    parser.add_argument('original_file', type=str, nargs="?",
                        default=os.path.join(cwd, "composer.orig.json"),
                        help="The original version of composer.json")
    parser.add_argument('new_file', type=str, nargs="?",
                        default=os.path.join(cwd, 'composer.json'))

    args = parser.parse_args()

    main(args.original_file, args.new_file)
