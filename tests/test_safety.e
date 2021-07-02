note
	description: "Comprehensive unit tests for formal safety interlock rules, SIL levels, TMR voters, and E-Stop coordinator."
	author: "Aneesh Krishna"

class
	TEST_SAFETY

create
	make

feature {NONE} -- Initialization

	make
		do
			print ("Running Safety Subsystem Unit Tests...%N")
			test_sil_levels
			test_interlock_rule
			test_cause_effect_matrix
			test_tmr_voting
			test_interlock_graph_cycle_detection
			test_safety_envelope
			test_emergency_stop
			print ("  -> Safety Subsystem Tests: ALL PASSED%N")
		end

feature -- Tests

	test_sil_levels
		local
			sil: GANTRY_SIL_LEVEL
		do
			create sil
			check sil_0_valid: sil.is_valid_sil (sil.Sil_0) end
			check sil_3_valid: sil.is_valid_sil (sil.Sil_3) end
			check sil_4_valid: sil.is_valid_sil (sil.Sil_4) end
			check sil_99_invalid: not sil.is_valid_sil (99) end
			check sil_3_str: sil.sil_name (sil.Sil_3).is_equal ("SIL_3") end
		end

	test_interlock_rule
		local
			rule: GANTRY_INTERLOCK_RULE
			tbl: GANTRY_IMAGE_TABLE
			di_fire: GANTRY_DIGITAL_POINT
			do_pump: GANTRY_DIGITAL_POINT
			sil: GANTRY_SIL_LEVEL
		do
			create sil
			create tbl.make
			create di_fire.make_digital ("FIRE_DETECTOR", "Thermal infrared flame sensor")
			create do_pump.make_digital ("FUEL_PUMP", "Main fuel injection pump")

			tbl.register_digital_input (di_fire)
			tbl.register_digital_output (do_pump)

			-- Rule: IF FIRE_DETECTOR is True, THEN FUEL_PUMP must be False (SIL 3)
			create rule.make ("R_ESD_01", "Trip fuel pump on fire alarm", sil.Sil_3)
			rule.add_cause ("FIRE_DETECTOR", True)
			rule.add_effect ("FUEL_PUMP", False)

			-- Start pump
			tbl.write_digital ("FUEL_PUMP", True, 1000)
			check pump_running: tbl.read_digital ("FUEL_PUMP") end

			-- Fire not detected: rule does not trip
			check not_tripped: not rule.evaluate (tbl, 1010) end
			check pump_still_running: tbl.read_digital ("FUEL_PUMP") end

			-- Fire detected!
			di_fire.update_value (True, 1020)
			check rule_trips: rule.evaluate (tbl, 1020) end
			check pump_tripped_off: not tbl.read_digital ("FUEL_PUMP") end
			check rule_is_tripped: rule.is_tripped end
		end

	test_cause_effect_matrix
		local
			cem: GANTRY_CAUSE_EFFECT_MATRIX
			rule1, rule2: GANTRY_INTERLOCK_RULE
			tbl: GANTRY_IMAGE_TABLE
			di_hi_press: GANTRY_DIGITAL_POINT
			do_flare_vlv: GANTRY_DIGITAL_POINT
			sil: GANTRY_SIL_LEVEL
		do
			create sil
			create tbl.make
			create di_hi_press.make_digital ("PT_HIGH_ALM", "Overpressure switch")
			create do_flare_vlv.make_digital ("FLARE_VALVE", "Emergency depressurization valve")

			tbl.register_digital_input (di_hi_press)
			tbl.register_digital_output (do_flare_vlv)

			create cem.make
			create rule1.make ("R_01", "Open flare valve on overpressure", sil.Sil_3)
			rule1.add_cause ("PT_HIGH_ALM", True)
			rule1.add_effect ("FLARE_VALVE", True)

			create rule2.make ("R_02", "Dummy rule", sil.Sil_1)

			cem.add_rule (rule1)
			cem.add_rule (rule2)
			check cem_count: cem.rules.count = 2 end

			-- Normal condition
			check no_trips: cem.evaluate_all (tbl, 1000) = 0 end
			check flare_closed: not tbl.read_digital ("FLARE_VALVE") end

			-- Overpressure trigger
			di_hi_press.update_value (True, 1010)
			check one_trip: cem.evaluate_all (tbl, 1010) = 1 end
			check flare_opened: tbl.read_digital ("FLARE_VALVE") end
		end

	test_tmr_voting
		local
			voter: GANTRY_TMR_VOTER
			v_bool: BOOLEAN
			v_ana: REAL_64
		do
			create voter.make ("TMR_PRESSURE")

			-- Discrete 2oo3 test: True, True, False -> Result must be True, Channel C faulted
			v_bool := voter.vote_discrete (True, True, False)
			check majority_true: v_bool end
			check ch_a_ok: not voter.channel_a_fault end
			check ch_b_ok: not voter.channel_b_fault end
			check ch_c_faulted: voter.channel_c_fault end
			check disc_flagged: voter.has_discrepancy end

			-- Analog 2oo3 test: A=50.0, B=50.2, C=85.0 (drift) with threshold 5.0
			v_ana := voter.vote_analog (50.0, 50.2, 85.0, 5.0)
			check ch_c_drift: voter.channel_c_fault end
			check fallback_avg: (v_ana - 50.1).abs < 0.001 end
		end

	test_interlock_graph_cycle_detection
		local
			graph: GANTRY_INTERLOCK_GRAPH
		do
			create graph.make

			-- Linear chain: A -> B -> C (Acyclic)
			graph.add_edge ("VALVE_A", "VALVE_B")
			graph.add_edge ("VALVE_B", "PUMP_C")
			check no_initial_cycle: not graph.has_cycle end

			-- Add circular back-edge: PUMP_C -> VALVE_A (Cycle!)
			graph.add_edge ("PUMP_C", "VALVE_A")
			check cycle_detected: graph.has_cycle end
		end

	test_safety_envelope
		local
			envelope: GANTRY_SAFETY_ENVELOPE
			tbl: GANTRY_IMAGE_TABLE
			do_fwd, do_rev: GANTRY_DIGITAL_POINT
			ai_press: GANTRY_ANALOG_POINT
		do
			create tbl.make
			create do_fwd.make_digital ("MOTOR_FWD", "Motor forward contactor")
			create do_rev.make_digital ("MOTOR_REV", "Motor reverse contactor")
			create ai_press.make_analog ("REACTOR_PRESSURE", "Vessel pressure", "bar")

			tbl.register_digital_output (do_fwd)
			tbl.register_digital_output (do_rev)
			tbl.register_analog_input (ai_press)

			create envelope.make
			envelope.add_mutual_exclusion ("MOTOR_FWD", "MOTOR_REV")
			envelope.add_high_limit ("REACTOR_PRESSURE", 100.0)

			-- Safe state: only forward energized, pressure 80 bar
			tbl.write_digital ("MOTOR_FWD", True, 100)
			ai_press.update_value (80.0, 100)
			check safe_envelope: envelope.verify_envelope (tbl) end

			-- Violate mutual exclusion: energize reverse at same time
			tbl.write_digital ("MOTOR_REV", True, 110)
			check exclusion_breach: not envelope.verify_envelope (tbl) end
			check breach_logged: envelope.violation_count = 1 end

			-- Reset reverse to False
			tbl.write_digital ("MOTOR_REV", False, 120)
			check recovered: envelope.verify_envelope (tbl) end

			-- Breach physical pressure limit: 120 bar > 100 bar
			ai_press.update_value (120.0, 130)
			check pressure_breach: not envelope.verify_envelope (tbl) end
		end

	test_emergency_stop
		local
			estop: GANTRY_EMERGENCY_STOP
			tbl: GANTRY_IMAGE_TABLE
			do_power: GANTRY_DIGITAL_POINT
		do
			create tbl.make
			create do_power.make_digital ("MAIN_FEED", "Main transformer breaker")
			tbl.register_digital_output (do_power)

			create estop.make
			check not estop.is_tripped end

			tbl.write_digital ("MAIN_FEED", True, 1000)
			check feed_energized: tbl.read_digital ("MAIN_FEED") end

			-- Trigger E-Stop
			estop.trip ("Operator hit main emergency pushbutton", 1010)
			check estop.is_tripped end
			check trips_counted: estop.total_estop_trips = 1 end

			-- Enforce fail safe isolation
			estop.enforce_fail_safe (tbl, 1010)
			check feed_isolated: not tbl.read_digital ("MAIN_FEED") end

			-- Attempt reset while physical PB is still depressed (False) -> must fail
			check reset_denied: not estop.attempt_reset (False) end
			check still_tripped: estop.is_tripped end

			-- Reset with physical PB released (True) -> succeeds
			check reset_ok: estop.attempt_reset (True) end
			check cleared: not estop.is_tripped end
		end

end
