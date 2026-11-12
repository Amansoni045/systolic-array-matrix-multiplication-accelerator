#!/usr/bin/env python3
"""
Golden model for the 4×4 systolic array matrix multiplication accelerator.

Provides:
  - matmul_4x4(A, B)         -- pure-Python signed 8-bit × 8-bit → 32-bit accumulate
  - generate_test_vectors()  -- writes verification/test_vectors/test_NNN.txt (20+ cases)
  - verify_verilog_output()  -- checks a 512-bit hex dump against expected C = A*B
  - export_readmemh()        -- writes a $readmemh-compatible hex file for one test
  - main()                   -- runs everything and prints PASS/FAIL per vector
"""

import os
import random
import struct

SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
VECTORS_DIR = os.path.join(SCRIPT_DIR, "test_vectors")

# ---------------------------------------------------------------------------
# Core computation
# ---------------------------------------------------------------------------

def _s8(v: int) -> int:
    """Clamp / sign-extend an integer to signed 8-bit range [-128, 127]."""
    v = v & 0xFF
    return v if v < 128 else v - 256


def matmul_4x4(A, B):
    """
    Compute C = A × B for 4×4 matrices of signed 8-bit integers.

    Args:
        A, B: list-of-lists [4][4] with values in -128..127 (clamped with _s8).

    Returns:
        C: list-of-lists [4][4] of signed 32-bit accumulated sums.
    """
    C = [[0] * 4 for _ in range(4)]
    for r in range(4):
        for c in range(4):
            acc = 0
            for k in range(4):
                acc += _s8(A[r][k]) * _s8(B[k][c])
            C[r][c] = acc          # naturally stays in 32-bit range for 8-bit inputs
    return C


# ---------------------------------------------------------------------------
# Test-vector file I/O
# ---------------------------------------------------------------------------

def _matrix_to_lines(M, name):
    lines = [f"{name}:"]
    for row in M:
        lines.append("  ".join(str(v) for v in row))
    return lines


def _write_vector(path, A, B, C):
    with open(path, "w") as f:
        for line in _matrix_to_lines(A, "A"):
            f.write(line + "\n")
        f.write("\n")
        for line in _matrix_to_lines(B, "B"):
            f.write(line + "\n")
        f.write("\n")
        for line in _matrix_to_lines(C, "Expected C"):
            f.write(line + "\n")


def _read_vector(path):
    """Parse a test vector file; return (A, B, C_exp)."""
    with open(path) as f:
        raw = [l.strip() for l in f if l.strip()]

    def parse_block(start_idx):
        rows = []
        for i in range(start_idx, start_idx + 4):
            rows.append([int(v) for v in raw[i].split()])
        return rows

    # Lines: "A:", row0..row3, "", "B:", row0..row3, "", "Expected C:", row0..row3
    a_start = raw.index("A:") + 1
    b_start = raw.index("B:") + 1
    c_start = raw.index("Expected C:") + 1
    return parse_block(a_start), parse_block(b_start), parse_block(c_start)


# ---------------------------------------------------------------------------
# Test-vector generation
# ---------------------------------------------------------------------------

