note
	description: "Abstract base class for cyber-physical plant simulations coupling continuous ODE physics to discrete I/O."
	author: "Aneesh Krishna"

deferred class
	GANTRY_SIM_PLANT

feature {NONE} -- Initialization

	make_plant (a_name: STRING)
		require
			name_not_empty: not a_name.is_empty
		do
			name := a_name.twin
			sim_time_ms := 0
			step_count := 0
		ensure
			name_set: name.is_equal (a_name)
			time_zero: sim_time_ms = 0
		end

feature -- Access

	name: STRING
	sim_time_ms: INTEGER_64
	step_count: INTEGER_64

feature -- Simulation Lifecycle

	bind_image_table (a_table: GANTRY_IMAGE_TABLE)
			-- Register plant sensor points and actuator points into the process image table.
		require
			table_attached: a_table /= Void
		deferred
		end

	step_simulation (a_dt_sec: REAL_64; a_table: GANTRY_IMAGE_TABLE)
			-- Advance differential equations by dt and synchronize field sensors and actuators.
		require
			positive_dt: a_dt_sec > 0.0
			table_attached: a_table /= Void
		deferred
		ensure
			time_advanced: sim_time_ms > old sim_time_ms
			step_incremented: step_count = old step_count + 1
		end

invariant
	name_valid: not name.is_empty
	time_non_negative: sim_time_ms >= 0

end
