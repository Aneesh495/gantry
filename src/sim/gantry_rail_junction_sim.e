note
	description: "Railway interlocking turnout and automatic block signalling simulator with track circuit occupancy."
	author: "Aneesh Krishna"

class
	GANTRY_RAIL_JUNCTION_SIM

inherit
	GANTRY_SIM_PLANT

create
	make

feature {NONE} -- Initialization

	make
		do
			make_plant ("RAIL_JUNCTION_TURNOUT")
			train_pos_m := 0.0
			train_speed_mps := 15.0
			point_position := 0 -- 0: Normal, 1: Reverse, -1: In transit
			point_target := 0
			point_transition_timer_sec := 0.0
			tc1_approach_occ := False
			tc2_turnout_occ := False
			tc3_main_occ := False
			tc4_branch_occ := False
		ensure
			name_set: name.is_equal ("RAIL_JUNCTION_TURNOUT")
		end

feature -- Plant State

	train_pos_m: REAL_64
	train_speed_mps: REAL_64
	point_position: INTEGER
	point_target: INTEGER
	point_transition_timer_sec: REAL_64

	tc1_approach_occ: BOOLEAN
	tc2_turnout_occ: BOOLEAN
	tc3_main_occ: BOOLEAN
	tc4_branch_occ: BOOLEAN

feature -- Simulation Lifecycle

	bind_image_table (a_table: GANTRY_IMAGE_TABLE)
		local
			dp: GANTRY_DIGITAL_POINT
		do
			-- Track Circuit Inputs
			create dp.make_digital ("RAIL_TC1_APPROACH", "Approach block track circuit")
			a_table.register_digital_input (dp)

			create dp.make_digital ("RAIL_TC2_TURNOUT", "Turnout fouling section track circuit")
			a_table.register_digital_input (dp)

			create dp.make_digital ("RAIL_TC3_MAIN", "Mainline departure track circuit")
			a_table.register_digital_input (dp)

			create dp.make_digital ("RAIL_TC4_BRANCH", "Branchline departure track circuit")
			a_table.register_digital_input (dp)

			create dp.make_digital ("RAIL_POINT_NORMAL_IND", "Point machine locked in Normal alignment")
			a_table.register_digital_input (dp)

			create dp.make_digital ("RAIL_POINT_REVERSE_IND", "Point machine locked in Reverse alignment")
			a_table.register_digital_input (dp)

			-- Actuator Commands
			create dp.make_digital ("RAIL_POINT_MOTOR_REV_CMD", "Drive point machine to Reverse")
			a_table.register_digital_output (dp)

			create dp.make_digital ("RAIL_SIGNAL_GREEN_CMD", "Clear home signal aspect to Green")
			a_table.register_digital_output (dp)
		end

	step_simulation (a_dt_sec: REAL_64; a_table: GANTRY_IMAGE_TABLE)
		local
			rev_cmd, green_cmd: BOOLEAN
		do
			-- 1. Read commands from image table
			rev_cmd := False
			if a_table.digital_outputs.has ("RAIL_POINT_MOTOR_REV_CMD") then
				rev_cmd := a_table.read_digital ("RAIL_POINT_MOTOR_REV_CMD")
			end

			green_cmd := False
			if a_table.digital_outputs.has ("RAIL_SIGNAL_GREEN_CMD") then
				green_cmd := a_table.read_digital ("RAIL_SIGNAL_GREEN_CMD")
			end

			-- 2. Point machine mechanical travel (takes 2 seconds to throw switch)
			if rev_cmd then
				point_target := 1
			else
				point_target := 0
			end

			if point_position /= point_target then
				point_transition_timer_sec := point_transition_timer_sec + a_dt_sec
				if point_transition_timer_sec >= 2.0 then
					point_position := point_target
					point_transition_timer_sec := 0.0
				end
			end

			-- 3. Train motion dynamics
			if green_cmd or train_pos_m > 50.0 then
				train_pos_m := train_pos_m + (train_speed_mps * a_dt_sec)
			end

			-- Wrap around for continuous loop
			if train_pos_m > 500.0 then
				train_pos_m := 0.0
			end

			-- Track circuit bounds
			-- TC1: 0 to 100m (Approach)
			-- TC2: 100 to 200m (Turnout)
			-- TC3: 200 to 500m (Mainline if point normal)
			-- TC4: 200 to 500m (Branch if point reverse)
			tc1_approach_occ := (train_pos_m >= 0.0 and train_pos_m < 100.0)
			tc2_turnout_occ := (train_pos_m >= 100.0 and train_pos_m < 200.0)
			tc3_main_occ := (train_pos_m >= 200.0 and point_position = 0)
			tc4_branch_occ := (train_pos_m >= 200.0 and point_position = 1)

			-- Advance sim clock
			sim_time_ms := sim_time_ms + (a_dt_sec * 1000.0).to_integer_64
			step_count := step_count + 1

			-- 4. Publish sensor telemetry to image table
			if a_table.digital_inputs.has ("RAIL_TC1_APPROACH") then
				if attached a_table.get_digital_input ("RAIL_TC1_APPROACH") as p then
					p.update_value (tc1_approach_occ, sim_time_ms)
				end
			end

			if a_table.digital_inputs.has ("RAIL_TC2_TURNOUT") then
				if attached a_table.get_digital_input ("RAIL_TC2_TURNOUT") as p then
					p.update_value (tc2_turnout_occ, sim_time_ms)
				end
			end

			if a_table.digital_inputs.has ("RAIL_TC3_MAIN") then
				if attached a_table.get_digital_input ("RAIL_TC3_MAIN") as p then
					p.update_value (tc3_main_occ, sim_time_ms)
				end
			end

			if a_table.digital_inputs.has ("RAIL_TC4_BRANCH") then
				if attached a_table.get_digital_input ("RAIL_TC4_BRANCH") as p then
					p.update_value (tc4_branch_occ, sim_time_ms)
				end
			end

			if a_table.digital_inputs.has ("RAIL_POINT_NORMAL_IND") then
				if attached a_table.get_digital_input ("RAIL_POINT_NORMAL_IND") as p then
					p.update_value (point_position = 0 and point_transition_timer_sec = 0.0, sim_time_ms)
				end
			end

			if a_table.digital_inputs.has ("RAIL_POINT_REVERSE_IND") then
				if attached a_table.get_digital_input ("RAIL_POINT_REVERSE_IND") as p then
					p.update_value (point_position = 1 and point_transition_timer_sec = 0.0, sim_time_ms)
				end
			end
		end

end
