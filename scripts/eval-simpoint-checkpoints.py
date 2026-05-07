#!/usr/bin/env python3
import argparse
import concurrent.futures
import glob
import json
import math
import re
import subprocess
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Optional

INT_TOKEN_RE = r"([0-9][0-9,]*)"
FLOAT_TOKEN_RE = r"([0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)"
CYCLE_RE = re.compile(
    rf"Core(?:-| )0 instrCnt = {INT_TOKEN_RE}, cycleCnt = {INT_TOKEN_RE}, IPC = {FLOAT_TOKEN_RE}"
)
GUEST_CYCLE_RE = re.compile(rf"Guest cycle spent: {INT_TOKEN_RE}")
BBV_SIZE_RE = re.compile(r"size:\s*(\d+)x(\d+)")

@dataclass
class SimpointEntry:
    simpoint_id: int
    weight: float
    cluster_id: int
    payload: Path

@dataclass
class RunResult:
    simpoint_id: int
    cluster_id: int
    weight: float
    payload: str
    instr_cnt: int
    cycle_cnt: int
    ipc: float
    guest_cycle_spent: Optional[int]


def parse_simpoints(weights_path: Path, simpoints_path: Path, payload_root: Path, skip_missing: bool = True, renormalize: bool = True):
    weights_lines = [ln.strip() for ln in weights_path.read_text().splitlines() if ln.strip()]
    simpoint_lines = [ln.strip() for ln in simpoints_path.read_text().splitlines() if ln.strip()]
    if len(weights_lines) != len(simpoint_lines):
        raise ValueError(f"weights/simpoints length mismatch: {len(weights_lines)} vs {len(simpoint_lines)}")

    entries: list[SimpointEntry] = []
    skipped: list[dict] = []
    total_kept_weight = 0.0

    for wln, sln in zip(weights_lines, simpoint_lines):
        w_parts = wln.split()
        s_parts = sln.split()
        if len(w_parts) < 2 or len(s_parts) < 2:
            raise ValueError(f"bad line pair: '{wln}' / '{sln}'")
        weight = float(w_parts[0])
        w_cluster = int(w_parts[1])
        simpoint_id = int(s_parts[0])
        s_cluster = int(s_parts[1])
        if w_cluster != s_cluster:
            raise ValueError(f"cluster id mismatch for simpoint {simpoint_id}: {w_cluster} != {s_cluster}")

        pattern = str(payload_root / str(simpoint_id) / f"_{simpoint_id}_*.zstd")
        matches = sorted(glob.glob(pattern))
        if not matches:
            pattern2 = str(payload_root / str(simpoint_id) / f"_{simpoint_id}_*.zst")
            matches = sorted(glob.glob(pattern2))
        if not matches:
            info = {
                "simpoint_id": simpoint_id,
                "cluster_id": w_cluster,
                "weight": weight,
                "reason": f"missing payload under {payload_root / str(simpoint_id)}",
            }
            if skip_missing:
                skipped.append(info)
                continue
            raise FileNotFoundError(info["reason"])

        if len(matches) > 1:
            exact = [m for m in matches if f"_{simpoint_id}_{weight}" in m]
            payload = Path(exact[0]) if len(exact) == 1 else Path(matches[0])
        else:
            payload = Path(matches[0])

        entries.append(SimpointEntry(simpoint_id=simpoint_id, weight=weight, cluster_id=w_cluster, payload=payload))
        total_kept_weight += weight

    if renormalize and entries and total_kept_weight > 0.0 and abs(total_kept_weight - 1.0) > 1e-9:
        for e in entries:
            e.weight /= total_kept_weight

    return entries, skipped, total_kept_weight


def renormalize_entries(entries: list[SimpointEntry]) -> float:
    total = sum(e.weight for e in entries)
    if total > 0.0:
        for e in entries:
            e.weight /= total
    return total


def parse_interval_count(cluster_out: Path) -> int:
    text = cluster_out.read_text(errors="ignore")
    m = BBV_SIZE_RE.search(text)
    if not m:
        raise ValueError(f"could not parse interval count from {cluster_out}")
    return int(m.group(1))


