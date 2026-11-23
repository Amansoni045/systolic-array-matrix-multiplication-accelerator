from __future__ import annotations

import random
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import golden_model as gm

def naive_matmul(A, B, data_width, acc_width):
    n = len(A)
    C = [[0] * n for _ in range(n)]
    for r in range(n):
        for c in range(n):
            acc = 0
            for k in range(n):
                acc += gm.wrap_signed(A[r][k], data_width) * gm.wrap_signed(B[k][c], data_width)
            C[r][c] = gm.wrap_signed(acc, acc_width)
    return C

class GoldenModelTests(unittest.TestCase):
    def test_matmul_matches_naive_across_sizes(self):
        rng = random.Random(7)
        for size in (1, 2, 3, 4, 5):
            for data_width, acc_width in ((8, 32), (16, 48), (8, 16)):
                lo = -(1 << (data_width - 1))
                hi = (1 << (data_width - 1)) - 1
                for _ in range(5):
                    A = [[rng.randint(lo, hi) for _ in range(size)] for _ in range(size)]
                    B = [[rng.randint(lo, hi) for _ in range(size)] for _ in range(size)]
                    self.assertEqual(
                        gm.matmul(A, B, data_width, acc_width),
                        naive_matmul(A, B, data_width, acc_width),
                        msg=f"size={size} dw={data_width} aw={acc_width}",
                    )

    def test_accumulator_wraparound_matches_rtl(self):
        A = [[127] * 4 for _ in range(4)]
        B = [[127] * 4 for _ in range(4)]
        C = gm.matmul(A, B, data_width=8, acc_width=16)
        self.assertEqual(C[0][0], 64516 - 65536)
        self.assertEqual(C, [[-1020] * 4 for _ in range(4)])

    def test_minimum_accumulator_width_is_supported(self):
        A = [[127, 0], [0, 127]]
        B = [[127, 0], [0, 127]]
        C = gm.matmul(A, B, data_width=8, acc_width=16)
        self.assertEqual(C, [[gm.wrap_signed(16129, 16), 0], [0, gm.wrap_signed(16129, 16)]])

    def test_inputs_are_wrapped_to_data_width(self):
        self.assertEqual(gm.matmul([[300]], [[2]], data_width=8, acc_width=32), [[88]])
        self.assertEqual(gm.matmul([[-129]], [[1]], data_width=8, acc_width=32), [[127]])

    def test_signed_extremes_across_widths(self):
        for data_width, acc_width in ((4, 8), (8, 16), (8, 32), (16, 48)):
            lo = -(1 << (data_width - 1))
            hi = (1 << (data_width - 1)) - 1
            A = [[lo, hi], [hi, lo]]
            B = [[lo, lo], [hi, hi]]
            self.assertEqual(
                gm.matmul(A, B, data_width, acc_width),
                naive_matmul(A, B, data_width, acc_width),
            )

    def test_pack_unpack_roundtrip(self):
        rng = random.Random(11)
        for size in (1, 2, 3, 4, 8):
            for width in (8, 16):
                lo = -(1 << (width - 1))
                hi = (1 << (width - 1)) - 1
                matrix = [[rng.randint(lo, hi) for _ in range(size)] for _ in range(size)]
                packed = gm.pack_matrix(matrix, width)
                self.assertEqual(gm.unpack_matrix(packed, size, width), matrix)
                self.assertEqual(len(gm.matrix_to_hex(matrix, width)), (size * size * width + 3) // 4)

    def test_pack_bit_layout(self):
        matrix = [[1, 2], [3, 4]]
        packed = gm.pack_matrix(matrix, 8)
        self.assertEqual(packed, 1 | (2 << 8) | (3 << 16) | (4 << 24))
        self.assertEqual(gm.matrix_to_hex(matrix, 8), "04030201")

    def test_verify_result_hex(self):
        A = [[1, 2], [3, 4]]
        B = [[5, 6], [7, 8]]
        C = gm.matmul(A, B, 8, 32)
        packed = gm.pack_matrix(C, 32)
        hex_result = f"{packed:0{(2 * 2 * 32 + 3) // 4}x}"
        self.assertTrue(gm.verify_result_hex(hex_result, A, B, 8, 32, verbose=False))
        corrupted = f"{packed ^ 1:0{(2 * 2 * 32 + 3) // 4}x}"
        self.assertFalse(gm.verify_result_hex(corrupted, A, B, 8, 32, verbose=False))
        self.assertTrue(gm.verify_result_hex("0x" + hex_result.upper(), A, B, 8, 32, verbose=False))

    def test_vector_file_roundtrip(self):
        A = [[-1, 2], [3, -4]]
        B = [[5, -6], [-7, 8]]
        C = gm.matmul(A, B, 8, 32)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "case.txt"
            gm.write_vector(path, A, B, C, 8, 32, name="roundtrip")
            A2, B2, C2, meta = gm.read_vector(path)
        self.assertEqual((A2, B2, C2), (A, B, C))
        self.assertEqual(meta["ARRAY_SIZE"], "2")
        self.assertEqual(meta["DATA_WIDTH"], "8")
        self.assertEqual(meta["ACC_WIDTH"], "32")
        self.assertEqual(meta["NAME"], "roundtrip")

    def test_readmemh_files_are_flat_and_wrapped(self):
        A = [[-1, 2], [3, -4]]
        B = [[5, -6], [-7, 8]]
        C = gm.matmul(A, B, 8, 32)
        with tempfile.TemporaryDirectory() as tmp:
            a_path, b_path, c_path = gm.write_rtl_vectors(tmp, [A], [B], [C], 8, 32)
            a_lines = a_path.read_text().split()
            b_lines = b_path.read_text().split()
            c_lines = c_path.read_text().split()
        self.assertEqual(a_lines, ["ff", "02", "03", "fc"])
        self.assertEqual(b_lines, ["05", "fa", "f9", "08"])
        self.assertEqual(len(c_lines), 4)
        self.assertEqual(
            [gm.wrap_signed(int(line, 16), 32) for line in c_lines],
            [C[0][0], C[0][1], C[1][0], C[1][1]],
        )

    def test_rejects_invalid_dimensions(self):
        with self.assertRaises(ValueError):
            gm.matmul([[1, 2]], [[1], [2]], 8, 32)
        with self.assertRaises(ValueError):
            gm.matmul([[1, 2], [3, 4]], [[1, 2], [3, 4]], 8, 8)
        with self.assertRaises(ValueError):
            gm.matmul([[1, 2], [3]], [[1, 2], [3, 4]], 8, 32)
        with self.assertRaises(ValueError):
            gm.matmul([[1]], [[1]], 0, 32)

    def test_directed_cases_are_square_and_correct(self):
        for size in (1, 2, 3, 4, 5):
            for data_width, acc_width in ((8, 32), (16, 48)):
                cases = gm.directed_cases(size, data_width, acc_width)
                self.assertGreaterEqual(len(cases), 15)
                for name, A, B in cases:
                    self.assertEqual(len(A), size, msg=name)
                    self.assertTrue(all(len(row) == size for row in A), msg=name)
                    self.assertEqual(len(B), size, msg=name)
                    self.assertEqual(
                        gm.matmul(A, B, data_width, acc_width),
                        naive_matmul(A, B, data_width, acc_width),
                        msg=name,
                    )

if __name__ == "__main__":
    unittest.main(verbosity=2)
