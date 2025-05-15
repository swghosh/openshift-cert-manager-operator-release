import glob
import yaml
import os
import re

ANNOTATION_KEY = "pipelinesascode.tekton.dev/on-cel-expression"

OLD_FILE_VERSION = "1-15"
NEW_FILE_VERSION = "1-16"

OLD_VERION = "1.15"
NEW_VERSION = "1.16"

old_files = glob.glob(".tekton/*-%s-*.yaml" % OLD_FILE_VERSION)

for old_file in old_files:
    # replace 1-15 with 1-16
    new_file = re.sub(OLD_FILE_VERSION, NEW_FILE_VERSION, old_file)
    print(f"{old_file} -> {new_file}")

    with open(old_file, 'r') as f:
        old_data = yaml.safe_load(f)

    # looking for metadata.annotations[...cel-expr..] in old yaml
    try:
        val = old_data['metadata']['annotations'][ANNOTATION_KEY]
    except KeyError:
        print(f"Annotation key not found in {old_file}, skipping.")
        continue

    if not os.path.exists(new_file):
        print(f"New file {new_file} does not exist, skipping.")
        continue

    with open(new_file, 'r') as f:
        new_data = yaml.safe_load(f)

    if 'metadata' not in new_data:
        new_data['metadata'] = {}
    if 'annotations' not in new_data['metadata']:
        new_data['metadata']['annotations'] = {}

    # apply cel-expr value in new yaml, by replacing
    # 1.15 -> 1.16, 1-15 -> 1.16
    val = val.replace(OLD_FILE_VERSION, NEW_FILE_VERSION).replace(OLD_VERION, NEW_VERSION)
    new_data['metadata']['annotations'][ANNOTATION_KEY] = val

    with open(new_file, 'w') as f:
        yaml.dump(new_data, f, default_flow_style=False)
