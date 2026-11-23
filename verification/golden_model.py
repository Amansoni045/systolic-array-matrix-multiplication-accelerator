#!/usr/bin/env python3
"""Golden model and test-vector generator for the Phase II systolic array.

The model matches the RTL bit-for-bit:

* operand values are interpreted as ``DATA_WIDTH``-bit two's complement;
* products are exact signed integers (``2*DATA_WIDTH`` bits);
* accumulation wraps modulo ``2**ACC_WIDTH``.

Everything is parameterized by the square matrix size ``N`` (``ARRAY_SIZE``),
the signed operand width and the signed accumulator width.  The module can be
imported by the regression runner or used from the command line to generate
``$readmemh``-compatible vectors and to verify an RTL result dump.
"""

from __future__ import annotations

import argparse
import random
import sys
from pathlib import Path
from typing import Iterable, Sequence

DEFAULT_SIZE = 4
DEFAULT_DATA_WIDTH = 8
DEFAULT_ACC_WIDTH = 32
DEFAULT_VECTORS_DIR = (
    Path(__file__).resolve().parents[1] / "simulation" / "results" / "golden_vectors"
)

Matrix = list[list[int]]
Vector = tuple[str, Matrix, Matrix, Matrix]


def wrap_signed(value: int, width: int) -> int:
    """Return *value* as a signed two's-complement integer of *width* bits."""
    if width < 1:
        raise ValueError("width must be at least 1")
    mask = (1 << width) - 1
    value &= mask
    sign_bit = 1 << (width - 1)
    return value - (1 << width) if value & sign_bit else value


def _validate_params(size: int, data_width: int, acc_width: int) -> None:
    if size < 1:
        raise ValueError("size must be at least 1")
    if data_width < 1:
        raise ValueError("data_width must be at least 1")
    if acc_width < 2 * data_width:
        raise ValueError("acc_width must be at least 2*data_width")


def _validate_square(matrix: Sequence[Sequence[int]], name: str) -> int:
    if not matrix:
        raise ValueError(f"{name} must not be empty")
    size = len(matrix)
    for row in matrix:
        if len(row) != size:
            raise ValueError(f"{name} must be square (got {size}x{len(row)})")
    return size


def matmul(
    A: Sequence[Sequence[int]],
    B: Sequence[Sequence[int]],
    data_width: int = DEFAULT_DATA_WIDTH,
    acc_width: int = DEFAULT_ACC_WIDTH,
) -> Matrix:
    """Compute ``C = A x B`` with RTL-equivalent signed wrapping.

    Args:
        A, B: square list-of-lists matrices with the same dimension.
        data_width: signed operand width (inputs are wrapped to this width).
        acc_width: signed accumulator width (sums wrap modulo 2**acc_width).

    Returns:
        A new square list-of-lists matrix of signed accumulator values.
    """
    _validate_params(len(A), data_width, acc_width)
    size = _validate_square(A, "A")
    if _validate_square(B, "B") != size:
        raise ValueError("A and B must have the same dimensions")

    result: Matrix = [[0] * size for _ in range(size)]
    for r in range(size):
        for c in range(size):
            acc = 0
            for k in range(size):
                a = wrap_signed(A[r][k], data_width)
                b = wrap_signed(B[k][c], data_width)
                acc = wrap_signed(acc + a * b, acc_width)
            result[r][c] = acc
    return result


def pack_matrix(matrix: Sequence[Sequence[int]], data_width: int) -> int:
    """Pack a row-major square matrix into one integer (element 0 is the LSB)."""
    size = _validate_square(matrix, "matrix")
    mask = (1 << data_width) - 1
    packed = 0
    for r in range(size):
        for c in range(size):
            packed |= (matrix[r][c] & mask) << (data_width * (r * size + c))
    return packed


