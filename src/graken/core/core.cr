module Graken
  enum NodeType
    Normal
    Parallel
    Initial
    ParallelFlat
  end

  class Node
    getter :name, :type, :parallel, :edges_in, :edges_out, :children
    setter :name
    getter parent : Node | Nil
    def initialize(@name : String, @type=NodeType::Normal, @parallel=[] of Node)
      @parent = nil
      @children = {} of String => Node
      @edges_in = [] of Edge
      @edges_out = [] of Edge
    end
    def initialize(duplicate : Node)
      @name=duplicate.name
      @type=duplicate.type
      @parallel=duplicate.parallel
      @parent = nil
      @children = {} of String => Node
      @edges_in = [] of Edge
      @edges_out = [] of Edge
    end
    def to_s
      name = "#{@name}"
      name = name + " < #{@parent.not_nil!.name}" unless @parent.nil?
      name = name + "\n\t[#{@parallel.map(&.name.to_s).join(", ")}]" unless @parallel.empty?
      name = name + "\n\t#{@edges_in.map(&.to_s).join("\n\t")}" unless @edges_in.empty?
      name = name + "\n\t#{@edges_out.map(&.to_s).join("\n\t")}" unless @edges_out.empty?
      name
    end
    def add_edge_in(edge : Edge)
      @edges_in.push edge
    end
    def add_edge_out(edge : Edge)
      @edges_out.push edge
    end
    def add_child(node : Node)
      @children[node.name] = node
    end
    def remove_child(node : Node)
      @children.delete node.name
    end
    def parent=(node : Node | Nil)
      @parent.not_nil!.remove_child self unless @parent.nil?
      @parent = node
      @parent.not_nil!.add_child self unless @parent.nil?
    end
    def remove_edge(edge : Edge)
      edges_in.delete edge if edges_in.includes? edge
      edges_out.delete edge if edges_out.includes? edge
    end
  end

  class Edge
    getter :name, :from, :to, :distance, :trigger, :guard
    setter :name, :guard
    def initialize(@from : Node, @to : Node, @distance=0.0, @name="", @trigger="", @guard="")
      @from.add_edge_out self
      @to.add_edge_in self
    end
    def initialize(duplicate : Edge, @from : Node, @to : Node)
      @distance=duplicate.distance
      @name=duplicate.name
      @trigger=duplicate.trigger
      @guard=duplicate.guard
      @from.add_edge_out self
      @to.add_edge_in self
    end
    def dependencies
      @guard.gsub /(In\(')|('\))/,"" 
    end
    def to_s
      "#{@from.name} --> #{@to.name} : #{@trigger}[#{dependencies}]" 
    end
  end

  class Graph
    Log = ::Log.for("graken.graph")
    getter :nodes, :edges

    def initialize
      @nodes = {} of String => Node
      @edges = [] of Edge
      @id = 0
      @flattened = false
      @validated = false
    end

    def self.from_node(node : Node)
      graph = Graph.new
      core = Node.new node
      graph.add_node core
      node.edges_in.each do |e|
        if graph.nodes.has_key? e.from.name
          from = graph.nodes[e.from.name]
        else
          from = Node.new e.from
          graph.add_node from
        end
        graph.add_edge Edge.new e,from,core
      end
      node.edges_out.each do |e|
        if graph.nodes.has_key? e.to.name
          to = graph.nodes[e.to.name]
        else
          to = Node.new e.to
          graph.add_node to
        end
        graph.add_edge Edge.new e,core,to
      end
      graph
    end

    private def get_id
      @id = 1 + @id
      "δ#{@id}"
    end

    def add_node(node : Node)
      @nodes[node.name] = node unless @nodes.has_key? node.name
      self
    end

    def add_edge(edge : Edge)
      edge.name = get_id if edge.name.empty?
      add_node edge.from
      add_node edge.to
      @edges.push edge
      self
    end

    def node(name : String)
      if @nodes.has_key? name
        return @nodes[name]
      else
        @nodes.each do |k,n|
          n.parallel.each do |par|
            return par if par.name == name
          end
        end
      end
      nil
    end

    def find_parallel(parallel : Array(String))
      parallel = parallel.sort
      @nodes.find { |n| n.type == NodeType::ParallelFlat && n.parallel == parallel }
    end

    def remove_edge(edge : Edge)
      Log.trace { "Remove edge - #{edge.from.name} --> #{edge.to.name}" }
      edge.from.remove_edge edge
      edge.to.remove_edge edge
      @edges.delete edge
    end

    def remove_node(node : Node)
      Log.trace { "Remove node - #{node.name}" }
      node.edges_in.each { |e| remove_edge(e) }
      node.edges_out.each { |e| remove_edge(e) }
      @nodes.delete node.name
      self
    end

    def remove_node_recursive(node : Node)
      Fiber.yield
      node.children.each do |k,n|
        remove_node_recursive(n)
      end
      remove_node(node)
      self
    end
  end
end