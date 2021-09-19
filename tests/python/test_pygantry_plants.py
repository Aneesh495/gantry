"""
Unit tests for cyber-physical simulation plants coupled to GantryEngine.
"""

import unittest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent / "bindings" / "python"))

from pygantry import GantryEngine, GantryPlant, PlantType


class TestPlantSimulations(unittest.TestCase):

    def test_container_crane_dynamics(self):
        with GantryEngine("CRANE_CONTROLLER", 1000) as eng:
            with GantryPlant(PlantType.CRANE, eng) as crane:
                self.assertEqual(crane.plant_type, "crane")

                # Initial position check
                init_pos = eng["CRANE_TROLLEY_POS"]
                self.assertEqual(init_pos, 10.0)

                # Command forward force
                eng["CRANE_TROLLEY_FORCE_CMD"] = 60.0
                eng["CRANE_HOIST_VEL_CMD"] = 0.5

                # Step 30 times at dt = 0.1s
                for _ in range(30):
                    crane.step(0.1)
                    eng.step_cycle()

                # Trolley should advance and sway should be excited
                self.assertGreater(eng["CRANE_TROLLEY_POS"], init_pos)
                self.assertGreater(eng["CRANE_HOIST_POS"], 15.0)
                self.assertNotEqual(eng["CRANE_SWAY_ANGLE"], 0.0)

    def test_pressure_vessel_reactor(self):
        with GantryEngine("REACTOR_PLC", 1000) as eng:
            with GantryPlant(PlantType.REACTOR, eng) as reactor:
                init_temp = eng["REACTOR_TEMP"]
                init_press = eng["REACTOR_PRESS"]

                # Exothermic runaway: full feed, no cooling
                eng["FEED_RATE_CMD"] = 400.0
                eng["COOLANT_FLOW_CMD"] = 0.0

                for _ in range(40):
                    reactor.step(0.1)
                    eng.step_cycle()

                # Temperature and pressure should have risen
                self.assertGreater(eng["REACTOR_TEMP"], init_temp)
                self.assertGreater(eng["REACTOR_PRESS"], init_press)

                # Emergency vent dump
                eng["EMERGENCY_VENT_VALVE"] = True
                reactor.step(0.1)
                eng.step_cycle()
                self.assertLess(eng["REACTOR_PRESS"], 90.0)

    def test_rail_junction_switching(self):
        with GantryEngine("RAIL_INTERLOCKING", 1000) as eng:
            with GantryPlant(PlantType.RAIL, eng) as rail:
                self.assertTrue(eng["RAIL_POINT_NORMAL_IND"])
                self.assertFalse(eng["RAIL_POINT_REVERSE_IND"])

                # Command switch to reverse
                eng["RAIL_POINT_MOTOR_REV_CMD"] = True

                # Step through 3.0s motor transition
                for _ in range(35):
                    rail.step(0.1)
                    eng.step_cycle()

                self.assertTrue(eng["RAIL_POINT_REVERSE_IND"])
                self.assertFalse(eng["RAIL_POINT_NORMAL_IND"])


if __name__ == "__main__":
    unittest.main()
