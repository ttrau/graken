require "xml"

module Graken
  class Importer
    def initialize(xml)
      @scxml = XML.parse(xml)
    end
    def import
      g = Graph.new
      @scxml.xpath_nodes("//*[local-name() = 'state' or local-name() = 'parallel']").each do |node|
        type = NodeType::Normal
        type = NodeType::Parallel if node.name == "parallel"
        new_node = Node.new(node["id"],type)
        find_parent = node.xpath_string("string(parent::*/@id)")
        new_node.parent = g.nodes[find_parent] unless find_parent.nil? || find_parent.empty?
        g.add_node(new_node)
      end

      root = @scxml.root
      if root
        init_node = Node.new("init_#{root["initial"]}", NodeType::Initial)
        root_node = g.nodes[root["initial"]]
        g.add_node(init_node)
        g.add_edge(Edge.new(init_node,root_node,0.0))
      end

      @scxml.xpath_nodes("//*[local-name() = 'state' or local-name() = 'parallel']").each do |node|
        id = node["id"].nil? ? "" : node["id"]
        node.xpath_nodes("*[local-name() = 'transition']").each do |t|
          target = t["target"]?.nil? ? id : t["target"]
          trigger = t["event"]?.nil? ? "" : t["event"]
          guard = t["cond"]?.nil? ? "" : t["cond"]
          g.add_edge(Edge.new(g.nodes[id],g.nodes[target],1.0,"",trigger,guard))
        end
        node.xpath_nodes("*[local-name() = 'initial']").each do |initial|
          target = initial.xpath_string("string(*[local-name() = 'transition']/@target)")
          init_node = Node.new("init_#{id}_#{target}", NodeType::Initial)
          init_node.parent = g.nodes[id]
          g.add_node(init_node)
          g.add_edge(Edge.new(init_node,g.nodes[target],0.0))
        end
      end
      g
    end
  end

  class Exporter
    def initialize(@graph : Graph)
    end
    def export
      xml = XML.build(indent: "  ") do |xml|
        xml.element("graph") do
          xml.element("nodes") do
            @graph.nodes.each do |node|
              xml.element(node.name, parent: node.parent, type: node.type.to_s, parallel: node.parallel.join(","))
            end
          end
          xml.element("edges") do
            @graph.edges.each do |edge|
              xml.element(edge.from, trigger: edge.trigger, guard: edge.guard, distance: edge.distance.to_s) { xml.text edge.to }
            end
          end
        end
      end
      xml.to_s
    end
    def export_dijkstra(path : String)
      File.write path,""
      File.open(path, "w") do |file|
        @graph.nodes.each do |name,node|
          file.puts "#{name} #{node.edges_out.map { |e| "#{e.to.name},#{e.distance}" }.join(" ")}"
        end
      end
    end
    def export_file(path : String)
      File.write path,""
      File.open(path, "w") do |file|
        @graph.nodes.each do |name,node|
          edges = node.edges_out.map { |e| "#{e.to.name},#{e.distance},#{e.trigger},#{e.guard}" }.join(";")
          parallel = node.parallel.map(&.name).join(",")
          file.puts "#{name};#{parallel};#{edges}"
        end
      end
    end
    def export_cypher(path : String)
      File.write path,""
      File.open(path, "w") do |file|
        @graph.nodes.each do |name,node|
          id = name.gsub /\./,""
          file.puts "MERGE (#{id}:Node {name:\"#{name}\"})"
          node.parallel.each do |par|
            par_id = par.name.gsub /\./,""
            file.puts "MERGE (#{par_id}:Node {name:\"#{par.name}\"})"
            file.puts "MERGE (#{id})-[:Parallel]->(#{par_id})"
          end
        end
        @graph.edges.each do |edge|
          file.puts "MERGE (#{edge.from.name.gsub(/\./,"")})-[:Edge {distance:#{edge.distance},trigger:\"#{edge.trigger}\",guard:\"#{edge.guard}\"}]->(#{edge.to.name.gsub(/\./,"")})"
        end
        file.puts ";"
      end
    end
  end
end
