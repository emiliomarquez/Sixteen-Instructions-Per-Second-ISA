// Create Date:    2018.04.05
// Design Name:    BasicProcessor
// Module Name:    TopLevel 
// CSE141L
// partial only	
import definitions::*;									   
module TopLevel(		   // you will have the same 3 ports
    input        Reset,	   // init/reset, active high
			     Start,    // start next program
	             Clk,	   // clock -- posedge used inside design
    output logic Ack	   // done flag from DUT
    );

wire [ 9:0] PgmCtr,        // program counter
			PCTarg;
wire [ 8:0] Instruction;   // our 9-bit opcode
wire [ 7:0] ReadA, ReadB;  // reg_file outputs
wire [ 7:0] InA, InB, 	   // ALU operand inputs
            ALU_out,DataAddress;       // ALU result
wire [ 7:0] RegWriteValue, // data in to reg file
            MemWriteValue, // data in to data_memory
	   	    MemReadValue;  // data out from data_memory
wire [ 2:0] RegWriteAddr,
				RegReadAddr;
wire        MemWrite,	   // data_memory write enable
			RegWrEn,	   // reg_file write enable
			Zero,		   // ALU output = 0 flag
            Jump,	       // to program counter: jump 
				WriteR,
				ImmMux,
            BranchEn;	   // to program counter: branch enable
wire[ 4:0] OP,
			 Imm;
logic[15:0] CycleCt;	   // standalone; NOT PC!

// Fetch = Program Counter + Instruction ROM
// Program Counter
  InstFetch IF1 (
	.Reset       (Reset   ) , 
	.Start       (Start   ) ,  // SystemVerilg shorthand for .halt(halt), 
	.Clk         (Clk     ) ,  // (Clk) is required in Verilog, optional in SystemVerilog
	.BranchAbs   (Jump    ) ,  // jump enable
	.BranchRelEn (BranchEn) ,  // branch enable
	.ALU_flag	 (Zero    ) ,
    .Target      (PCTarg  ) ,
	.ProgCtr     (PgmCtr  )	   // program count = index to instruction memory
	);					  

// Control decoder
  Ctrl Ctrl1 (
	.Instruction  (Instruction), // from instr_ROM
	.Jump         (Jump),		     // to PC
	.BranchEn     (BranchEn),		 // to PC
	.WriteR		  (WriteR),
	.ImmMux		  (ImmMux),
	.OP			  (OP)
  );
// instruction ROM
  InstROM #(.W(9)) IR1(
	.InstAddress   (PgmCtr), 
	.InstOut       (Instruction)
	);

  assign LoadInst = Instruction[8:3]=={typeI,iLOAD};  // calls out load specially
  assign RegReadAddr = Instruction[2:0];
  assign RegWriteAddr = WriteR? Instruction[2:0]:3'b001;
  assign Imm = ImmMux? Instruction[4:0] : {2'b00,Instruction[5:3]};
// reg file
	RegFile #(.W(8),.D(3)) RF1 (
		.Clk    				  ,
		.WriteEn   (RegWrEn)    , 
		.Raddr    (RegReadAddr),         //concatenate with 0 to give us 4 bits
		.Waddr     (RegWriteAddr), 	       // mux above
		.DataIn    (RegWriteValue) , 
		.DataOutA  (ReadA        ) , 
		.DataOutB  (ReadB		 )
	);

// one pointer, two adjacent read accesses: (optional approach)
//	.raddrA ({Instruction[5:3],1'b0});
//	.raddrB ({Instruction[5:3],1'b1});

    assign InA = ReadA;						          // connect RF out to ALU in
	assign InB = ReadB;
	assign MemWrite = (Instruction[8:3] == {typeI,iSTORE});       // mem_store command
	assign RegWriteValue = LoadInst? MemReadValue : ALU_out;  // 2:1 switch into reg_file  

    ALU ALU1  (
	  .InputA  (InA),
	  .InputB  (InB),
	  .Imm	  (Imm), 
	  .OP      (OP),
	  .Out     (ALU_out),//regWriteValue),
	  .Zero
	  );
  assign Ack = (OP==HALT)? 'b1 : 'b0;
  assign MemWriteValue = ALU_out;
  assign DataAddress = (BranchEn||Jump)? (8'b10000000+Imm) : ReadB;
	DataMem DM(
		.DataAddress  (DataAddress)    , 
		.WriteEn      (MemWrite), 
		.DataIn       (MemWriteValue), 
		.DataOut      (MemReadValue)  , 
		.Clk 		  		     ,
		.Reset		  (Reset)
	);
	assign RegWrEn = (MemWrite||BranchEn||Jump||Ack)? 'b0 : 'b1;
	assign PCTarg = MemReadValue;
// count number of instructions executed
always_ff @(posedge Clk)
  if (Start == 1)	   // if(start)
  	CycleCt <= 0;
  else if(Ack == 0)   // if(!halt)
  	CycleCt <= CycleCt+16'b1;

endmodule