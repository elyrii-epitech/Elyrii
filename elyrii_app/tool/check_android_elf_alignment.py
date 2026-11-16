"""Validate every ELF PT_LOAD segment in a release APK/AAB for 16 KiB pages.

APK ZIP alignment is a separate `zipalign -c -P 16 -v 4` check.
"""
import argparse
import struct
import zipfile


def check(data):
    if data[:4] != b"\x7fELF" or data[5] not in (1, 2):
        raise ValueError("Not a supported ELF")
    endian = "<" if data[5] == 1 else ">"
    if data[4] == 2:
        offset = struct.unpack_from(endian + "Q", data, 32)[0]
        size, count = struct.unpack_from(endian + "HH", data, 54)
        fmt = endian + "IIQQQQQQ"
        indices = (2, 3, 7)
    elif data[4] == 1:
        offset = struct.unpack_from(endian + "I", data, 28)[0]
        size, count = struct.unpack_from(endian + "HH", data, 42)
        fmt = endian + "IIIIIIII"
        indices = (1, 2, 7)
    else:
        raise ValueError("Unknown ELF class")
    loads = 0
    for index in range(count):
        header = struct.unpack_from(fmt, data, offset + index * size)
        if header[0] != 1:
            continue
        loads += 1
        file_offset, address, alignment = (header[i] for i in indices)
        if alignment < 16384 or alignment % 16384 or (address - file_offset) % alignment:
            raise ValueError(f"PT_LOAD segment {index} has incompatible alignment {alignment}")
    if loads == 0:
        raise ValueError("ELF contains no loadable segments")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle")
    args = parser.parse_args()
    with zipfile.ZipFile(args.bundle) as archive:
        libraries = [n for n in archive.namelist() if n.endswith(".so")]
        if not libraries:
            raise ValueError("No native libraries found")
        for name in libraries:
            try:
                check(archive.read(name))
            except ValueError as error:
                raise ValueError(name + ": " + str(error)) from error
    print(f"16 KiB ELF alignment validated for {len(libraries)} native libraries.")


if __name__ == "__main__":
    main()
