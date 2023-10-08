module br_bool(br_instr_ID_EX, PSW,
               jmp_imm_ID_EX,jmp_reg_ID_EX,rti_ID_EX,
			   cc_ID_EX,flow_change_ID_EX);

//////////////////////////////////////////////////////
// determines branch or not based on cc, and flags //
////////////////////////////////////////////////////
input br_instr_ID_EX;		// from ID, tell us if this is a branch instruction
input jmp_imm_ID_EX;		// from ID, tell us this is jump immediate instruction
input jmp_reg_ID_EX;		// from ID, tell us this is jump register instruction
input rti_ID_EX;
input [2:0] cc_ID_EX;		// condition code from instr[14:12]
input [3:0] PSW;			// flag bits from ALU

output logic flow_change_ID_EX;		// asserted if we should take branch or jumping

always_comb begin

  if (br_instr_ID_EX)
    case (cc_ID_EX)
	  3'b000 : flow_change_ID_EX = ~PSW[0];
	  3'b001 : flow_change_ID_EX = PSW[0];
	  3'b010 : flow_change_ID_EX = ~PSW[0] & ~PSW[1];
	  3'b011 : flow_change_ID_EX = PSW[1];
	  3'b100 : flow_change_ID_EX = PSW[0] | ~PSW[1];
	  3'b101 : flow_change_ID_EX = PSW[1] | PSW[0];
	  3'b110 : flow_change_ID_EX = PSW[2];
	  3'b111 : flow_change_ID_EX = 1;
	endcase
  else
    flow_change_ID_EX = jmp_imm_ID_EX | jmp_reg_ID_EX | rti_ID_EX;	// jumps always change the flow

end

endmodule