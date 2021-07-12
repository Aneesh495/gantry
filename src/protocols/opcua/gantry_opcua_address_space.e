note
	description: "OPC UA Address Space hierarchical node manager providing browse path resolution and telemetry bridging."
	author: "Aneesh Krishna"

class
	GANTRY_OPCUA_ADDRESS_SPACE

create
	make

feature {NONE} -- Initialization

	make
		local
			root: GANTRY_OPCUA_NODE
			objects_folder: GANTRY_OPCUA_NODE
		do
			create nodes_by_id.make (128)
			create root.make_folder ("ns=0;i=84", "Root")
			create objects_folder.make_folder ("ns=0;i=85", "Objects")
			root.add_child (objects_folder)

			add_node (root)
			add_node (objects_folder)
			root_node := root
		ensure
			root_attached: root_node /= Void
			objects_present: nodes_by_id.has ("ns=0;i=85")
		end

feature -- Access

	root_node: GANTRY_OPCUA_NODE
	nodes_by_id: HASH_TABLE [GANTRY_OPCUA_NODE, STRING]

feature -- Node Registration

	add_node (a_node: GANTRY_OPCUA_NODE)
		require
			node_attached: a_node /= Void
			unique_id: not nodes_by_id.has (a_node.node_id)
		do
			nodes_by_id.put (a_node, a_node.node_id)
		ensure
			registered: nodes_by_id.has (a_node.node_id)
		end

	get_node (a_node_id: STRING): detachable GANTRY_OPCUA_NODE
		require
			id_not_empty: not a_node_id.is_empty
		do
			if nodes_by_id.has (a_node_id) then
				Result := nodes_by_id.item (a_node_id)
			end
		end

feature -- Telemetry Bridging

	sync_from_image_table (a_table: GANTRY_IMAGE_TABLE)
			-- Update OPC UA Variable node values from Gantry process image table.
		require
			table_attached: a_table /= Void
		local
			n_id: STRING
		do
			across a_table.digital_inputs as cur loop
				n_id := "ns=2;s=" + cur.tag
				if attached nodes_by_id.item (n_id) as n then
					n.set_boolean_value (cur.value)
				end
			end

			across a_table.analog_inputs as cur loop
				n_id := "ns=2;s=" + cur.tag
				if attached nodes_by_id.item (n_id) as n then
					n.set_double_value (cur.value)
				end
			end
		end

invariant
	nodes_attached: nodes_by_id /= Void
	root_present: root_node /= Void

end
