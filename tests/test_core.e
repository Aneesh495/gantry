note
	description: "Unit tests for Gantry core process image table, telemetry points, and cyclic executive."
	author: "Aneesh Krishna"

class
	TEST_CORE

create
	make

feature {NONE} -- Initialization

	make
			-- Run all core unit tests and report assertions.
		do
			print ("Running Core Subsystem Unit Tests...%N")
			test_point_status
			test_digital_point
			test_analog_point
			test_image_table
			test_cyclic_stats
			test_watchdog
			test_scan_engine
			print ("  -> Core Subsystem Tests: ALL PASSED%N")
		end

feature -- Tests

	test_point_status
		local
			status_helper: GANTRY_POINT_STATUS
		do
			create status_helper
			check valid_good: status_helper.is_valid_status (status_helper.Status_good) end
			check valid_bad: status_helper.is_valid_status (status_helper.Status_bad_sensor) end
			check invalid_code: not status_helper.is_valid_status (99) end
			check usable_good: status_helper.is_usable (status_helper.Status_good) end
			check unusable_bad: not status_helper.is_usable (status_helper.Status_bad_sensor) end
			check str_good: status_helper.status_to_string (status_helper.Status_good).is_equal ("GOOD") end
		end

	test_digital_point
		local
			dp: GANTRY_DIGITAL_POINT
		do
			create dp.make_digital ("VALVE_OPEN", "Limit switch for isolation valve")
			check init_val: not dp.value end
			check init_raw: not dp.raw_value end

			dp.update_value (True, 1000)
			check updated_val: dp.value end
			check updated_raw: dp.raw_value end
			check rising_count: dp.rising_edge_count = 1 end
			check falling_count: dp.falling_edge_count = 0 end

			dp.update_value (False, 1050)
			check fall_val: not dp.value end
			check falling_bump: dp.falling_edge_count = 1 end

			-- Test manual override
			dp.force_value (True)
			check is_forced: dp.is_forced end
			check forced_val: dp.value end

			dp.update_value (False, 1100)
			check keep_forced: dp.value end

			dp.release_override
			check not_forced: not dp.is_forced end
			check val_restored: not dp.value end
		end

	test_analog_point
		local
			ap: GANTRY_ANALOG_POINT
			d: REAL_64
		do
			create ap.make_scaled ("TANK_PRESSURE", "Vessel pressure transmitter", "bar", 4.0, 20.0, 0.0, 100.0)
			check units_match: ap.engineering_units.is_equal ("bar") end

			-- 4 mA -> 0 bar
			ap.update_value (4.0, 1000)
			d := ap.value - 0.0
			check zero_scale: d.abs < 0.001 end

			-- 12 mA -> 50 bar
			ap.update_value (12.0, 2000)
			d := ap.value - 50.0
			check mid_scale: d.abs < 0.001 end

			-- 20 mA -> 100 bar
			ap.update_value (20.0, 3000)
			d := ap.value - 100.0
			check full_scale: d.abs < 0.001 end

			-- Deadband test
			ap.set_deadband (2.0)
			ap.update_value (12.1, 4000) -- Small delta < 2.0 bar should not alter value
			d := ap.value - 100.0
			check deadband_holds: d.abs < 0.001 end

			ap.update_value (10.0, 5000) -- Delta 12.5 bar > 2.0 bar must alter value
			d := ap.value - 37.5
			check deadband_trips: d.abs < 0.001 end
		end

	test_image_table
		local
			tbl: GANTRY_IMAGE_TABLE
			di: GANTRY_DIGITAL_POINT
			ao: GANTRY_ANALOG_POINT
			d: REAL_64
		do
			create tbl.make
			create di.make_digital ("PUMP_RUNNING", "Pump auxiliary contact")
			create ao.make_analog ("MOTOR_SPEED", "VFD reference command", "RPM")

			tbl.register_digital_input (di)
			tbl.register_analog_output (ao)
			check total_pts: tbl.total_points_count = 2 end

			di.update_value (True, 100)
			check di_read: tbl.read_digital ("PUMP_RUNNING") end

			tbl.write_analog ("MOTOR_SPEED", 1750.0, 200)
			d := tbl.read_analog ("MOTOR_SPEED") - 1750.0
			check ao_read: d.abs < 0.001 end
		end

	test_cyclic_stats
		local
			stats: GANTRY_CYCLIC_STATS
		do
			create stats.make (10000) -- 10 ms target period
			stats.record_cycle (9800)
			stats.record_cycle (10200)
			stats.record_cycle (11500) -- Overrun

			check total_cyc: stats.total_cycles = 3 end
			check overruns: stats.cycle_overruns = 1 end
			check min_dur: stats.min_scan_duration_us = 9800 end
			check max_dur: stats.max_scan_duration_us = 11500 end
			check max_jit: stats.max_jitter_us = 1500 end
		end

	test_watchdog
		local
			wd: GANTRY_WATCHDOG
		do
			create wd.make (50) -- 50 ms timeout
			wd.kick (100)
			check safe_kick: not wd.check_timeout (130) end -- 30 ms elapsed: safe
			check trip_timeout: wd.check_timeout (160) end -- 60 ms elapsed: timeout tripped
			check is_tripped: wd.is_tripped end
			check trips_count: wd.trip_count = 1 end

			wd.reset (200)
			check reset_safe: not wd.is_tripped end
		end

	test_scan_engine
		local
			engine: GANTRY_SCAN_ENGINE
			di: GANTRY_DIGITAL_POINT
			do_pt: GANTRY_DIGITAL_POINT
		do
			create engine.make (10, 50)
			create di.make_digital ("ESTOP_PB", "Emergency Stop Pushbutton")
			create do_pt.make_digital ("MAIN_CONTACTOR", "Line power contactor")

			engine.image_table.register_digital_input (di)
			engine.image_table.register_digital_output (do_pt)

			engine.start_engine (1000)
			check is_run: engine.is_running end

			engine.image_table.write_digital ("MAIN_CONTACTOR", True, 1000)
			check contactor_on: engine.image_table.read_digital ("MAIN_CONTACTOR") end

			engine.execute_cycle (8500)
			check time_adv: engine.current_time_ms = 1010 end

			-- Test fault trigger and fail-safe de-energization
			engine.trigger_fault ("Field loop power loss")
			check is_fault: engine.is_faulted end
			check stopped: not engine.is_running end
			check contactor_off: not engine.image_table.read_digital ("MAIN_CONTACTOR") end
		end

end
