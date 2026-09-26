# =============================================================================
#  Makefile – AXI Interconnect 2x8 Testbench
#
#  Tool chain : Synopsys VCS (compile + simulate) + Synopsys Verdi (debug)
#  Source list : run.f  (all RTL and TB files listed there)
#
#  Usage:
#    make          – clean, compile, and simulate
#    make compile  – compile only
#    make sim      – run simulation (generates inter.fsdb)
#    make verdi    – open Verdi waveform viewer
#    make clean    – remove all build artefacts
# =============================================================================

# --------------------------------------------------------------------------- #
# Tools
# --------------------------------------------------------------------------- #
VCS   := vcs
VERDI := verdi
SIMV  := ./simv

# --------------------------------------------------------------------------- #
# Top-level module and file list
# --------------------------------------------------------------------------- #
TOP    := tb_axi_interconnect_wrap_2x8
FILELIST := run.f

# --------------------------------------------------------------------------- #
# FSDB / NOVAS PLI  (resolved from VERDI_HOME or PATH)
# --------------------------------------------------------------------------- #
VERDI_HOME ?= $(shell which verdi 2>/dev/null | xargs dirname | xargs dirname)
NOVAS_TAB  := $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab
NOVAS_LIB  := $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a

# --------------------------------------------------------------------------- #
# VCS flags  (matches the command recorded in compile.log)
# --------------------------------------------------------------------------- #
VCS_FLAGS := \
    -full64             \
    -sverilog           \
    -timescale=1ns/1ps  \
    -debug_access+all   \
    -kdb                \
    -lca                \
    +vcs+lic+wait       \
    -top $(TOP)         \
    -o simv

VCS_PLI_FLAGS := \
    -P $(NOVAS_TAB)     \
    $(NOVAS_LIB)

# --------------------------------------------------------------------------- #
# Artefacts to clean
# --------------------------------------------------------------------------- #
CLEAN_TARGETS := \
    csrc         \
    simv         \
    simv.daidir  \
    ucli.key     \
    *.fsdb       \
    verdiLog     \
    novas.*      \
    64           \
    compile.log

# --------------------------------------------------------------------------- #
# Targets
# --------------------------------------------------------------------------- #
.PHONY: all compile sim verdi clean

all: clean compile sim

compile:
	$(VCS) $(VCS_FLAGS) $(VCS_PLI_FLAGS) -f $(FILELIST) -l compile.log

sim:
	$(SIMV)

verdi:
	$(VERDI) -ssf inter.fsdb &

clean:
	rm -rf $(CLEAN_TARGETS)
