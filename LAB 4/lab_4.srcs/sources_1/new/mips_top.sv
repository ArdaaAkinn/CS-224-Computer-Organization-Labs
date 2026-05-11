// ============================================================
// CS224 - Lab 4 - Pipelined MIPS Testbench
// Section: 6
// Arda Akın
// 22402316
// April 10, 2026
//
// HOW TO USE:
//   Simulate this file together with 22402316_Arda_Akin_06_LAB_4.txt
//   in Vivado / ModelSim. The testbench will automatically:
//     1. Run all 4 test programs
//     2. Check expected register values
//     3. Print PASS / FAIL for each test
//     4. Print a final summary
//
// EXPECTED RESULTS:
//   Test 1 - No Hazards      : $t3 ($11) = 8
//   Test 2 - EX Forwarding   : $s1 ($17) = 14
//   Test 3 - Load-Use Stall  : $s3 ($19) = 20
//   Test 4 - Branch + Jump   : $t3 ($11) = 42, $t2 ($10) = 0
// ============================================================

`timescale 1ns/1ps

module testbench_pipelined_mips();

    // ---- DUT signals ----
    logic        clk, reset;
    logic [31:0] pc, aluout, writedata, instrOut, resultW;
    logic        memwrite;

    // ---- Instantiate DUT ----
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

    // ---- Clock: 10 ns period ----
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Test tracking ----
    integer pass_count = 0;
    integer fail_count = 0;
    integer cycle_num  = 0;

    // ---- Task: check a register value ----
    // Directly reads the regfile inside the datapath hierarchy
    task automatic check_reg(
        input string   test_name,
        input [4:0]    reg_num,
        input [31:0]   expected
    );
        logic [31:0] actual;
        actual = dut.dp.rf.rf[reg_num];
        if (actual === expected) begin
            $display("  [PASS] %s : $%0d = 0x%08h", test_name, reg_num, actual);
            pass_count++;
        end else begin
            $display("  [FAIL] %s : $%0d = 0x%08h  (expected 0x%08h)",
                     test_name, reg_num, actual, expected);
            fail_count++;
        end
    endtask

    // ---- Task: wait N clock cycles ----
    task automatic wait_cycles(input integer n);
        integer i;
        for (i = 0; i < n; i++) begin
            @(posedge clk); #1;
            cycle_num++;
        end
    endtask

    // ---- Cycle-by-cycle monitor ----
    always @(posedge clk) begin
        if (!reset) begin
            $display("CYC %3d | PC=%08h | INSTR=%08h | ALU=%08h | WD=%08h | MW=%b",
                     cycle_num, pc, instrOut, aluout, writedata, memwrite);
        end
    end

    // ---- Register write monitor ----
    always @(negedge clk) begin
        if (!reset && dut.dp.RegWriteW && dut.dp.WriteRegW != 0)
            $display("         >> REG WRITE: $%0d <= 0x%08h",
                     dut.dp.WriteRegW, dut.dp.ResultW);
    end

    // ================================================================
    // MAIN TEST SEQUENCE
    // ================================================================
    initial begin
        $dumpfile("pipelined_mips.vcd");   // waveform dump (optional)
        $dumpvars(0, testbench_pipelined_mips);

        $display("================================================");
        $display(" CS224 Lab 4 - Pipelined MIPS Testbench");
        $display(" Arda Akin  22402316  Section 6");
        $display("================================================");

        // ---- Reset ----
        reset = 1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;
        cycle_num = 0;

        // ================================================================
        // TEST 1 - No Hazards
        // Instructions at 0x00 - 0x18
        // addi $t0,$0,5  |  addi $t1,$0,3  |  addi $t2,$0,10
        // nop  |  nop  |  add $t3,$t0,$t1  |  nop
        // Expected: $t0=5, $t1=3, $t2=10, $t3=8
        // No stalls, no forwarding needed (2 NOPs between producer & consumer)
        // Pipeline needs ~10 cycles to drain
        // ================================================================
        $display("\n---- TEST 1: No Hazards (0x00-0x18) ----");
        wait_cycles(12);

        $display("  Checking register values after Test 1:");
        check_reg("No-Hazard $t0",  8, 32'h00000005);   // $t0 = 5
        check_reg("No-Hazard $t1",  9, 32'h00000003);   // $t1 = 3
        check_reg("No-Hazard $t2", 10, 32'h0000000a);   // $t2 = 10
        check_reg("No-Hazard $t3", 11, 32'h00000008);   // $t3 = 8

        // ================================================================
        // TEST 2 - EX Forwarding (Compute-Use Hazard)
        // Instructions at 0x1c - 0x20
        // addi $s0,$0,7  |  add $s1,$s0,$s0
        // Hazard: $s0 in EX when add needs it -> ForwardAE=ForwardBE=01
        // Expected: $s0=7, $s1=14
        // ================================================================
        $display("\n---- TEST 2: EX Forwarding / Compute-Use (0x1c-0x20) ----");
        wait_cycles(8);

        $display("  Checking register values after Test 2:");
        check_reg("EX-Fwd $s0", 16, 32'h00000007);   // $s0 = 7
        check_reg("EX-Fwd $s1", 17, 32'h0000000e);   // $s1 = 14

        // ================================================================
        // TEST 3 - Load-Use Stall
        // Instructions at 0x24 - 0x30
        // addi $t4,$0,10  |  sw $t4,0x50($0)  |  lw $s2,0x50($0)
        // add $s3,$s2,$s2
        // Hazard: lw result not ready when add reaches Decode
        //         -> 1-cycle stall (StallF=StallD=1, FlushE=1)
        //         -> then WB forwarding for the add
        // Expected: MEM[0x50]=10, $s2=10, $s3=20
        // ================================================================
        $display("\n---- TEST 3: Load-Use Stall (0x24-0x30) ----");
        wait_cycles(12);

        $display("  Checking register values after Test 3:");
        check_reg("LdUse $t4", 12, 32'h0000000a);   // $t4 = 10
        check_reg("LdUse $s2", 18, 32'h0000000a);   // $s2 = 10
        check_reg("LdUse $s3", 19, 32'h00000014);   // $s3 = 20

        // Also verify the memory write happened
        begin
            logic [31:0] mem_val;
            mem_val = dut.dp.dm1.RAM[32'h50 >> 2];
            if (mem_val === 32'h0000000a) begin
                $display("  [PASS] LdUse MEM[0x50] = 0x%08h", mem_val);
                pass_count++;
            end else begin
                $display("  [FAIL] LdUse MEM[0x50] = 0x%08h  (expected 0x0000000a)", mem_val);
                fail_count++;
            end
        end

        // ================================================================
        // TEST 4 - Branch Hazard (early branch resolved in Decode) + Jump
        // Instructions at 0x34 - 0x50
        // addi $t0,$0,5  |  addi $t1,$0,5  |  nop  |  nop
        // beq $t0,$t1,+1  -> taken, PC jumps to 0x4c
        // addi $t2,$0,99  -> MUST be flushed (wrong-path instruction)
        // addi $t3,$0,42  -> branch target: $t3 = 42
        // j 0x50          -> halt loop
        //
        // Expected: $t3=42, $t2 unchanged (still 10 from Test 3 or 0)
        // FlushD fires when PcSrcD=1, flushing the wrongly fetched instr
        // ================================================================
        $display("\n---- TEST 4: Branch Hazard + Jump (0x34-0x50) ----");
        wait_cycles(14);

        $display("  Checking register values after Test 4:");
        check_reg("Branch $t3",       11, 32'h0000002a);   // $t3 = 42
        // $t2 should NOT be 99 - it must have been flushed
        begin
            logic [31:0] t2_val;
            t2_val = dut.dp.rf.rf[10];
            if (t2_val !== 32'h00000063) begin
                $display("  [PASS] Branch flush: $t2 != 99  ($t2 = 0x%08h, correctly flushed)", t2_val);
                pass_count++;
            end else begin
                $display("  [FAIL] Branch flush: $t2 = 0x%08h = 99 (should have been flushed!)", t2_val);
                fail_count++;
            end
        end

        // ================================================================
        // HAZARD UNIT SIGNAL CHECK
        // Verify key internal signals during a known stall cycle
        // (This is a static snapshot - for dynamic checking use waveform)
        // ================================================================
        $display("\n---- HAZARD UNIT Internal Signal Snapshot ----");
        $display("  StallF    = %b  (expect 0 at idle)", dut.dp.StallF);
        $display("  StallD    = %b  (expect 0 at idle)", dut.dp.StallD);
        $display("  FlushE    = %b  (expect 0 at idle)", dut.dp.FlushE);
        $display("  FlushD    = %b  (expect 0 at idle)", dut.dp.FlushD);
        $display("  ForwardAE = %b", dut.dp.ForwardAE);
        $display("  ForwardBE = %b", dut.dp.ForwardBE);
        $display("  ForwardAD = %b", dut.dp.ForwardAD);
        $display("  ForwardBD = %b", dut.dp.ForwardBD);

        // ================================================================
        // FINAL SUMMARY
        // ================================================================
        $display("\n================================================");
        $display(" RESULTS: %0d PASSED, %0d FAILED  (Total %0d checks)",
                 pass_count, fail_count, pass_count + fail_count);
        if (fail_count == 0)
            $display(" ALL TESTS PASSED - Pipelined MIPS is working!");
        else
            $display(" SOME TESTS FAILED - Check waveform for details.");
        $display("================================================\n");

        $finish;
    end

endmodule