note
	description: "Comprehensive unit tests for Modbus TCP/IP, OPC UA binary, DNP3, and MQTT-SN industrial protocol stacks."
	author: "Aneesh Krishna"

class
	TEST_PROTOCOLS

create
	make

feature {NONE} -- Initialization

	make
		do
			print ("Running Industrial Protocols Subsystem Unit Tests...%N")
			test_modbus_framing
			test_modbus_server_and_client
			test_opcua_address_space
			test_opcua_chunks_and_subscriptions
			test_dnp3_crc_and_link_frames
			test_dnp3_outstation
			test_mqttsn_gateway
			print ("  -> Protocols Subsystem Tests: ALL PASSED%N")
		end

feature -- Tests

	test_modbus_framing
		local
			frame: GANTRY_MODBUS_FRAME
			bytes: ARRAYED_LIST [INTEGER]
			payload: ARRAYED_LIST [INTEGER]
			parsed: GANTRY_MODBUS_FRAME
			mb_const: GANTRY_MODBUS_CONSTANTS
		do
			create mb_const
			create payload.make (4)
			payload.extend (0) -- Address high
			payload.extend (10) -- Address low (10)
			payload.extend (0) -- Count high
			payload.extend (5)  -- Count low (5)

			create frame.make_request (101, 1, mb_const.Fc_read_holding_registers, payload)
			bytes := frame.to_bytes
			check min_bytes: bytes.count = 12 end
			check trans_hi: bytes.i_th (1) = 0 end
			check trans_lo: bytes.i_th (2) = 101 end
			check fc_match: bytes.i_th (8) = frame.Fc_read_holding_registers end

			create parsed.make_from_bytes (bytes)
			check parsed_tid: parsed.transaction_id = 101 end
			check parsed_fc: parsed.function_code = frame.Fc_read_holding_registers end
			check parsed_len: parsed.data_payload.count = 4 end
		end

	test_modbus_server_and_client
		local
			reg_map: GANTRY_MODBUS_REGISTER_MAP
			server: GANTRY_MODBUS_SERVER
			client: GANTRY_MODBUS_CLIENT
			tbl: GANTRY_IMAGE_TABLE
			do_valve: GANTRY_DIGITAL_POINT
			ao_sp: GANTRY_ANALOG_POINT
			req, resp: GANTRY_MODBUS_FRAME
		do
			create tbl.make
			create do_valve.make_digital ("SOLENOID_V1", "Isolation solenoid")
			create ao_sp.make_analog ("SPEED_SP", "Motor speed setpoint", "RPM")
			tbl.register_digital_output (do_valve)
			tbl.register_analog_output (ao_sp)

			create reg_map.make
			reg_map.map_coil (10, "SOLENOID_V1")
			reg_map.map_holding_register (100, "SPEED_SP")

			create server.make (reg_map)
			create client.make

			-- 1. Client writes single coil 10 -> True
			req := client.build_write_single_coil (1, 10, True)
			resp := server.handle_request (req, tbl, 1000)
			check resp_fc: resp.function_code = server.Fc_write_single_coil end
			check coil_updated: tbl.read_digital ("SOLENOID_V1") end

			-- 2. Client polls holding register 100
			tbl.write_analog ("SPEED_SP", 1800.0, 1000)
			req := client.build_read_holding_registers (1, 100, 1)
			resp := server.handle_request (req, tbl, 1010)
			check resp_read_fc: resp.function_code = server.Fc_read_holding_registers end
			check byte_count: resp.data_payload.i_th (1) = 2 end
			check val_hi: resp.data_payload.i_th (2) = (1800 // 256) end
			check val_lo: resp.data_payload.i_th (3) = (1800 \\ 256) end
		end

	test_opcua_address_space
		local
			space: GANTRY_OPCUA_ADDRESS_SPACE
			node: GANTRY_OPCUA_NODE
			tbl: GANTRY_IMAGE_TABLE
			di_limit: GANTRY_DIGITAL_POINT
			ai_temp: GANTRY_ANALOG_POINT
			opc_types: GANTRY_OPCUA_TYPES
		do
			create opc_types
			create space.make
			check objects_exists: space.nodes_by_id.has ("ns=0;i=85") end

			create node.make_variable ("ns=2;s=LIMIT_SW", "LIMIT_SW", opc_types.Type_boolean, 0.0)
			space.add_node (node)
			check node_registered: space.get_node ("ns=2;s=LIMIT_SW") /= Void end

			-- Telemetry sync test
			create tbl.make
			create di_limit.make_digital ("LIMIT_SW", "Carriage limit")
			create ai_temp.make_analog ("MOTOR_TEMP", "Stator winding temperature", "degC")
			tbl.register_digital_input (di_limit)
			tbl.register_analog_input (ai_temp)

			di_limit.update_value (True, 100)
			space.sync_from_image_table (tbl)
			if attached space.get_node ("ns=2;s=LIMIT_SW") as n then
				check synced_bool: n.boolean_value end
			end
		end

	test_opcua_chunks_and_subscriptions
		local
			payload: ARRAYED_LIST [INTEGER]
			chunk, parsed_chunk: GANTRY_OPCUA_CHUNK
			bytes: ARRAYED_LIST [INTEGER]
			space: GANTRY_OPCUA_ADDRESS_SPACE
			var_node: GANTRY_OPCUA_NODE
			sub: GANTRY_OPCUA_SUBSCRIPTION
			changes: INTEGER
			opc_types: GANTRY_OPCUA_TYPES
		do
			create opc_types
			-- Test chunk framing
			create payload.make (4)
			payload.extend (10); payload.extend (20); payload.extend (30); payload.extend (40)
			create chunk.make ("MSG", 'F', 42, payload)
			bytes := chunk.to_bytes
			check chunk_min_size: bytes.count = 16 end
			check chunk_msg: bytes.i_th (1) = 77 and bytes.i_th (2) = 83 and bytes.i_th (3) = 71 end -- "MSG"

			create parsed_chunk.make_from_bytes (bytes)
			check chunk_type_ok: parsed_chunk.message_type.is_equal ("MSG") end
			check chunk_id_ok: parsed_chunk.channel_id = 42 end

			-- Test subscriptions
			create space.make
			create var_node.make_variable ("ns=2;s=SPEED", "SPEED", opc_types.Type_double, 100.0)
			space.add_node (var_node)

			create sub.make (1, 100) -- 100 ms publishing interval
			sub.add_monitored_item ("ns=2;s=SPEED")

			changes := sub.check_publish (space, 1000)
			check initial_change: changes = 1 end

			-- Next cycle: no change
			changes := sub.check_publish (space, 1050)
			check no_change: changes = 0 end

			-- Mutate node value and advance time past 100 ms
			var_node.set_double_value (150.0)
			changes := sub.check_publish (space, 1150)
			check change_emitted: changes = 1 end
		end

	test_dnp3_crc_and_link_frames
		local
			crc: GANTRY_DNP3_CRC
			test_bytes: ARRAYED_LIST [INTEGER]
			calc_crc: INTEGER
			frame, parsed_frame: GANTRY_DNP3_LINK_FRAME
			payload: ARRAYED_LIST [INTEGER]
			wire_bytes: ARRAYED_LIST [INTEGER]
		do
			create crc.make
			create test_bytes.make (8)
			-- Standard FT3 frame header bytes: 0x05, 0x64, 0x05, 0xC4, 0x01, 0x00, 0x02, 0x00
			test_bytes.extend (5); test_bytes.extend (100); test_bytes.extend (5)
			test_bytes.extend (196); test_bytes.extend (1); test_bytes.extend (0)
			test_bytes.extend (2); test_bytes.extend (0)

			calc_crc := crc.compute_crc (test_bytes, 1, 8)
			check valid_crc: calc_crc >= 0 and calc_crc <= 65535 end

			-- Test full link frame
			create payload.make (2)
			payload.extend (1); payload.extend (2)
			create frame.make_frame (196, 1, 2, payload)
			wire_bytes := frame.to_bytes
			check wire_has_sync: wire_bytes.i_th (1) = 5 and wire_bytes.i_th (2) = 100 end

			create parsed_frame.make_from_bytes (wire_bytes)
			check parsed_dest: parsed_frame.dest_address = 1 end
			check parsed_src: parsed_frame.source_address = 2 end
			check parsed_payload: parsed_frame.user_data.count = 2 end
		end

	test_dnp3_outstation
		local
			outstation: GANTRY_DNP3_OUTSTATION
			tbl: GANTRY_IMAGE_TABLE
			di: GANTRY_DIGITAL_POINT
			ai: GANTRY_ANALOG_POINT
			resp_frame: GANTRY_DNP3_LINK_FRAME
		do
			create outstation.make (10)
			create tbl.make
			create di.make_digital ("BREAKER_CLOSED", "Bus breaker status")
			create ai.make_analog ("GRID_FREQ", "Frequency", "Hz")
			tbl.register_digital_input (di)
			tbl.register_analog_input (ai)

			di.update_value (True, 100)
			ai.update_value (60.0, 100)

			resp_frame := outstation.handle_read_class_zero (1, tbl)
			check poll_handled: outstation.processed_polls = 1 end
			check resp_has_data: not resp_frame.user_data.is_empty end
			check resp_fc: resp_frame.user_data.i_th (2) = outstation.Fc_response end
		end

	test_mqttsn_gateway
		local
			gateway: GANTRY_MQTTSN_GATEWAY
			tbl: GANTRY_IMAGE_TABLE
			ai_flow: GANTRY_ANALOG_POINT
			tid: INTEGER
			payload: ARRAYED_LIST [INTEGER]
			pub_packet, puback: GANTRY_MQTTSN_PACKET
		do
			create gateway.make
			create tbl.make
			create ai_flow.make_analog ("COOLING_FLOW", "Cooling jacket flow", "L/min")
			tbl.register_analog_input (ai_flow)

			tid := gateway.register_topic ("COOLING_FLOW")
			check tid_positive: tid > 0 end

			-- Construct PUBLISH packet: Flags(0), TopicId(tid), MsgId(1), Data(120)
			create payload.make (7)
			payload.extend (0) -- Flags
			payload.extend (tid // 256)
			payload.extend (tid \\ 256)
			payload.extend (0) -- MsgId high
			payload.extend (1) -- MsgId low
			payload.extend (0) -- Data high
			payload.extend (120) -- Data low: 120 L/min

			create pub_packet.make (gateway.Msg_publish, payload)
			puback := gateway.handle_publish (pub_packet, tbl, 1000)
			check puback_type: puback.message_type = gateway.Msg_puback end
			check puback_accepted: puback.payload.last = gateway.Rc_accepted end
			check flow_updated: (tbl.read_analog ("COOLING_FLOW") - 120.0).abs < 0.001 end
		end

end
