#!/bin/bash
# 构建 RISC-V LLVM/Clang 交叉编译工具链的脚本
# 在 x86 主机上构建，生成的 Clang 可以交叉编译 RISC-V 代码

# 设置 RISC-V 交叉编译器路径（用于编译 compiler-rt 等运行时库）
export RISCV_TOOLCHAIN_PREFIX=riscv64-linux-gnu-
export RISCV=$XS_PROJECT_ROOT/local/llvm
export PATH=$RISCV/bin:$PATH
# 检查交叉编译器是否存在
if ! command -v ${RISCV_TOOLCHAIN_PREFIX}gcc &> /dev/null; then
    echo "错误: 找不到 RISC-V 交叉编译器 ${RISCV_TOOLCHAIN_PREFIX}gcc"
    echo "请安装 RISC-V 交叉编译工具链:"
    echo "  sudo apt-get install gcc-riscv64-linux-gnu g++-riscv64-linux-gnu"
    exit 1
fi

# 设置 RISCV 环境变量（如果未设置）
if [ -z "$RISCV" ]; then
    export RISCV=$(pwd)/install
    echo "设置 RISCV=$RISCV"
fi
mkdir -p $RISCV
cd $XS_PROJECT_ROOT
# 创建构建目录
mkdir -p build && cd build

# 配置 cmake
# 注意：
# - LLVM/Clang 本身用主机编译器（x86）编译（默认，不指定 CMAKE_C_COMPILER）
# - compiler-rt 等运行时库用 RISC-V 交叉编译器编译
# - LLVM 的构建系统会自动检测并使用交叉编译器来编译目标架构的运行时库
cmake -DCMAKE_INSTALL_PREFIX=$RISCV \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_OPTIMIZED_TABLEGEN=On \
  -DLLVM_ENABLE_PROJECTS="clang;lld;clang-tools-extra" \
  -DLLVM_LINK_LLVM_DYLIB=On \
  -DLLVM_DEFAULT_TARGET_TRIPLE="riscv64-unknown-linux-gnu" \
  -DLLVM_TARGETS_TO_BUILD="RISCV" \
  ../llvm

# 构建
# 如果需要 builtins 库，可以先构建 builtins，然后再构建其他库
# 但通常不需要，因为系统库已经提供了这些函数
make -j$(nproc) && make install

