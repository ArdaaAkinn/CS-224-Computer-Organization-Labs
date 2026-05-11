// ============================================================
// CS224 - Lab 4 - Pipelined MIPS Processor (BASYS3 Ready)
// Section: 6 | Arda Akın - 22402316 | April 10, 2026
// ============================================================

// ------------------------------------------------------------
// 1. TOP-LEVEL HARDWARE WRAPPER (BASYS3)
// ------------------------------------------------------------
module top_basys3(
    input  logic       clk,
    input  logic       btnC,
    input  logic       btnU,
    output logic [6:0] seg,
    output logic [3:0] an,
    output logic [15:0] led
);
    logic pulse_clk, clean_reset;
    logic [31:0] pc, aluout, writedata, instr, resultW;
    logic memwrite;

    pulse_controller pc_unit(clk, btnC, pulse_clk);
    pulse_controller reset_unit(clk, btnU, clean_reset);

    mips mips_core(
        .clk(pulse_clk), .reset(clean_reset),
        .pc(pc), .memwrite(memwrite), .aluout(aluout),
        .writedata(writedata), .instrOut(instr), .resultW(resultW)
    );

    assign led[0]    = memwrite;
    assign led[15:1] = pc[16:2];

    // sol 2 digit (an3,an2) = data adresi  aluout[7:0]
    // sag 2 digit (an1,an0) = write data   writedata[7:0]
    logic [15:0] display_data;
    always_comb
        display_data = { aluout[7:0], writedata[7:0] };

    display_controller dc_unit(
        .clk(clk), .reset(clean_reset),
        .data(display_data), .seg(seg), .an(an)
    );
endmodule

// ------------------------------------------------------------
// 2. MIPS PROCESSOR CORE
// ------------------------------------------------------------
module mips(
    input  logic        clk, reset,
    output logic [31:0] pc,
    output logic        memwrite,
    output logic [31:0] aluout, writedata,
    output logic [31:0] instrOut,
    output logic [31:0] resultW
);
    logic memtoreg, alusrc, regdst, regwrite, jump, branch;
    logic MemWriteD;
    logic [2:0] alucontrol;
    logic [31:0] instrD_ctrl;

    assign instrOut = instrD_ctrl; 

    controller ctrl(
    .op(instrD_ctrl[31:26]), .funct(instrD_ctrl[5:0]),
    .memtoreg(memtoreg), .memwrite(MemWriteD), .alusrc(alusrc),
    .regdst(regdst), .regwrite(regwrite), .jump(jump),
    .alucontrol(alucontrol), .branch(branch)
);

    datapath dp(
        .clk(clk), .reset(reset),
        .RegWriteD(regwrite), .MemToRegD(memtoreg), .MemWriteD(MemWriteD),
        .ALUSrcD(alusrc), .RegDstD(regdst), .BranchD(branch), .JumpD(jump),
        .ALUControlD(alucontrol), .MemWriteM(memwrite),
        .ALUOutM(aluout), .WriteDataM(writedata),
        .PCF(pc), .instrD_out(instrD_ctrl), .ResultW(resultW)
    );
endmodule

