#!/usr/bin/perl -w



#USAGE:

#

# asmbl.pl <infile> [ > <outfile> ]



#NOTES:

# -All labels MUST start with L

# -Shift amounts must be in decimal

# -Immediate may be in hex or decimal.  If in hex, precede with "0x"

# -Comments may be specified with either "#" or "//".  

# -No multiline comments

#

# MEM <ADDR> and DATA <VALUE> may be used to specify memory

#





#################################################################





use strict;



if(@ARGV < 1) { print "Usage: asmbl.pl <input assembly file> > outputFile\n"; exit; }





my %regs = ("R0" => "0000", "R1" => "0001", "R2" => "0010", "R3" => "0011",

	    "R4" => "0100", "R5" => "0101", "R6" => "0110", "R7" => "0111",

	    "R8" => "1000", "R9" => "1001", "R10"=> "1010", "R11"=> "1011",

	    "R12"=> "1100", "R13"=> "1101", "R14"=> "1110", "R15"=> "1111");



my %conds = ("NEQ" => "000", "EQ" => "001", "GT" => "010", "LT" => "011", "GTE" => "100", "LTE" => "101", "OVFL" => "110", "UNCOND" => "111");



my %numArgs = ( qw/ADD 3 ADDC 3 SUB 3 SUBB 3 AND 3 OR 3 NAND 3 XOR 3 ADDI 3 ADDIEQ 3 ADDINE 3 ADDIGT 3 SUBI 3 ANDI 3 ORI 3 XORI 3 SLL 3 SRL 3 SRA 3 B 2 LW 3 SW 3 LHB 2 LLB 2 JAL 1 JR 1 RTI 0 PUSH 1 POP 1 MOVC 3 MULU 3 MULS 3 XMULH 1/);



my %opcode = ( qw/ADD 00000 ADDC 00001 SUB 00010 SUBB 00011 AND 00100 OR 00101 NAND 00110 XOR 00111 ADDI 01000 ADDIEQ 01001 ADDINE 01010 ADDIGT 01011 SUBI 01100 ANDI 01101 ORI 01110 XORI 01111 SLL 10000 SRL 10001 SRA 10010 B 10011 LW 10100 SW 10101 LHB 10110 LLB 10111 JAL 11000 JR 11001 RTI 11010 PUSH 11011 POP 11100 MOVC 11101 MULU 11110 MULS 11110 XMULH 11111/);



my %rlookup = ( "1111", "F" , "1110", "E" , "1101", "D" , "1100", "C",

                "1011", "B" , "1010", "A" , "1001", "9" , "1000", "8",

                "0111", "7" , "0110", "6" , "0101", "5" , "0100", "4",

                "0011", "3" , "0010", "2" , "0001", "1" , "0000", "0");





open(IN, "$ARGV[0]") or die("Can't open $ARGV[0]: $!");



my %labels = ( );

my @mem;

my @code;

my @source_lines;

my $addr = 0;



