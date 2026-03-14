// C++ main function for Verilator simulation
// This file instantiates the SystemVerilog testbench and runs the simulation

#include "Vtb_top.h"
#include "verilated.h"
#include <iostream>

int main(int argc, char** argv) {
    // Initialize Verilator
    Verilated::commandArgs(argc, argv);
    
    // Create an instance of the testbench
    Vtb_top* top = new Vtb_top;
    
    // Run simulation until $finish is called
    // With --timing, Verilator handles all timing constructs automatically
    while (!Verilated::gotFinish()) {
        top->eval();
    }
    
    // Final model evaluation
    top->final();
    
    // Clean up
    delete top;
    
    return 0;
}
