"""
Unit tests for GantryEngine core I/O, process image table, and cyclic executive.
"""

import unittest
import sys
from pathlib import Path

# Add bindings/python to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent / "bindings" / "python"))

from pygantry import GantryEngine, GantryEngineError


class TestGantryCore(unittest.TestCase):

    def test_engine_lifecycle(self):
        with GantryEngine("TEST_PLC", 1000) as eng:
            self.assertEqual(eng.name, "TEST_PLC")
            self.assertEqual(eng.scan_period_us, 1000)
            self.assertIsNotNone(eng.handle)
        # Should be closed after exit
        self.assertIsNone(eng._handle)

    def test_digital_io(self):
        with GantryEngine("IO_TEST", 1000) as eng:
            eng.register_digital_output("MOTOR_START", "Main conveyor motor", False)
            eng.register_digital_input("PROX_SENSOR", "Part present photoeye", True, 5)

            # Check initial output value
            self.assertFalse(eng.read_digital("MOTOR_START"))

            # Write and read back
            eng.write_digital("MOTOR_START", True)
            self.assertTrue(eng.read_digital("MOTOR_START"))

            # Dictionary access
            eng["MOTOR_START"] = False
            self.assertFalse(eng["MOTOR_START"])

    def test_analog_io(self):
        with GantryEngine("ANALOG_TEST", 1000) as eng:
            eng.register_analog_output("VFD_SPEED_CMD", "Drive speed", "Hz", 0, 60, 0, 60)
            eng.register_analog_input("FLOW_RATE", "Pipe flow sensor", "L/min", 0, 100, 0, 100)

            eng.write_analog("VFD_SPEED_CMD", 45.5)
            self.assertAlmostEqual(eng.read_analog("VFD_SPEED_CMD"), 45.5, places=2)

            eng["VFD_SPEED_CMD"] = 52.0
            self.assertAlmostEqual(eng["VFD_SPEED_CMD"], 52.0, places=2)

    def test_cyclic_scan_and_stats(self):
        with GantryEngine("STATS_TEST", 500) as eng:
            for _ in range(50):
                eng.step_cycle()

            stats = eng.get_stats()
            self.assertEqual(stats["total_cycles"], 50)
            self.assertGreaterEqual(stats["avg_scan_us"], 0.0)
            self.assertGreaterEqual(stats["max_scan_us"], 0.0)
            self.assertGreaterEqual(stats["last_jitter_us"], 0.0)

    def test_duplicate_registration_error(self):
        with GantryEngine("ERR_TEST", 1000) as eng:
            eng.register_digital_output("DO_VALVE", "Sol valve", False)
            with self.assertRaises(GantryEngineError):
                eng.register_digital_output("DO_VALVE", "Duplicate", False)


if __name__ == "__main__":
    unittest.main()
