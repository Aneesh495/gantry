note
	description: "Append-only chronological event journal for SOE persistence and forensic post-mortem analysis."
	author: "Aneesh Krishna"

class
	GANTRY_EVENT_JOURNAL

create
	make

feature {NONE} -- Initialization

	make
		do
			create records.make (100)
			total_logged := 0
		ensure
			empty_journal: records.is_empty
			zero_logged: total_logged = 0
		end

feature -- Access

	records: ARRAYED_LIST [GANTRY_HISTORIAN_RECORD]
	total_logged: INTEGER_64

feature -- Logging Operations

	append_record (a_record: GANTRY_HISTORIAN_RECORD)
		require
			record_attached: a_record /= Void
		do
			records.extend (a_record)
			total_logged := total_logged + 1
		ensure
			appended: records.count = old records.count + 1
		end

	query_range (a_start_ms, a_end_ms: INTEGER_64): ARRAYED_LIST [GANTRY_HISTORIAN_RECORD]
			-- Extract all events within the timestamp interval [start, end].
		require
			valid_window: a_end_ms >= a_start_ms
		local
			res: ARRAYED_LIST [GANTRY_HISTORIAN_RECORD]
		do
			create res.make (32)
			across records as cur loop
				if cur.timestamp_ms >= a_start_ms and cur.timestamp_ms <= a_end_ms then
					res.extend (cur)
				end
			end
			Result := res
		ensure
			res_attached: Result /= Void
		end

	query_by_tag (a_tag: STRING): ARRAYED_LIST [GANTRY_HISTORIAN_RECORD]
			-- Extract all events matching a specific point tag.
		require
			tag_not_empty: not a_tag.is_empty
		local
			res: ARRAYED_LIST [GANTRY_HISTORIAN_RECORD]
		do
			create res.make (32)
			across records as cur loop
				if cur.tag.is_equal (a_tag) then
					res.extend (cur)
				end
			end
			Result := res
		ensure
			res_attached: Result /= Void
		end

invariant
	records_attached: records /= Void

end
