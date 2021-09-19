"""
Unit tests for Swinging Door Trending (SDT) lossy compression algorithm.
"""

import unittest
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent / "bindings" / "python"))

from pygantry import SDTCompressor


class TestSDTCompression(unittest.TestCase):

    def test_sdt_flat_signal(self):
        compressor = SDTCompressor(deviation=0.5)
        n = 100
        ts = [float(i) * 0.1 for i in range(n)]
        val = [25.0 + 0.05 * math.sin(i) for i in range(n)]

        c_ts, c_val = compressor.compress(ts, val)
        # For a flat signal within deviation, only start and end points should be retained
        self.assertLessEqual(len(c_ts), 4)
        ratio = SDTCompressor.compression_ratio(len(ts), len(c_ts))
        self.assertGreaterEqual(ratio, 95.0)

    def test_sdt_linear_ramp(self):
        compressor = SDTCompressor(deviation=0.1)
        n = 100
        ts = [float(i) for i in range(n)]
        val = [10.0 + 2.0 * float(i) for i in range(n)]

        c_ts, c_val = compressor.compress(ts, val)
        # Linear slope has zero curvature, only endpoints needed
        self.assertLessEqual(len(c_ts), 4)

    def test_sdt_step_change(self):
        compressor = SDTCompressor(deviation=0.2)
        n = 50
        ts = [float(i) for i in range(n)]
        val = [10.0 if i < 25 else 50.0 for i in range(n)]

        c_ts, c_val = compressor.compress(ts, val)
        # Step change must capture the inflection point
        self.assertGreaterEqual(len(c_ts), 3)
        self.assertTrue(any(abs(v - 50.0) < 0.1 for v in c_val))
        self.assertTrue(any(abs(v - 10.0) < 0.1 for v in c_val))


if __name__ == "__main__":
    unittest.main()
