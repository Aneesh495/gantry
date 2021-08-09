note
	description: "ISA-18.2 compliant process alarm point implementing deterministic state machine transitions."
	author: "Aneesh Krishna"

class
	GANTRY_ALARM

inherit
	GANTRY_ALARM_STATE
	GANTRY_ALARM_PRIORITY

create
	make_high_alarm,
	make_low_alarm

feature {NONE} -- Initializers

	make_high_alarm (a_tag: STRING; a_limit, a_hys: REAL_64; a_prio: INTEGER)
		require
			tag_not_empty: not a_tag.is_empty
			valid_prio: is_valid_priority (a_prio)
			hys_non_negative: a_hys >= 0.0
		do
			tag := a_tag.twin
			limit_threshold := a_limit
			priority := a_prio
			current_state := State_normal
			create hysteresis.make (a_limit, a_hys, True)
			trip_time_ms := 0
			ack_time_ms := 0
			shelve_expiry_time_ms := 0
			total_activations := 0
		ensure
			tag_set: tag.is_equal (a_tag)
			state_normal: current_state = State_normal
		end

	make_low_alarm (a_tag: STRING; a_limit, a_hys: REAL_64; a_prio: INTEGER)
		require
			tag_not_empty: not a_tag.is_empty
			valid_prio: is_valid_priority (a_prio)
			hys_non_negative: a_hys >= 0.0
		do
			tag := a_tag.twin
			limit_threshold := a_limit
			priority := a_prio
			current_state := State_normal
			create hysteresis.make (a_limit, a_hys, False)
			trip_time_ms := 0
			ack_time_ms := 0
			shelve_expiry_time_ms := 0
			total_activations := 0
		ensure
			tag_set: tag.is_equal (a_tag)
			state_normal: current_state = State_normal
		end

feature -- Access

	tag: STRING
	limit_threshold: REAL_64
	priority: INTEGER
	current_state: INTEGER
	hysteresis: GANTRY_ALARM_HYSTERESIS

	trip_time_ms: INTEGER_64
	ack_time_ms: INTEGER_64
	shelve_expiry_time_ms: INTEGER_64
	total_activations: INTEGER

feature -- State Evaluation

	evaluate (a_val: REAL_64; a_time_ms: INTEGER_64)
			-- Process new telemetry value through ISA-18.2 state transition logic.
		local
			in_alarm: BOOLEAN
		do
			-- Check shelving timeout expiration
			if current_state = State_shelved and a_time_ms >= shelve_expiry_time_ms then
				current_state := State_normal
			end

			if current_state /= State_shelved and current_state /= State_suppressed and current_state /= State_out_of_service then
				in_alarm := hysteresis.evaluate (a_val)

				inspect current_state
				when State_normal then
					if in_alarm then
						current_state := State_unack_alarm
						trip_time_ms := a_time_ms
						total_activations := total_activations + 1
					end
				when State_unack_alarm then
					if not in_alarm then
						-- Cleared before operator acknowledgment
						current_state := State_unack_cleared
					end
				when State_ack_alarm then
					if not in_alarm then
						-- Cleared after operator acknowledgment -> returns to normal
						current_state := State_normal
					end
				when State_unack_cleared then
					if in_alarm then
						-- Re-tripped before being acknowledged
						current_state := State_unack_alarm
						total_activations := total_activations + 1
					end
				else
				end
			end
		end

feature -- Operator Actions

	acknowledge (a_time_ms: INTEGER_64)
			-- Operator acknowledges active or cleared alarm.
		do
			if current_state = State_unack_alarm then
				current_state := State_ack_alarm
				ack_time_ms := a_time_ms
			elseif current_state = State_unack_cleared then
				current_state := State_normal
				ack_time_ms := a_time_ms
			end
		ensure
			ack_valid: (old current_state = State_unack_alarm implies current_state = State_ack_alarm) and
				(old current_state = State_unack_cleared implies current_state = State_normal)
		end

	shelve (a_duration_ms: INTEGER_64; a_time_ms: INTEGER_64)
			-- Operator temporarily shelves nuisance alarm with auto-unshelve timeout.
		require
			positive_duration: a_duration_ms > 0
		do
			current_state := State_shelved
			shelve_expiry_time_ms := a_time_ms + a_duration_ms
		ensure
			shelved: current_state = State_shelved
		end

	unshelve
			-- Manually return shelved alarm to service.
		require
			is_shelved: current_state = State_shelved
		do
			current_state := State_normal
			shelve_expiry_time_ms := 0
		ensure
			normal: current_state = State_normal
		end

	is_active_alarm: BOOLEAN
		do
			Result := (current_state = State_unack_alarm or current_state = State_ack_alarm)
		ensure
			consistent: Result = (current_state = State_unack_alarm or current_state = State_ack_alarm)
		end

	is_unacknowledged: BOOLEAN
		do
			Result := (current_state = State_unack_alarm or current_state = State_unack_cleared)
		ensure
			consistent: Result = (current_state = State_unack_alarm or current_state = State_unack_cleared)
		end

invariant
	tag_valid: not tag.is_empty
	valid_state: is_valid_state (current_state)
	valid_priority: is_valid_priority (priority)
	activations_non_negative: total_activations >= 0

end
