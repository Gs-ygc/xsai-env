#!/bin/bash

# This script will setup XiangShan develop environment automatically

# Init submodules
# Setup XiangShan environment variables

dev(){
    git submodule update --init DRAMsim3 NEMU NutShell nexus-am riscv-matrix-spec qemu
    git submodule update --init --depth 1 llvm-project-ame
    cd nexus-am && git lfs pull; cd -;
    git submodule update --init XSAI && make -C XSAI init;
    cd firmware && make init; cd -;
}
user(){
    git submodule update --init qemu
    cd firmware && make init; cd -;
}
user
source $(dirname "$0")/../env.sh
# OPTIONAL: export them to .bashrc
echo XS_PROJECT_ROOT: ${XS_PROJECT_ROOT}
echo NEMU_HOME: ${NEMU_HOME}
echo AM_HOME: ${AM_HOME}
echo NOOP_HOME: ${NOOP_HOME}
