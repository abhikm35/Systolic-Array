## NxN Systolic Array Accelerator (SystemVerilog)

Small educational **NxN fixed‑point systolic array accelerator** for matrix–matrix multiplication (MMM), written in **SystemVerilog**.  

- **Technologies**: SystemVerilog RTL, Python/MATLAB for stimulus and golden models, any modern SV simulator (Xcelium / VCS / Questa / Verilator).
- **Use cases**: Experiment with systolic arrays, instruction‑driven MMM workloads, and basic PPA trade‑offs.

---

## Features

- Parameterizable **NxN** systolic array architecture with 16‑bit fixed‑point MACs.
- Separate on‑chip SRAMs for input matrix `A`, weight matrix `B`, output matrix `O`, and instruction memory `I`.
- Simple memory‑mapped top‑level interface suitable for a small CPU, firmware, or pure testbench.
- Compact integer **[a, b, c]** instruction format that encodes chained matrix–matrix multiplies.
- Designed to support experiments with array size, data width, and throughput/area trade‑offs.

---

## Quick Start

1. **Clone**
   - `git clone <this-repo-url>`
   - `cd Systolic_Array`

2. **Choose a simulator**
   - Any SystemVerilog‑capable simulator should work (Xcelium, VCS, Questa, Verilator, etc.).

3. **Compile and run** (example)
   - Compile `rtl/top.sv` together with your testbench (for example `tb/tb_top.sv` once implemented).
   - In the testbench, preload `memA`, `memB`, and `memI`, pulse `ap_start`, wait for `ap_done`, then read `memO`.

4. **Compare against a golden model**
   - Use Python (NumPy) or MATLAB scripts to generate random fixed‑point matrices and expected MMM results.

---

## Top‑Level Architecture

The design is organized into four conceptual blocks:

- **Systolic Array Core**
  - Parameterizable **NxN** 2‑D array of processing elements (PEs).
  - Each PE performs **16‑bit fixed‑point multiply‑accumulate (MAC)**.
  - Input activations and weights are streamed from orthogonal directions and accumulated as they propagate.

- **On‑Chip Memories**
  - `memA`: Input matrix \(A\) (size up to `DEPTH_A` words of width `DATA_W`).
  - `memB`: Weight matrix \(B\) (size up to `DEPTH_B`).
  - `memO`: Output matrix \(O\) (size up to `DEPTH_O`).
  - `memI`: Instruction memory for the MMM instruction stream (depth `DEPTH_I`, width `INSTR_W`).

- **Instruction Controller** (to be extended)
  - Reads instructions from `memI`.
  - Decodes integer triples **[a, b, c]** that describe one matrix–matrix multiply:
    - Input matrix:  \(a \times b\)
    - Weight matrix: \(b \times c\)
    - Output matrix: \(a \times c\)
  - Sequences reads from `memA` and `memB`, streams tiles into the systolic array, and writes results into `memO`.
  - Supports chained MMMs (e.g., instruction sequence `[32, 16, 64, 8, 16, 0]`) to model small multi‑layer MLPs.

- **Top‑Level Wrapper (`rtl/top.sv`)**
  - Instantiates data and instruction memories.
  - Will instantiate the controller and systolic array core.
  - Provides a clean external interface for integration with a CPU or testbench.

---

## Top‑Level Interface

The `top` module exposes a **memory‑style interface**:

- **Global control**
  - `clk`: Clock.
  - `rst_n`: Active‑low synchronous reset.
  - `ap_start`: Pulse signal to start processing the instruction stream.
  - `ap_done`: Level signal indicating all MMM operations are complete.

- **Input Matrix A Write Port**
  - `addrA[ADDR_A_W-1:0]`: Address into `memA`.
  - `enA`: Write enable.
  - `dataA[DATA_W-1:0]`: Data to be written.

- **Weight Matrix B Write Port**
  - `addrB[ADDR_B_W-1:0]`: Address into `memB`.
  - `enB`: Write enable.
  - `dataB[DATA_W-1:0]`: Data to be written.