// ------------------------------------------------------------
// 3. DATAPATH & HAZARD UNIT
// ------------------------------------------------------------
module datapath(
    input  logic        clk, reset,
    input  logic        RegWriteD, MemToRegD, MemWriteD,
    input  logic        ALUSrcD, RegDstD, BranchD, JumpD,
    input  logic [2:0]  ALUControlD,
    output logic        MemWriteM,
    output logic [31:0] ALUOutM, WriteDataM,
    output logic [31:0] PCF,
    output logic [31:0] instrD_out,
    output logic [31:0] ResultW
);
    // Dahili Sinyaller
    logic StallF, StallD, FlushE, FlushD;
    logic [1:0] ForwardAE, ForwardBE;
    logic ForwardAD, ForwardBD;
    logic [31:0] PC_next, PcPlus4F, instrF, instrD, PcPlus4D;
    logic [31:0] RD1D, RD2D, RD1D_fwd, RD2D_fwd, SignImmD, ShiftedImmD;
    logic EqualD, PcSrcD;
    logic [4:0] rsD, rtD, rdD;
    logic [25:0] JumpTargetD;
    
    logic RegWriteE, MemToRegE, MemWriteE, ALUSrcE, RegDstE, BranchE, JumpE;
    logic [2:0] ALUControlE;
    logic [31:0] RD1E, RD2E, SignImmE, PcPlus4E, SrcAE, SrcBE, WriteDataE, ALUOutE, ShiftedImmE, PCBranchE;
    logic ZeroE;
    logic [4:0] rsE, rtE, rdE, WriteRegE;
    logic [25:0] JumpTargetE;
    
    logic RegWriteM_s, MemToRegM, BranchM, JumpM, ZeroM;
    logic [31:0] PCBranchM;
    logic [4:0] WriteRegM;
    logic [25:0] JumpTargetM;
    logic [31:0] ReadDataM;
    
    logic RegWriteW, MemToRegW;
    logic [31:0] ReadDataW, ALUOutW;
    logic [4:0] WriteRegW;

    // --- FETCH (IF) ---
    always_comb begin
        if (JumpM)      PC_next = {PcPlus4D[31:28], JumpTargetM, 2'b00};
        else if (PcSrcD) PC_next = PCBranchE; 
        else            PC_next = PcPlus4F;
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset)      PCF <= 32'h0;
        else if (~StallF) PCF <= PC_next;
    end

    assign PcPlus4F = PCF + 4;
    imem im1(PCF[7:2], instrF);

    // --- DECODE (ID) ---
    always_ff @(posedge clk or posedge reset) begin
        if (reset || FlushD) begin instrD <= 0; PcPlus4D <= 0; end
        else if (~StallD)    begin instrD <= instrF; PcPlus4D <= PcPlus4F; end
    end
    
    assign instrD_out = instrD;
    assign rsD = instrD[25:21]; assign rtD = instrD[20:16]; assign rdD = instrD[15:11];
    assign JumpTargetD = instrD[25:0];

    regfile rf(clk, RegWriteW, rsD, rtD, WriteRegW, ResultW, RD1D, RD2D);
    signext se(instrD[15:0], SignImmD);
    
    mux2 #(32) fwdAD_mux(RD1D, ALUOutM, ForwardAD, RD1D_fwd);
    mux2 #(32) fwdBD_mux(RD2D, ALUOutM, ForwardBD, RD2D_fwd);
    assign EqualD = (RD1D_fwd == RD2D_fwd);
    assign PcSrcD = BranchD & EqualD;

    // --- EXECUTE (EX) ---
    PipeDtoE pDtoE(
        .clk(clk), .FlushE(FlushE),
        .RegWriteD(RegWriteD), .MemToRegD(MemToRegD), .MemWriteD(MemWriteD),
        .ALUSrcD(ALUSrcD), .RegDstD(RegDstD), .BranchD(BranchD), .JumpD(JumpD),
        .ALUControlD(ALUControlD), .RD1D(RD1D_fwd), .RD2D(RD2D_fwd),
        .SignImmD(SignImmD), .PcPlus4D(PcPlus4D),
        .rsD(rsD), .rtD(rtD), .rdD(rdD), .JumpTargetD(JumpTargetD),
        .RegWriteE(RegWriteE), .MemToRegE(MemToRegE), .MemWriteE(MemWriteE),
        .ALUSrcE(ALUSrcE), .RegDstE(RegDstE), .BranchE(BranchE), .JumpE(JumpE),
        .ALUControlE(ALUControlE), .RD1E(RD1E), .RD2E(RD2E), .SignImmE(SignImmE),
        .PcPlus4E(PcPlus4E), .rsE(rsE), .rtE(rtE), .rdE(rdE), .JumpTargetE(JumpTargetE)
    );

    mux2 #(5) wreg_mux(rtE, rdE, RegDstE, WriteRegE);
    
    always_comb begin
        case (ForwardAE)
            2'b01:   SrcAE = ALUOutM;
            2'b10:   SrcAE = ResultW;
            default: SrcAE = RD1E;
        endcase
        case (ForwardBE)
            2'b01:   WriteDataE = ALUOutM;
            2'b10:   WriteDataE = ResultW;
            default: WriteDataE = RD2E;
        endcase
    end
    
    mux2 #(32) alusrc_mux(WriteDataE, SignImmE, ALUSrcE, SrcBE);
    alu alu1(SrcAE, SrcBE, ALUControlE, ALUOutE, ZeroE);
    sl2 sl_E(SignImmE, ShiftedImmE);
    adder ba_E(PcPlus4E, ShiftedImmE, PCBranchE);

    // --- MEMORY (MEM) ---
    PipeEtoM pEtoM(
        .clk(clk), .RegWriteE(RegWriteE), .MemToRegE(MemToRegE), .MemWriteE(MemWriteE),
        .BranchE(BranchE), .JumpE(JumpE), .ZeroE(ZeroE), .ALUOutE(ALUOutE),
        .WriteDataE(WriteDataE), .PCBranchE(PCBranchE), .WriteRegE(WriteRegE),
        .JumpTargetE(JumpTargetE),
        .RegWriteM(RegWriteM_s), .MemToRegM(MemToRegM), .MemWriteM(MemWriteM),
        .BranchM(BranchM), .JumpM(JumpM), .ZeroM(ZeroM), .ALUOutM(ALUOutM),
        .WriteDataM(WriteDataM), .PCBranchM(PCBranchM), .WriteRegM(WriteRegM),
        .JumpTargetM(JumpTargetM)
    );

    dmem dm1(
        .clk(clk),
        .we(MemWriteM),
        .a(ALUOutM),
        .wd(WriteDataM),
        .rd(ReadDataM)
    );

    // --- WRITEBACK (WB) ---
    PipeMtoW pMtoW(
        .clk(clk), .RegWriteM(RegWriteM_s), .MemToRegM(MemToRegM),
        .ReadDataM(ReadDataM), .ALUOutM(ALUOutM), .WriteRegM(WriteRegM),
        .RegWriteW(RegWriteW), .MemToRegW(MemToRegW), .ReadDataW(ReadDataW),
        .ALUOutW(ALUOutW), .WriteRegW(WriteRegW)
    );

    mux2 #(32) result_mux(ALUOutW, ReadDataW, MemToRegW, ResultW);

    // --- HAZARD UNIT ---
    HazardUnit hu(
        .RegWriteW(RegWriteW), .WriteRegW(WriteRegW),
        .RegWriteM(RegWriteM_s), .MemToRegM(MemToRegM), .WriteRegM(WriteRegM),
        .RegWriteE(RegWriteE), .MemToRegE(MemToRegE), .WriteRegE(WriteRegE),
        .rsE(rsE), .rtE(rtE), .rsD(rsD), .rtD(rtD),
        .PcSrcD(PcSrcD), .JumpD(JumpD),
        .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
        .ForwardAD(ForwardAD), .ForwardBD(ForwardBD),
        .FlushE(FlushE), .FlushD(FlushD), .StallD(StallD), .StallF(StallF)
    );
