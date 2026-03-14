#!/usr/bin/env python3
"""
Generate test data and golden reference for the systolic array testbench.

Writes hex files that SystemVerilog $readmemh can load:
  - memA.hex   : input matrix A (row-major), 16-bit hex per line
  - memB.hex   : weight matrix B (stored column-major for RTL feed order)
  - memI.hex   : instruction stream [a, b, c, ..., 0], 16-bit hex per line
  - golden_O.hex : expected output C = A @ B, row-major, 16-bit hex per line

Usage:
  python3 scripts/gen_test_data.py [--out-dir DIR]
  Default out-dir is tb/data/ (relative to project root).

Run from project root:  python3 scripts/gen_test_data.py
"""

import argparse
import numpy as np
from pathlib import Path


# Systolic array size (must match RTL parameter N)
N = 4
# Data width in bits (RTL uses 16-bit; we take lower 16 bits of result)
DATA_W = 16
MAX_VAL = (1 << (DATA_W - 1)) - 1   # 32767 for signed 16-bit
MIN_VAL = -(1 << (DATA_W - 1))     # -32768


def to_s16(x: int) -> int:
    """Clamp and represent as signed 16-bit."""
    return max(MIN_VAL, min(MAX_VAL, int(np.round(x)))) & 0xFFFF


def write_hex_lines(path: Path, values: list) -> None:
    """Write one 16-bit hex value per line (no 0x prefix, 4 hex digits)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        for v in values:
            f.write(f"{v & 0xFFFF:04X}\n")


def main():
    parser = argparse.ArgumentParser(description="Generate systolic array test data and golden output.")
    parser.add_argument("--out-dir", type=str, default="tb/data", help="Output directory for .hex files")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for reproducibility")
    args = parser.parse_args()
    out_dir = Path(args.out_dir)
    np.random.seed(args.seed)

    # -------------------------------------------------------------------------
    # 1. Generate A (N x N) and B (N x N) with small integers for clear math
    # -------------------------------------------------------------------------
    A = np.random.randint(-3, 4, (N, N)).astype(np.int64)
    B = np.random.randint(-3, 4, (N, N)).astype(np.int64)

    # -------------------------------------------------------------------------
    # 2. Golden output: C = A @ B (matrix multiply); keep 16-bit range
    # -------------------------------------------------------------------------
    C = A @ B
    C_flat = C.flatten(order="C")  # row-major
    golden_O = [to_s16(x) for x in C_flat]

    # -------------------------------------------------------------------------
    # 3. Instruction stream: one MMM with dimensions [N, N, N], then 0
    # -------------------------------------------------------------------------
    instr = [N, N, N, 0]
    instr_hex = [x & 0xFFFF for x in instr]

    # -------------------------------------------------------------------------
    # 4. Memory layout for RTL
    #    - A: row-major  A[0,0], A[0,1], ..., A[0,N-1], A[1,0], ...
    #    - B: RTL reads B in column-major order: B[0,0], B[1,0], ..., B[N-1,0], B[0,1], ...
    #         So we store B column-major in the file to match RTL addrB_r order.
    # -------------------------------------------------------------------------
    A_flat = A.flatten(order="C")
    A_hex = [to_s16(x) for x in A_flat]

    # B in column-major: column 0, then column 1, ...
    B_colmajor = B.flatten(order="F")
    B_hex = [to_s16(x) for x in B_colmajor]

    # -------------------------------------------------------------------------
    # 5. Write hex files (one value per line for $readmemh)
    # -------------------------------------------------------------------------
    write_hex_lines(out_dir / "memA.hex", A_hex)
    write_hex_lines(out_dir / "memB.hex", B_hex)
    write_hex_lines(out_dir / "memI.hex", instr_hex)
    write_hex_lines(out_dir / "golden_O.hex", golden_O)

    # Optional: human-readable summary
    summary = out_dir / "summary.txt"
    with open(summary, "w") as f:
        f.write("Systolic array test data summary\n")
        f.write("================================\n")
        f.write(f"N = {N}, seed = {args.seed}\n\n")
        f.write("A (row-major):\n")
        f.write(np.array2string(A) + "\n\n")
        f.write("B:\n")
        f.write(np.array2string(B) + "\n\n")
        f.write("Golden C = A @ B (row-major):\n")
        f.write(np.array2string(C) + "\n\n")
        f.write("Instructions: " + str(instr) + "\n")
    print(f"Wrote {out_dir}/memA.hex, memB.hex, memI.hex, golden_O.hex, summary.txt")


if __name__ == "__main__":
    main()
