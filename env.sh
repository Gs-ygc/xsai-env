# This script will setup XiangShan environment variables

export XS_PROJECT_ROOT=$(pwd)
export NEMU_HOME=$(pwd)/NEMU
export AM_HOME=$(pwd)/nexus-am
export NOOP_HOME=$(pwd)/XSAI
export DRAMSIM3_HOME=$(pwd)/DRAMsim3
export LLVM_HOME=$(pwd)/local/llvm

export ARCH=riscv
export CROSS_COMPILE=riscv64-linux-gnu-
# export PATH=$LLVM_HOME/bin:$PATH

echo SET XS_PROJECT_ROOT: ${XS_PROJECT_ROOT}
echo SET NOOP_HOME \(XSAI RTL Home\): ${NOOP_HOME}
echo SET NEMU_HOME: ${NEMU_HOME}
echo SET AM_HOME: ${AM_HOME}
echo SET DRAMSIM3_HOME: ${DRAMSIM3_HOME}
echo SET LLVM_HOME: ${LLVM_HOME}
