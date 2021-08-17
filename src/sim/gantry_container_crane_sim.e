note
	description: "Automated Container Terminal Gantry Crane cyber-physical simulator with nonlinear pendulum sway dynamics."
	author: "Aneesh Krishna"

class
	GANTRY_CONTAINER_CRANE_SIM

inherit
	GANTRY_SIM_PLANT

create
	make

feature {NONE} -- Initialization

	make
		do
			make_plant ("STS_CONTAINER_GANTRY_CRANE")
			trolley_pos_m := 10.0
			trolley_vel_mps := 0.0
			hoist_pos_m := 15.0
			hoist_vel_mps := 0.0
			sway_angle_rad := 0.0
			sway_rate_radps := 0.0
			twistlocks_engaged := False
			spreader_landed := False
		ensure
			name_set: name.is_equal ("STS_CONTAINER_GANTRY_CRANE")
		end

feature -- Plant State

	trolley_pos_m: REAL_64
	trolley_vel_mps: REAL_64
	hoist_pos_m: REAL_64
	hoist_vel_mps: REAL_64
	sway_angle_rad: REAL_64
	sway_rate_radps: REAL_64
	twistlocks_engaged: BOOLEAN
	spreader_landed: BOOLEAN

feature -- Physical Constants

	Gravitational_accel: REAL_64 = 9.80665
	Trolley_mass_kg: REAL_64 = 25000.0
	Rail_damping_coeff: REAL_64 = 1500.0
	Sway_damping_coeff: REAL_64 = 0.05
	Rail_length_m: REAL_64 = 80.0
	Max_hoist_depth_m: REAL_64 = 35.0