endmodule

// ------------------------------------------------------------
// 4. PIPELINE REGISTERS
// ------------------------------------------------------------
module PipeDtoE(
    input logic clk, FlushE, RegWriteD, MemToRegD, MemWriteD, ALUSrcD, RegDstD, BranchD, JumpD,
    input logic [2:0] ALUControlD, input logic [31:0] RD1D, RD2D, SignImmD, PcPlus4D,
    input logic [4:0] rsD, rtD, rdD, input logic [25:0] JumpTargetD,
    output logic RegWriteE, MemToRegE, MemWriteE, ALUSrcE, RegDstE, BranchE, JumpE,
    output logic [2:0] ALUControlE, output logic [31:0] RD1E, RD2E, SignImmE, PcPlus4E,
    output logic [4:0] rsE, rtE, rdE, output logic [25:0] JumpTargetE
);
    always_ff @(posedge clk) begin
        if (FlushE) begin 
            {RegWriteE, MemToRegE, MemWriteE, ALUSrcE, RegDstE, BranchE, JumpE} <= 0; 
            ALUControlE <= 0; {RD1E, RD2E, SignImmE, PcPlus4E} <= 0; {rsE, rtE, rdE} <= 0; JumpTargetE <= 0; 
        end
        else begin 
            {RegWriteE, MemToRegE, MemWriteE, ALUSrcE, RegDstE, BranchE, JumpE} <= {RegWriteD, MemToRegD, MemWriteD, ALUSrcD, RegDstD, BranchD, JumpD}; 
            ALUControlE <= ALUControlD; {RD1E, RD2E, SignImmE, PcPlus4E} <= {RD1D, RD2D, SignImmD, PcPlus4D}; 
            {rsE, rtE, rdE} <= {rsD, rtD, rdD}; JumpTargetE <= JumpTargetD; 
        end
    end
