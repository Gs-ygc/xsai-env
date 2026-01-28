# RISC-V Firmware Build System
# Requirements: RISCV environment variable must point to toolchain root

SHELL := /bin/bash

# Environment setup
export RISCV := /opt/riscv/
export ARCH := riscv
export CROSS_COMPILE := riscv64-unknown-linux-gnu-

# Directory setup
export WORK_DIR := $(CURDIR)
export RISCV_LINUX_HOME := $(WORK_DIR)/riscv-linux
export RISCV_ROOTFS_HOME := $(WORK_DIR)/riscv-rootfs
export OPENSBI := $(WORK_DIR)/opensbi
export WORKLOAD_BUILD_ENV_HOME := $(WORK_DIR)/nemu_board
export GCPT_HOME := $(WORK_DIR)/LibCheckpoint
export PATH := $(RISCV)/bin:$(PATH)
# Linux kernel version
LINUX_VERSION := 6.10.7
LINUX_TARBALL := linux-$(LINUX_VERSION).tar.xz
LINUX_URL := https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_TARBALL)

# Build targets
LINUX_IMAGE := $(RISCV_LINUX_HOME)/arch/riscv/boot/Image
DTB_FILE := $(WORKLOAD_BUILD_ENV_HOME)/dts/build/xiangshan.dtb
OPENSBI_PAYLOAD := $(OPENSBI)/build/platform/generic/firmware/fw_payload.bin
GCPT_BIN := $(GCPT_HOME)/build/gcpt.bin	

.PHONY: all check-env download-linux setup-submodules build-rootfs build-linux build-dtb build-opensbi build-gcpt clean help

all: setup-submodules build-rootfs build-linux build-dtb build-opensbi build-gcpt
	@echo "✓ Build complete!"
	@echo "  Linux Image: $(LINUX_IMAGE)"
	@echo "  DTB: $(DTB_FILE)"
	@echo "  OpenSBI Payload: $(OPENSBI_PAYLOAD)"
	@echo "  GCPT Binary: $(GCPT_BIN)"

help:
	@echo "RISC-V Firmware Build System"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - Set RISCV environment variable to toolchain root"
	@echo "  - Ensure riscv64-unknown-linux-gnu-gcc is in PATH"
	@echo ""
	@echo "Targets:"
	@echo "  all              - Build everything (default)"
	@echo "  check-env        - Verify environment setup"
	@echo "  download-linux   - Download Linux kernel"
	@echo "  setup-submodules - Initialize git submodules"
	@echo "  build-rootfs     - Build root filesystem"
	@echo "  build-linux      - Build Linux kernel"
	@echo "  build-dtb        - Build device tree blob"
	@echo "  build-opensbi    - Build OpenSBI firmware"
	@echo "  build-gcpt       - Build GCPT checkpoint tool"
	@echo "  clean            - Clean build artifacts"
	@echo "  distclean        - Clean everything including downloads"

check-env:
	@echo "Checking environment..."
	@if [ -z "$(RISCV)" ]; then \
		echo "✗ Error: RISCV environment variable not set"; \
		exit 1; \
	fi
	@if [ ! -f "$(RISCV)/bin/$(CROSS_COMPILE)gcc" ]; then \
		echo "✗ Error: Compiler not found at $(RISCV)/bin/$(CROSS_COMPILE)gcc"; \
		exit 1; \
	fi
	@echo "✓ Environment OK"
	@echo "  RISCV=$(RISCV)"
	@echo "  Compiler: $(shell $(RISCV)/bin/$(CROSS_COMPILE)gcc --version | head -n1)"

download-linux: $(LINUX_TARBALL)
	@echo "Extracting Linux kernel..."
	@if [ ! -d "linux-$(LINUX_VERSION)" ]; then \
		tar xf $(LINUX_TARBALL); \
		ln -s linux-$(LINUX_VERSION) $(RISCV_LINUX_HOME); \
		echo "✓ Linux kernel extracted"; \
	else \
		echo "✓ Linux kernel already extracted"; \
	fi
init: download-linux
	git submodule update --init LibCheckpoint nemu_board opensbi riscv-rootfs
	git submodule update --init --recursive opensbi
$(LINUX_TARBALL):
	@echo "Downloading Linux kernel $(LINUX_VERSION)..."
	@wget -q --show-progress $(LINUX_URL)

