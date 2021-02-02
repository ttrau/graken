require "file_utils"

module Graken
  class DotGraph
    def initialize(@graph : Graph, @title = "graken", @root : Node | Nil = nil)
      @subgraphs = [] of DotGraph
      @nodes = {} of Node => Int32
      @base_headers = {} of Symbol => String
      @headers = {} of Symbol => Hash(Symbol,String)
      @node_naming = Proc(Node, Int32, Hash(Symbol,String)).new { |x,i| { :label => x.name } }
      @edge_naming = Proc(Edge, Hash(Symbol,String)).new { |x| { :label => x.name } }
    end
    def import
      @subgraphs.clear
      @graph.nodes.values.each_with_index { |n,i| @nodes[n] = i if n.parent == @root }
      node_names = @nodes.map { |n,i| n.name }
      @nodes.each { |n,i| @subgraphs.push DotGraph.new(@graph,root:n) if !n.children.empty? }
      @subgraphs.each { |g| g.import }
    end
    def clear
      @base_headers.clear
      @headers.clear
      self[:layout] = "dot"
      self[:compound] = "true"
      self[:splines] = "spline"
      self[:rankdir] = "LR"
      self[:size] = "8,5"
    end
    def setup_default
      clear
      self[:node] = { :shape => "box", :style => "rounded", :fontname => "CMU Serif, Normal", :penwidth => "1.8" }
      self[:edge] = { :arrowhead => "vee", :fontname => "CMU Serif, Normal", :penwidth => "1.8" }
      @node_naming = Proc(Node, Int32, Hash(Symbol,String)).new { |x,i| { :label => x.name } }
      @edge_naming = Proc(Edge, Hash(Symbol,String)).new { |x| { :label => x.name } }
      @subgraphs.each { |g| g.setup_default }
    end
    def setup_parallel
      clear
      self[:node] = { :shape => "box", :style => "rounded", :fontname => "CMU Serif, Normal", :penwidth => "1.8" }
      self[:edge] = { :arrowhead => "vee", :fontname => "CMU Serif, Normal" }
      @node_naming = Proc(Node, Int32, Hash(Symbol,String)).new do |n,i|
        case n.type
        when NodeType::Initial
          { :label => "", :shape => "point", :style => "filled" }
        when NodeType::ParallelFlat
          { :label => n.parallel.empty? ? n.name : "#{n.name}\n#{n.parallel.map(&.name).join("\n")}" }
        else
          { :label => n.name }
        end
      end
      @edge_naming = Proc(Edge, Hash(Symbol,String)).new  do |e|
        if e.from.type == NodeType::Initial
          { :label => "" }
        elsif e.from.type == NodeType::ParallelFlat && e.to.type == NodeType::ParallelFlat
          { :label => (e.to.parallel.map(&.name) - e.from.parallel.map(&.name)).join(",") }
        else
          { :label => e.name }
        end
      end
      @subgraphs.each { |g| g.setup_parallel }
    end
    def setup_large
      clear
      self[:size] = "1"
      self[:node] = { :shape => "circle", :fontname => "CMU Serif, Normal", :penwidth => "1.8", :fixedsize => "true" }
      self[:edge] = { :arrowhead => "vee", :fontname => "CMU Serif, Normal", :penwidth => "1.8" }
      @node_naming = Proc(Node, Int32, Hash(Symbol,String)).new { |x,i| { :label => i.to_s, :style => "filled" } }
      @edge_naming = Proc(Edge, Hash(Symbol,String)).new { |x| { :label => ""} }
      @subgraphs.each { |g| g.setup_large }
    end
    def []=(key : Symbol, value : String|Hash(Symbol,String))
      @base_headers[key] = value if value.is_a? String
      @headers[key] = value if value.is_a? Hash(Symbol,String)
    end
    def set_node_style(&block : Node, Int32 -> Hash(Symbol,String))
      @node_naming = block
      @subgraphs.each { |g| g.set_node_style &block }
    end
    def set_edge_style(&block : Edge -> Hash(Symbol,String))
      @edge_naming = block
      @subgraphs.each { |g| g.set_edge_style &block }
    end
    def to_svg
      svg = pipe "dot", self.to_s, args: ["-Tsvg"]
      # fix graphviz error
      if svg =~ /\<svg width=\"(.*)pt\" height/
        scale = $1.to_f / 1000.0
        svg = svg.gsub /transform=\"scale((.*) (.*)) rotate/,"transform=\"scale(#{scale} #{scale}) rotate"
      end
      svg
    end
    def to_s
      core = @base_headers.map { |k,v| "#{k}=\"#{v}\"" }
      core = core + @headers.map { |bk,bv| "#{bk} [#{bv.map { |k,v| "#{k} =\"#{v}\"" }.join(",")}]" }
      @nodes.each do |n,i|
        node_names = @node_naming.call(n,i)
        core.push "#{i} [#{node_names.map { |k,v| "#{k}=\"#{v}\"" }.join(",")}]"
        n.edges_out.each do |e|
          edge_names = @edge_naming.call(e)
          core.push "#{i} -> #{@nodes[e.to]} [#{edge_names.map { |k,v| "#{k}=\"#{v}\"" }.join(",")}]"
        end
      end
      @subgraphs.each { |g| core.push g.to_s }
      "#{@root.nil? ? "digraph" : "subgraph"} #{@title} {\n\t#{core.join(";\n\t")};\n}"
    end
    private def pipe(command,content=nil,args=nil)
      output = IO::Memory.new
      if content.nil?
        Process.run(command, args, output: output)
      else
        Process.run(command, args, input: IO::Memory.new(content), output: output)
      end
      output.close
      output.to_s
    end
  end
end
