note
	description: "OPC UA Address Space node representing a Variable, Object, or Folder with browse references."
	author: "Aneesh Krishna"

class
	GANTRY_OPCUA_NODE

inherit
	GANTRY_OPCUA_TYPES

create
	make_variable,
	make_folder,
	make_object

feature {NONE} -- Initializers

	make_variable (a_id: STRING; a_browse_name: STRING; a_type: INTEGER; a_init_val: REAL_64)
		require
			id_not_empty: not a_id.is_empty
			name_not_empty: not a_browse_name.is_empty
		do
			node_id := a_id.twin
			browse_name := a_browse_name.twin
			display_name := a_browse_name.twin
			node_class := Class_variable
			data_type := a_type
			double_value := a_init_val
			string_value := ""
			boolean_value := (a_init_val > 0.5)
			create children.make (4)
			children.compare_objects
		ensure
			id_set: node_id.is_equal (a_id)
			name_set: browse_name.is_equal (a_browse_name)
		end

	make_folder (a_id: STRING; a_browse_name: STRING)
		do
			make_variable (a_id, a_browse_name, Type_string, 0.0)
			node_class := Class_folder
		ensure
			is_folder: node_class = Class_folder
		end

	make_object (a_id: STRING; a_browse_name: STRING)
		do
			make_variable (a_id, a_browse_name, Type_string, 0.0)
			node_class := Class_object
		ensure
			is_object: node_class = Class_object
		end

feature -- Node Classes

	Class_object: INTEGER = 1
	Class_variable: INTEGER = 2
	Class_method: INTEGER = 4
	Class_folder: INTEGER = 8

feature -- Access

	node_id: STRING
	browse_name: STRING
	display_name: STRING
	node_class: INTEGER
	data_type: INTEGER

	double_value: REAL_64
	string_value: STRING
	boolean_value: BOOLEAN

	children: ARRAYED_LIST [GANTRY_OPCUA_NODE]

feature -- Mutators

	set_double_value (a_val: REAL_64)
		do
			double_value := a_val
			boolean_value := (a_val > 0.5)
		ensure
			val_set: double_value = a_val
		end

	set_boolean_value (a_val: BOOLEAN)
		do
			boolean_value := a_val
			if a_val then double_value := 1.0 else double_value := 0.0 end
		ensure
			bool_set: boolean_value = a_val
		end

	add_child (a_node: GANTRY_OPCUA_NODE)
		require
			node_attached: a_node /= Void
		do
			children.extend (a_node)
		ensure
			child_added: children.count = old children.count + 1
		end

invariant
	id_valid: not node_id.is_empty
	name_valid: not browse_name.is_empty
	children_attached: children /= Void

end
