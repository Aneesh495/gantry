note
	description: "Continuous stirred-tank chemical reactor (CSTR) simulator with exothermic runaway kinetics and pressure relief."
	author: "Aneesh Krishna"

class
	GANTRY_PRESSURE_VESSEL_SIM

inherit
	GANTRY_SIM_PLANT

create
	make

feature {NONE} -- Initialization

	make
		do
			make_plant ("CSTR_EXOTHERMIC_REACTOR")
			temperature_c := 65.0
			pressure_bar := 15.0
			coolant_temp_c := 20.0
			burst_disc_blown := False
		ensure
			name_set: name.is_equal ("CSTR_EXOTHERMIC_REACTOR")
		end

feature -- Plant State

	temperature_c: REAL_64
	pressure_bar: REAL_64
	coolant_temp_c: REAL_64
	burst_disc_blown: BOOLEAN

feature -- Design Limits

	Design_pressure_bar: REAL_64 = 85.0
	Burst_disc_rating_bar: REAL_64 = 95.0

feature -- Simulation Lifecycle

	bind_image_table (a_table: GANTRY_IMAGE_TABLE)
		local
			dp: GANTRY_DIGITAL_POINT
			ap: GANTRY_ANALOG_POINT
		do
			-- Sensors
			create ap.make_scaled ("REACTOR_TEMP", "Reactor internal bulk temperature", "degC", 0.0, 300.0, 0.0, 300.0)
			a_table.register_analog_input (ap)

			create ap.make_scaled ("REACTOR_PRESS", "Vessel internal vapor pressure", "bar", 0.0, 150.0, 0.0, 150.0)
			a_table.register_analog_input (ap)

			create dp.make_digital ("BURST_DISC_STATUS", "Emergency rupture disc rupture sensor")
			a_table.register_digital_input (dp)

			-- Actuators
			create ap.make_scaled ("COOLANT_FLOW_CMD", "Cooling jacket water flow valve", "m3/h", 0.0, 100.0, 0.0, 100.0)
			a_table.register_analog_output (ap)

			create ap.make_scaled ("FEED_RATE_CMD", "Reactant A and B chemical feed rate", "kg/h", 0.0, 500.0, 0.0, 500.0)
			a_table.register_analog_output (ap)

			create dp.make_digital ("EMERGENCY_VENT_VALVE", "Emergency flare depressurization dump valve")
			a_table.register_digital_output (dp)
		end

	step_simulation (a_dt_sec: REAL_64; a_table: GANTRY_IMAGE_TABLE)
		local
			feed_rate: REAL_64
			coolant_flow: REAL_64
			vent_open: BOOLEAN
			q_rxn, q_cool: REAL_64
			dt_temp: REAL_64
		do
			-- 1. Read commands from image table
			feed_rate := 100.0
			if a_table.analog_outputs.has ("FEED_RATE_CMD") then
				feed_rate := a_table.read_analog ("FEED_RATE_CMD")
			end

			coolant_flow := 20.0
			if a_table.analog_outputs.has ("COOLANT_FLOW_CMD") then
				coolant_flow := a_table.read_analog ("COOLANT_FLOW_CMD")
			end

			vent_open := False
			if a_table.digital_outputs.has ("EMERGENCY_VENT_VALVE") then
				vent_open := a_table.read_digital ("EMERGENCY_VENT_VALVE")
			end

			-- 2. Kinetic thermal balance
			-- Exothermic reaction rate increases exponentially with temperature
			q_rxn := feed_rate * 0.15 * (1.0 + (temperature_c / 50.0) ^ 2)
			q_cool := coolant_flow * 0.8 * (temperature_c - coolant_temp_c)

			dt_temp := (q_rxn - q_cool) * 0.05
			temperature_c := temperature_c + (dt_temp * a_dt_sec)
			if temperature_c < 10.0 then temperature_c := 10.0 end

			-- 3. Pressure balance (vapor pressure rises with temperature + feed)
			pressure_bar := 1.0 + ((temperature_c / 100.0) ^ 3) * 15.0

			-- Flare vent depressurization
			if vent_open then
				pressure_bar := pressure_bar * 0.4 -- Rapid flare dump
			end

			-- Rupture disc mechanical safety
			if pressure_bar >= Burst_disc_rating_bar then
				burst_disc_blown := True
			end

			if burst_disc_blown then
				pressure_bar := 1.5 -- Atmospheric venting
			end

			-- Advance clock
			sim_time_ms := sim_time_ms + (a_dt_sec * 1000.0).truncated_to_integer_64.max (1)
			step_count := step_count + 1

			-- 4. Publish telemetry to image table
			if a_table.analog_inputs.has ("REACTOR_TEMP") then
				if attached a_table.get_analog_input ("REACTOR_TEMP") as p then
					p.update_value (temperature_c, sim_time_ms)
				end
			end

			if a_table.analog_inputs.has ("REACTOR_PRESS") then
				if attached a_table.get_analog_input ("REACTOR_PRESS") as p then
					p.update_value (pressure_bar, sim_time_ms)
				end
			end

			if a_table.digital_inputs.has ("BURST_DISC_STATUS") then
				if attached a_table.get_digital_input ("BURST_DISC_STATUS") as p then
					p.update_value (burst_disc_blown, sim_time_ms)
				end
			end
		end

end