endmodule

module PipeEtoM(
    input logic clk, RegWriteE, MemToRegE, MemWriteE, BranchE, JumpE, ZeroE,
    input logic [31:0] ALUOutE, WriteDataE, PCBranchE, input logic [4:0] WriteRegE,
    input logic [25:0] JumpTargetE,
    output logic RegWriteM, MemToRegM, MemWriteM, BranchM, JumpM, ZeroM,
    output logic [31:0] ALUOutM, WriteDataM, PCBranchM, output logic [4:0] WriteRegM,
    output logic [25:0] JumpTargetM
);
    always_ff @(posedge clk) begin 
        RegWriteM <= RegWriteE; MemToRegM <= MemToRegE; MemWriteM <= MemWriteE;
        BranchM <= BranchE; JumpM <= JumpE; ZeroM <= ZeroE;
        ALUOutM <= ALUOutE; WriteDataM <= WriteDataE; PCBranchM <= PCBranchE;
        WriteRegM <= WriteRegE; JumpTargetM <= JumpTargetE;
    end
endmodule

module PipeMtoW(
    input logic clk, RegWriteM, MemToRegM, input logic [31:0] ReadDataM, ALUOutM,
    input logic [4:0] WriteRegM, output logic RegWriteW, MemToRegW,
    output logic [31:0] ReadDataW, ALUOutW, output logic [4:0] WriteRegW
);
    always_ff @(posedge clk) begin 
        {RegWriteW, MemToRegW} <= {RegWriteM, MemToRegM}; 
        {ReadDataW, ALUOutW} <= {ReadDataM, ALUOutM}; WriteRegW <= WriteRegM; 
    end
endmodule

// ------------------------------------------------------------
// 5. HAZARD UNIT
// ------------------------------------------------------------
module HazardUnit(
    input  logic       RegWriteW, input logic [4:0] WriteRegW, 
    input  logic       RegWriteM, MemToRegM, input logic [4:0] WriteRegM, 
    input  logic       RegWriteE, MemToRegE, input logic [4:0] WriteRegE, 
    input  logic [4:0] rsE, rtE, rsD, rtD, 
    input  logic       PcSrcD, JumpD, 
    output logic [1:0] ForwardAE, ForwardBE, 
    output logic       ForwardAD, ForwardBD, 
    output logic       FlushE, FlushD, StallD, StallF
);
    always_comb begin
        {ForwardAE, ForwardBE} = 4'b0000; {ForwardAD, ForwardBD} = 2'b00;
        {StallF, StallD, FlushE, FlushD} = 4'b0000;

        if (RegWriteM && (WriteRegM != 0) && (WriteRegM == rsE)) ForwardAE = 2'b01; 
        else if (RegWriteW && (WriteRegW != 0) && (WriteRegW == rsE)) ForwardAE = 2'b10;
        if (RegWriteM && (WriteRegM != 0) && (WriteRegM == rtE)) ForwardBE = 2'b01; 
        else if (RegWriteW && (WriteRegW != 0) && (WriteRegW == rtE)) ForwardBE = 2'b10;

        ForwardAD = RegWriteM && (WriteRegM != 0) && (WriteRegM == rsD);
        ForwardBD = RegWriteM && (WriteRegM != 0) && (WriteRegM == rtD);

        if (MemToRegE && ((WriteRegE == rsD) || (WriteRegE == rtD))) begin
            StallF = 1'b1; StallD = 1'b1; FlushE = 1'b1;
        end
        if (PcSrcD || JumpD) begin
            FlushD = 1'b1; if (!StallD) FlushE = 1'b1;
        end
    end
