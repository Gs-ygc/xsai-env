.PHONY: help deps init llvm update test clean nemu xsai test-matrix qemu

XS_PROJECT_ROOT := $(shell pwd)
NEMU_HOME := $(XS_PROJECT_ROOT)/NEMU
AM_HOME := $(XS_PROJECT_ROOT)/nexus-am
NOOP_HOME := $(XS_PROJECT_ROOT)/XSAI
LLVM_HOME := $(XS_PROJECT_ROOT)/local/llvm

help:
	@echo "XSAI Environment Manager"
	@echo "Usage:"
	@echo "  make deps        - Install system dependencies (requires sudo)"
	@echo "  make init        - Initialize submodules and environment"
	@echo "  make llvm        - Build custom LLVM toolchain"
	@echo "  make nemu        - Build NEMU simulator"
	@echo "  make xsai        - Build XSAI RTL simulation (Verilator)"
	@echo "  make test-matrix - Run matrix simple test"
	@echo "  make update      - Update submodules to latest"
	@echo "  make test        - Test the environment"
	@echo "  make clean       - Clean build artifacts"

deps:
	./scripts/setup-tools.sh

init:
	./scripts/setup.sh

llvm:
	./scripts/build-llvm.sh
qemu:
	cd qemu && mkdir -p build && cd build && ../configure --target-list=riscv64-softmmu,riscv64-linux-user --enable-debug --enable-zstd && make -j && cd ../..
nemu:
	$(MAKE) -C $(NEMU_HOME) riscv64-matrix-xs_defconfig
	$(MAKE) -C $(NEMU_HOME) -j

xsai:
	$(MAKE) -C $(NOOP_HOME) emu -j CONFIG=DefaultMatrixConfig WITH_CHISELDB=1 WITH_CONSTANTIN=0 EMU_THREADS=8 EMU_TRACE=fst

test-matrix:
	$(NEMU_HOME)/build/riscv64-nemu-interpreter -b $(AM_HOME)/apps/llama/llama-riscv64-xs.bin

update:
	./scripts/update-submodule.sh

test:
	./scripts/env-test.sh

clean:
	rm -rf build
	rm -rf local/llvm
