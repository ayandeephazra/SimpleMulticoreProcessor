#########################################################
# Squares Matrix from imemory using MOVC and stores     #
# in dmem.  Then squares matrix in dmem to dmem further #
#########################################################
		B UNCOND, Lstart	# Jump around ISR to start of pgrm
		
		MEM 0x0010			# start of ISR for int_src0
		PUSH R0
		PUSH R1
		POP R1
		RTI
		
		MEM 0x0020

### Square Matrix from imemory ###		
Lstart:	LLB R0, 0x00
		LHB R0, 0x10		# R0 contains pointer to matrix source data
		LLB R1, 0x04		# R1 contains square matrix size
		LLB R10, 0x00		# R10 points to where we store result
		LLB R2, 0x00		# R2 contains row count (outer loop)
Lrow:	LLB R3, 0x00		# R3 contains col count (inner loop)
Lcol:	MULU R4, R1, R2		# start building address for row ptr
		ADD R4, R4, R0		# R4 points to first row data element
    	ADDI R5, R3, 0		# start building pointer for col data element
		ADD R5, R5, R0
		LLB R6, 0x00		# zero accumulator for row/col
		
		ADDI R9, R1, 0		# mult loop counter starts at matrix size
Lmult:	MOVC R7, R4, 0		# load first row data into R7
		MOVC R8, R5, 0		# load first col data into R8
		MULS R8, R8, R7
		ADD R6, R6, R8		# accumulate row/col
		ADDI R4, R4, 1		# inc row ptr
		ADD R5, R5, R1		# inc col ptr
		SUBI R9, R9, 1		# dec mult loop counter
		B NEQ, Lmult
		SW R6, R10, 0		# store new calculated element of matrix
		ADDI R10, R10, 1	# increment storage pointer
		ADDI R3, R3, 1
		SUB R11, R3, R1
		B LT, Lcol
		ADDI R2, R2, 1
		SUB R11, R2, R1
		B LT, Lrow
### Square Matrix just formed to calc M^4 ###
		LLB R0, 0x00
		LHB R0, 0x00		# R0 contains pointer to matrix source data
		LLB R1, 0x04		# R1 contains square matrix size
		MULU R10, R1, R1	# R10 points to where we store result
		LLB R2, 0x00		# R2 contains row count (outer loop)
Lrow2:	LLB R3, 0x00		# R3 contains col count (inner loop)
Lcol2:	MULU R4, R1, R2		# start building address for row ptr
		ADD R4, R4, R0		# R4 points to first row data element
    	ADDI R5, R3, 0		# start building pointer for col data element
		ADD R5, R5, R0
		LLB R6, 0x00		# zero accumulator for row/col
		
		ADDI R9, R1, 0		# mult loop counter starts at matrix size
Lmult2:	LW R7, R4, 0		# load first row data into R7
		LW R8, R5, 0		# load first col data into R8
		MULS R8, R8, R7
		ADD R6, R6, R8		# accumulate row/col
		ADDI R4, R4, 1		# inc row ptr
		ADD R5, R5, R1		# inc col ptr
		SUBI R9, R9, 1		# dec mult loop counter
		B NEQ, Lmult2
		SW R6, R10, 0		# store new calculated element of matrix
		ADDI R10, R10, 1	# increment storage pointer
		ADDI R3, R3, 1
		SUB R11, R3, R1
		B LT, Lcol2
		ADDI R2, R2, 1
		SUB R11, R2, R1
		B LT, Lrow2
#### Now perform a data memory read from 0x011F.  This will cause #####
#### an eviction of 0x001C - 0x001F from the cache  Then reload   #####
#### 0x001F into the cache and check contents. #####
		LLB R0, 0x1F
		LHB R0, 0x01
		LW R1, R0, 0		# miss with eviction will occur
		ADDI R0, R0, 0	# nop
		ADDI R0, R0, 0
		ADDI R0, R0, 0 # nop
		LHB R0, 0x00
		LW R1, R0, 0	# another miss/evict/load
		LLB R2, 0x74
		LHB R2, 0x10	# correct answer for 0x001F location is 0x1074
		SUB R11, R1, R2
		B NEQ, LFail
		B UNCOND, LPass
		
		
		MEM 0x07AA		# locate at 0x07AA so easy to see at pass routine 
LPass:	B UNCOND, LPass

	   MEM 0x07FF		# locate at 0x07FF so easy to see it is fail routine
Lfail: 	B UNCOND, Lfail

		
		MEM 0x1000			# matrix data for 4x4 matrix
		DATA 0x0000			# 0
		DATA 0x0001			# 1
		DATA 0x0002			# 2
		DATA 0x0003			# 3
		DATA 0x0004			# 4
		DATA 0x0005			# 5
		DATA 0x0006			# 6
		DATA 0x0007			# 7
		DATA 0x0007			# 7
		DATA 0x0006			# 6
		DATA 0x0005			# 5
		DATA 0x0004			# 4
		DATA 0x0003			# 3
		DATA 0x0002			# 2
		DATA 0x0001			# 1
		DATA 0x0000			# 0