- **Instruction Memory I Write Port**
  - `addrI[ADDR_I_W-1:0]`: Address into `memI`.
  - `enI`: Write enable.
  - `dataI[INSTR_W-1:0]`: Encoded instruction word.

- **Output Matrix O Read Port**
  - `addrO[ADDR_O_W-1:0]`: Address into `memO`.
  - `dataO[DATA_W-1:0]`: Data read from result memory.

All memories are modeled as **simple synchronous RAMs** inferred from arrays and `always_ff` write and read processes.

---

## Instruction Format

The **instruction stream** is a sequence of **non‑zero integers** stored in `memI`.  
Each group of three consecutive integers **[a, b, c]** specifies one matrix–matrix multiplication (**MMM**):

- Input matrix \(A\): \(a \times b\)
- Weight matrix \(B\): \(b \times c\)
- Output matrix \(O\): \(a \times c\)

The integer **0** marks the end of the instruction sequence (no more MMMs).

### Example: Chained MMMs

Given the instruction sequence:

```text
[32, 16, 64, 8, 16, 0]
```

This encodes three chained MMMs, where each output becomes the next input:

1. First MMM  
   - Input:  \(32 \times 16\)  
   - Weights: \(16 \times 64\)  
   - Output: \(32 \times 64\)

2. Second MMM  
   - Input:  \(32 \times 64\) (output of previous step)  
   - Weights: \(64 \times 8\)  
   - Output: \(32 \times 8\)

3. Third MMM  
   - Input:  \(32 \times 8\)  
   - Weights: \(8 \times 16\)  
   - Output: \(32 \times 16\)

This models a small 3‑layer MLP with matrix multiplies back‑to‑back.

---

## Testbench & Workload Generation

Although a full testbench is still under construction, the intended verification flow is:

- **Stimulus Generation**
  - Use **Python** or **MATLAB** to generate random fixed‑point matrices for \(A\), \(B\), and instruction sequences.
  - Quantize floating‑point data to 16‑bit fixed point to match `DATA_W`.

- **Golden Model**
  - Use numpy/MATLAB to compute expected MMM results and chained GEMM sequences.
  - Compare the RTL outputs in `memO` against the golden results sample‑by‑sample.

- **SystemVerilog Testbench**
  - Write testbench code to:
    - Drive writes into `memA`, `memB`, and `memI` through the top‑level ports.
    - Pulse `ap_start`, wait for `ap_done`.
    - Read back `memO` via `addrO`/`dataO` and compare to the golden model.

---

## Simulation

This project is simulator‑agnostic and should work with any modern **SystemVerilog** simulator (e.g., Cadence Xcelium, Synopsys VCS, Mentor Questa, or Verilator with appropriate flags).

General steps:

1. **Compile**
   - Include all relevant RTL and testbench files, for example:
     - `rtl/top.sv`
     - `tb/tb_top.sv` (when implemented)

2. **Run**
   - Load the generated hex/binary/vector files for matrices and instructions.
   - Run simulation until `ap_done` asserts.

3. **Inspect Results**
   - Dump waveforms (e.g., VCD/FSDB) if desired.
   - Compare memory `memO` contents against the golden model.

Please adapt the exact compile/run commands to your simulator of choice.

---

## Extending the Design

Some extensions and TODOs:

- Add **performance counters**:
  - Track number of cycles per MMM.
  - Report effective throughput (GOp/s) for different N and clock frequencies.

- Explore **PPA trade‑offs**:
  - Synthesize for an FPGA or ASIC‑like library.
  - Sweep N and data width and compare area, frequency, and energy.

---

## Repository Layout

- `rtl/`
  - Core RTL, including `top.sv` for the NxN systolic array accelerator.
- `tb/`
  - SystemVerilog testbench files (e.g., `tb_top.sv`).
- `scripts/`
  - Placeholder for Python/MATLAB scripts to generate fixed‑point inputs, instructions, and golden results.

---
