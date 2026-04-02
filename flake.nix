{
  description = "Nix devshells for XiangShan";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  };

  outputs = {nixpkgs, ...}: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    riscvGcc = pkgs.pkgsCross.riscv64.buildPackages.gcc;

    # Common packages for both shells
    basePackages = with pkgs; [
      autoconf
      bear
      bison
      cmake
      curl
      dtc
      flex
      git
      git-lfs
      gnumake
      direnv
      gnugrep
      gnused
      gawk
      gtkwave
      libcap_ng
      libslirp
      openjdk
      pixman
      pkg-config
      python3
      python3Packages.psutil
      readline
      SDL2
      sqlite
      time
      tmux
      wget
      zlib
      zstd
      (mill.overrideAttrs (finalAttrs: _: {
        version = "0.12.15";
        src = pkgs.fetchurl {
          url = "https://repo1.maven.org/maven2/com/lihaoyi/mill-dist/${finalAttrs.version}/mill-dist-${finalAttrs.version}.exe";
          hash = "sha256-6hu6AeIg9M4guzMyR9JUor+bhlVMEMPX1+FmQewKdtg=";
        };
      }))
      (verilator.overrideAttrs (finalAttrs: _: {
        version = "5.040";
        VERILATOR_SRC_VERSION = "v${finalAttrs.version}";
        src = pkgs.fetchFromGitHub {
          owner = "verilator";
          repo = "verilator";
          rev = "v${finalAttrs.version}";
          hash = "sha256-S+cDnKOTPjLw+sNmWL3+Ay6+UM8poMadkyPSGd3hgnc=";
        };
        doCheck = false;
      }))
    ];

    smokeInputs = with pkgs; [
      bash
      coreutils
      findutils
      git
      gnumake
      gnugrep
      gnused
      nix
      riscvGcc
    ];

    # Common shell hook setup
    mkShellHook = isPure: ''
      export XSAI_ENV_QUIET=1

      # Set RISCV to the cross toolchain
      export RISCV="${riscvGcc}"

      source ./scripts/env-common.sh
      xsai_env_init

      echo "=== Welcome to XiangShan devshell! ${if isPure then "(PURE)" else "(default)"} ==="
      echo "Version info:"
      echo "- $(verilator --version)"
      echo "- $(mill --version | head -n 1)"
      echo "- Host GCC: $(gcc --version | head -n 1)"
      echo "- RISC-V GCC: $("$RISCV"/bin/riscv64-unknown-linux-gnu-gcc --version | head -n 1)"
      echo "- $(java -version 2>&1 | head -n 1)"
      echo ""
      ${if isPure then ''
        echo "PURE MODE: System paths are excluded"
        echo "  - No /usr/include or /usr/lib pollution"
        echo "  - All tools from Nix store only"
      '' else ''
        echo "Note: RISC-V cross compiler is at \$RISCV/bin/"
      ''}
      echo "You can press Ctrl + D to exit devshell."
    '';
  in {
    devShells.${system} = {
      # Default shell - allows system tools to be used
      default = pkgs.mkShell {
        packages = basePackages ++ [pkgs.gcc];
        shellHook = mkShellHook false + ''
          export LD_LIBRARY_PATH="${pkgs.zlib}/lib:${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH"
        '';
      };

      # Pure shell - completely isolated from system
      pure = pkgs.mkShell {
        buildInputs = basePackages ++ [
          pkgs.nix
          pkgs.gcc
          pkgs.glibc
          pkgs.glibc.dev
        ];

        # Keep GCC wrapper environment variables intact
        shellHook = mkShellHook true + ''
          # Create RISC-V cross compiler wrappers
          RISCV_WRAPPER_DIR="$(mktemp -d)"
          for bin in "$RISCV"/bin/riscv64-unknown-linux-gnu-*; do
            if [[ -x "$bin" ]]; then
              name=$(basename "$bin")
              ln -sf "$bin" "$RISCV_WRAPPER_DIR/$name" 2>/dev/null || true
            fi
          done

          # Pure mode: replace PATH entirely, do NOT append $PATH (avoids host/WSL pollution)
          export PATH="$RISCV_WRAPPER_DIR:${pkgs.lib.makeBinPath (basePackages ++ [
            pkgs.nix
            pkgs.gcc
            pkgs.gnumake
            pkgs.cmake
            pkgs.coreutils
            pkgs.bash
            pkgs.which
            pkgs.file
            pkgs.glibc
          ])}"

          # IMPORTANT: Do NOT unset NIX_CFLAGS_COMPILE or NIX_LDFLAGS
          # They are set by GCC wrapper and point to Nix glibc headers
          # We only add our own flags on top

          # Unset LD_LIBRARY_PATH to avoid glibc/libstdc++ version conflicts.
          # Nix binaries have their library paths baked in via RPATH, so they
          # don't need LD_LIBRARY_PATH. Setting it causes stack smashing when
          # the host (WSL) dynamic linker loads Nix glibc.
          unset LD_LIBRARY_PATH

          echo ""
          echo "Environment validation:"
          echo "  glibc: $(ldd --version 2>/dev/null | head -1 || echo 'N/A')"
          echo "  gcc: $(gcc --version | head -1)"
          echo "  cmake: $(cmake --version | head -1)"
          echo "  riscv64-unknown-linux-gnu-gcc: $(riscv64-unknown-linux-gnu-gcc --version | head -1)"
          echo ""
          echo "To build LLVM: nix develop .#llvm -c make llvm  (or: make nix-llvm)"
        '';
      };

    };

    checks.${system}.smoke = pkgs.runCommand "xsai-smoke" {
      nativeBuildInputs = smokeInputs;
      src = ./.;
    } ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      cp -R "$src" repo
      chmod -R u+w repo
      cd repo
      bash ./scripts/smoke-test.sh --mode nix
      touch "$out"
    '';
  };
}
