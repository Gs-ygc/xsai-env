cd XSAI; git fetch origin; git checkout origin/master; make init; cd ..
cd NEMU; git checkout dev-v0.6; git pull --rebase; cd ..
cd nexus-am; git checkout master; git pull --rebase; cd ..
cd llvm-project-ame; git fetch origin triton-commit-hash; git checkout triton-commit-hash; git pull --rebase origin triton-commit-hash; cd ..
cd qemu; git checkout 9.0.0_matrix-v0.6; git pull --rebase; cd ..