################################################
# This reads mm switches and writes to mm LEDs #
################################################
		B UNCOND, Lstart	# Jump around ISR to start of pgrm
		
		MEM 0x0010			# start of ISR for int_src0
		PUSH R0
		PUSH R1
		POP R1
		ADDI R0, R0, 1
		ADDI R0, R0, 1
		RTI
		ADDI R12, R12, 1
		ADDI R12, R12, 1
		
		MEM 0x0020
		
Lstart:	LLB R1, 0x55
		LHB R1, 0xC0		# R1 contains DATA C055
		LLB R2, 0x66
		LHB R2, 0x10		# R2 contains ADDR 1066
		SW  R1, R2, 0		# write 0xC055 to mem[0x1066]
		SUBI R2, R2, 1		# decrement address
		ADDi R2, R2, -1		# decrement address again
		LW  R3, R2, 2		# read from mem[R2+2] which should return 0xC055
		SUB R4, R3, R1		# should result in equal
		B NEQ, Lfail
		
		ADDIEQ R3, R3, 0x10 # should occur
		LLB R4, 0x65
		LHB R4, 0xC0
		SUB R4, R3, R4		# should result in equal
		B NEQ, Lfail
		
		XORI R3, R3, -1		# should result in 0x3F9A
		ADDINE R3, R3, 1	# should not occur
		LLB R4, 0x9A
		LHB R4, 0x3F
		SUB R4, R3, R4
		B NEQ, Lfail
		
		LLB R4, 0x55
		LHB R4, 0xAA
		LLB R3, 0xAB
		LHB R3, 0x55
		ADD R5, R3, R4		# should result in 0x0000 with carry
		B NEQ, Lfail
		ADDC R5, R5, R5		# should result in 0x0001
		LLB R4, 0x01
		SUB R4, R5, R4		# should be equal
		B NEQ, Lfail

		LLB R4, 0x55		# R4 = 0x0055
		LLB R5, 0x01		# R5 = 0x0001
		LLB R6, 0x56		# R6 = 0x0056
		LLB R7, 0x01		# R7 = 0x0001
		SUB R2, R4, R6		# R2 = 0xFFFF
		SUBB R3, R5, R7		# R3 = 0xFFFF
		B GTE, Lfail
		LLB R4, 0xFF        # R4 = 0xFFFF
		SUB R5, R2, R4
		B NEQ, Lfail
		SUB R5, R3, R4
		B NEQ, Lfail

        ANDI R2, R2, 0x0000 # R2 = 0x0000
		LLB R3, 0x55		# R3 = 0x0055
		LHB R3, 0x01		# R3 = 0x0155
        JAL LshftLL

		LLB R3, 0xA9		# R3 = 0xFFA9
		JAL LshftRA

		LLB R3, 0x69
		LHB R3, 0x03		# R3 = 0x0369
        ADDI R5, R3, 0x0011	# R5 = 0x037A	
		PUSH R3
		PUSH R5
		POP R3
		POP R5				# registers should have swapped
		LLB R4, 0x7A
		LHB R4, 0x03
		SUB R4, R3, R4
		B NEQ, Lfail
		LLB R4, 0x69
		LHB R4, 0x03
		SUB R4, R5, R4
		B NEQ, Lfail
		
		LLB R3, 0x45		# R4 = 0x0045
		LLB R5, 0x74		# R5 = 0x0074
		LLB R4, 0x44
		LHB R4, 0x1F		# load expected result in R4
		MULU R6, R5, R3		# unsigned mult results in 0x1F44
		SUB R4, R6, R4
		B NEQ, Lfail
		
		LLB R10, 0xA5	    # R10 = 0xFFA5
		LLB R11, 0xB2
		LHB R11, 0x03		# R11 = 0x03B2
		LLB R4, 0xBA
		LHB R4, 0xAF		# load expected result in R4
	    MULS R12, R10, R11
		SUB R4, R12, R4
		B NEQ, Lfail
		
		XMULH R13			# move high word into R13
		LLB R4, 0xFE
		LHB R4, 0xFF		# load expected result in R4
		SUB R4, R13, R4
		B NEQ, Lfail
		
		LLB R0, 0x00
		LHB R0, 0x11
		MOVC R1, R0, 0
		LLB R4, 0x41
		SUB R4, R1, R4
		B NEQ, Lfail
		
		## Do multiple MOVCs in a row deadlock the machine? 
		MOVC R1, R0, 1	# read 'B' (0x42)
		MOVC R2, R0, 2	# read 'C'
		MOVC R3, R0, 3	# read 'D'
		LLB R4, 0x42
		SUB R4, R1, R4
		B NEQ, Lfail
		LLB R4, 0x43
		SUB R4, R2, R4
		B NEQ, Lfail
		LLB R4, 0x44
		SUB R4, R3, R4
		B NEQ, Lfail		
		
		// Interrupt should occur while in this loop
		LLB R3, 0x00
Loop:   ADDI R3, R3, 1
        B UNCOND, Loop
		
		
LshftLL:
		SLL R2, R3, 1		# shift left by 1
		LLB R4, 0xAA
		LHB R4, 0x02		
		SUB R4, R4, R2
		B NEQ, Lfail
		JR R15
		
LshftRA:
		SRA R2, R3, 2		# shift right arith by 2
		LLB R4, 0xEA
		LHB R4, 0xFF		
		SUB R4, R4, R2
		B NEQ, Lfail
		JR R15
		
		
		MEM 0x0800
		
Lfail: B UNCOND, Lfail


#######################################
# Following routine polls UART status #
# register and waits for TX fifo to   #
# be empty.                           #
#######################################
L_WAIT_TX_EMPTY:
        LLB R5, 0x80
		LHB R5, 0x00		# R5 Contains 0x0080 (queue empty count)
L_U_POLL:
        LW R4, R3, 1		# Read status register
		SUB R6, R4, R5
		B NEQ, L_U_POLL
		JR R15
		
		MEM 0x1100			# string data
		DATA 0x0041			# 'A'
		DATA 0x0042			# 'B'
		DATA 0x0043			# 'C'
		DATA 0x0044			# 'D'
