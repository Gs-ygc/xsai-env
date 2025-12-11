# XSAI Development Environment

This repository provides an out-of-the-box development environment for XSAI (XiangShan AI).

## Quick Start

### 1. Setup

Clone the repository and initialize the environment. This only needs to be done once.

```bash
git clone https://github.com/Gs-ygc/xsai-env
cd xsai-env
sudo make deps   # Install dependencies (Ubuntu/Debian)
make init        # Initialize submodules
```

### 2. Environment Variables

Before working, load the environment variables. We recommend using [direnv](https://direnv.net/) for automatic loading.

```bash
source env.sh
```

## Workflow

You can use the `Makefile` in the root directory to manage the workflow.

### 1. NEMU (Instruction Set Simulator)

Build the NEMU simulator.

```bash
make nemu
```

### 2. XSAI (RTL Simulation)

Build the Verilator simulation executable from RTL code.

```bash
make xsai
```

### 3. LLVM Compiler (AME Support)

Build the custom LLVM compiler with AME instruction support.

```bash
make llvm
```

This will install the compiler to `$XS_PROJECT_ROOT/local/llvm`.

### 4. Running Tests

Compile and run the matrix simple test in `nexus-am`.

```bash
make test-matrix
```

## Directory Structure

* `NEMU`: Instruction Set Simulator
* `XSAI`: RTL Code (XiangShan AI)
* `llvm-project-ame`: LLVM compiler source with AME support
* `nexus-am`: Abstract Machine and tests