feature -- Simulation Lifecycle

	bind_image_table (a_table: GANTRY_IMAGE_TABLE)
		local
			dp: GANTRY_DIGITAL_POINT
			ap: GANTRY_ANALOG_POINT
		do
			-- Sensors
			create ap.make_scaled ("CRANE_TROLLEY_POS", "Trolley carriage position", "m", 0.0, 100.0, 0.0, 100.0)
			a_table.register_analog_input (ap)

			create ap.make_scaled ("CRANE_HOIST_POS", "Spreader hoist cable depth", "m", 0.0, 50.0, 0.0, 50.0)
			a_table.register_analog_input (ap)

			create ap.make_scaled ("CRANE_SWAY_ANGLE", "Payload pendulum sway angle", "deg", -45.0, 45.0, -45.0, 45.0)
			a_table.register_analog_input (ap)

			create dp.make_digital ("CRANE_TROLLEY_EAST_LS", "East buffer travel limit switch")
			a_table.register_digital_input (dp)

			create dp.make_digital ("CRANE_TROLLEY_WEST_LS", "West buffer travel limit switch")
			a_table.register_digital_input (dp)

			create dp.make_digital ("CRANE_HOIST_UPPER_LS", "Hoist top overtravel limit switch")
			a_table.register_digital_input (dp)

			create dp.make_digital ("CRANE_SPREADER_LANDED", "Spreader landing proximity sensors")
			a_table.register_digital_input (dp)

			create dp.make_digital ("CRANE_TWISTLOCKS_LOCKED", "Corner casting twistlocks locked")
			a_table.register_digital_input (dp)

			-- Actuator Commands
			create ap.make_scaled ("CRANE_TROLLEY_FORCE_CMD", "Trolley motor thrust command", "kN", -100.0, 100.0, -100.0, 100.0)
			a_table.register_analog_output (ap)

			create ap.make_scaled ("CRANE_HOIST_VEL_CMD", "Hoist winch velocity command", "m/s", -3.0, 3.0, -3.0, 3.0)
			a_table.register_analog_output (ap)

			create dp.make_digital ("CRANE_LOCK_TWISTLOCKS", "Energize twistlock hydraulic pins")
			a_table.register_digital_output (dp)
		end

	step_simulation (a_dt_sec: REAL_64; a_table: GANTRY_IMAGE_TABLE)
		local
			thrust_cmd, hoist_cmd: REAL_64
			lock_cmd: BOOLEAN
			trolley_accel, sway_accel: REAL_64
			sway_deg: REAL_64
			cable_l: REAL_64
		do
			-- 1. Read commands from image table
			thrust_cmd := 0.0
			if a_table.analog_outputs.has ("CRANE_TROLLEY_FORCE_CMD") then
				thrust_cmd := a_table.read_analog ("CRANE_TROLLEY_FORCE_CMD") * 1000.0 -- convert kN to N
			end

			hoist_cmd := 0.0
			if a_table.analog_outputs.has ("CRANE_HOIST_VEL_CMD") then
				hoist_cmd := a_table.read_analog ("CRANE_HOIST_VEL_CMD")
			end

			lock_cmd := False
			if a_table.digital_outputs.has ("CRANE_LOCK_TWISTLOCKS") then
				lock_cmd := a_table.read_digital ("CRANE_LOCK_TWISTLOCKS")
			end

			-- 2. Trolley translation equations
			trolley_accel := (thrust_cmd - (Rail_damping_coeff * trolley_vel_mps)) / Trolley_mass_kg
			trolley_vel_mps := trolley_vel_mps + (trolley_accel * a_dt_sec)
			trolley_pos_m := trolley_pos_m + (trolley_vel_mps * a_dt_sec)

			-- Boundary clamping
			if trolley_pos_m < 0.5 then
				trolley_pos_m := 0.5
				trolley_vel_mps := 0.0
			elseif trolley_pos_m > Rail_length_m - 0.5 then
				trolley_pos_m := Rail_length_m - 0.5
				trolley_vel_mps := 0.0
			end

			-- 3. Hoist dynamics
			hoist_vel_mps := hoist_cmd
			hoist_pos_m := hoist_pos_m + (hoist_vel_mps * a_dt_sec)
			if hoist_pos_m < 1.0 then
				hoist_pos_m := 1.0
				hoist_vel_mps := 0.0
			elseif hoist_pos_m > Max_hoist_depth_m then
				hoist_pos_m := Max_hoist_depth_m
				hoist_vel_mps := 0.0
			end

			-- 4. Pendulum sway dynamics
			cable_l := hoist_pos_m
			if cable_l < 1.0 then cable_l := 1.0 end
			-- theta'' = -(g/L)*sin(theta) - (x''/L)*cos(theta) - b*theta'
			sway_accel := -(Gravitational_accel / cable_l) * sway_angle_rad -
				(trolley_accel / cable_l) - (Sway_damping_coeff * sway_rate_radps)
			sway_rate_radps := sway_rate_radps + (sway_accel * a_dt_sec)
			sway_angle_rad := sway_angle_rad + (sway_rate_radps * a_dt_sec)

			-- 5. Twistlocks and landing
			spreader_landed := (hoist_pos_m >= 34.5)
			if spreader_landed and lock_cmd then
				twistlocks_engaged := True
			elseif not lock_cmd then
				twistlocks_engaged := False
			end

			-- Advance sim clock
			sim_time_ms := sim_time_ms + (a_dt_sec * 1000.0).to_integer_64
			step_count := step_count + 1

			-- 6. Update process image table field inputs
			sway_deg := sway_angle_rad * 57.2957795
			if a_table.analog_inputs.has ("CRANE_TROLLEY_POS") then
				if attached a_table.get_analog_input ("CRANE_TROLLEY_POS") as p then
					p.update_value (trolley_pos_m, sim_time_ms)
				end
			end

			if a_table.analog_inputs.has ("CRANE_HOIST_POS") then
				if attached a_table.get_analog_input ("CRANE_HOIST_POS") as p then
					p.update_value (hoist_pos_m, sim_time_ms)
				end
			end

			if a_table.analog_inputs.has ("CRANE_SWAY_ANGLE") then
				if attached a_table.get_analog_input ("CRANE_SWAY_ANGLE") as p then
					p.update_value (sway_deg, sim_time_ms)
				end
			end

			if a_table.digital_inputs.has ("CRANE_TROLLEY_WEST_LS") then
				if attached a_table.get_digital_input ("CRANE_TROLLEY_WEST_LS") as p then
					p.update_value (trolley_pos_m <= 1.0, sim_time_ms)
				end
			end

			if a_table.digital_inputs.has ("CRANE_TROLLEY_EAST_LS") then
				if attached a_table.get_digital_input ("CRANE_TROLLEY_EAST_LS") as p then
					p.update_value (trolley_pos_m >= Rail_length_m - 1.0, sim_time_ms)
				end
			end

			if a_table.digital_inputs.has ("CRANE_HOIST_UPPER_LS") then
				if attached a_table.get_digital_input ("CRANE_HOIST_UPPER_LS") as p then
					p.update_value (hoist_pos_m <= 1.5, sim_time_ms)
				end
			end

			if a_table.digital_inputs.has ("CRANE_SPREADER_LANDED") then
				if attached a_table.get_digital_input ("CRANE_SPREADER_LANDED") as p then
					p.update_value (spreader_landed, sim_time_ms)
				end
			end

			if a_table.digital_inputs.has ("CRANE_TWISTLOCKS_LOCKED") then
				if attached a_table.get_digital_input ("CRANE_TWISTLOCKS_LOCKED") as p then
					p.update_value (twistlocks_engaged, sim_time_ms)
				end
			end
		end

end
