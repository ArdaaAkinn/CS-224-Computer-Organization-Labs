`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.04.2026 20:58:28
// Design Name: 
// Module Name: aludec_tb
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


module alu_tb();

    logic [31:0] a, b;
    logic [2:0] alucont;
    logic [31:0] result;
    logic zero;

    alu uut (
        .a(a),
        .b(b),
        .alucont(alucont),
        .result(result),
        .zero(zero)
    );

    initial begin
      
        a = 10; b = 5; alucont = 3'b010; #10;
        $display("ADD result = %d", result);

        a = 10; b = 5; alucont = 3'b110; #10;
        $display("SUB result = %d", result);

        a = 6; b = 3; alucont = 3'b000; #10;
        $display("AND result = %b", result);

        a = 6; b = 3; alucont = 3'b001; #10;
        $display("OR result = %b", result);

        a = 3; b = 7; alucont = 3'b111; #10;
        $display("SLT result = %d", result);

        // ZERO test
        a = 5; b = 5; alucont = 3'b110; #10;
        $display("ZERO = %b", zero);

        $finish;
    end

endmodule
