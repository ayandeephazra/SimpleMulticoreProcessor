onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /cpu_tb/iCPU/p0
add wave -noupdate /cpu_tb/iCPU/p1
add wave -noupdate /cpu_tb/iCPU/DM_we
add wave -noupdate /cpu_tb/iCPU/iaddr
add wave -noupdate /cpu_tb/iCPU/instr
add wave -noupdate /cpu_tb/iCPU/dst_EX_DM
add wave -noupdate /cpu_tb/iCPU/p0_EX_DM
add wave -noupdate /cpu_tb/iCPU/dm_re_EX_DM
add wave -noupdate /cpu_tb/iCPU/dm_we_EX_DM
add wave -noupdate /cpu_tb/iCPU/dm_rd_data_EX_DM
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {125 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {1 ns}
