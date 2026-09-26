// run.f – VCS file list for axi_interconnect_wrap_2x8 testbench
// Usage:  vcs -f run.f  (invoked via Makefile)

// RTL source files
../rtl/priority_encoder.v
../rtl/arbiter.v
../rtl/axi_interconnect.v
../rtl/axi_interconnect_wrap_2x8.v

// Testbench files
"../tb files/axi_slave_dummy.v"
"../tb files/tb_axi_interconnect_wrap_2x8.v"
