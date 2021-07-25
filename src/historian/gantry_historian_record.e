note
	description: "Sequence of Events (SOE) timestamped telemetry event record."
	author: "Aneesh Krishna"

class
	GANTRY_HISTORIAN_RECORD

create
	make_analog_record,
	make_digital_record

feature {NONE} -- Initializers

	make_analog_record (a_time: INTEGER_64; a_tag: STRING; a_val: REAL_64; a_status: INTEGER)
		require
			time_non_negative: a_time >= 0
			tag_not_empty: not a_tag.is_empty
		do
			timestamp_ms := a_time
			tag := a_tag.twin
			analog_value := a_val
			digital_value := False
			is_digital := False
			quality_status := a_status
		ensure
			time_set: timestamp_ms = a_time
			tag_set: tag.is_equal (a_tag)
			not_digital: not is_digital
		end

	make_digital_record (a_time: INTEGER_64; a_tag: STRING; a_val: BOOLEAN; a_status: INTEGER)
		require
			time_non_negative: a_time >= 0
			tag_not_empty: not a_tag.is_empty
		do
			timestamp_ms := a_time
			tag := a_tag.twin
			analog_value := 0.0
			digital_value := a_val
			is_digital := True
			quality_status := a_status
		ensure
			time_set: timestamp_ms = a_time
			tag_set: tag.is_equal (a_tag)
			is_digital: is_digital
		end

feature -- Access

	timestamp_ms: INTEGER_64
	tag: STRING
	analog_value: REAL_64
	digital_value: BOOLEAN
	is_digital: BOOLEAN
	quality_status: INTEGER

feature -- Formatting

	to_string: STRING
		do
			Result := "[" + timestamp_ms.out + " ms] " + tag + " = "
			if is_digital then
				Result.append (digital_value.out)
			else
				Result.append (analog_value.out)
			end
			Result.append (" (Status: " + quality_status.out + ")")
		ensure
			not_empty: not Result.is_empty
		end

invariant
	tag_valid: not tag.is_empty
	time_non_negative: timestamp_ms >= 0

end
