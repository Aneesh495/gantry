note
	description: "Comprehensive unit tests for Sequence of Events (SOE) ring buffer, deadband filter, and SDT compression."
	author: "Aneesh Krishna"

class
	TEST_HISTORIAN

create
	make

feature {NONE} -- Initialization

	make
		do
			print ("Running Historian Subsystem Unit Tests...%N")
			test_historian_record
			test_ring_buffer
			test_deadband_filter
			test_swinging_door_trending
			test_event_journal
			print ("  -> Historian Subsystem Tests: ALL PASSED%N")
		end

feature -- Tests

	test_historian_record
		local
			r_ana, r_dig: GANTRY_HISTORIAN_RECORD
		do
			create r_ana.make_analog_record (1000, "PT_101", 75.5, 0)
			check not r_ana.is_digital end
			check r_ana.timestamp_ms = 1000 end
			check (r_ana.analog_value - 75.5).abs < 0.001 end
			check not r_ana.to_string.is_empty end

			create r_dig.make_digital_record (1020, "VALVE_101", True, 0)
			check r_dig.is_digital end
			check r_dig.digital_value end
		end

	test_ring_buffer
		local
			rb: GANTRY_RING_BUFFER
			r1, r2, r3, r4: GANTRY_HISTORIAN_RECORD
			popped: detachable GANTRY_HISTORIAN_RECORD
		do
			create rb.make (3) -- Capacity 3
			check rb.is_empty end

			create r1.make_analog_record (100, "TAG1", 1.0, 0)
			create r2.make_analog_record (200, "TAG2", 2.0, 0)
			create r3.make_analog_record (300, "TAG3", 3.0, 0)

			rb.push (r1)
			rb.push (r2)
			rb.push (r3)
			check rb.is_full end
			check rb.count = 3 end

			-- Overwrite oldest r1 with r4
			create r4.make_analog_record (400, "TAG4", 4.0, 0)
			rb.push (r4)
			check rb.count = 3 end
			check rb.overwritten_count = 1 end

			-- First popped must now be r2
			popped := rb.pop
			if attached popped as p then
				check popped_r2: p.tag.is_equal ("TAG2") end
			end
		end

	test_deadband_filter
		local
			filter: GANTRY_DEADBAND_FILTER
		do
			create filter.make (2.0) -- 2.0 unit deadband

			-- First point always archived
			check initial_archived: filter.should_archive (50.0) end
			check filter.archived_count = 1 end

			-- Deviation 0.5 < 2.0 -> suppressed
			check small_dev_suppressed: not filter.should_archive (50.5) end
			check filter.suppressed_count = 1 end

			-- Deviation 3.0 >= 2.0 -> archived
			check large_dev_archived: filter.should_archive (53.0) end
			check filter.archived_count = 2 end
		end

	test_swinging_door_trending
		local
			sdt: GANTRY_SWINGING_DOOR
			pt: detachable TUPLE [time: INTEGER_64; val: REAL_64]
			i: INTEGER
			t: INTEGER_64
			v: REAL_64
		do
			create sdt.make (1.0, 10000) -- Deviation 1.0, max time 10s

			-- Feed linear ramp with small jitter: points on a line should be highly compressed
			from
				i := 0
			until
				i >= 20
			loop
				t := i.to_integer_64 * 100
				v := 10.0 + (i.to_double * 2.0) -- Slope 2.0
				pt := sdt.process_point (t, v)
				i := i + 1
			end

			-- Now make sharp step change: must trigger archived inflection point!
			pt := sdt.process_point (2100, 100.0)
			check sharp_step_archived: pt /= Void end

			-- Check that compression ratio eliminated redundant collinear samples
			check high_compression: sdt.compression_ratio > 40.0 end
		end

	test_event_journal
		local
			journal: GANTRY_EVENT_JOURNAL
			r1, r2, r3: GANTRY_HISTORIAN_RECORD
			range_res: ARRAYED_LIST [GANTRY_HISTORIAN_RECORD]
			tag_res: ARRAYED_LIST [GANTRY_HISTORIAN_RECORD]
		do
			create journal.make
			create r1.make_analog_record (1000, "PRESS_A", 50.0, 0)
			create r2.make_analog_record (2000, "PRESS_B", 60.0, 0)
			create r3.make_analog_record (3000, "PRESS_A", 55.0, 0)

			journal.append_record (r1)
			journal.append_record (r2)
			journal.append_record (r3)
			check journal.records.count = 3 end

			range_res := journal.query_range (1500, 2500)
			check range_one: range_res.count = 1 end
			check range_tag: range_res.first.tag.is_equal ("PRESS_B") end

			tag_res := journal.query_by_tag ("PRESS_A")
			check tag_two: tag_res.count = 2 end
		end

end