while(<IN>) {

    my $bits = "";



    s/\#(.*)$//;  #remove  (#) comments

    s#//(.*)$##;  #remove (//) comments

    next if( /^\s*$/ );  #skip blank lines



    if(/MEM\s+(\S*)/) {

	$addr = hex($1);

	next;

    }

    if(/DATA\s+(.*)/) {

	my $data = $1;

	$data =~ s/\s*(\S+)\s*/$1/;

	while(length($data) < 4) { $data = "0" . $data }

	$mem[$addr++] = hexToBin($data, 20);

	next;

    }
	
    if(/STRING\s+(.*)/) {

	my $data = $1;

    my @chars;
	
    @chars = split(//,$data);
	
	my $x;
	
	for ($x=1; $x<(length($data)-1); $x++) {
		$mem[$addr] = decToBin(ord($chars[$x]),20);
		$source_lines[$addr++] = $chars[$x];
	}
	$mem[$addr] = decToBin(0,20);	## NULL terminate
	$source_lines[$addr++] = "Null terminate";

	next;

    }

    $source_lines[$addr] = $_;

    $source_lines[$addr] =~ s/^\s+|\s+$//g;

    $_ = uc($_);



  if(s/(.*)://) {  #capture labels

    my $label = $1;

    $label =~ s/\s*(\S+)\s*/$1/;   #strip white space

    $labels{$label} = $addr;

  }



  if( /^\s*(\S+)\s*(.*)/ ) {

      my $instr = $1;

      my @args = split(",", $2);

      

      if(!exists($numArgs{$instr})) { die("Unknown instruction\n$_") }

      if($numArgs{$instr} != @args) { 

	  die("Error:\n$_\nWrong number of arguments (need $numArgs{$instr} args)\n") 

	  }

      

      $bits = "$opcode{$instr}";



      #strip whitespace from arguments

      for(my $c=0; $c<@args; $c++) { 

	  $args[$c] =~ s/^\s*(\S+)\s*$/$1/ ;

      }

      

  if($instr =~ /^(ADD|ADDC|SUB|SUBB|AND|OR|NAND|XOR)$/) {

	  foreach my $reg ($args[0], $args[1], $args[2]) {

	      if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

	      $bits .= $regs{$reg};

	  }

          $bits .= "000";
		  
      }
      elsif($instr =~ /^(ADDI|ADDIEQ|ADDINE|ADDIGT|SUBI|ANDI|ORI|XORI)$/) {

	  foreach my $reg ($args[0], $args[1]) {

	      if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

	      $bits .= $regs{$reg};

	  }
	  $bits .= parseImmediate($args[2], 7);

      }
      elsif($instr =~ /^(SRA|SLL|SRL)$/) {

	  foreach my $reg ($args[0], $args[1]) {

	      if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

	      $bits .= $regs{$reg};

	  }

      $bits .= "000";
	  $bits .= parseImmediate($args[2], 4);

      }
      elsif($instr =~ /^(LW|SW)$/) {

	  foreach my $reg ($args[0], $args[1]) {

	      if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

	      $bits .= $regs{$reg};

	  }

	  $bits .= parseImmediate($args[2], 7);

      }
	  elsif($instr =~ /^(B)$/) {

	  if(!$conds{$args[0]}) { die("Invalid condition code ($args[0])\n$_\nUse only from {NEQ, EQ, GT, LT, GTE, LTE, OVFL, UNCOND}") }

	  else { $bits .= $conds{$args[0]}; }



	  if($args[1] !~ /[a-zA-Z]/) { print STDERR "Error: Invalid label name: \"$args[1]\" in line:\n$_"; exit; }

	  $bits .= "|" . $args[1] . "|12|B|";

      }
      elsif($instr =~ /^(LHB|LLB)$/) {

	  foreach my $reg ($args[0]) {

	      if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

	      $bits .= $regs{$reg};

	  }
	  
	  $bits .= "000";

	  $bits .= parseImmediate($args[1], 8);

      }

      elsif($instr =~ /^(JAL)$/) {

	  if($args[0] !~ /[a-zA-Z]/) { print STDERR "Error: Invalid label name: \"$args[0]\" in line:\n$_"; exit; }

	  $bits .= "|" . $args[0] . "|15|J|";

      }

      elsif($instr =~ /^(JR)$/) {
    foreach my $reg ($args[0]) {

        if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

        $bits .= "0000" . $regs{$reg} . "0000000";

    }

      }

      elsif($instr =~ /^(RTI)$/) {
    $bits .= "000000000000000";

      }
      elsif($instr =~ /^(PUSH|POP|XMULH)$/) {

	  foreach my $reg ($args[0]) {

	      if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

	      $bits .= $regs{$reg} . "00000000000";


	  }

      }
	  elsif($instr =~ /^(MOVC)$/) {

	  foreach my $reg ($args[0], $args[1]) {

	      if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

	      $bits .= $regs{$reg};

	  }
	  
	  $bits .= parseImmediate($args[2], 7);

      }
	  elsif($instr =~ /^(MULU|MULS)$/) {

	  foreach my $reg ($args[0], $args[1], $args[2]) {

	      if(!$regs{$reg}) { die("Bad register ($reg)\n$_") }

	      $bits .= $regs{$reg};

	  }
          if ($instr =~/^MULU$/) {		## differentiate unsigned vs signed with LSB
            $bits .= "000";
		  } else {
		    $bits .= "001";
		  }
		  
      }
	  
      #print $bits;

      $mem[$addr] = $bits;

      $code[$addr] = $_;

      $addr += 1;

  }    

}

close(IN);



# print "DEPTH = 64;\n";

# print "WIDTH = 16;\n";

# print "ADDRESS_RADIX = HEX;\n";

# print "DATA_RADIX = HEX;\n";

# print "CONTENT\n";

# print "BEGIN\n";

#print "@"."0\n";



for(my $i=0; $i<scalar(@mem); $i++) {

  $addr = $mem[$i];

  next if(!$addr);
 
  if($addr =~ /\|(.+)\|(\d+)\|(\w)\|/) { 

    if(!$labels{$1}) { die("Error:\nLabel referenced, but doesnt exist ($1)\n") }

    my $disp = $labels{$1} - $i - 1;
#    my $disp = ($3 eq "J") ? $labels{$1} : ($labels{$1} - ($i*2 + 2)) / 2;

    $disp = decToBin($disp, $2);

    $addr =~ s/\|(.+)\|(\d+)\|(\w)\|/$disp/;

  }

  #my $j = $i / 2;  #shift from a byte address to a word address

  # print decToHex($i) . "  :  " . binToHex($addr) . "  ;\n";
	
  print "\@" . decToHex($i, 4) . " " . binToHex($addr) . "\t// " . $source_lines[$i] . "\n";

  #if($code[$i]) { print $code[$i] }

  #else { print "\n" }

}







sub parseImmediate {

    my $imm = $_[0];

    my $hex = ($imm =~ /^0x/i) ? 1 : 0;

    $imm =~ s/^0x//i if($hex);

    return $hex ? hexToBin($imm, $_[1]) : decToBin($imm, $_[1]);

}



sub hexToBin {

  return decToBin(hex($_[0]), $_[1]);

}



sub decToBin {

    my $ret = sprintf("%b", $_[0]);

    while(length($ret) < $_[1]) { $ret = "0" . $ret }

    if(length($ret) > $_[1]) { $ret = substr($ret, length($ret)-$_[1]) }

    return $ret;

}







sub decToHex {

  my $ret = sprintf("%x", $_[0]);

  while(length($ret) < 4) { $ret = "0" . $ret }

  return $ret;

}



sub binToHex {
	
	## print "in binToHex with $_[0]";

  $_[0] =~ /(\d{4})(\d{4})(\d{4})(\d{4})(\d{4})/;

  return $rlookup{$1} . $rlookup{$2} . $rlookup{$3} . $rlookup{$4} . $rlookup{$5}; 

}



