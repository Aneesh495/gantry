note
	description: "Cause-and-Effect Matrix (CEM) executing multi-variable emergency shutdown logic conforming to ISA-84."
	author: "Aneesh Krishna"

class
	GANTRY_CAUSE_EFFECT_MATRIX

create
	make

feature {NONE} -- Initialization

	make
		do
			create rules.make (16)
			active_trips_count := 0
		ensure
			empty_matrix: rules.is_empty
			zero_active: active_trips_count = 0
		end

feature -- Access

	rules: ARRAYED_LIST [GANTRY_INTERLOCK_RULE]
			-- Collection of registered cause-effect interlock rules.

	active_trips_count: INTEGER
			-- Number of rules currently actively tripped.

feature -- Management

	add_rule (a_rule: GANTRY_INTERLOCK_RULE)
		require
			rule_attached: a_rule /= Void
		do
			rules.extend (a_rule)
		ensure
			rule_added: rules.count = old rules.count + 1
		end

feature -- Evaluation

	evaluate_all (a_table: GANTRY_IMAGE_TABLE; a_timestamp_ms: INTEGER_64): INTEGER
			-- Evaluate all rules against process image table and return count of active trips.
		require
			table_attached: a_table /= Void
		local
			tripped: BOOLEAN
		do
			active_trips_count := 0
			across rules as r loop
				tripped := r.evaluate (a_table, a_timestamp_ms)
				if tripped then
					active_trips_count := active_trips_count + 1
				end
			end
			Result := active_trips_count
		ensure
			consistent_result: Result = active_trips_count
			bounded_result: Result >= 0 and Result <= rules.count
		end

	has_active_trip: BOOLEAN
		do
			Result := (active_trips_count > 0)
		ensure
			consistent: Result = (active_trips_count > 0)
		end

invariant
	rules_attached: rules /= Void
	active_bounded: active_trips_count >= 0 and active_trips_count <= rules.count

end
