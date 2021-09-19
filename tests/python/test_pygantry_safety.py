"""
Unit tests for Gantry safety interlocking and Emergency Stop latching.
"""

import unittest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent / "bindings" / "python"))

from pygantry import GantryEngine, SilLevel


class TestGantrySafety(unittest.TestCase):

    def test_cause_and_effect_interlock(self):
        with GantryEngine("SAFETY_PLC", 1000) as eng:
            eng.register_digital_input("OVERPRESSURE_SWITCH", "Pressure switch", False)
            eng.register_digital_output("PUMP_ENABLE", "Main hydraulic pump", False)

            # Start pump
            eng["PUMP_ENABLE"] = True
            eng.step_cycle()
            self.assertTrue(eng["PUMP_ENABLE"])

            # Add interlock: if OVERPRESSURE_SWITCH trips, force PUMP_ENABLE to False
            eng.add_interlock_rule(
                rule_id="RULE_IL_01",
                cause_tag="OVERPRESSURE_SWITCH",
                effect_tag="PUMP_ENABLE",
                effect_trip_val=False,
                sil=SilLevel.SIL_3,
            )

            # Normal cycle
            eng.step_cycle()
            self.assertTrue(eng["PUMP_ENABLE"])

            # Cause trip
            eng["OVERPRESSURE_SWITCH"] = True
            eng.step_cycle()
            self.assertFalse(eng["PUMP_ENABLE"])

    def test_estop_trip_and_reset(self):
        with GantryEngine("ESTOP_PLC", 1000) as eng:
            eng.register_digital_output("DO_CONVEYOR", "Conveyor motor", False)
            eng["DO_CONVEYOR"] = True
            eng.step_cycle()
            self.assertTrue(eng["DO_CONVEYOR"])

            # Trip E-Stop
            eng.trip_estop("OP_ANEESH", "Field pull-cord pulled")
            self.assertTrue(eng.is_estop_active)

            # Output must be forced to fail-safe immediately and on cycle
            eng.step_cycle()
            self.assertFalse(eng["DO_CONVEYOR"])

            # Attempting to re-enable during active E-Stop must fail to stay True
            eng["DO_CONVEYOR"] = True
            eng.step_cycle()
            self.assertFalse(eng["DO_CONVEYOR"])

            # Reset E-Stop
            eng.reset_estop("OP_ANEESH")
            self.assertFalse(eng.is_estop_active)


if __name__ == "__main__":
    unittest.main()
