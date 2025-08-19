import xml.etree.ElementTree as ET
import sys

files = sys.argv[1:]
merged_root = None

for i, fname in enumerate(files):
    tree = ET.parse(fname)
    root = tree.getroot()
    if merged_root is None:
        merged_root = root
    else:
        for protein in root.findall("protein"):
            merged_root.append(protein)

ET.ElementTree(merged_root).write("merged.xml", encoding="UTF-8", xml_declaration=True)