def generate_test_vectors(seed=42):
    """
    Generate ≥20 test vectors (corner cases + random) and write to VECTORS_DIR.
    Returns list of (A, B, C) tuples in the order written.
    """
    os.makedirs(VECTORS_DIR, exist_ok=True)
    rng = random.Random(seed)
    vectors = []

    # -- Corner cases --------------------------------------------------------

    # 0: Zero × Zero
    Z = [[0]*4 for _ in range(4)]
    vectors.append((Z, Z, matmul_4x4(Z, Z)))

    # 1: Identity × Identity = Identity
    I = [[(1 if r == c else 0) for c in range(4)] for r in range(4)]
    vectors.append((I, I, matmul_4x4(I, I)))

    # 2: Identity × arbitrary
    M = [[r*4 + c + 1 for c in range(4)] for r in range(4)]
    vectors.append((I, M, matmul_4x4(I, M)))

    # 3: Arbitrary × Identity
    vectors.append((M, I, matmul_4x4(M, I)))

    # 4: All-ones
    ONE = [[1]*4 for _ in range(4)]
    vectors.append((ONE, ONE, matmul_4x4(ONE, ONE)))

    # 5: All-127 (max positive)
    P = [[127]*4 for _ in range(4)]
    vectors.append((P, P, matmul_4x4(P, P)))

    # 6: All -128 (most negative)
    N = [[-128]*4 for _ in range(4)]
    vectors.append((N, N, matmul_4x4(N, N)))

    # 7: Max × most-negative
    vectors.append((P, N, matmul_4x4(P, N)))

    # 8: Alternating -128 / 127
    ALT_A = [[(-128 if (r+c)%2==0 else 127) for c in range(4)] for r in range(4)]
    ALT_B = [[(127  if (r+c)%2==0 else -128) for c in range(4)] for r in range(4)]
    vectors.append((ALT_A, ALT_B, matmul_4x4(ALT_A, ALT_B)))

    # 9: Diagonal
    D = [[(r+1 if r==c else 0) for c in range(4)] for r in range(4)]
    vectors.append((D, D, matmul_4x4(D, D)))

    # 10: Anti-diagonal
    AD = [[(4-c if r+c==3 else 0) for c in range(4)] for r in range(4)]
    vectors.append((AD, AD, matmul_4x4(AD, AD)))

    # 11: Lower triangular × Upper triangular
    LT = [[(r+1 if c<=r else 0) for c in range(4)] for r in range(4)]
    UT = [[(c+1 if r<=c else 0) for c in range(4)] for r in range(4)]
    vectors.append((LT, UT, matmul_4x4(LT, UT)))

    # 12: Sequential positive (1..16)
    SEQ = [[r*4+c+1 for c in range(4)] for r in range(4)]
    vectors.append((SEQ, SEQ, matmul_4x4(SEQ, SEQ)))

    # 13: Sequential negative (-1..-16)
    NSEQ = [[-(r*4+c+1) for c in range(4)] for r in range(4)]
    vectors.append((NSEQ, NSEQ, matmul_4x4(NSEQ, NSEQ)))

    # 14: Positive × negative sequential
    vectors.append((SEQ, NSEQ, matmul_4x4(SEQ, NSEQ)))

    # 15: Row-vector outer product (rank-1)
    u = [[1, 2, 3, 4], [0,0,0,0], [0,0,0,0], [0,0,0,0]]
    v = [[1,0,0,0],[2,0,0,0],[3,0,0,0],[4,0,0,0]]
    vectors.append((u, v, matmul_4x4(u, v)))

    # 16: Mixed small positive and negative
    MIX = [[(r-c) for c in range(4)] for r in range(4)]
    vectors.append((MIX, MIX, matmul_4x4(MIX, MIX)))

    # 17: Checkerboard ±1
    CHK_A = [[(1 if (r+c)%2==0 else -1) for c in range(4)] for r in range(4)]
    CHK_B = [[(-1 if (r+c)%2==0 else 1) for c in range(4)] for r in range(4)]
    vectors.append((CHK_A, CHK_B, matmul_4x4(CHK_A, CHK_B)))

    # 18: Transpose relationship: A × A^T
    T = [[r*4+c-7 for c in range(4)] for r in range(4)]
    TT = [[T[c][r] for c in range(4)] for r in range(4)]
    vectors.append((T, TT, matmul_4x4(T, TT)))

    # 19: Identity scalar multiple
    S2 = [[(2 if r==c else 0) for c in range(4)] for r in range(4)]
    vectors.append((S2, SEQ, matmul_4x4(S2, SEQ)))

    # -- 20 random cases -----------------------------------------------------
    for _ in range(20):
        A = [[rng.randint(-128, 127) for _ in range(4)] for _ in range(4)]
        B = [[rng.randint(-128, 127) for _ in range(4)] for _ in range(4)]
        vectors.append((A, B, matmul_4x4(A, B)))

    # Write files
    for idx, (A, B, C) in enumerate(vectors):
        fname = os.path.join(VECTORS_DIR, f"test_{idx:03d}.txt")
        _write_vector(fname, A, B, C)

    print(f"Generated {len(vectors)} test vectors in {VECTORS_DIR}/")
    return vectors


# ---------------------------------------------------------------------------
# Verilog output verification
# ---------------------------------------------------------------------------

