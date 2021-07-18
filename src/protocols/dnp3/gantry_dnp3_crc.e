note
	description: "DNP3 / FT3 16-bit Cyclic Redundancy Check (CRC-16) conforming to IEEE 802.3 and IEC 60870-5."
	author: "Aneesh Krishna"

class
	GANTRY_DNP3_CRC

create
	make

feature {NONE} -- Initialization

	make
		do
			build_crc_table
		ensure
			table_built: crc_table.count = 256
		end

feature -- Access

	crc_table: ARRAY [INTEGER]
			-- Lookup table for polynomial 0xA653.

feature -- Calculation

	compute_crc (a_bytes: ARRAYED_LIST [INTEGER]; a_offset, a_len: INTEGER): INTEGER
			-- Compute inverted 16-bit CRC over specified byte slice.
		require
			bytes_attached: a_bytes /= Void
			valid_range: a_offset >= 1 and a_offset + a_len - 1 <= a_bytes.count
		local
			crc: INTEGER
			i, idx, b: INTEGER
		do
			crc := 0
			from
				i := 0
			until
				i >= a_len
			loop
				b := a_bytes.i_th (a_offset + i)
				idx := (crc \\ 256).bit_xor (b) + 1
				crc := (crc // 256).bit_xor (crc_table.item (idx))
				i := i + 1
			end
			-- DNP3 requires final inversion (bit_not) masked to 16 bits
			Result := crc.bit_not.bit_and (65535)
		ensure
			bounded_16_bit: Result >= 0 and Result <= 65535
		end

feature {NONE} -- Table Generation

	build_crc_table
		local
			i, j, crc: INTEGER
		do
			create crc_table.make_filled (0, 1, 256)
			from
				i := 0
			until
				i >= 256
			loop
				crc := i
				from
					j := 0
				until
					j >= 8
				loop
					if (crc.bit_and (1)) /= 0 then
						crc := (crc // 2).bit_xor (42579) -- 0xA653 inverted representation
					else
						crc := crc // 2
					end
					j := j + 1
				end
				crc_table.put (crc.bit_and (65535), i + 1)
				i := i + 1
			end
		end

invariant
	table_size: crc_table.count = 256

end
