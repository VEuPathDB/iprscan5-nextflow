#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import argparse
import glob
import sys

def main():
    parser = argparse.ArgumentParser(description="Merge InterProScan XML output files into one valid XML file.")
    parser.add_argument("--out", required=True, help="Path to the output XML file")
    parser.add_argument("--pattern", default="interpro.xml*", help="Pattern to match XML files (default: interpro.xml*)")
    args = parser.parse_args()

    # Collect matching XML files
    files = sorted(glob.glob(args.pattern))
    if not files:
        print(f"No files found matching pattern '{args.pattern}'", file=sys.stderr)
        sys.exit(1)

    # Use first file as base
    tree = ET.parse(files[0])
    merged_root = tree.getroot()

    # Append <protein> elements from remaining files
    for fname in files[1:]:
        t = ET.parse(fname)
        r = t.getroot()
        for protein in r.findall("{*}protein"):  # {*} handles XML namespaces
            merged_root.append(protein)

    # Write out the merged XML with header
    ET.ElementTree(merged_root).write(args.out, encoding="UTF-8", xml_declaration=True)
    print(f"Merged {len(files)} files into {args.out}")

if __name__ == "__main__":
    main()
