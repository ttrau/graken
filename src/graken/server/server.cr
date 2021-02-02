require "http/server"

module Default
  class Server
    def initialize
      @routes = {} of String => (HTTP::Server::Context,HTTP::Params -> String)
      @matches = {} of Regex => (HTTP::Server::Context,HTTP::Params,Regex::MatchData -> String)
      @server = HTTP::Server.new do |context|
        req = context.request
        res = context.response
        q = context.request.query_params
        res.status = HTTP::Status::OK
        res.content_type = "text/plain"
        if @routes.has_key?(req.path.to_s)
          res.print @routes[req.path.to_s].call context,q
        else
          route = @matches.keys.find { |r| r.match(req.path.to_s) }
          unless route.nil?
            res.print @matches[route].call context,q,req.path.to_s.match(route).not_nil!
          else
            res.status = HTTP::Status::NOT_FOUND
            res.content_type = "text/plain"
            res.print "404 - Not found."
          end
        end
      end
    end

    def run
      yield @server
      @server.listen
    end

    def get(route : String, &block : HTTP::Server::Context,HTTP::Params -> String)
      @routes[route] = block
    end

    def match(route : Regex, &block : HTTP::Server::Context,HTTP::Params,Regex::MatchData -> String)
      @matches[route] = block
    end
  end
end

module Graken
  class Server < Default::Server
    def initialize(@graph : Graph)
      super()
      get "/" do |context,q|
        "#{@graph.nodes.size} Nodes\n#{@graph.edges.size} Edges"
      end
      get "/calculate/" do |context,q|
        calc = @graph.calculate
        "#{calc[0]} Nodes\n#{calc[1]} Edges"
      end
      get "/flatten/" do |context,q|
        @graph.flatten!
        "#{@graph.nodes.size} Nodes\n#{@graph.edges.size} Edges"
      end
      get "/validate/" do |context,q|
        @graph.flatten!
        @graph.validate!
        "#{@graph.nodes.size} Nodes\n#{@graph.edges.size} Edges"
      end
      get "/nodes/" do |context,q|
        @graph.nodes.keys.join ", "
      end
      get "/sample/" do |context,q|
        dest = @graph.nodes.values.sample
        "#{dest.nil? ? "not_found" : dest.to_s}"
      end
      get "/dot/" do |context,q|
        next "missing id parameter" unless q.has_key? "id"
        next "node #{q["id"]} not found" unless @graph.nodes.has_key? q["id"]
        dest = @graph.nodes[q["id"]]
        dot = DotGraph.new(Graph.from_node dest)
        dot.setup_parallel
        dot.import
        dot.to_s
      end
      match /^\/graph\/(.*)$/ do |context,q,md|
        next "node #{md[1]} not found" unless @graph.nodes.has_key? md[1]
        context.response.content_type = "image/svg+xml"
        dest = @graph.nodes[md[1]]
        dot = DotGraph.new(Graph.from_node dest)
        dot.setup_parallel
        dot[:size] = "20! 20!"
        dot.import
        svg = dot.to_svg
        match = /<text (.*)>(.*)<\/text>/
        svg = svg.gsub(match) do |reg|
          if reg =~ />(.*)<\/text>/
              "<a xlink:href=\"./#{$1}\">#{reg}</a>"
          else
            reg
          end
        end
        svg
      end
      get "/sample_dot/" do |context,q|
        dest = @graph.nodes.values.sample
        dot = DotGraph.new(Graph.from_node dest)
        dot.setup_parallel
        dot.import
        dot.to_s
      end
      get "/sample_graph/" do |context,q|
        context.response.content_type = "image/svg+xml"
        dest = @graph.nodes.values.sample
        dot = DotGraph.new(Graph.from_node dest)
        dot.setup_parallel
        dot.import
        dot.to_svg
      end
    end
  end
end
