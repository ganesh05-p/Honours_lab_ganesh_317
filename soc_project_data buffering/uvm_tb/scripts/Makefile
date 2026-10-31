# ==============================================================================
# Makefile : UVM Verification Suite
# Project  : RISC-V VeeR EL2 Real-Time Data Buffering SoC
# Team     : 5-Member DV Team Structure
# ==============================================================================

export VCS_HOME ?= /home/student/snps_tools_target/vcs/U-2023.03
export VERDI_HOME ?= /home/student/snps_tools_target/verdi/U-2023.03-SP1
export SNPSLMD_LICENSE_FILE ?= 27021@14.139.1.126
export PATH := $(VCS_HOME)/bin:$(VERDI_HOME)/bin:$(PATH)
export RV_ROOT := /home/student/Documents/317/soc_project_data_buffering/rtl/Cores-VeeR-EL2

PRJ_DIR ?= /home/student/Documents/317/soc_project_data_buffering
RUN_DIR := $(PRJ_DIR)/run
FLIST   := ../uvm_tb/flist/uvm_soc.f

VCS_FLAGS := -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
             -debug_access+all -kdb -lca +vcs+lic+wait \
             -top tb_soc_uvm_top -f $(FLIST)

.PHONY: compile test_fifo test_dma test_plic test_axi_uart test_e2e regression clean help

help:
	@echo "Available targets:"
	@echo "  make compile        - Compile the UVM testbench and DUT"
	@echo "  make test_fifo      - Member 1: FIFO Verification"
	@echo "  make test_dma       - Member 2: DMA Controller Verification"
	@echo "  make test_plic      - Member 3: PLIC Interrupt Controller Verification"
	@echo "  make test_axi_uart  - Member 4: AXI Interconnect & UART AXI-Lite Regression"
	@echo "  make test_e2e       - Member 5: Full SoC End-to-End Real-Time Buffering Test"
	@echo "  make regression     - Run all 5 member tests in sequence"
	@echo "  make clean          - Remove simulation artifacts"

compile:
	@mkdir -p $(RUN_DIR)
	cd $(RUN_DIR) && vcs $(VCS_FLAGS) -o simv_uvm -l uvm_compile.log

test_fifo: compile
	cd $(RUN_DIR) && ./simv_uvm +UVM_TESTNAME=soc_fifo_test +UVM_VERBOSITY=UVM_LOW -l soc_fifo_test.log

test_dma: compile
	cd $(RUN_DIR) && ./simv_uvm +UVM_TESTNAME=soc_dma_test +UVM_VERBOSITY=UVM_LOW -l soc_dma_test.log

test_plic: compile
	cd $(RUN_DIR) && ./simv_uvm +UVM_TESTNAME=soc_plic_test +UVM_VERBOSITY=UVM_LOW -l soc_plic_test.log

test_axi_uart: compile
	cd $(RUN_DIR) && ./simv_uvm +UVM_TESTNAME=soc_axi_uart_test +UVM_VERBOSITY=UVM_LOW -l soc_axi_uart_test.log

test_e2e: compile
	cd $(RUN_DIR) && ./simv_uvm +UVM_TESTNAME=soc_e2e_test +UVM_VERBOSITY=UVM_LOW -l soc_e2e_test.log

regression: compile
	@echo "=========================================================="
	@echo "   STARTING 5-MEMBER UVM DV TEAM REGRESSION"
	@echo "=========================================================="
	@$(MAKE) test_fifo
	@$(MAKE) test_dma
	@$(MAKE) test_plic
	@$(MAKE) test_axi_uart
	@$(MAKE) test_e2e
	@echo "=========================================================="
	@echo "   ALL 5 UVM TESTS COMPLETED SUCCESSFULLY!"
	@echo "=========================================================="

clean:
	cd $(RUN_DIR) && rm -rf simv* csrc *.log ucli.key vc_hdrs.h *.daidir DVEfiles
