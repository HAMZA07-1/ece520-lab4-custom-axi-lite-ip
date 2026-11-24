# Run in the VIVADO Tcl Console (not XSCT).
# Extract the zip to C:/Vivado_ECE520/ECE520_Lab4_FIFO_VHDL first.
# Creates an independent simulation project without touching your working SoC.
catch {close_project}
set root {C:/Vivado_ECE520/ECE520_Lab4_FIFO_VHDL}
set sim_project {C:/Vivado_ECE520/sc_fifo_axi_sim}
create_project -force sc_fifo_axi_sim $sim_project -part xc7z010clg400-1
set_property target_language VHDL [current_project]
add_files -norecurse [file join $root src sc_fifo.vhd]
add_files -norecurse [file join $root src sc_fifo_axi_v1_0_S00_AXI.vhd]
add_files -norecurse [file join $root src sc_fifo_axi_v1_0.vhd]
add_files -fileset sim_1 -norecurse [file join $root sim tb_sc_fifo_axi.vhd]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property top tb_sc_fifo_axi [get_filesets sim_1]
launch_simulation
run 100 us
puts "Inspect simulation Tcl console for PASS or assertion failures."
