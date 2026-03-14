# Testbench and Python-generated data

The testbench loads data from **hex files** produced by a **Python** script and compares the RTL output to a **golden** file from the same script.

## Flow

1. **Python** (`scripts/gen_test_data.py`) generates:
   - `tb/data/memA.hex`   – input matrix A (row-major)
   - `tb/data/memB.hex`   – weight matrix B (column-major for RTL)
   - `tb/data/memI.hex`   – instruction stream `[a, b, c, 0]`
   - `tb/data/golden_O.hex` – expected output C = A×B (row-major)
   - `tb/data/summary.txt` – human-readable matrices and instructions

2. **SystemVerilog testbench** (`tb/tb_top.sv`):
   - Uses `$readmemh("tb/data/memA.hex", ...)` etc. to load those files.
   - Writes A, B, I into the DUT via the top-level ports.
   - Pulses `ap_start`, waits for `ap_done`.
   - Reads `memO` via `addrO`/`dataO` and compares each word to `golden_O.hex`.
   - Reports **PASS** or **FAIL** and any mismatches.

## How to run

From the **project root** (`Systolic_Array/`):

```bash
# 1. Generate data and golden (Python)
python3 scripts/gen_test_data.py

# 2. Run simulation (example: Verilator)
verilator --cc --exe -o Vtop rtl/top.sv rtl/controller.sv rtl/systolic_array.sv rtl/pe.sv tb/tb_top.sv
# ... then build and run the C++ harness, or use your simulator's compile/run.
```

For **Icarus Verilog**:

```bash
iverilog -o sim -s tb_top rtl/top.sv rtl/controller.sv rtl/systolic_array.sv rtl/pe.sv tb/tb_top.sv
vvp sim
```

For **Xcelium/VCS/Questa**: compile all `rtl/*.sv` and `tb/tb_top.sv`, run with cwd = project root so that `tb/data/*.hex` paths resolve.

## Regenerating data

To change matrices or seed:

```bash
python3 scripts/gen_test_data.py --out-dir tb/data --seed 123
```

Then re-run simulation; the testbench will read the new hex files.
