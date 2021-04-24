note
	description: "Discrete binary process point supporting debouncing, edge counters, and inversion logic."
	author: "Aneesh Krishna"

class
	GANTRY_DIGITAL_POINT

inherit
	GANTRY_POINT
		redefine
			force_override,
			release_override
		end

create
	make_digital,
	make_with_options

feature {NONE} -- Initialization

	make_digital (a_tag: STRING; a_description: STRING)
			-- Initialize digital point with default settings (no inversion, no debounce).
		require
			tag_not_empty: not a_tag.is_empty
		do
			make_point (a_tag, a_description)
			value := False
			raw_value := False
			is_inverted := False
			debounce_time_ms := 0
			last_transition_time_ms := 0
			rising_edge_count := 0
			falling_edge_count := 0
		ensure
			default_value: not value
			default_raw: not raw_value
			not_inverted: not is_inverted
			debounce_zero: debounce_time_ms = 0
			rising_edges_zero: rising_edge_count = 0
			falling_edges_zero: falling_edge_count = 0
		end

	make_with_options (a_tag: STRING; a_description: STRING; a_inverted: BOOLEAN; a_debounce_ms: INTEGER)
			-- Initialize digital point with explicit inversion and debounce interval.
		require
			tag_not_empty: not a_tag.is_empty
			debounce_non_negative: a_debounce_ms >= 0
		do
			make_digital (a_tag, a_description)
			is_inverted := a_inverted
			debounce_time_ms := a_debounce_ms
		ensure
			inversion_set: is_inverted = a_inverted
			debounce_set: debounce_time_ms = a_debounce_ms
		end

feature -- Access

	value: BOOLEAN
			-- Debounced, conditioned, and potentially inverted binary state.

	raw_value: BOOLEAN
			-- Unfiltered raw physical hardware state.

	is_inverted: BOOLEAN
			-- If True, physical high represents logical False (active-low signal).

	debounce_time_ms: INTEGER
			-- Required stable persistence interval before state transition is confirmed.

	last_transition_time_ms: INTEGER_64
			-- Epoch millisecond timestamp of the last confirmed binary transition.

	rising_edge_count: INTEGER_64
			-- Total detected rising edges (transition from False to True).

	falling_edge_count: INTEGER_64
			-- Total detected falling edges (transition from True to False).

feature -- Telemetry Updates

	update_value (a_raw: BOOLEAN; a_timestamp_ms: INTEGER_64)
			-- Process new discrete telemetry from hardware or communication driver.
		require
			timestamp_valid: a_timestamp_ms >= 0
		local
			candidate: BOOLEAN
			elapsed: INTEGER_64
		do
			raw_value := a_raw
			set_timestamp (a_timestamp_ms)
			increment_update_count

			if is_forced then
				-- Value is overridden; do not mutate active logical state.
			else
				if is_inverted then
					candidate := not a_raw
				else
					candidate := a_raw
				end

				if candidate /= value then
					elapsed := a_timestamp_ms - last_transition_time_ms
					if elapsed >= debounce_time_ms.to_integer_64 or debounce_time_ms = 0 then
						-- Debounce duration satisfied; commit transition
						if not value and candidate then
							rising_edge_count := rising_edge_count + 1
						elseif value and not candidate then
							falling_edge_count := falling_edge_count + 1
						end
						value := candidate
						last_transition_time_ms := a_timestamp_ms
					end
				else
					-- Candidate matches current logical value; reset transition benchmark
					last_transition_time_ms := a_timestamp_ms
				end

				if status = Status_uninitialized or status = Status_bad_sensor or status = Status_comm_failure then
					set_status (Status_good)
				end
			end
		ensure
			raw_recorded: raw_value = a_raw
			timestamp_updated: timestamp_ms = a_timestamp_ms
		end

feature -- Configuration & Overrides

	set_inverted (a_inverted: BOOLEAN)
			-- Configure active-low or active-high interpretation.
		do
			is_inverted := a_inverted
		ensure
			inverted_set: is_inverted = a_inverted
		end

	set_debounce_time (a_debounce_ms: INTEGER)
			-- Configure noise debounce filter window in milliseconds.
		require
			non_negative: a_debounce_ms >= 0
		do
			debounce_time_ms := a_debounce_ms
		ensure
			debounce_assigned: debounce_time_ms = a_debounce_ms
		end

	force_value (a_forced_value: BOOLEAN)
			-- Operator manual override with explicit binary target state.
		do
			force_override
			value := a_forced_value
		ensure
			forced_flag: is_forced
			forced_value_set: value = a_forced_value
		end

	force_override
			-- Override inherited feature to arm force status.
		do
			Precursor
		ensure then
			forced_is_true: is_forced
		end

	release_override
			-- Release manual override and recalculate state from raw input.
		do
			Precursor
			if is_inverted then
				value := not raw_value
			else
				value := raw_value
			end
		ensure then
			not_forced: not is_forced
		end

	reset_edge_counters
			-- Zero out diagnostic edge counters.
		do
			rising_edge_count := 0
			falling_edge_count := 0
		ensure
			rising_zero: rising_edge_count = 0
			falling_zero: falling_edge_count = 0
		end

invariant
	debounce_non_negative: debounce_time_ms >= 0
	last_transition_non_negative: last_transition_time_ms >= 0
	rising_edges_non_negative: rising_edge_count >= 0
	falling_edges_non_negative: falling_edge_count >= 0

end