endmodule

// ------------------------------------------------------------
// 6. LOW-LEVEL COMPONENTS
// ------------------------------------------------------------
module controller(input logic [5:0] op, funct, output logic memtoreg, memwrite, alusrc, regdst, regwrite, jump, output logic [2:0] alucontrol, output logic branch);
    logic [1:0] aluop;
    maindec md(op, memtoreg, memwrite, branch, alusrc, regdst, regwrite, jump, aluop);
    aludec ad(funct, aluop, alucontrol);
endmodule

module maindec(input logic [5:0] op, output logic memtoreg, memwrite, branch, alusrc, regdst, regwrite, jump, output logic [1:0] aluop);
    logic [8:0] controls;
    assign {regwrite,regdst,alusrc,branch,memwrite,memtoreg,aluop,jump} = controls;
    always_comb case (op)
        6'b000000: controls = 9'b110000100; // R-type
        6'b100011: controls = 9'b101001000; // lw
        6'b101011: controls = 9'b001010000; // sw
        6'b000100: controls = 9'b000100010; // beq
        6'b001000: controls = 9'b101000000; // addi
        6'b000010: controls = 9'b000000001; // j
        default:   controls = 9'b000000000;
    endcase
endmodule

module aludec(input logic [5:0] funct, input logic [1:0] aluop, output logic [2:0] alucontrol);
    always_comb case (aluop)
        2'b00: alucontrol = 3'b010; // add
        2'b01: alucontrol = 3'b110; // sub
        default: case (funct)
            6'b100000: alucontrol = 3'b010; // add
            6'b100010: alucontrol = 3'b110; // sub
            6'b100100: alucontrol = 3'b000; // and
            6'b100101: alucontrol = 3'b001; // or
            6'b101010: alucontrol = 3'b111; // slt
            default:   alucontrol = 3'bxxx;
        endcase
    endcase
endmodule

module regfile(input logic clk, we3, input logic [4:0] ra1, ra2, wa3, input logic [31:0] wd3, output logic [31:0] rd1, rd2);
    logic [31:0] rf[31:0];
    always_ff @(negedge clk) if (we3) rf[wa3] <= wd3;
    assign rd1 = (ra1 != 0) ? rf[ra1] : 32'h0;
    assign rd2 = (ra2 != 0) ? rf[ra2] : 32'h0;
endmodule