setup-submodules:
	@echo "Initializing submodules..."
	@echo "git submodule update --init --recursive"
	@echo "✓ Submodules initialized"

build-rootfs: setup-submodules
	@echo "Building root filesystem..."
	@cd $(RISCV_ROOTFS_HOME) && \
		$(MAKE) apps/busybox -j && \
		$(MAKE) apps/before_workload -j && \
		$(MAKE) apps/hello -j
	@echo "✓ Root filesystem built"

build-linux: build-rootfs
	@echo "Configuring Linux kernel..."
	@cd $(RISCV_LINUX_HOME) && \
		cp $(WORKLOAD_BUILD_ENV_HOME)/configs/xiangshan_defconfig arch/riscv/configs/xiangshan_defconfig && \
		$(MAKE) xiangshan_defconfig && \
		./scripts/config --enable CONFIG_BLOCK && \
		./scripts/config --enable CONFIG_BLK_DEV && \
		./scripts/config --enable CONFIG_VIRTIO_MENU && \
		./scripts/config --enable CONFIG_VIRTIO_MMIO && \
		./scripts/config --enable CONFIG_VIRTIO_BLK && \
		./scripts/config --enable CONFIG_SYSFS && \
		./scripts/config --enable CONFIG_TMPFS && \
		./scripts/config --enable CONFIG_DEVTMPFS && \
		./scripts/config --enable CONFIG_EXT4_FS && \
		./scripts/config --enable CONFIG_BINFMT_SCRIPT && \
		./scripts/config --set-str CONFIG_INITRAMFS_SOURCE "$(RISCV_ROOTFS_HOME)/rootfsimg/initramfs-disk.txt"
	@echo "Building Linux kernel..."
	@cd $(RISCV_LINUX_HOME) && yes ""|$(MAKE) -j$(shell nproc)
	@echo "✓ Linux kernel built: $(LINUX_IMAGE)"

build-dtb: setup-submodules
	@echo "Building device tree blob..."
	@cd $(WORKLOAD_BUILD_ENV_HOME)/dts && \
		bash build_single_core_for_nemu.sh
	@echo "✓ DTB built: $(DTB_FILE)"

# build-opensbi: build-linux build-dtb
build-opensbi:build-dtb
	@echo "Building OpenSBI firmware..."
	@cd $(OPENSBI) && \
		$(MAKE) PLATFORM=generic \
			FW_PAYLOAD_PATH=$(LINUX_IMAGE) \
			FW_FDT_PATH=$(DTB_FILE) \
			FW_PAYLOAD_OFFSET=0x700000 \
			-j$(shell nproc)
	@echo "✓ OpenSBI payload built: $(OPENSBI_PAYLOAD)"

build-gcpt: build-opensbi
	@echo "Building GCPT checkpoint tool..."
	@cd $(GCPT_HOME) && \
		python3 -m venv .gcpt_venv && \
		source .gcpt_venv/bin/activate && \
		pip install --upgrade protobuf grpcio-tools && \
		git checkout f8c33689cdf11aa2f8f25dbf99075dca148ecd44 && \
		git submodule update --init && \
		export GCPT_PAYLOAD_PATH=$(OPENSBI_PAYLOAD) && \
		$(MAKE) USING_DEFAULT_CONFIG=1 -j$(shell nproc) && \
		ls build/gcpt.bin
	@echo "✓ GCPT binary built: $(GCPT_BIN)"

clean:
	@echo "Cleaning build artifacts..."
	@[ -d "$(RISCV_LINUX_HOME)" ] && cd $(RISCV_LINUX_HOME) && $(MAKE) clean || true
	@[ -d "$(OPENSBI)" ] && cd $(OPENSBI) && $(MAKE) clean || true
	@[ -d "$(GCPT_HOME)" ] && cd $(GCPT_HOME) && $(MAKE) clean || true
	@[ -d "$(RISCV_ROOTFS_HOME)" ] && cd $(RISCV_ROOTFS_HOME) && $(MAKE) clean || true
	@echo "✓ Clean complete"

distclean: clean
	@echo "Removing all generated files..."
	@rm -rf $(RISCV_LINUX_HOME)
	@rm -f $(LINUX_TARBALL)
	@git submodule deinit -f --all
	@echo "✓ Deep clean complete"
