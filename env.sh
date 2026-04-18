# This script sets up the core XiangShan environment variables.
# It is the baseline workflow for manual shells and CI.
# `.envrc` layers on the same shared environment, optional local overrides,
# and submodule freshness checks.

source "$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)/scripts/env-common.sh"
xsai_env_init

if [[ "${XSAI_ENV_QUIET:-0}" != "1" ]]; then
  xsai_env_print_summary
fi
