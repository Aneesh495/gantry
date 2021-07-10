note
	description: "Standard OPC Unified Architecture (OPC UA) binary primitive type identifiers."
	author: "Aneesh Krishna"

class
	GANTRY_OPCUA_TYPES

feature -- Type Identifiers

	Type_boolean: INTEGER = 1
	Type_sbyte: INTEGER = 2
	Type_byte: INTEGER = 3
	Type_int16: INTEGER = 4
	Type_uint16: INTEGER = 5
	Type_int32: INTEGER = 6
	Type_uint32: INTEGER = 7
	Type_int64: INTEGER = 8
	Type_uint64: INTEGER = 9
	Type_float: INTEGER = 10
	Type_double: INTEGER = 11
	Type_string: INTEGER = 12
	Type_datetime: INTEGER = 13
	Type_nodeid: INTEGER = 17

feature -- Query

	type_name (a_type: INTEGER): STRING
		do
			inspect a_type
			when Type_boolean then Result := "Boolean"
			when Type_int32 then Result := "Int32"
			when Type_float then Result := "Float"
			when Type_double then Result := "Double"
			when Type_string then Result := "String"
			when Type_datetime then Result := "DateTime"
			when Type_nodeid then Result := "NodeId"
			else
				Result := "Variant"
			end
		ensure
			not_empty: not Result.is_empty
		end

end
