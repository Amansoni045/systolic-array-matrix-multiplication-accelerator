#!/usr/bin/env python3
"""Run Member 2's array regressions; requires Icarus Verilog on PATH.

Run from any working directory. Generated files stay in ignored simulation/results
and simulation/waveforms directories. No other member's sources are modified.
"""
import argparse
import csv
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RESULTS = ROOT / 'phase2/simulation/results'
WAVES = ROOT / 'phase2/simulation/waveforms'
CONFIGS = (
    (2, 8, 32), (4, 8, 32), (8, 8, 32),
    (2, 16, 48), (4, 16, 48), (8, 16, 48),
    (4, 8, 16), (4, 16, 32),  # Minimum legal accumulator: wraparound.
    (1, 8, 32), (3, 8, 32),   # No skew stages, and a non-power-of-two grid.
)


def run_command(command, log, timeout):
    completed = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, timeout=timeout, check=False)
    log.write_text(completed.stdout)
    if completed.returncode:
        raise RuntimeError(f'Command failed ({completed.returncode}); see {log.relative_to(ROOT)}\n'
                           f'{completed.stdout[-4000:]}')
    return completed.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--waveforms', action='store_true', help='Save per-configuration VCD files')
    parser.add_argument('--random-cases', type=int, default=100)
    args = parser.parse_args()
    if args.random_cases < 0:
        parser.error('--random-cases must be nonnegative')
    missing = [name for name in ('iverilog', 'vvp') if shutil.which(name) is None]
    if missing:
        print('Cannot run HDL simulations: missing ' + ', '.join(missing) + ' on PATH.', file=sys.stderr)
        return 2
    RESULTS.mkdir(parents=True, exist_ok=True)
    WAVES.mkdir(parents=True, exist_ok=True)
    summary = RESULTS / 'array_summary.csv'
    summary.unlink(missing_ok=True)
    rows = []
    for size, data_width, acc_width in CONFIGS:
        name = f'array_{size}x{size}_d{data_width}_a{acc_width}'
        executable = RESULTS / f'{name}.vvp'
        report = RESULTS / f'{name}.csv'
        report.unlink(missing_ok=True)
        command = ['iverilog', '-g2012', '-Wall', '-s', 'tb_systolic_array_core',
                   '-P', f'tb_systolic_array_core.ARRAY_SIZE={size}',
                   '-P', f'tb_systolic_array_core.DATA_WIDTH={data_width}',
                   '-P', f'tb_systolic_array_core.ACC_WIDTH={acc_width}',
                   '-P', f'tb_systolic_array_core.RANDOM_CASES={args.random_cases}',
                   '-o', str(executable), 'phase2/rtl/processing_element.v',
                   'phase2/rtl/systolic_array.v', 'phase2/testbench/tb_systolic_array_core.v']
        run_command(command, RESULTS / f'{name}_compile.log', 60)
        command = ['vvp', str(executable), f'+REPORT={report}']
        if args.waveforms:
            command.append(f'+VCD={WAVES / (name + ".vcd")}')
        output = run_command(command, RESULTS / f'{name}.log', 120)
        if 'ALL ARRAY CORE TESTS PASSED' not in output:
            raise RuntimeError(f'{name}: simulation did not report success')
        with report.open(newline='') as handle:
            records = list(csv.DictReader(handle))
        if len(records) != 1 or records[0]['status'] != 'PASS':
            raise RuntimeError(f'{name}: invalid simulation report')
        row = records[0]
        if int(row['core_edges']) != 3*size-2 or int(row['drain_edges']) != 2*(size-1):
            raise RuntimeError(f'{name}: measured latency does not match schedule')
        rows.append(row)
        print(f'PASS {name}: {row["matrices"]} matrices, {row["checked_edges"]} checked edges; '
              f'core={row["core_edges"]}, drain={row["drain_edges"]}')
    with summary.open('w', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f'All {len(rows)} configurations passed. Measured results: {summary.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as exc:
        print(f'Array regression failed: {exc}', file=sys.stderr)
        sys.exit(1)
