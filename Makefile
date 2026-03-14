# Makefile for Systolic Array RTL Project
# Supports multiple SystemVerilog simulators

# ============================================================================
# Configuration
# ============================================================================

# Simulator selection: verilator, icarus, xcelium, vcs, questa
SIMULATOR ?= verilator

# RTL source files
RTL_DIR = rtl
TB_DIR = tb
RTL_FILES = $(RTL_DIR)/top.sv \
            $(RTL_DIR)/controller.sv \
            $(RTL_DIR)/systolic_array.sv \
            $(RTL_DIR)/pe.sv

TB_FILES = $(TB_DIR)/tb_top.sv
TB_CPP_FILES = $(TB_DIR)/tb_top_main.cpp

ALL_SV_FILES = $(RTL_FILES) $(TB_FILES)

# Test data generation script
GEN_DATA_SCRIPT = scripts/gen_test_data.py
DATA_DIR = tb/data

# Build directories
BUILD_DIR = build
VERILATOR_DIR = $(BUILD_DIR)/verilator
ICARUS_DIR = $(BUILD_DIR)/icarus

# ============================================================================
# Default target
# ============================================================================

.PHONY: all
all: help

# ============================================================================
# Python dependencies
# ============================================================================

.PHONY: install-deps
install-deps:
	@echo "[MAKE] Installing Python dependencies..."
	@if ! python3 -m pip --version >/dev/null 2>&1; then \
		echo "[ERROR] pip is not installed. Please install it first:"; \
		echo "  sudo apt-get install python3-pip  # On Debian/Ubuntu"; \
		echo "  or: python3 -m ensurepip --upgrade"; \
		exit 1; \
	fi
	@python3 -m pip install --user -r requirements.txt || \
	 python3 -m pip install -r requirements.txt
	@echo "[MAKE] Dependencies installed."

.PHONY: check-deps
check-deps:
	@python3 -c "import numpy" 2>/dev/null || \
	 (echo "[ERROR] numpy not found. Run 'make install-deps' to install dependencies." && exit 1)

# ============================================================================
# Test data generation
# ============================================================================

.PHONY: data
data: check-deps
	@echo "[MAKE] Generating test data..."
	@python3 $(GEN_DATA_SCRIPT)
	@echo "[MAKE] Test data generated in $(DATA_DIR)/"

# ============================================================================
# Verilator targets
# ============================================================================

.PHONY: verilator
verilator: data $(VERILATOR_DIR)/Vtop
	@echo "[MAKE] Running Verilator simulation..."
	@cd $(CURDIR) && $(VERILATOR_DIR)/Vtop

$(VERILATOR_DIR)/Vtop: $(ALL_SV_FILES) $(TB_CPP_FILES) | $(VERILATOR_DIR)
	@echo "[MAKE] Compiling with Verilator..."
	@if ! command -v verilator >/dev/null 2>&1; then \
		echo "[ERROR] Verilator is not installed."; \
		echo "  Install with: sudo apt-get install verilator"; \
		echo "  Or download from: https://www.veripool.org/verilator/"; \
		exit 1; \
	fi
	@if ! command -v g++ >/dev/null 2>&1; then \
		echo "[ERROR] g++ (C++ compiler) is not installed."; \
		echo "  Install with: sudo apt-get install g++"; \
		exit 1; \
	fi
	verilator --cc --exe \
		--top-module tb_top \
		--Mdir $(VERILATOR_DIR) \
		--build \
		--timing \
		-j $$(nproc) \
		-Wall \
		-Wno-fatal \
		$(CURDIR)/$(RTL_DIR)/top.sv \
		$(CURDIR)/$(RTL_DIR)/controller.sv \
		$(CURDIR)/$(RTL_DIR)/systolic_array.sv \
		$(CURDIR)/$(RTL_DIR)/pe.sv \
		$(CURDIR)/$(TB_DIR)/tb_top.sv \
		$(CURDIR)/$(TB_DIR)/tb_top_main.cpp
	@mv $(VERILATOR_DIR)/Vtb_top $(VERILATOR_DIR)/Vtop || true

# ============================================================================
# Icarus Verilog targets
# ============================================================================

.PHONY: icarus
icarus: data $(ICARUS_DIR)/sim
	@echo "[MAKE] Running Icarus Verilog simulation..."
	cd $(ICARUS_DIR) && vvp sim

