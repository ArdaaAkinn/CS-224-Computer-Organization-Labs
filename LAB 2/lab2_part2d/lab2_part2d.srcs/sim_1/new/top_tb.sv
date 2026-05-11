`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.04.2026 21:55:08
// Design Name: 
// Module Name: top_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module top_tb();

    // Inputs
    logic clk;
    logic reset;

    // Outputs
    logic [31:0] writedata;
    logic [31:0] dataadr;
    logic [31:0] pc;
    logic [31:0] instr;
    logic [31:0] readdata;
    logic memwrite;

    // Instantiate the Unit Under Test (UUT)
    top uut (
        .clk(clk),
        .reset(reset),
        .writedata(writedata),
        .dataadr(dataadr),
        .pc(pc),
        .instr(instr),
        .readdata(readdata),
        .memwrite(memwrite)
    );

    // Clock generation (100 MHz -> 10ns period)
    always begin
        clk = 0;
        #5;
        clk = 1;
        #5;
    end

    // Test sequence
    initial begin
        // Initialize inputs
        reset = 1;
        
        // Wait 22 ns for global reset to settle
        #22;
        reset = 0;
        
        $display("--- Simulation Started ---");
        
        // Monitor the execution
        $monitor("Time: %0t | PC: %h | Instr: %h | ALUOut/Addr: %h | WriteData: %h | MemWrite: %b", 
                 $time, pc, instr, dataadr, writedata, memwrite);
                 
        // Wait for the program to reach the infinite loop at address 0x48
        // or a timeout (to prevent hanging if something goes wrong).
        wait (pc == 32'h00000048);
        
        // Let it spin in the loop for a few cycles to observe it
        #50;
        
        $display("--- Simulation Finished ---");
        $display("Final Check: Verifying data written to memory...");
        
        // At address 0x44, the code executes: sw $v0, 0x54($zero)
        // Let's see if RAM[0x54] contains the expected value.
        // In word-aligned indexing, 0x54 >> 2 = 21.
        if (uut.dmem.RAM[21] === 32'h00000001) begin
            $display("SUCCESS: RAM[0x54] contains correct value (0x01).");
        end else begin
            $display("FAILURE: RAM[0x54] contains %h (Expected 0x01).", uut.dmem.RAM[21]);
        end
        
        $finish;
    end
      
endmodule