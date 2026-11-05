#!/usr/bin/env python3
"""Экспорт RCDATA №1 из PE-файла без исполнения кода образца."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import pefile


def extract_rcdata(pe_path: Path) -> bytes:
    pe = pefile.PE(str(pe_path), fast_load=False)
    try:
        for resource_type in pe.DIRECTORY_ENTRY_RESOURCE.entries:
            if resource_type.id != 10:  # RT_RCDATA
                continue
            for resource_name in resource_type.directory.entries:
                if resource_name.id != 1:
                    continue
                for language in resource_name.directory.entries:
                    data = language.data.struct
                    return pe.get_data(data.OffsetToData, data.Size)
    finally:
        pe.close()
    raise ValueError("RCDATA №1 не найден")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pe", type=Path, help="путь к выданному преподавателем PE-файлу")
    parser.add_argument("output", type=Path, help="новый файл для RCDATA")
    args = parser.parse_args()
    if args.output.exists():
        parser.error(f"файл уже существует: {args.output}")
    blob = extract_rcdata(args.pe)
    args.output.write_bytes(blob)
    print(f"RCDATA №1: {len(blob)} байт")
    print(f"SHA-256: {hashlib.sha256(blob).hexdigest()}")


if __name__ == "__main__":
    main()
