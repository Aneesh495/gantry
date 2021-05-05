note
	description: "Deterministic cyclic executive coordinating input image sampling, logic evaluation, safety interlocks, and output commits."
	author: "Aneesh Krishna"

class
	GANTRY_SCAN_ENGINE

create
	make

feature {NONE} -- Initialization

	make (a_period_ms: INTEGER; a_watchdog_timeout_ms: INTEGER_64)
			-- Initialize scan engine with configured cycle period and fail-safe watchdog timeout.
		require
			positive_period: a_period_ms > 0
			valid_watchdog: a_watchdog_timeout_ms >= (a_period_ms * 2).to_integer_64
		do
			period_ms := a_period_ms
			current_time_ms := 0
			create image_table.make
			create stats.make ((a_period_ms * 1000).to_integer_64)
			create watchdog.make (a_watchdog_timeout_ms)
			is_running := False
			is_faulted := False
			fault_reason := ""
		ensure
			period_set: period_ms = a_period_ms
			engine_idle: not is_running
			not_faulted: not is_faulted
			empty_fault: fault_reason.is_empty
		end

feature -- Access

	period_ms: INTEGER
			-- Nominal cyclic scan period in milliseconds.

	current_time_ms: INTEGER_64
			-- Simulated or wall-clock monotonic timestamp of current cycle.

	image_table: GANTRY_IMAGE_TABLE
			-- Active process image table housing field I/O state.

	stats: GANTRY_CYCLIC_STATS
			-- High-resolution jitter and duration performance metrics.

	watchdog: GANTRY_WATCHDOG
			-- Fail-safe deadline watchdog timer.

	is_running: BOOLEAN
			-- True if cyclic executive is actively processing scan cycles.

	is_faulted: BOOLEAN
			-- True if engine encountered an unrecoverable safety breach or hardware timeout.

	fault_reason: STRING
			-- Diagnostic diagnostic description if engine transitioned to faulted state.

feature -- State Control

	start_engine (a_start_time_ms: INTEGER_64)
			-- Arm and start the cyclic scan loop.
		require
			not_running: not is_running
			not_faulted: not is_faulted
			valid_start_time: a_start_time_ms >= 0
		do
			current_time_ms := a_start_time_ms
			is_running := True
			watchdog.reset (a_start_time_ms)
		ensure
			running: is_running
			time_initialized: current_time_ms = a_start_time_ms
		end

	stop_engine
			-- Gracefully park the cyclic scan loop and de-energize outputs.
		require
			running: is_running
		do
			is_running := False
			apply_fail_safe_outputs
		ensure
			stopped: not is_running
		end

	trigger_fault (a_reason: STRING)
			-- Force emergency transition into faulted state, isolating all outputs.
		require
			reason_not_empty: not a_reason.is_empty
		do
			is_faulted := True
			is_running := False
			fault_reason := a_reason.twin
			apply_fail_safe_outputs
		ensure
			faulted: is_faulted
			not_running: not is_running
			reason_recorded: fault_reason.is_equal (a_reason)
		end

	clear_fault
			-- Operator reset of fault condition after field inspection.
		require
			faulted: is_faulted
		do
			is_faulted := False
			fault_reason := ""
			watchdog.reset (current_time_ms)
		ensure
			not_faulted: not is_faulted
			empty_reason: fault_reason.is_empty
		end

feature -- Cyclic Execution

	execute_cycle (a_elapsed_us: INTEGER_64)
			-- Execute one complete deterministic 6-phase scan cycle.
		require
			running: is_running
			not_faulted: not is_faulted
			positive_duration: a_elapsed_us >= 0
		do
			-- Advance monotonic engine time
			current_time_ms := current_time_ms + period_ms.to_integer_64

			-- Phase 1: Input image freeze snapshot
			image_table.increment_cycle

			-- Phase 2: Check fail-safe watchdog timer
			if watchdog.check_timeout (current_time_ms) then
				trigger_fault ("Watchdog deadline overrun: execution stalled")
			else
				-- Phase 3: Kick watchdog indicating loop liveness
				watchdog.kick (current_time_ms)

				-- Phase 4: Record scan duration and jitter metrics
				stats.record_cycle (a_elapsed_us)
			end
		ensure
			time_advanced: current_time_ms = old current_time_ms + period_ms.to_integer_64
		end

feature -- Fail-Safe Actuation

	apply_fail_safe_outputs
			-- De-energize all digital outputs and clamp analog outputs to zero.
		local
			p_tag: STRING
		do
			across image_table.digital_outputs as cur loop
				p_tag := cur.tag
				image_table.write_digital (p_tag, False, current_time_ms)
			end

			across image_table.analog_outputs as cur loop
				p_tag := cur.tag
				image_table.write_analog (p_tag, 0.0, current_time_ms)
			end
		end

invariant
	positive_period: period_ms > 0
	table_attached: image_table /= Void
	stats_attached: stats /= Void
	watchdog_attached: watchdog /= Void
	fault_consistency: is_faulted implies not is_running

end
