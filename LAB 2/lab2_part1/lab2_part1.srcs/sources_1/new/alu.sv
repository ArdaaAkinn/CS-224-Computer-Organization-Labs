`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.04.2026 20:55:01
// Design Name: 
// Module Name: alu
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

module alu(input  logic [31:0] a, b,  
           input  logic [2:0]  alucont,  
           output logic [31:0] result, 
           output logic zero); 
// ALU operations can be seen in the table 5.1 
    always_comb 
        case(alucont) 
            3'b010: result = a + b; 
            3'b110: result = a - b; 
            3'b000: result = a & b; 
            3'b001: result = a | b; 
            3'b111: result = (a < b) ? 1 : 0; 
            default: result = {32{1'bx}}; 
        endcase 
     
    assign zero = (result == 0) ? 1'b1 : 1'b0; 
endmodule
