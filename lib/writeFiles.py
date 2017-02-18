from distutils import dir_util
import json
import logging
import os
import shutil
import sys


def mkdir(d):
    try:
        os.makedirs(d)
    except OSError:
        if os.path.isdir(d):
            pass  # It already existed.

def main(argv):
    f = argv[1]
    out = argv[2]
    with open(f) as fh:
        data = json.load(fh)

    for key, src in data["files"].items():

        if type(src) in [str, unicode]:
            dst = os.path.join(out, key)

            if os.path.isdir(src):
                logging.debug("Copy dir %s", dst)
                dir_util.copy_tree(src, dst)
            else:
                logging.debug("Copy file %s", dst)
                mkdir(os.path.dirname(dst))
                shutil.copyfile(src, dst)

        elif type(src) == dict:
            dst = os.path.join(out, key)
            mkdir(os.path.dirname(dst))

            if "content" in src:
                logging.debug("Creating file %s", dst)
                with open(dst, "w") as dst_fh:
                    dst_fh.write(src["content"])

            elif "link" in src:
                logging.debug("Symlinking %s", dst)
                os.symlink(src["link"], dst)

if __name__ == '__main__':
    main(sys.argv)
