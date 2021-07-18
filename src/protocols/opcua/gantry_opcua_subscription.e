note
	description: "OPC UA Monitored Item Subscription manager tracking telemetry change notifications."
	author: "Aneesh Krishna"

class
	GANTRY_OPCUA_SUBSCRIPTION

create
	make

feature {NONE} -- Initialization

	make (a_sub_id: INTEGER; a_publishing_interval_ms: INTEGER_64)
		require
			positive_id: a_sub_id > 0
			positive_interval: a_publishing_interval_ms > 0
		do
			subscription_id := a_sub_id
			publishing_interval_ms := a_publishing_interval_ms
			create monitored_node_ids.make (16)
			monitored_node_ids.compare_objects
			create last_known_values.make (16)
			last_publish_time_ms := 0
			notifications_emitted := 0
		ensure
			id_set: subscription_id = a_sub_id
			interval_set: publishing_interval_ms = a_publishing_interval_ms
		end

feature -- Access

	subscription_id: INTEGER
	publishing_interval_ms: INTEGER_64
	monitored_node_ids: ARRAYED_LIST [STRING]
	last_known_values: HASH_TABLE [REAL_64, STRING]
	last_publish_time_ms: INTEGER_64
	notifications_emitted: INTEGER_64

feature -- Monitored Items

	add_monitored_item (a_node_id: STRING)
		require
			id_not_empty: not a_node_id.is_empty
		do
			if not monitored_node_ids.has (a_node_id) then
				monitored_node_ids.extend (a_node_id.twin)
				last_known_values.force (0.0, a_node_id)
			end
		ensure
			registered: monitored_node_ids.has (a_node_id)
		end

feature -- Publishing

	check_publish (a_space: GANTRY_OPCUA_ADDRESS_SPACE; a_current_time_ms: INTEGER_64): INTEGER
			-- Evaluate monitored items and return count of value change notifications.
		require
			space_attached: a_space /= Void
		local
			dt: INTEGER_64
			changes: INTEGER
			n_id: STRING
			node: detachable GANTRY_OPCUA_NODE
			cur_val, prev_val: REAL_64
		do
			changes := 0
			dt := a_current_time_ms - last_publish_time_ms

			if dt >= publishing_interval_ms or last_publish_time_ms = 0 then
				across monitored_node_ids as cur loop
					n_id := cur
					node := a_space.get_node (n_id)
					if attached node as n then
						cur_val := n.double_value
						prev_val := 0.0
						if last_known_values.has (n_id) then
							prev_val := last_known_values.item (n_id)
						end
						if (cur_val - prev_val).abs > 0.000001 or last_publish_time_ms = 0 then
							changes := changes + 1
							last_known_values.force (cur_val, n_id)
						end
					end
				end
				last_publish_time_ms := a_current_time_ms
				notifications_emitted := notifications_emitted + changes.to_integer_64
			end

			Result := changes
		ensure
			non_negative_changes: Result >= 0
		end

invariant
	positive_id: subscription_id > 0
	positive_interval: publishing_interval_ms > 0
	monitored_attached: monitored_node_ids /= Void

end
