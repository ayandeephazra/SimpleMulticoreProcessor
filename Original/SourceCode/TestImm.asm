###########################################
# Tests immediate instructions of new ISA #
###########################################
		# Test ADDI basic function #
		############################
		LLB R1, 0x55		# R1 contains 0x0055
		ADDI R2, R1, 0x3F	# add most positive value, should be 0x94
	    LLB R3, 0x94		# R3 contains 0xFF94
		LHB R3, 0x00		# R3 contains 0x0094
		SUB R3, R2, R3		# compare R2 to known right answer
		B NEQ, L_FAIL		# branch to fail routine
		
		####################################
		# Test ADDI most negative value    #
		# Also checks that ADDI set Z flag #
		####################################
		LLB R3, 0x40		# R3 contains +0x40
		ADDI R2, R3, 0xC0	# Adding -0x40
		B NEQ, L_FAIL		# result should be zero
		
		######################################
		# Test that ADDI sets the carry flag #
		# Also a test of ADDC with C set     #
		######################################
		LLB R1, 0x03
		ADD R1, R1, R1		# ensure C flag zero to start, R1 = 0x0006
		LLB R3, 0xE0		# R3 contains 0xFFE0
		ADDI R2, R3, 0x3F	# will produce a carry
		ADDC R2, R1, R1		# should be adding 0x0006 + 0x0006 + 1 = 0x000D
		LLB R3, 0x0D
		SUB R3, R2, R3		# compare to 0x000D
		B NEQ, L_FAIL
		
		.
		.	Further testing
		.
		
		B UNCOND, L_PASS

		##########################
		# Pass routine at 0x0AAA #
		##########################
		MEM 0x0AAA			# locate fail routine at 0xAAA
L_PASS: B UNCOND, L_PASS

		##########################
		# Fail routine at 0x0FFF #
		##########################
		MEM 0x0FFF			# locate fail routine at 0xFFF
L_FAIL: B UNCOND, L_FAIL

		
		MEM 0x1100			# string data
		STRING "Hello World"
