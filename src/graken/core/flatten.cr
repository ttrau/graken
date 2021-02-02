module Graken
  class Graph
    def flatten!
      return if @flattened || @validated
      @flattened = true
      top = @nodes.select { |k,n| n.parent.nil? }
      top.each {|k,n| recurse_flatten(n)}
    end

    private def recurse_flatten(node : Node)
      node.children.each do |k,child|
        recurse_flatten child
      end
      if node.children.size > 0
        if node.type == NodeType::Parallel
          Log.debug { "Resolve parallel - #{node.name}" }
          resolve_parallel(node)
        elsif !node.parent.nil? && node.parent.not_nil!.type == NodeType::Parallel
          Log.debug { "Resolve parallel-sub - #{node.name}" }
          #resolve parallel at parent level => so nothing
        else
          Log.debug { "Resolve hierarchy - #{node.name}" }
          resolve_hierarchy(node)
        end
      end
    end

    private def resolve_parallel(node)
      initial_states = [] of Node
      parallel_states = [] of Array(Node)

      node.children.each do |kp,parallel_sub|
        atomic_states = parallel_sub.children.values.select { |n| n.type != NodeType::Initial } #get arrays of atomic states per parallel substate
        initial_state = parallel_sub.children.values.find { |n| n.type == NodeType::Initial }
        if initial_state.nil?
          initial_states.push atomic_states.first
        else
          initial_states.push initial_state.not_nil!.edges_out.first.to
        end
        parallel_states.push atomic_states
      end
      vector = Array.product(parallel_states)
      vector_trans = [] of Array(Node)
      vector.transpose.each do |v|
        vector_trans.push v.uniq
      end
      dimensions = vector_trans.map { |v| v.size }

      original_edges = @edges.dup

      new_nodes = [] of Node
      Log.trace { "Adding #{vector.size} parallel-flat nodes" }
      progress = Progress::Bar.new("Resolving edges to \"#{node.name}\": ",vector.size,50,Math.sqrt(vector.size).to_i,show_memory: false)
      progress.custom_info { "nodes #{self.nodes.keys.size}, edges: #{self.edges.size}" }
      vector.each_with_index do |row,i|
        new_state = "#{node.name}_#{i.to_s}"#.rjust(2, '0')}"
        new_node = Node.new(new_state, NodeType::ParallelFlat, row)
        new_node.parent = node.parent

        add_node(new_node)
        new_nodes.push new_node

        # add Edges going away from the parallel state chart node for each of the new parallel flat nodes
        node.edges_out.each do |edge|
          Fiber.yield
          Log.trace { "add edge - #{new_state} (parallel flat) --> #{edge.to}" }
          add_edge(Edge.new(edge,new_node,edge.to))
        end
        if initial_states == row
          # add Edges going to the parallel state chart node for only the resulting initial state of the flat state chart
          node.edges_in.each do |edge|
            Log.trace { "add edge - #{edge.from.name} --> #{new_state} (initial state)" }
            add_edge(Edge.new(edge,edge.from,new_node))
          end
        end
        progress.tick
      end

      puts "ERROR" if new_nodes.size != vector.size
      progress = Progress::Bar.new("Resolving edges from \"#{node.name}\": ",vector.size,50,Math.sqrt(vector.size).to_i,show_memory: false)
      progress.custom_info { "nodes #{self.nodes.keys.size}, edges: #{self.edges.size}" }
      new_nodes.each_with_index do |from_node,i|
        from_node.parallel.each do |par_state|
          par_state.edges_out.each do |edge|
            to_row = from_node.parallel.map { |x| x == par_state ? edge.to : x }
            to_node_index = -1
            to_node_index = index_encode(to_row,dimensions,vector_trans)
            to_node = new_nodes[to_node_index]

            raise "error: #{to_node.parallel} != #{to_row}" unless (to_node.parallel - to_row).empty?
            Fiber.yield
            Log.trace { "add edge - #{from_node.name} --> #{to_node.name}" }
            add_edge(Edge.new(edge,from_node,to_node))
          end
        end unless from_node.nil?
        progress.tick
      end

      remove_node_recursive(node)
    end

    private def percentage(at,of)
      sprintf "%.2f", at.to_f / (of.to_f / 100.to_f)
    end

    private def index_encode(position,dimensions,vector_trans = [] of Array(String))
      position = position.map_with_index { |pos,i| vector_trans[i].index(pos).as Int32 }
      dimensions_size = dimensions[0..-2].map_with_index { |d,i| dimensions[i+1..-1].reduce { |j,k| j*k } }.tap { |dims| dims.push 1 }
      position.map_with_index { |pos,i| dimensions_size[i]*pos }.reduce { |j,k| j+k }
    end

    private def resolve_hierarchy(node)
      initial = node.children.values.find { |n| n.type == NodeType::Initial }

      progress = Progress::Bar.new("Resolving hierarchy \"#{node.name}\": ",node.children.size,50,Math.sqrt(node.children.size).to_i,show_memory: false)
      progress.custom_info { "nodes #{self.nodes.keys.size}, edges: #{self.edges.size}" }
      node.children.each do |k,child|
        node.edges_out.each do |edge|
          add_edge(Edge.new(edge,child,edge.to)) # add current nodes edges also for children
          Log.trace { "add edge - #{child.name} -> #{edge.to} (#{node.parent})" }
        end
        child.parent = node.parent #set child to current nodes hierarchical level
        progress.tick
      end

      unless initial.nil?
        initial_edge = @edges.find { |e| e.from == initial.name }
        unless initial_edge.nil?
          @edges.select { |e| e.to == node.name }.each do |edge| #reroute all edges to current node to the initial node
            add_edge(Edge.new(edge.from,initial_edge.to,edge.distance,edge.name,edge.trigger,edge.guard))
          end
        end
        remove_node(initial)
      end

      remove_node(node)
    end
  end
end
