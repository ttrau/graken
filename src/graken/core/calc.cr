module Graken
  class Graph
    def calculate
      top = @nodes.select { |k,n| n.parent.nil? }
      calc = top.map { |k,n| recurse_calc(n) }
      nodes_calc = calc.map{ |n| n[0] }.reduce { |i,j| i+j } + 1 # plus initial
      trans_calc = calc.map{ |n| n[1] }.reduce { |i,j| i+j }
      [nodes_calc,trans_calc]
    end

    private def recurse_calc(node : Node)
      if node.type == NodeType::Initial
        return [0,0]
      end
      node_count = 1
      trans_count = node.edges_out.size

      child_count = [] of Array(Int32)
      node.children.each do |k,child|
        child_count.push recurse_calc(child)
      end

      if node.children.size > 0
        if node.type == NodeType::Parallel
          nc,tc = calc_parallel(node, child_count)
          node_count = node_count + nc - 1 # minus self
          trans_count = trans_count * nc + tc
        elsif !node.parent.nil? && node.parent.not_nil!.type == NodeType::Parallel
          #puts "--------------------"
          node_count = node_count + child_count.map{ |n| n[0] }.reduce { |i,j| i+j } - 1 # minus self
          trans_count = trans_count + child_count.map{ |n| n[1] }.reduce { |i,j| i+j }
        else
          nc,tc = calc_hierarchy(node, child_count)
          node_count = node_count + nc
          node_count = node_count - 1 if node.parent.nil?
          trans_count = trans_count * nc + tc
        end
      end
      return [node_count,trans_count]
    end

    private def calc_parallel(node : Node, count : Array(Array(Int32)))
      nodes = count.map{ |n| n[0] }
      node_count = nodes.reduce { |i,j| i*j }
      trans_count = count.map_with_index do |n,i|
        other_nodes = nodes.dup.tap{ |n| n.delete_at(i) }.reduce { |i,j| i*j }
        n[1] * other_nodes
      end.reduce { |i,j| i+j }
      [node_count,trans_count]
    end

    private def calc_hierarchy(node : Node, count : Array(Array(Int32)))
      nodes = count.map{ |n| n[0] }
      node_count = nodes.reduce { |i,j| i+j }
      trans_count = count.map{ |n| n[1] }.reduce { |i,j| i+j }
      [node_count,trans_count]
    end
  end
end
