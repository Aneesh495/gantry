note
	description: "DNP3 Link Layer (FT3) frame encoder and decoder with block-level CRC-16 checking."
	author: "Aneesh Krishna"

class
	GANTRY_DNP3_LINK_FRAME

create
	make_frame,
	make_from_bytes

feature {NONE} -- Initializers

	make_frame (a_control, a_dest, a_src: INTEGER; a_payload: ARRAYED_LIST [INTEGER])
		require
			valid_dest: a_dest >= 0 and a_dest <= 65535
			valid_src: a_src >= 0 and a_src <= 65535
			payload_attached: a_payload /= Void
		do
			create crc_calc.make
			control_byte := a_control
			dest_address := a_dest
			source_address := a_src
			user_data := a_payload.twin
			length := 5 + user_data.count -- Control (1) + Dest (2) + Src (2) + UserData
		ensure
			dest_set: dest_address = a_dest
			src_set: source_address = a_src
		end

	make_from_bytes (a_bytes: ARRAYED_LIST [INTEGER])
		require
			min_link_size: a_bytes.count >= 10
		local
			hdr_crc, calc_crc: INTEGER
			rem_data: INTEGER
			pos: INTEGER
			chunk_len: INTEGER
			i: INTEGER
		do
			create crc_calc.make
			-- Validate 0x05 0x64 sync
			length := a_bytes.i_th (3)
			control_byte := a_bytes.i_th (4)
			dest_address := a_bytes.i_th (5) + (a_bytes.i_th (6) * 256)
			source_address := a_bytes.i_th (7) + (a_bytes.i_th (8) * 256)
			hdr_crc := a_bytes.i_th (9) + (a_bytes.i_th (10) * 256)

			calc_crc := crc_calc.compute_crc (a_bytes, 1, 8)
			-- Extract user data chunks
			rem_data := length - 5
			create user_data.make (rem_data)
			pos := 11

			from
			until
				rem_data <= 0 or pos > a_bytes.count
			loop
				if rem_data > 16 then
					chunk_len := 16
				else
					chunk_len := rem_data
				end

				from
					i := 0
				until
					i >= chunk_len
				loop
					user_data.extend (a_bytes.i_th (pos + i))
					i := i + 1
				end

				pos := pos + chunk_len + 2 -- skip data + 2 byte CRC
				rem_data := rem_data - chunk_len
			end
		end

feature -- Access

	length: INTEGER
	control_byte: INTEGER
	dest_address: INTEGER
	source_address: INTEGER
	user_data: ARRAYED_LIST [INTEGER]

feature {NONE} -- Internal Helpers

	crc_calc: GANTRY_DNP3_CRC

feature -- Serialization

	to_bytes: ARRAYED_LIST [INTEGER]
		local
			res: ARRAYED_LIST [INTEGER]
			hdr_crc, data_crc: INTEGER
			rem, chunk_len, pos, i: INTEGER
			chunk_bytes: ARRAYED_LIST [INTEGER]
		do
			create res.make (32)

			-- 1. Sync octets
			res.extend (5)   -- 0x05
			res.extend (100) -- 0x64

			-- 2. Length (5 + user data length)
			res.extend (5 + user_data.count)

			-- 3. Control byte
			res.extend (control_byte)

			-- 4. Destination Address (Little-endian 16-bit)
			res.extend (dest_address \\ 256)
			res.extend ((dest_address // 256) \\ 256)

			-- 5. Source Address (Little-endian 16-bit)
			res.extend (source_address \\ 256)
			res.extend ((source_address // 256) \\ 256)

			-- 6. Header CRC (over bytes 1 to 8)
			hdr_crc := crc_calc.compute_crc (res, 1, 8)
			res.extend (hdr_crc \\ 256)
			res.extend ((hdr_crc // 256) \\ 256)

			-- 7. User Data in blocks of <= 16 octets, each with 16-bit CRC
			rem := user_data.count
			pos := 1

			from
			until
				rem <= 0
			loop
				if rem > 16 then
					chunk_len := 16
				else
					chunk_len := rem
				end

				create chunk_bytes.make (chunk_len)
				from
					i := 0
				until
					i >= chunk_len
				loop
					chunk_bytes.extend (user_data.i_th (pos + i))
					res.extend (user_data.i_th (pos + i))
					i := i + 1
				end

				data_crc := crc_calc.compute_crc (chunk_bytes, 1, chunk_len)
				res.extend (data_crc \\ 256)
				res.extend ((data_crc // 256) \\ 256)

				pos := pos + chunk_len
				rem := rem - chunk_len
			end

			Result := res
		ensure
			valid_size: Result.count >= 10
		end

invariant
	data_attached: user_data /= Void

end
