#!/bin/bash
# ==============================================================================
# Script : run_uvm.sh
# Project: RISC-V VeeR EL2 Real-Time Data Buffering SoC
# Description: Automated compilation and execution script for UVM testbench
# ==============================================================================

set -e

# Toolchain configuration
export VCS_HOME=${VCS_HOME:-/home/student/snps_tools_target/vcs/U-2023.03}
export VERDI_HOME=${VERDI_HOME:-/home/student/snps_tools_target/verdi/U-2023.03-SP1}
export SNPSLMD_LICENSE_FILE=${SNPSLMD_LICENSE_FILE:-27021@14.139.1.126}
export PATH=$VCS_HOME/bin:$VERDI_HOME/bin:$PATH
export RV_ROOT="/home/student/Documents/317/soc_project_data_buffering/rtl/Cores-VeeR-EL2"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
PRJ_DIR=$(cd "$SCRIPT_DIR/../.." && pwd -P)
RUN_DIR="$PRJ_DIR/run"

mkdir -p "$RUN_DIR"
cd "$RUN_DIR"

TEST_NAME=${1:-"soc_e2e_test"}
VERBOSITY=${2:-"UVM_LOW"}

echo "=============================================================================="
echo "   COMPILING RISC-V VeeR EL2 SoC UVM TESTBENCH"
echo "=============================================================================="
vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
    -debug_access+all -kdb -lca +vcs+lic+wait \
    -top tb_soc_uvm_top -o simv_uvm \
    -f ../uvm_tb/flist/uvm_soc.f \
    -l uvm_compile.log

echo "=============================================================================="
echo "   RUNNING UVM TEST: $TEST_NAME"
echo "=============================================================================="
./simv_uvm +UVM_TESTNAME="$TEST_NAME" +UVM_VERBOSITY="$VERBOSITY" -l "${TEST_NAME}.log"

echo "=============================================================================="
echo "   TEST EXECUTION COMPLETED: $TEST_NAME"
echo "=============================================================================="