module alu(input logic [31:0] a, b, input logic [2:0] alucont, output logic [31:0] result, output logic zero);
    always_comb case (alucont)
        3'b010: result = a + b; 
        3'b110: result = a - b; 
        3'b000: result = a & b;
        3'b001: result = a | b; 
        3'b111: result = (a < b) ? 32'h1 : 32'h0;
        default: result = 32'h0;
    endcase
    assign zero = (result == 32'h0);
endmodule

module imem(input logic [5:0] addr, output logic [31:0] instr);
    always_comb case ({addr, 2'b00})
        8'h00: instr = 32'h20080005; // addi $t0, $0, 5
        8'h04: instr = 32'h20090003; // addi $t1, $0, 3
        8'h08: instr = 32'h200a000a; // addi $t2, $0, 10
        8'h0c: instr = 32'h00000000; // nop
        8'h10: instr = 32'h00000000; // nop
        8'h14: instr = 32'h01095820; // add  $t3, $t0, $t1 ($t3=8)
        8'h18: instr = 32'h00000000; // nop
        //Test - 2 EX Forward
        8'h1c: instr = 32'h20100007; // addi $s0, $0, 7
        8'h20: instr = 32'h02108820; // add  $s1, $s0, $s0 ($s1=14)
        //Test - 3 Load Use Stall
        8'h24: instr = 32'h200c000a; // addi $t4, $0, 10
        8'h28: instr = 32'hac0c0050; // sw   $t4, 80($0)
        8'h2c: instr = 32'h8c100050; // lw   $s0, 80($0)
        8'h30: instr = 32'h02108820; // add  $s1, $s0, $s0 (STALL!)
        //Test - 4 Branch 
        8'h34: instr = 32'h20080005; // addi $t0, $0, 5
        8'h38: instr = 32'h20090005; // addi $t1, $0, 5
        8'h3c: instr = 32'h00000000; // nop
        8'h40: instr = 32'h00000000; // nop
        8'h44: instr = 32'h11090001; // beq  $t0, $t1, +1 (0x4c'ye)
        8'h48: instr = 32'h20120063; // addi $t2, $0, 99 (FLUSH!)
        8'h4c: instr = 32'h2013002a; // addi $t3, $0, 42
        8'h50: instr = 32'h08000014; // j    0x50 (halt)
        default: instr = 32'h00000000;
    endcase
endmodule

module dmem(input logic clk, we, input logic [31:0] a, wd, output logic [31:0] rd);
    logic [31:0] RAM[63:0]; assign rd = RAM[a[31:2]];
    always_ff @(posedge clk) if (we) RAM[a[31:2]] <= wd;
endmodule

module pulse_controller(input logic clk, btn, output logic pulse);
    logic r1, r2, r3;
    always_ff @(posedge clk) begin r1 <= btn; r2 <= r1; r3 <= r2; end
    assign pulse = r2 & ~r3;
endmodule

module display_controller(
    input  logic        clk,
    input  logic        reset,
    input  logic [15:0] data,
    output logic [6:0]  seg,
    output logic [3:0]  an
);
    logic [17:0] count;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) count <= 18'd0;
        else       count <= count + 1;
    end

    logic [3:0] digit;
    always_comb begin
        case (count[17:16])
            2'b00: begin digit = data[3:0];   an = 4'b1110; end  // an0 = writedata  alt
            2'b01: begin digit = data[7:4];   an = 4'b1101; end  // an1 = writedata  ust
            2'b10: begin digit = data[11:8];  an = 4'b1011; end  // an2 = data addr  alt
            2'b11: begin digit = data[15:12]; an = 4'b0111; end  // an3 = data addr  ust
        endcase
        case (digit)
            4'h0: seg = 7'b1000000; 4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100; 4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001; 4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010; 4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000; 4'h9: seg = 7'b0010000;
            4'ha: seg = 7'b0001000; 4'hb: seg = 7'b0000011;
            4'hc: seg = 7'b1000110; 4'hd: seg = 7'b0100001;
            4'he: seg = 7'b0000110; 4'hf: seg = 7'b0001110;
            default: seg = 7'b1111111;
        endcase
    end
endmodule

module adder(input logic [31:0] a, b, output logic [31:0] y); assign y = a + b; endmodule
module sl2(input logic [31:0] a, output logic [31:0] y); assign y = {a[29:0], 2'b00}; endmodule
module signext(input logic [15:0] a, output logic [31:0] y); assign y = {{16{a[15]}}, a}; endmodule
module mux2 #(parameter WIDTH = 8)(input logic [WIDTH-1:0] d0, d1, input logic s, output logic [WIDTH-1:0] y); assign y = s ? d1 : d0; endmodule