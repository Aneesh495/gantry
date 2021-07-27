note
	description: "Fixed-capacity circular ring buffer for sub-millisecond Sequence of Events (SOE) storage."
	author: "Aneesh Krishna"

class
	GANTRY_RING_BUFFER

create
	make

feature {NONE} -- Initialization

	make (a_capacity: INTEGER)
		require
			positive_capacity: a_capacity > 0
		do
			capacity := a_capacity
			create buffer.make_filled (Void, 1, a_capacity)
			head := 1
			tail := 1
			count := 0
			total_pushed := 0
			overwritten_count := 0
		ensure
			capacity_set: capacity = a_capacity
			empty_count: count = 0
		end

feature -- Access

	capacity: INTEGER
	count: INTEGER
	total_pushed: INTEGER_64
	overwritten_count: INTEGER_64

	is_empty: BOOLEAN
		do
			Result := (count = 0)
		ensure
			consistent: Result = (count = 0)
		end

	is_full: BOOLEAN
		do
			Result := (count = capacity)
		ensure
			consistent: Result = (count = capacity)
		end

feature {NONE} -- Internal State

	buffer: ARRAY [detachable GANTRY_HISTORIAN_RECORD]
	head: INTEGER
	tail: INTEGER

feature -- Ring Operations

	push (a_record: GANTRY_HISTORIAN_RECORD)
			-- Insert event into circular buffer; overwrites oldest entry if full.
		require
			record_attached: a_record /= Void
		do
			buffer.put (a_record, head)
			total_pushed := total_pushed + 1

			head := (head \\ capacity) + 1

			if count = capacity then
				-- Full: advance tail pointer, dropping oldest entry
				tail := (tail \\ capacity) + 1
				overwritten_count := overwritten_count + 1
			else
				count := count + 1
			end
		ensure
			not_empty: not is_empty
			count_bounded: count <= capacity
		end

	pop: detachable GANTRY_HISTORIAN_RECORD
			-- Extract oldest event from buffer.
		require
			not_empty: not is_empty
		do
			Result := buffer.item (tail)
			buffer.put (Void, tail)
			tail := (tail \\ capacity) + 1
			count := count - 1
		ensure
			count_decremented: count = old count - 1
		end

	item_at (a_idx: INTEGER): detachable GANTRY_HISTORIAN_RECORD
			-- Peek 1-based chronological entry from tail (1 = oldest, count = newest).
		require
			valid_index: a_idx >= 1 and a_idx <= count
		local
			pos: INTEGER
		do
			pos := ((tail - 1 + a_idx - 1) \\ capacity) + 1
			Result := buffer.item (pos)
		end

invariant
	positive_capacity: capacity > 0
	count_bounds: count >= 0 and count <= capacity
	head_bounds: head >= 1 and head <= capacity
	tail_bounds: tail >= 1 and tail <= capacity

end
