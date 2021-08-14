note
	description: "Comprehensive unit tests for ISA-18.2 alarm state machine, hysteresis deadbands, and annunciator manager."
	author: "Aneesh Krishna"

class
	TEST_ALARMS

create
	make

feature {NONE} -- Initialization

	make
		do
			print ("Running Alarm Subsystem Unit Tests...%N")
			test_alarm_states
			test_alarm_hysteresis
			test_alarm_lifecycle
			test_alarm_shelving
			test_alarm_manager
			print ("  -> Alarm Subsystem Tests: ALL PASSED%N")
		end

feature -- Tests

	test_alarm_states
		local
			state: GANTRY_ALARM_STATE
		do
			create state
			check normal_valid: state.is_valid_state (state.State_normal) end
			check unack_valid: state.is_valid_state (state.State_unack_alarm) end
			check ack_valid: state.is_valid_state (state.State_ack_alarm) end
			check str_normal: state.state_name (state.State_normal).is_equal ("NORMAL") end
		end

	test_alarm_hysteresis
		local
			hys_high: GANTRY_ALARM_HYSTERESIS
			hys_low: GANTRY_ALARM_HYSTERESIS
		do
			-- High trip at 80.0 with 5.0 deadband
			create hys_high.make (80.0, 5.0, True)
			check not_tripped_79: not hys_high.evaluate (79.0) end
			check trips_at_80: hys_high.evaluate (80.0) end
			check stays_at_77: hys_high.evaluate (77.0) end -- Within hysteresis band (80 - 5 = 75)
			check clears_at_74: not hys_high.evaluate (74.0) end

			-- Low trip at 20.0 with 3.0 deadband
			create hys_low.make (20.0, 3.0, False)
			check not_tripped_21: not hys_low.evaluate (21.0) end
			check trips_at_20: hys_low.evaluate (20.0) end
			check stays_at_22: hys_low.evaluate (22.0) end -- Within band (20 + 3 = 23)
			check clears_at_24: not hys_low.evaluate (24.0) end
		end

	test_alarm_lifecycle
		local
			alm: GANTRY_ALARM
			prio: GANTRY_ALARM_PRIORITY
		do
			create prio
			create alm.make_high_alarm ("PRESSURE_HIGH", 100.0, 5.0, prio.Priority_high)
			check alm.current_state = alm.State_normal end

			-- Trip alarm
			alm.evaluate (105.0, 1000)
			check alm.current_state = alm.State_unack_alarm end
			check alm.is_active_alarm end
			check alm.is_unacknowledged end

			-- Operator acknowledges alarm
			alm.acknowledge (1020)
			check alm.current_state = alm.State_ack_alarm end
			check alm.is_active_alarm end
			check not alm.is_unacknowledged end

			-- Process clears below 95.0 (100 - 5)
			alm.evaluate (90.0, 1050)
			check alm.current_state = alm.State_normal end
			check not alm.is_active_alarm end

			-- Cycle 2: Clears before acknowledgment (Unack Cleared)
			alm.evaluate (105.0, 2000)
			check alm.current_state = alm.State_unack_alarm end

			alm.evaluate (90.0, 2020)
			check alm.current_state = alm.State_unack_cleared end

			alm.acknowledge (2030)
			check alm.current_state = alm.State_normal end
		end

	test_alarm_shelving
		local
			alm: GANTRY_ALARM
			prio: GANTRY_ALARM_PRIORITY
		do
			create prio
			create alm.make_high_alarm ("BEARING_TEMP", 80.0, 2.0, prio.Priority_medium)

			-- Shelve for 500 ms
			alm.shelve (500, 1000)
			check alm.current_state = alm.State_shelved end

			-- During shelving: high temperature does not trip alarm
			alm.evaluate (95.0, 1200)
			check alm.current_state = alm.State_shelved end

			-- Shelving timeout expires at 1500 ms
			alm.evaluate (70.0, 1550)
			check alm.current_state = alm.State_normal end
		end

	test_alarm_manager
		local
			mgr: GANTRY_ALARM_MANAGER
			alm1, alm2: GANTRY_ALARM
			prio: GANTRY_ALARM_PRIORITY
			tbl: GANTRY_IMAGE_TABLE
			ai_press: GANTRY_ANALOG_POINT
			ai_temp: GANTRY_ANALOG_POINT
		do
			create prio
			create tbl.make
			create ai_press.make_analog ("REACTOR_P", "Vessel pressure", "bar")
			create ai_temp.make_analog ("REACTOR_T", "Vessel temperature", "degC")
			tbl.register_analog_input (ai_press)
			tbl.register_analog_input (ai_temp)

			create mgr.make
			create alm1.make_high_alarm ("REACTOR_P", 100.0, 5.0, prio.Priority_critical)
			create alm2.make_high_alarm ("REACTOR_T", 200.0, 10.0, prio.Priority_low)
			mgr.register_alarm (alm1)
			mgr.register_alarm (alm2)

			-- Normal values
			ai_press.update_value (80.0, 1000)
			ai_temp.update_value (150.0, 1000)
			mgr.evaluate_all (tbl, 1000)
			check mgr.active_count = 0 end
			check not mgr.is_horn_active end

			-- Trip critical pressure alarm
			ai_press.update_value (105.0, 1010)
			mgr.evaluate_all (tbl, 1010)
			check mgr.active_count = 1 end
			check mgr.critical_count = 1 end
			check mgr.is_horn_active end -- Audible horn sounds!

			-- Operator acknowledges all
			mgr.acknowledge_all (1020)
			check not mgr.is_horn_active end -- Horn silenced
			check mgr.unacknowledged_count = 0 end
			check mgr.active_count = 1 end -- Condition still active
		end

end