def parse_int_token(token: str) -> int:
    return int(token.replace(",", ""))


def run_payload(repo_root: Path, payload: Path, max_instr: int, make_target: str, extra_make_args: list[str]):
    if make_target == "run-emu" and not extra_make_args:
        cmd = [
            str(repo_root / "scripts" / "run-emu.sh"),
            "--log",
            "-I", str(max_instr),
            str(payload),
        ]
    else:
        cmd = [
            "make",
            make_target,
            f"PAYLOAD={payload}",
            "DIFF=0",
            f"MAX={max_instr}",
            f"MAX_INSTR={max_instr}",
            *extra_make_args,
        ]
    proc = subprocess.run(cmd, cwd=repo_root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out = proc.stdout
    if proc.returncode != 0:
        raise RuntimeError(f"command failed for {payload}: exit {proc.returncode}\n{out}")

    m = CYCLE_RE.search(out)
    if not m:
        raise RuntimeError(f"could not parse instr/cycle from output for {payload}\n{out}")
    g = GUEST_CYCLE_RE.search(out)
    return (
        parse_int_token(m.group(1)),
        parse_int_token(m.group(2)),
        float(m.group(3)),
        (parse_int_token(g.group(1)) if g else None),
        out,
    )


def resolve_json_out(repo_root: Path, output_dir: Path, json_out: str) -> Path:
    path = Path(json_out)
    if path.is_absolute():
        return path
    if path.parts and path.parts[0] == "log":
        return repo_root / path
    return output_dir / path


def main() -> int:
    parser = argparse.ArgumentParser(description="Run checkpoint fragments via emu and estimate weighted cycles")
    parser.add_argument("--weights", default="firmware/checkpoints/cluster-0-0/app/weights0")
    parser.add_argument("--simpoints", default="firmware/checkpoints/cluster-0-0/app/simpoints0")
    parser.add_argument("--payload-root", default="firmware/checkpoints/build/app")
    parser.add_argument("--cluster-out", default="firmware/checkpoints/cluster.out")
    parser.add_argument("--max-instr", type=int, default=100000, help="instruction cap for each emu run; usually CPT_INTERVAL")
    parser.add_argument("--make-target", default="run-emu")
    parser.add_argument("--make-arg", action="append", default=[], help="extra VAR=VALUE passed to make")
    parser.add_argument("--emu-instances", type=int, default=1, help="number of concurrent emu runs (1 = serial)")
    parser.add_argument("--limit", type=int, default=0, help="only run first N simpoints (0=all)")
    parser.add_argument("--topk-weight", type=int, default=0, help="run only the top-K simpoints by weight (0=disabled)")
    parser.add_argument("--topk-weight-percent", type=float, default=0.0, help="run the smallest prefix of simpoints whose cumulative raw weight reaches this fraction (0<val<=1, 0=disabled)")
    parser.add_argument("--interval-count", type=int, default=0, help="override total interval count")
    parser.add_argument("--real-prefill-cycles", type=int, default=0, help="optional real total prefill cycles for calibration")
    parser.add_argument("--real-prefill-ipc", type=float, default=0.0, help="optional real prefill IPC for comparison")
    parser.add_argument("--output-dir", default="log/simpoint-eval", help="directory for generated reports")
    parser.add_argument("--json-out", default="summary.json", help="JSON report path; relative paths are written under --output-dir")
    parser.add_argument("--strict-missing", action="store_true", help="fail instead of skipping missing payloads")
    parser.add_argument("--no-renormalize", action="store_true", help="do not renormalize weights after skipping missing payloads")
    args = parser.parse_args()
    if args.emu_instances < 1:
        raise ValueError("--emu-instances must be >= 1")

    enabled_selectors = sum(int(x) for x in [args.limit > 0, args.topk_weight > 0, args.topk_weight_percent > 0])
    if enabled_selectors > 1:
        raise ValueError("--limit, --topk-weight, and --topk-weight-percent are mutually exclusive")
    if args.topk_weight_percent < 0.0 or args.topk_weight_percent > 1.0:
        raise ValueError("--topk-weight-percent must be in [0, 1]")

    repo_root = Path(__file__).resolve().parents[1]
    output_dir = Path(args.output_dir)
    if not output_dir.is_absolute():
        output_dir = repo_root / output_dir
    entries, skipped, total_kept_weight = parse_simpoints(
        Path(args.weights), Path(args.simpoints), Path(args.payload_root),
        skip_missing=not args.strict_missing, renormalize=not args.no_renormalize
    )

    selected_raw_weight = sum(e.weight for e in entries)
    selected_mode = "all"
    if args.topk_weight > 0:
        entries = sorted(entries, key=lambda e: (-e.weight, e.simpoint_id))[:args.topk_weight]
        selected_mode = f"top-{args.topk_weight}-by-weight"
        selected_raw_weight = sum(e.weight for e in entries)
        if not args.no_renormalize:
            renormalize_entries(entries)
    elif args.topk_weight_percent > 0:
        sorted_entries = sorted(entries, key=lambda e: (-e.weight, e.simpoint_id))
        chosen = []
        accum = 0.0
        for entry in sorted_entries:
            chosen.append(entry)
            accum += entry.weight
            if accum + 1e-12 >= args.topk_weight_percent:
                break
        entries = chosen
        selected_mode = f"top-weight-percent-{args.topk_weight_percent:g}"
        selected_raw_weight = sum(e.weight for e in entries)
        if not args.no_renormalize:
            renormalize_entries(entries)
    elif args.limit > 0:
        entries = entries[:args.limit]
        selected_mode = f"first-{args.limit}"
        selected_raw_weight = sum(e.weight for e in entries)
        if not args.no_renormalize:
            renormalize_entries(entries)

    interval_count = args.interval_count or parse_interval_count(Path(args.cluster_out))

    if skipped:
        print("=== Skipped simpoints ===")
        for item in skipped:
            print(f"skip simpoint={item['simpoint_id']} cluster={item['cluster_id']} weight={item['weight']:.8f} reason={item['reason']}")
        print(f"kept raw weight sum        : {total_kept_weight:.8f}")
        print(f"weights renormalized       : {not args.no_renormalize}")
        print()

    if selected_mode != "all":
        print("=== Selected simpoints ===")
        print(f"selection mode            : {selected_mode}")
        print(f"selected simpoints        : {len(entries)}")
        print(f"selected raw weight sum   : {selected_raw_weight:.8f}")
        print(f"weights renormalized      : {not args.no_renormalize}")
        print()

    results: list[RunResult] = []
    print(f"emu instances            : {args.emu_instances}")

    if args.make_target == "run-emu" and not args.make_arg:
        subprocess.run(
            ["make", "_ensure_emu"],
            cwd=repo_root,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

    def _run_one(task: tuple[int, SimpointEntry]):
        idx, entry = task
        instr_cnt, cycle_cnt, ipc, guest_cycle_spent, _out = run_payload(
            repo_root, entry.payload, args.max_instr, args.make_target, args.make_arg
        )
        return idx, entry, RunResult(
            simpoint_id=entry.simpoint_id,
            cluster_id=entry.cluster_id,
            weight=entry.weight,
            payload=str(entry.payload),
            instr_cnt=instr_cnt,
            cycle_cnt=cycle_cnt,
            ipc=ipc,
            guest_cycle_spent=guest_cycle_spent,
        )

    indexed_entries = list(enumerate(entries, 1))
    if args.emu_instances == 1:
        for idx, entry in indexed_entries:
            print(f"[{idx}/{len(entries)}] run {entry.simpoint_id} weight={entry.weight:.8f} payload={entry.payload}", flush=True)
            _idx, _entry, result = _run_one((idx, entry))
            results.append(result)
            print(f"  -> instr={result.instr_cnt} cycle={result.cycle_cnt} ipc={result.ipc:.6f}", flush=True)
    else:
        pending = {
            idx: entry for idx, entry in indexed_entries
        }
        for idx, entry in indexed_entries:
            print(f"[queue {idx}/{len(entries)}] run {entry.simpoint_id} weight={entry.weight:.8f} payload={entry.payload}", flush=True)

        ordered_results: dict[int, RunResult] = {}
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.emu_instances) as executor:
            future_map = {
                executor.submit(_run_one, task): task[0]
                for task in indexed_entries
            }
            for future in concurrent.futures.as_completed(future_map):
                idx = future_map[future]
                entry = pending[idx]
                try:
                    _idx, _entry, result = future.result()
                except Exception as exc:
                    raise RuntimeError(
                        f"parallel run failed for simpoint {entry.simpoint_id} "
                        f"payload={entry.payload}: {type(exc).__name__}: {exc}"
                    ) from exc
                ordered_results[idx] = result
                print(
                    f"[done  {idx}/{len(entries)}] simpoint={entry.simpoint_id} "
                    f"instr={result.instr_cnt} cycle={result.cycle_cnt} ipc={result.ipc:.6f}",
                    flush=True,
                )
        results = [ordered_results[idx] for idx, _entry in indexed_entries]

    weighted_cycle = sum(r.weight * r.cycle_cnt for r in results)
    weighted_instr = sum(r.weight * r.instr_cnt for r in results)
    weighted_ipc = (weighted_instr / weighted_cycle) if weighted_cycle else float('nan')

    est_total_cycles = weighted_cycle * interval_count
    est_prefill_tps = 128 / (est_total_cycles/2000000000) # TODO 预测est_prefill_tps
    est_total_instr = weighted_instr * interval_count
    est_total_ipc = (est_total_instr / est_total_cycles) if est_total_cycles else float('nan')

    print("\n=== Weighted fragment summary ===")
    print(f"simpoints run            : {len(results)}")
    print(f"interval count           : {interval_count}")
    print(f"checkpoint interval      : {args.max_instr}")
    print(f"weighted cycle/interval  : {weighted_cycle:.3f}")
    print(f"weighted instr/interval  : {weighted_instr:.3f}")
    print(f"weighted IPC             : {weighted_ipc:.6f}")
    print(f"estimated total cycles   : {est_total_cycles:.3f}")
    print(f"estimated prefill tps    : {est_prefill_tps:.3f}")
    print(f"estimated total instr    : {est_total_instr:.3f}")
    print(f"estimated total IPC      : {est_total_ipc:.6f}")

    calibration = None
    if args.real_prefill_cycles:
        calibration = args.real_prefill_cycles / est_total_cycles if est_total_cycles else math.nan
        print("\n=== Calibration ===")
        print(f"real prefill cycles      : {args.real_prefill_cycles}")
        print(f"estimated/real ratio     : {est_total_cycles / args.real_prefill_cycles:.6f}")
        print(f"calibration factor       : {calibration:.6f}")
        print(f"calibrated total cycles  : {est_total_cycles * calibration:.3f}")
        if args.real_prefill_ipc:
            real_instr = args.real_prefill_cycles * args.real_prefill_ipc
            print(f"real prefill IPC         : {args.real_prefill_ipc:.6f}")
            print(f"real prefill instr est   : {real_instr:.3f}")
            print(f"weighted-vs-real instr ratio : {est_total_instr / real_instr:.6f}")

    if args.json_out:
        json_out = resolve_json_out(repo_root, output_dir, args.json_out)
        payload = {
            "interval_count": interval_count,
            "checkpoint_interval": args.max_instr,
            "weighted_cycle_per_interval": weighted_cycle,
            "weighted_instr_per_interval": weighted_instr,
            "weighted_ipc": weighted_ipc,
            "estimated_total_cycles": est_total_cycles,
            "estimated_total_instr": est_total_instr,
            "estimated_total_ipc": est_total_ipc,
            "real_prefill_cycles": args.real_prefill_cycles or None,
            "real_prefill_ipc": args.real_prefill_ipc or None,
            "calibration_factor": calibration,
            "skipped": skipped,
            "kept_raw_weight_sum": total_kept_weight,
            "selection_mode": selected_mode,
            "selected_raw_weight_sum": selected_raw_weight,
            "weights_renormalized": not args.no_renormalize,
            "results": [asdict(r) for r in results],
        }
        json_out.parent.mkdir(parents=True, exist_ok=True)
        json_out.write_text(json.dumps(payload, indent=2))
        print(f"\njson written to          : {json_out}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
