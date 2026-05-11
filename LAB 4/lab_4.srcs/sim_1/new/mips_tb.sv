// ============================================================
// CS224 - Lab 4 - Pipelined MIPS Testbench
// Section: 6
// Arda Akın - 22402316
// April 10, 2026
// ============================================================

`timescale 1ns/1ps

module mips_tb();

    logic        clk, reset;
    logic [31:0] pc, aluout, writedata, instrOut, resultW;
    logic        memwrite;

    // Unit Under Test (UUT)
    mips dut(
        .clk(clk),
        .reset(reset),
        .pc(pc),
        .memwrite(memwrite),
        .aluout(aluout),
        .writedata(writedata),
        .instrOut(instrOut),
        .resultW(resultW)
    );

    // Clock Generation (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count;
    integer fail_count;
    integer cyc;

    logic [31:0] actual;
    logic [31:0] mem_val;

    // 1. Register Write Monitor: Her register yazma işlemini konsola basar
    always @(negedge clk) begin
        if (!reset && dut.dp.RegWriteW && dut.dp.WriteRegW != 0)
            $display("  >> [WB] REG[%0d] <= %08h  (PC=%08h)",
                     dut.dp.WriteRegW, dut.dp.ResultW, pc);
    end

    // 2. Cycle-by-Cycle Pipeline Monitor: Tüm aşamaları ve hazard sinyallerini izler
    always @(posedge clk) begin
        if (!reset) begin
            cyc = cyc + 1;
            $display("CYC%3d | PC=%08h | INSTR=%08h | ALU=%08h | MW=%b | StallF=%b | FlushD=%b | FlushE=%b | FwdAE=%b | FwdBE=%b",
                cyc, pc, instrOut, aluout, memwrite,
                dut.dp.StallF, dut.dp.FlushD, dut.dp.FlushE,
                dut.dp.ForwardAE, dut.dp.ForwardBE);
        end
    end

    initial begin
        // Başlangıç değerleri
        pass_count = 0;
        fail_count = 0;
        cyc = 0;

        $display("================================================");
        $display(" CS224 Lab 4 - Pipelined MIPS Testbench");
        $display(" Arda Akin  22402316  Section 6");
        $display("================================================");

        // Reset İşlemi (3 çevrim)
        reset = 1;
        repeat(3) @(posedge clk);
        #1; reset = 0;

        // İşlemcinin tüm komutları bitirmesi için yeterli süre (80 çevrim)
        repeat(80) @(posedge clk);

        // 3. Register Dosyası Özeti
        $display("\n================================================");
        $display(" REGISTER FILE SNAPSHOT (FINAL):");
        $display("  $t0 ($8)  = %08h", dut.dp.rf.rf[8]);
        $display("  $t1 ($9)  = %08h", dut.dp.rf.rf[9]);
        $display("  $t2 ($10) = %08h", dut.dp.rf.rf[10]);
        $display("  $t3 ($11) = %08h", dut.dp.rf.rf[11]);
        $display("  $t4 ($12) = %08h", dut.dp.rf.rf[12]);
        $display("  $s0 ($16) = %08h", dut.dp.rf.rf[16]);
        $display("  $s1 ($17) = %08h", dut.dp.rf.rf[17]);
        $display("  $s2 ($18) = %08h", dut.dp.rf.rf[18]);
        $display("  $s3 ($19) = %08h", dut.dp.rf.rf[19]);
        $display("  MEM[0x50] = %08h", dut.dp.dm1.RAM[20]);
        $display("================================================");

        // ---- OTOMATİK TEST KONTROLLERİ ----

        $display("\n---- TEST 1: Basic Arithmetic & Data Flow ----");
        actual = dut.dp.rf.rf[8]; // $t0
        if (actual === 32'h00000005) begin $display("  [PASS] $t0 = 5"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] $t0 = %h (exp: 5)", actual); fail_count = fail_count + 1; end

        $display("\n---- TEST 2: Forwarding Unit (EX to EX) ----");
        actual = dut.dp.rf.rf[17]; // $s1 = s0 + s0 (7 + 7)
        if (actual === 32'h0000000e) begin $display("  [PASS] $s1 = 14 (0x0E)"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] $s1 = %h (exp: 0E)", actual); fail_count = fail_count + 1; end

        $display("\n---- TEST 3: Load-Use Stall & Memory ----");
        mem_val = dut.dp.dm1.RAM[20]; // 0x50 adresi
        if (mem_val === 32'h0000000a) begin $display("  [PASS] MEM[0x50] = 10 (0x0A)"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] MEM[0x50] = %h (exp: 0A)", mem_val); fail_count = fail_count + 1; end

        actual = dut.dp.rf.rf[19]; // lw sonrası kullanılan veri
        if (actual === 32'h00000014) begin $display("  [PASS] $s3 = 20 (0x14)"); pass_count = pass_count + 1; end
        else begin $display("  [FAIL] $s3 = %h (exp: 14)", actual); fail_count = fail_count + 1; end

        $display("\n---- TEST 4: Branch Hazard (Flush) ----");
        actual = dut.dp.rf.rf[10]; // Skip edilmesi gereken komut ($t2)
        if (actual !== 32'h00000063) begin 
            $display("  [PASS] Branch Flush Success: $t2 did not become 99 (0x63)"); 
            pass_count = pass_count + 1; 
        end else begin 
            $display("  [FAIL] Branch Flush FAILED: $t2 became 99!"); 
            fail_count = fail_count + 1; 
        end

        // Final Raporu
        $display("\n================================================");
        $display(" FINAL RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display(" STATUS: ALL SYSTEMS GO!");
        else
            $display(" STATUS: ISSUES DETECTED - Review cycle log above.");
        $display("================================================\n");

        $finish;
    end

endmodule