note
	description: "Directed dependency graph verifying absence of circular deadlocks in safety interlock cascades."
	author: "Aneesh Krishna"

class
	GANTRY_INTERLOCK_GRAPH

create
	make

feature {NONE} -- Initialization

	make
		do
			create nodes.make (16)
			nodes.compare_objects
			create adjacency.make (16)
			has_cycle := False
		ensure
			empty_graph: nodes.is_empty
			no_cycles: not has_cycle
		end

feature -- Access

	nodes: ARRAYED_LIST [STRING]
	adjacency: HASH_TABLE [ARRAYED_LIST [STRING], STRING]
	has_cycle: BOOLEAN

feature -- Graph Construction

	add_node (a_node: STRING)
		require
			node_not_empty: not a_node.is_empty
		local
			adj_list: ARRAYED_LIST [STRING]
		do
			if not nodes.has (a_node) then
				nodes.extend (a_node.twin)
				create adj_list.make (4)
				adj_list.compare_objects
				adjacency.put (adj_list, a_node)
			end
		ensure
			node_present: nodes.has (a_node)
		end

	add_edge (a_from, a_to: STRING)
			-- Add directed edge: a_from interlocks or triggers a_to.
		require
			from_not_empty: not a_from.is_empty
			to_not_empty: not a_to.is_empty
		do
			add_node (a_from)
			add_node (a_to)
			if attached adjacency.item (a_from) as list then
				if not list.has (a_to) then
					list.extend (a_to.twin)
				end
			end
			check_for_cycles
		end

feature -- Cycle Detection

	check_for_cycles
			-- Depth-first search (DFS) detecting cyclic interlock deadlocks.
		local
			visited: HASH_TABLE [INTEGER, STRING] -- 0: unvisited, 1: visiting (in stack), 2: visited
			cycle_detected: BOOLEAN
		do
			create visited.make (nodes.count)
			across nodes as n loop
				visited.put (0, n)
			end

			cycle_detected := False
			across nodes as n loop
				if not cycle_detected and visited.item (n) = 0 then
					cycle_detected := dfs_cycle (n, visited)
				end
			end
			has_cycle := cycle_detected
		end

feature {NONE} -- DFS Helper

	dfs_cycle (a_node: STRING; a_visited: HASH_TABLE [INTEGER, STRING]): BOOLEAN
		local
			neighbor: STRING
			found: BOOLEAN
		do
			a_visited.force (1, a_node) -- Mark visiting

			found := False
			if attached adjacency.item (a_node) as neighbors then
				across neighbors as cur loop
					neighbor := cur
					if not found then
						if a_visited.has (neighbor) and then a_visited.item (neighbor) = 1 then
							found := True -- Cycle back-edge found!
						elseif a_visited.has (neighbor) and then a_visited.item (neighbor) = 0 then
							if dfs_cycle (neighbor, a_visited) then
								found := True
							end
						end
					end
				end
			end

			a_visited.force (2, a_node) -- Mark finished
			Result := found
		end

invariant
	nodes_attached: nodes /= Void
	adjacency_attached: adjacency /= Void

end
