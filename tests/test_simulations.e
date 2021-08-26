note
	description: "Comprehensive unit and physics integration tests for cyber-physical simulation models."
	author: "Aneesh Krishna"

class
	TEST_SIMULATIONS

create
	make

feature {NONE} -- Initialization

	make
		do
			print ("Running Plant Simulation Unit Tests...%N")
			test_crane_dynamics
			test_crane_boundaries
			test_pressure_vessel_kinetics
			test_pressure_vessel_relief
			test_rail_junction_tracking
			test_rail_point_switching
			print ("  -> Plant Simulation Tests: ALL PASSED%N")
		end

feature -- Tests

	test_crane_dynamics
		local
			crane: GANTRY_CONTAINER_CRANE_SIM
			table: GANTRY_IMAGE_TABLE
			i: INTEGER
		do
			create crane.make
			create table.make
			crane.bind_image_table (table)

			check init_pos: crane.trolley_pos_m = 10.0 end
			check init_hoist: crane.hoist_pos_m = 15.0 end

			-- Apply forward thrust of 40 kN
			table.write_analog ("CRANE_TROLLEY_FORCE_CMD", 40.0, 0)
			table.write_analog ("CRANE_HOIST_VEL_CMD", 0.5, 0)

			from
				i := 1
			until
				i > 20
			loop
				crane.step_simulation (0.05, table)
				i := i + 1
			end

			-- Trolley should have moved forward and acquired velocity
			check pos_advanced: crane.trolley_pos_m > 10.0 end
			check vel_positive: crane.trolley_vel_mps > 0.0 end
			check hoist_lowered: crane.hoist_pos_m > 15.0 end

			-- Non-linear pendulum should have induced sway from acceleration
			check sway_induced: crane.sway_angle_rad.abs > 0.0001 end
			check table_synced: table.read_analog ("CRANE_TROLLEY_POS") = crane.trolley_pos_m end
		end

	test_crane_boundaries
		local
			crane: GANTRY_CONTAINER_CRANE_SIM
			table: GANTRY_IMAGE_TABLE
			i: INTEGER
		do
			create crane.make
			create table.make
			crane.bind_image_table (table)

			-- Command high reverse thrust to push towards west limit
			table.write_analog ("CRANE_TROLLEY_FORCE_CMD", -100.0, 0)

			from
				i := 1
			until
				i > 100 or crane.trolley_pos_m <= 0.6
			loop
				crane.step_simulation (0.1, table)
				i := i + 1
			end

			check bounded_west: crane.trolley_pos_m >= 0.5 end
			check west_limit_hit: table.read_digital ("CRANE_TROLLEY_WEST_LS") end
		end

	test_pressure_vessel_kinetics
		local
			vessel: GANTRY_PRESSURE_VESSEL_SIM
			table: GANTRY_IMAGE_TABLE
			init_temp, init_press: REAL_64
			i: INTEGER
		do
			create vessel.make
			create table.make
			vessel.bind_image_table (table)

			init_temp := vessel.temperature_c
			init_press := vessel.pressure_bar

			-- Heavy reactant feed with no cooling
			table.write_analog ("FEED_RATE_CMD", 300.0, 0)
			table.write_analog ("COOLANT_FLOW_CMD", 0.0, 0)

			from
				i := 1
			until
				i > 50
			loop
				vessel.step_simulation (0.1, table)
				i := i + 1
			end

			-- Exothermic reaction should increase temperature and vapor pressure
			check temp_rose: vessel.temperature_c > init_temp end
			check press_rose: vessel.pressure_bar > init_press end
			check table_temp_match: table.read_analog ("REACTOR_TEMP") = vessel.temperature_c end
		end

	test_pressure_vessel_relief
		local
			vessel: GANTRY_PRESSURE_VESSEL_SIM
			table: GANTRY_IMAGE_TABLE
			peak_press: REAL_64
			i: INTEGER
		do
			create vessel.make
			create table.make
			vessel.bind_image_table (table)

			-- Heat up vessel
			table.write_analog ("FEED_RATE_CMD", 250.0, 0)
			from i := 1 until i > 30 loop
				vessel.step_simulation (0.1, table)
				i := i + 1
			end

			peak_press := vessel.pressure_bar

			-- Open emergency relief valve and maximize cooling
			table.write_digital ("EMERGENCY_VENT_VALVE", True, 0)
			table.write_analog ("COOLANT_FLOW_CMD", 100.0, 0)

			from i := 1 until i > 30 loop
				vessel.step_simulation (0.1, table)
				i := i + 1
			end

			check relief_reduced_pressure: vessel.pressure_bar < peak_press end
		end

	test_rail_junction_tracking
		local
			junction: GANTRY_RAIL_JUNCTION_SIM
			table: GANTRY_IMAGE_TABLE
			i: INTEGER
		do
			create junction.make
			create table.make
			junction.bind_image_table (table)

			-- Initial approach block occupancy
			junction.step_simulation (0.1, table)
			check approach_occupied: table.read_digital ("RAIL_TC1_APPROACH") end

			-- Step train into turnout section (100m to 200m)
			from i := 1 until i > 100 or junction.train_pos_m >= 150.0 loop
				junction.step_simulation (0.1, table)
				i := i + 1
			end

			check turnout_occupied: table.read_digital ("RAIL_TC2_TURNOUT") end
		end

	test_rail_point_switching
		local
			junction: GANTRY_RAIL_JUNCTION_SIM
			table: GANTRY_IMAGE_TABLE
			i: INTEGER
		do
			create junction.make
			create table.make
			junction.bind_image_table (table)

			check initial_normal: table.read_digital ("RAIL_POINT_NORMAL_IND") end

			-- Command switch to reverse branch
			table.write_digital ("RAIL_POINT_MOTOR_REV_CMD", True, 0)

			from i := 1 until i > 40 loop
				junction.step_simulation (0.1, table)
				i := i + 1
			end

			-- After 3.0s motor transit, point should be locked in reverse
			check reverse_detected: table.read_digital ("RAIL_POINT_REVERSE_IND") end
			check not_normal: not table.read_digital ("RAIL_POINT_NORMAL_IND") end
		end

end
