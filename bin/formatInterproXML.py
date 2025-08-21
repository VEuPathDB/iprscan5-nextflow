#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import argparse
import glob
import sys

def main():
    parser = argparse.ArgumentParser(description="Merge all XML files in the current directory into one XML file.")
    parser.add_argument("--out", required=True, help="Path to the output XML file")
    args = parser.parse_args()

    # Collect all XML files in current directory
    files = sorted(glob.glob("*.xml"))
    if not files:
        print("No XML files found in the current directory.", file=sys.stderr)
        sys.exit(1)

    merged_root = None
    for i, fname in enumerate(files):
        tree = ET.parse(fname)
        root = tree.getroot()
        if merged_root is None:
            # Take the root from the first file
            merged_root = root
        else:
            # Append all <protein> elements from subsequent files
            for protein in root.findall("protein"):
                merged_root.append(protein)

    # Write out the merged XML
    ET.ElementTree(merged_root).write(args.out, encoding="UTF-8", xml_declaration=True)
    print(f"Merged {len(files)} files into {args.out}")

if __name__ == "__main__":
    main()