def unpack_matrix(packed: int, size: int, width: int) -> Matrix:
    """Inverse of :func:`pack_matrix` for a signed ``width``-bit field."""
    _validate_params(size, width, 2 * width)
    mask = (1 << width) - 1
    matrix: Matrix = [[0] * size for _ in range(size)]
    for index in range(size * size):
        field = (packed >> (width * index)) & mask
        matrix[index // size][index % size] = wrap_signed(field, width)
    return matrix


def matrix_to_hex(matrix: Sequence[Sequence[int]], width: int) -> str:
    """Return the row-major packed matrix as a zero-padded hex string."""
    size = _validate_square(matrix, "matrix")
    digits = (size * size * width + 3) // 4
    return f"{pack_matrix(matrix, width):0{digits}x}"


def verify_result_hex(
    result_hex: str,
    A: Sequence[Sequence[int]],
    B: Sequence[Sequence[int]],
    data_width: int = DEFAULT_DATA_WIDTH,
    acc_width: int = DEFAULT_ACC_WIDTH,
    verbose: bool = True,
) -> bool:
    """Compare a flat row-major RTL result (hex) against the golden model.

    ``result_hex`` uses the same convention as the RTL bus: ``C[0][0]`` is the
    least-significant ``acc_width`` bits.  Both 0x-prefixed and plain hex are
    accepted, as are underscores and whitespace.
    """
    size = _validate_square(A, "A")
    if _validate_square(B, "B") != size:
        raise ValueError("A and B must have the same dimensions")
    _validate_params(size, data_width, acc_width)

    cleaned = result_hex.strip().lower().replace("_", "").replace(" ", "")
    if cleaned.startswith("0x"):
        cleaned = cleaned[2:]
    if not cleaned or any(ch not in "0123456789abcdef" for ch in cleaned):
        raise ValueError("result_hex must contain only hexadecimal digits")
    value = int(cleaned, 16)
    expected = matmul(A, B, data_width=data_width, acc_width=acc_width)

    mask = (1 << acc_width) - 1
    ok = True
    for r in range(size):
        for c in range(size):
            field = (value >> (acc_width * (r * size + c))) & mask
            got = wrap_signed(field, acc_width)
            if got != expected[r][c]:
                ok = False
                if verbose:
                    print(f"  MISMATCH C[{r}][{c}]: expected {expected[r][c]}, got {got}")
    return ok


def _format_matrix(matrix: Sequence[Sequence[int]]) -> list[str]:
    return ["  ".join(str(value) for value in row) for row in matrix]


def write_vector(
    path: str | Path,
    A: Sequence[Sequence[int]],
    B: Sequence[Sequence[int]],
    C: Sequence[Sequence[int]] | None = None,
    data_width: int = DEFAULT_DATA_WIDTH,
    acc_width: int = DEFAULT_ACC_WIDTH,
    name: str | None = None,
) -> None:
    """Write one human-readable test vector with a small metadata header."""
    size = _validate_square(A, "A")
    if _validate_square(B, "B") != size:
        raise ValueError("A and B must have the same dimensions")
    if C is None:
        C = matmul(A, B, data_width=data_width, acc_width=acc_width)
    if _validate_square(C, "C") != size:
        raise ValueError("A, B and C must have the same dimensions")

    lines = [
        "# Parameterized systolic-array test vector",
        f"# ARRAY_SIZE={size}",
        f"# DATA_WIDTH={data_width}",
        f"# ACC_WIDTH={acc_width}",
    ]
    if name:
        lines.append(f"# NAME={name}")
    lines.append("A:")
    lines.extend(_format_matrix(A))
    lines.append("B:")
    lines.extend(_format_matrix(B))
    lines.append("Expected C:")
    lines.extend(_format_matrix(C))
    Path(path).write_text("\n".join(lines) + "\n")


def read_vector(path: str | Path) -> tuple[Matrix, Matrix, Matrix, dict[str, str]]:
    """Read a vector written by :func:`write_vector` (metadata is optional)."""
    meta: dict[str, str] = {}
    sections: dict[str, Matrix] = {"A": [], "B": [], "Expected C": []}
    current: str | None = None

    for raw_line in Path(path).read_text().splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#"):
            body = line[1:].strip()
            if "=" in body:
                key, _, value = body.partition("=")
                meta[key.strip()] = value.strip()
            continue
        if line in ("A:", "B:", "Expected C:"):
            current = line[:-1]
            continue
        if current is None:
            raise ValueError(f"{path}: value before any matrix header")
        row = [int(value) for value in line.split()]
        sections[current].append(row)

    A, B, C = sections["A"], sections["B"], sections["Expected C"]
    size = _validate_square(A, "A")
    if _validate_square(B, "B") != size:
        raise ValueError(f"{path}: A and B dimensions differ")
    if _validate_square(C, "Expected C") != size:
        raise ValueError(f"{path}: expected C has the wrong dimension")
    return A, B, C, meta


def _hex_digits(width: int) -> int:
    return (width + 3) // 4


def write_readmemh(
    path: str | Path,
    matrices: Iterable[Sequence[Sequence[int]]],
    width: int,
) -> None:
    """Flatten row-major matrices into a ``$readmemh`` file, one word per line."""
    digits = _hex_digits(width)
    mask = (1 << width) - 1
    lines: list[str] = []
    for matrix in matrices:
        size = _validate_square(matrix, "matrix")
        for r in range(size):
            for c in range(size):
                lines.append(f"{matrix[r][c] & mask:0{digits}x}")
    Path(path).write_text("\n".join(lines) + "\n")


def write_rtl_vectors(
    directory: str | Path,
    A_cases: Sequence[Sequence[Sequence[int]]],
    B_cases: Sequence[Sequence[Sequence[int]]],
    C_cases: Sequence[Sequence[Sequence[int]]],
    data_width: int = DEFAULT_DATA_WIDTH,
    acc_width: int = DEFAULT_ACC_WIDTH,
) -> tuple[Path, Path, Path]:
    """Write ``a.hex``, ``b.hex`` and ``c.hex`` consumed by the integration TB."""
    if not (len(A_cases) == len(B_cases) == len(C_cases)):
        raise ValueError("A/B/C case lists must have the same length")
    out_dir = Path(directory)
    out_dir.mkdir(parents=True, exist_ok=True)
    a_path, b_path, c_path = out_dir / "a.hex", out_dir / "b.hex", out_dir / "c.hex"
    write_readmemh(a_path, A_cases, data_width)
    write_readmemh(b_path, B_cases, data_width)
    write_readmemh(c_path, C_cases, acc_width)
    return a_path, b_path, c_path


def directed_cases(size: int, data_width: int, acc_width: int) -> list[tuple[str, Matrix, Matrix]]:
    """Return deterministic corner-case matrix pairs for any square size."""
    _validate_params(size, data_width, acc_width)
    n = size
    lo = -(1 << (data_width - 1))
    hi = (1 << (data_width - 1)) - 1

    def build(row_fn, col_fn) -> Matrix:
        return [[row_fn(r, c) for c in range(n)] for r in range(n)]

    zero = build(lambda r, c: 0, None)
    identity = build(lambda r, c: 1 if r == c else 0, None)
    ramp = build(lambda r, c: r * n + c + 1, None)
    neg_ramp = build(lambda r, c: -(r * n + c + 1), None)
    ones = build(lambda r, c: 1, None)
    all_hi = build(lambda r, c: hi, None)
    all_lo = build(lambda r, c: lo, None)
    diagonal = build(lambda r, c: (r + 1) if r == c else 0, None)
    lower = build(lambda r, c: (r + 1) if c <= r else 0, None)
    upper = build(lambda r, c: (c + 1) if r <= c else 0, None)
    alternating = build(lambda r, c: hi if (r + c) % 2 == 0 else lo, None)
    alt_inv = build(lambda r, c: lo if (r + c) % 2 == 0 else hi, None)
    checker = build(lambda r, c: 1 if (r + c) % 2 == 0 else -1, None)
    mixed = build(lambda r, c: (r * n + c + 1) if (r + c) % 2 == 0 else -(r * n + c + 1), None)
    rank_one_a = build(lambda r, c: (r + 1) if c == 0 else 0, None)
    rank_one_b = build(lambda r, c: (c + 1) if r == 0 else 0, None)
    transpose = [[ramp[c][r] for c in range(n)] for r in range(n)]

    pairs: list[tuple[str, Matrix, Matrix]] = [
        ("zero", zero, zero),
        ("identity", identity, identity),
        ("identity_left", identity, ramp),
        ("identity_right", ramp, identity),
        ("ones", ones, ones),
        ("max_positive", all_hi, all_hi),
        ("min_negative", all_lo, all_lo),
        ("max_times_min", all_hi, all_lo),
        ("alternating_extremes", alternating, alt_inv),
        ("diagonal", diagonal, diagonal),
        ("lower_upper", lower, upper),
        ("ramp", ramp, ramp),
        ("negative_ramp", neg_ramp, neg_ramp),
        ("ramp_times_negative", ramp, neg_ramp),
        ("rank_one", rank_one_a, rank_one_b),
        ("checkerboard", checker, checker),
        ("transpose_pair", ramp, transpose),
        ("mixed_signs", mixed, mixed),
        ("identity_accumulator", build(lambda r, c: (2 if r == c else 0), None), ramp),
    ]

    # Ensure every pair is dimensionally valid even for N=1.
    return [(name, A, B) for name, A, B in pairs if len(A) == n and len(B) == n]


def generate_vectors(
    size: int = DEFAULT_SIZE,
    data_width: int = DEFAULT_DATA_WIDTH,
    acc_width: int = DEFAULT_ACC_WIDTH,
    count: int = 20,
    seed: int = 42,
) -> list[Vector]:
    """Build directed plus deterministic random cases as ``(name, A, B, C)``."""
    _validate_params(size, data_width, acc_width)
    if count < 0:
        raise ValueError("count must be nonnegative")

    vectors: list[Vector] = []
    for name, A, B in directed_cases(size, data_width, acc_width):
        vectors.append((name, A, B, matmul(A, B, data_width, acc_width)))

    rng = random.Random(seed)
    lo = -(1 << (data_width - 1))
    hi = (1 << (data_width - 1)) - 1
    for index in range(count):
        A = [[rng.randint(lo, hi) for _ in range(size)] for _ in range(size)]
        B = [[rng.randint(lo, hi) for _ in range(size)] for _ in range(size)]
        vectors.append((f"random_{index:03d}", A, B, matmul(A, B, data_width, acc_width)))
    return vectors


def generate_test_vectors(
    size: int = DEFAULT_SIZE,
    data_width: int = DEFAULT_DATA_WIDTH,
    acc_width: int = DEFAULT_ACC_WIDTH,
    count: int = 20,
    seed: int = 42,
    out_dir: str | Path = DEFAULT_VECTORS_DIR,
) -> list[Vector]:
    """Generate vectors on disk and return them for immediate re-verification."""
    vectors = generate_vectors(size, data_width, acc_width, count, seed)
    out_path = Path(out_dir)
    out_path.mkdir(parents=True, exist_ok=True)

    for index, (name, A, B, C) in enumerate(vectors):
        path = out_path / f"test_{index:03d}.txt"
        write_vector(path, A, B, C, data_width, acc_width, name=name)

    manifest = out_path / "index.txt"
    manifest.write_text(
        "\n".join(
            f"test_{index:03d}.txt {name}" for index, (name, _, _, _) in enumerate(vectors)
        )
        + "\n"
    )
    return vectors


def _positive_int(text: str) -> int:
    value = int(text)
    if value < 1:
        raise argparse.ArgumentTypeError("value must be at least 1")
    return value


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--size", type=_positive_int, default=DEFAULT_SIZE,
                        help="square matrix dimension N (default: 4)")
    parser.add_argument("--data-width", type=_positive_int, default=DEFAULT_DATA_WIDTH,
                        help="signed operand width (default: 8)")
    parser.add_argument("--acc-width", type=_positive_int, default=DEFAULT_ACC_WIDTH,
                        help="signed accumulator width (default: 32)")
    parser.add_argument("--count", type=int, default=20,
                        help="number of random cases in addition to directed cases")
    parser.add_argument("--seed", type=int, default=42, help="random seed")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_VECTORS_DIR,
                        help="directory for generated .txt vectors")
    parser.add_argument("--result-hex", help="verify an RTL result hex dump")
    parser.add_argument("--vector", type=Path,
                        help="vector file that supplies A/B for --result-hex")
    args = parser.parse_args(argv)

    if args.count < 0:
        parser.error("--count must be nonnegative")
    try:
        _validate_params(args.size, args.data_width, args.acc_width)
    except ValueError as exc:
        parser.error(str(exc))

    if args.result_hex is not None:
        if args.vector is None:
            parser.error("--result-hex requires --vector")
        A, B, _, _ = read_vector(args.vector)
        ok = verify_result_hex(args.result_hex, A, B, args.data_width, args.acc_width)
        print("RTL result matches the golden model" if ok else "RTL result MISMATCH")
        return 0 if ok else 1

    print("=" * 68)
    print(
        f"Systolic Array Golden Model  (N={args.size}, DATA_WIDTH={args.data_width}, "
        f"ACC_WIDTH={args.acc_width})"
    )
    print("=" * 68)
    vectors = generate_test_vectors(
        args.size, args.data_width, args.acc_width, args.count, args.seed, args.out_dir
    )

    failures = 0
    for index, (name, A, B, C) in enumerate(vectors):
        recomputed = matmul(A, B, args.data_width, args.acc_width)
        ok = recomputed == C
        if not ok:
            failures += 1
            print(f"  test_{index:03d} ({name}): FAIL")
        else:
            print(f"  test_{index:03d} ({name}): PASS")
    print(f"\nGenerated {len(vectors)} vectors in {args.out_dir}")
    print(f"Golden self-check: {len(vectors) - failures} PASSED, {failures} FAILED")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
