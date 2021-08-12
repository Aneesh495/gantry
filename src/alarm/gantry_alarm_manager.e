note
	description: "Central ISA-18.2 Alarm Annunciator coordinating priority queues, audible horn logic, and batch acknowledgments."
	author: "Aneesh Krishna"

class
	GANTRY_ALARM_MANAGER

inherit
	GANTRY_ALARM_PRIORITY

create
	make

feature {NONE} -- Initialization

	make
		do
			create alarms.make (32)
			is_horn_active := False
		ensure
			empty_alarms: alarms.is_empty
			horn_silent: not is_horn_active
		end

feature -- Access

	alarms: ARRAYED_LIST [GANTRY_ALARM]
	is_horn_active: BOOLEAN

feature -- Configuration

	register_alarm (a_alarm: GANTRY_ALARM)
		require
			alarm_attached: a_alarm /= Void
		do
			alarms.extend (a_alarm)
		ensure
			registered: alarms.count = old alarms.count + 1
		end

feature -- Evaluation

	evaluate_all (a_table: GANTRY_IMAGE_TABLE; a_timestamp_ms: INTEGER_64)
			-- Process every registered alarm against the latest telemetry snapshot.
		require
			table_attached: a_table /= Void
		local
			val: REAL_64
			has_unack: BOOLEAN
		do
			has_unack := False

			across alarms as al loop
				if a_table.analog_inputs.has (al.tag) or a_table.analog_outputs.has (al.tag) then
					val := a_table.read_analog (al.tag)
					al.evaluate (val, a_timestamp_ms)
				elseif a_table.digital_inputs.has (al.tag) or a_table.digital_outputs.has (al.tag) then
					if a_table.read_digital (al.tag) then val := 1.0 else val := 0.0 end
					al.evaluate (val, a_timestamp_ms)
				end

				if al.is_unacknowledged and al.priority >= Priority_medium then
					has_unack := True
				end
			end

			-- Sound audible horn if any medium, high, or critical alarm is unacknowledged
			is_horn_active := has_unack
		end

feature -- Operator Actions

	acknowledge_all (a_timestamp_ms: INTEGER_64)
			-- Silence horn and acknowledge all outstanding alarms.
		do
			across alarms as al loop
				if al.is_unacknowledged then
					al.acknowledge (a_timestamp_ms)
				end
			end
			is_horn_active := False
		ensure
			horn_silenced: not is_horn_active
		end

feature -- Diagnostics

	active_count: INTEGER
		local
			cnt: INTEGER
		do
			cnt := 0
			across alarms as al loop
				if al.is_active_alarm then cnt := cnt + 1 end
			end
			Result := cnt
		end

	unacknowledged_count: INTEGER
		local
			cnt: INTEGER
		do
			cnt := 0
			across alarms as al loop
				if al.is_unacknowledged then cnt := cnt + 1 end
			end
			Result := cnt
		end

	critical_count: INTEGER
		local
			cnt: INTEGER
		do
			cnt := 0
			across alarms as al loop
				if al.is_active_alarm and al.priority = Priority_critical then
					cnt := cnt + 1
				end
			end
			Result := cnt
		end

invariant
	alarms_attached: alarms /= Void

end