$(ICARUS_DIR)/sim: $(ALL_SV_FILES) | $(ICARUS_DIR)
	@echo "[MAKE] Compiling with Icarus Verilog..."
	@if ! command -v iverilog >/dev/null 2>&1; then \
		echo "[ERROR] Icarus Verilog is not installed."; \
		echo "  Install with: sudo apt-get install iverilog"; \
		exit 1; \
	fi
	iverilog -o $(ICARUS_DIR)/sim \
		-s tb_top \
		-g2012 \
		$(ALL_SV_FILES)

# ============================================================================
# Commercial simulator targets (require license)
# ============================================================================

.PHONY: xcelium
xcelium: data
	@echo "[MAKE] Compiling with Cadence Xcelium..."
	@mkdir -p $(BUILD_DIR)/xcelium
	cd $(BUILD_DIR)/xcelium && \
	xrun -64bit -sv -access +rwc \
		-top tb_top \
		$(ALL_SV_FILES)
	@echo "[MAKE] Run simulation with: cd $(BUILD_DIR)/xcelium && xrun -R"

.PHONY: vcs
vcs: data
	@echo "[MAKE] Compiling with Synopsys VCS..."
	@mkdir -p $(BUILD_DIR)/vcs
	cd $(BUILD_DIR)/vcs && \
	vcs -full64 -sverilog \
		-top tb_top \
		+incdir+$(RTL_DIR) \
		+incdir+$(TB_DIR) \
		$(ALL_SV_FILES)
	@echo "[MAKE] Run simulation with: cd $(BUILD_DIR)/vcs && ./simv"

.PHONY: questa
questa: data
	@echo "[MAKE] Compiling with Mentor Questa..."
	@mkdir -p $(BUILD_DIR)/questa
	cd $(BUILD_DIR)/questa && \
	vlog -sv \
		+incdir+$(RTL_DIR) \
		+incdir+$(TB_DIR) \
		$(ALL_SV_FILES) && \
	vsim -c tb_top -do "run -all; quit"
	@echo "[MAKE] Run GUI with: cd $(BUILD_DIR)/questa && vsim tb_top"

# ============================================================================
# Generic run target (uses SIMULATOR variable)
# ============================================================================

.PHONY: run
run: $(SIMULATOR)

# ============================================================================
# Utility targets
# ============================================================================

.PHONY: clean
clean:
	@echo "[MAKE] Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "[MAKE] Clean complete."

.PHONY: clean-data
clean-data:
	@echo "[MAKE] Cleaning test data..."
	@rm -rf $(DATA_DIR)/*.hex $(DATA_DIR)/*.txt
	@echo "[MAKE] Test data cleaned."

.PHONY: clean-all
clean-all: clean clean-data

.PHONY: help
help:
	@echo "======================================================================"
	@echo "Systolic Array RTL - Makefile Help"
	@echo "======================================================================"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "  make install-deps  - Install Python dependencies (numpy)"
	@echo "  make data          - Generate test data (required before simulation)"
	@echo "  make verilator     - Compile and run with Verilator (open-source)"
	@echo "  make icarus        - Compile and run with Icarus Verilog (open-source)"
	@echo "  make xcelium       - Compile with Cadence Xcelium (requires license)"
	@echo "  make vcs           - Compile with Synopsys VCS (requires license)"
	@echo "  make questa        - Compile and run with Mentor Questa (requires license)"
	@echo "  make run           - Run with default simulator (SIMULATOR=verilator)"
	@echo "  make clean         - Remove build artifacts"
	@echo "  make clean-data    - Remove generated test data"
	@echo "  make clean-all     - Remove both build artifacts and test data"
	@echo "  make help          - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make install-deps           # Install Python dependencies first"
	@echo "  make data                   # Generate test data"
	@echo "  make verilator              # Run with Verilator"
	@echo "  make SIMULATOR=icarus run   # Run with Icarus Verilog"
	@echo "  make clean-all              # Clean everything"
	@echo ""
	@echo "Installing simulators:"
	@echo "  sudo apt-get install verilator    # For Verilator"
	@echo "  sudo apt-get install iverilog    # For Icarus Verilog"
	@echo ""
	@echo "Current simulator: $(SIMULATOR)"
	@echo "======================================================================"

# ============================================================================
# Directory creation
# ============================================================================

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(VERILATOR_DIR): | $(BUILD_DIR)
	@mkdir -p $(VERILATOR_DIR)

$(ICARUS_DIR): | $(BUILD_DIR)
	@mkdir -p $(ICARUS_DIR)