def verify_verilog_output(result_hex_512bit: str, A, B) -> bool:
    """
    Verify the RTL output against the golden model.

    Args:
        result_hex_512bit: hex string of the 512-bit acc_out bus (128 hex chars,
                           LSB first in memory, i.e., result[31:0] = C[0][0]).
        A, B: 4×4 lists of integers (signed 8-bit values).

    Returns:
        True if all 16 entries match, False otherwise.
    """
    hex_str = result_hex_512bit.strip().replace("_", "").replace(" ", "")
    # Pad to 128 hex digits (512 bits)
    hex_str = hex_str.zfill(128)
    raw_bytes = bytes.fromhex(hex_str)   # 64 bytes, little-endian word order

    C_golden = matmul_4x4(A, B)
    all_ok = True

    for idx in range(16):
        r, c = divmod(idx, 4)
        # Word idx occupies bytes [4*idx : 4*idx+4] in little-endian order
        got = struct.unpack_from("<i", raw_bytes, 4 * idx)[0]
        exp = C_golden[r][c]
        if got != exp:
            print(f"  MISMATCH C[{r}][{c}]: expected {exp}, got {got}")
            all_ok = False

    return all_ok


# ---------------------------------------------------------------------------
# $readmemh export
# ---------------------------------------------------------------------------

def export_readmemh(A, B, out_path: str):
    """
    Write a Verilog $readmemh-compatible file for the given input matrices.

    Format: 32 lines, each line is a 2-digit hex byte.
    Line 0 = A[0][0], line 1 = A[0][1], ... line 15 = A[3][3]
    Line 16 = B[0][0], ... line 31 = B[3][3]
    """
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "w") as f:
        for r in range(4):
            for c in range(4):
                v = _s8(A[r][c]) & 0xFF
                f.write(f"{v:02x}\n")
        for r in range(4):
            for c in range(4):
                v = _s8(B[r][c]) & 0xFF
                f.write(f"{v:02x}\n")
    print(f"Wrote $readmemh file: {out_path}")


# ---------------------------------------------------------------------------
# Main: run all test vectors and print PASS/FAIL
# ---------------------------------------------------------------------------

def main():
    print("=" * 60)
    print("Systolic Array Golden Model — Test Vector Runner")
    print("=" * 60)

    vectors = generate_test_vectors()

    print("\nRunning all test vectors against golden model...")
    pass_count = 0
    fail_count = 0

    for idx, (A, B, C_exp) in enumerate(vectors):
        C_got = matmul_4x4(A, B)
        ok = all(C_got[r][c] == C_exp[r][c] for r in range(4) for c in range(4))
        status = "PASS" if ok else "FAIL"
        if ok:
            pass_count += 1
        else:
            fail_count += 1
            for r in range(4):
                for c in range(4):
                    if C_got[r][c] != C_exp[r][c]:
                        print(f"  test_{idx:03d} C[{r}][{c}]: expected {C_exp[r][c]}, got {C_got[r][c]}")
        print(f"  test_{idx:03d}: {status}")

    print(f"\nResults: {pass_count} PASSED, {fail_count} FAILED out of {len(vectors)} vectors")

    # Export a readmemh file for test_002 (Identity × M)
    A2, B2, _ = vectors[2]
    readmemh_path = os.path.join(VECTORS_DIR, "test_002_readmemh.hex")
    export_readmemh(A2, B2, readmemh_path)

    # Demonstrate verify_verilog_output with a self-generated hex string
    print("\nDemonstrating verify_verilog_output with test_002 (Identity x M):")
    A_demo, B_demo, _ = vectors[2]
    C_demo = matmul_4x4(A_demo, B_demo)
    # Build the 512-bit little-endian packed result
    packed = b""
    for r in range(4):
        for c in range(4):
            packed += struct.pack("<i", C_demo[r][c])
    hex_512 = packed.hex()
    result = verify_verilog_output(hex_512, A_demo, B_demo)
    print(f"  verify_verilog_output returned: {'PASS' if result else 'FAIL'}")

    if fail_count == 0:
        print("\nAll golden model checks PASSED.")
    else:
        print(f"\nWARNING: {fail_count} check(s) FAILED.")


if __name__ == "__main__":
    main()
