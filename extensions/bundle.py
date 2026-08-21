import json
import os
import shutil
import struct
import sys
import urllib.request
import zipfile


def varint(buf, i):
    value = shift = 0
    while True:
        byte = buf[i]
        i += 1
        value |= (byte & 0x7F) << shift
        shift += 7
        if not byte & 0x80:
            return value, i


folder, name, url = sys.argv[1:]
os.makedirs(folder, exist_ok=True)
build_path = os.path.join(folder, "BUILD.gn")
index_path = os.path.join(folder, "bundled.json")
if not os.path.exists(build_path):
    shutil.copy(os.path.join(os.path.dirname(os.path.abspath(__file__)), "BUILD.gn"), build_path)

crx = f"{name}.crx"
path = os.path.join(folder, crx)
urllib.request.urlretrieve(url, path)
data = open(path, "rb").read()
header = data[12:12 + struct.unpack("<I", data[8:12])[0]]
i = 0
while i < len(header):
    key, i = varint(header, i)
    length, i = varint(header, i)
    if key >> 3 == 10000:
        break
    i += length

ext_id = "".join(chr(97 + n) for b in header[i + 2:i + 18] for n in (b >> 4, b & 15))
version = json.load(zipfile.ZipFile(path).open("manifest.json"))["version"]
print(f"{crx}: {ext_id} {version}")

index = json.load(open(index_path)) if os.path.exists(index_path) else {}
index = {k: v for k, v in index.items() if v["external_crx"] != crx}
assert ext_id not in index, f"{crx} shares id {ext_id}, key required"
index[ext_id] = {"external_crx": crx, "external_version": version}
open(index_path, "w").write(json.dumps(index, indent=2) + "\n")

build = open(build_path).read()
for line, entry in [("renaming_sources = [", crx),
                    ("renaming_destinations = [", f"extensions/{crx}")]:
    head, rest = build.split(line, 1)
    body, tail = rest.split("  ]", 1)
    if f'"{entry}",' not in body:
        body += f'    "{entry}",\n'
    build = head + line + body + "  ]" + tail
open(build_path, "w").write(build)
