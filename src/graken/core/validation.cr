module Graken
  class Graph
    def validate!(only_valid=false)
      return if @validated
      @validated = true
      reject = [] of Edge
      progress = Progress::Bar.new("Validate edges: ",@edges.size,50,Math.sqrt(@edges.size).to_i,show_memory: false)
      progress.custom_info { "nodes #{self.nodes.keys.size}, edges: #{self.edges.size}" }
      @edges.reject! do |edge|
        Fiber.yield
        progress.tick
        unless edge.guard.nil?
          validate_guard(edge)
          case evaluate_expression(edge.guard)
          when 1 # edge is valid
            #puts "Valid: #{edge.guard}"
            edge.guard = ""
            false
          when 0 # edge is not valid
            #puts "Not valid: #{edge.guard}"
            edge.from.remove_edge edge
            edge.to.remove_edge edge
            true
          else # edge cannot be validated
            #puts "Unknown: #{edge.guard}"
            if only_valid
              edge.from.remove_edge edge
              edge.to.remove_edge edge
              true
            else
              false
            end
          end
        else
          false
        end
      end

      progress = Progress::Bar.new("Cleaning nodes: ",@nodes.size,50,Math.sqrt(@nodes.size).to_i,show_memory: false)
      progress.custom_info { "nodes #{self.nodes.keys.size}, edges: #{self.edges.size}" }
      @nodes.each do |name,node|
        unless node.type == NodeType::Initial
          Fiber.yield
          remove_node node if node.edges_in.empty?
        end
        progress.tick
      end
    end

    private def validate_guard(edge : Edge)
      unless edge.from.parallel.empty?
        source = edge.from.parallel.map(&.name.to_s)
        edge.guard = edge.guard.gsub(/In\('(.*?)'\)/) do |reg|
          if reg =~ /In\('(.*?)'\)/ && source.includes?($1)
            true
          else
            false
          end
        end
      end
    end

    private def evaluate_expression(cond : String)
      cond = cond.gsub(/\s+/, " ")
      stack = {} of Int32 => Char
      expressions = [] of Array(Int32)
      sub_expressions = cond.chars.each_with_index do |c,i|
        stack[i] = c if c == '('
        if stack.size == 1 && c == ')' && stack.values.first == '('
          expressions.push [stack.keys.first,i]
          stack.clear
        elsif c == ')' && stack.values.last == '('
          stack.delete stack.keys.last #remove inner expressions
        elsif c == ')'
          raise "bracket close error"
        end
      end
      expressions.reverse.each do |ary|
        i,j = [ary.first+1,ary.last-1]
        valid = evaluate_expression cond[i..j]
        cond = cond.gsub("(#{cond[i..j]})", valid == 1 ? true : valid == 0 ? false : -1)
      end
      check_conditionals cond
    end

    private def check_conditionals(cond : String)
      split = cond.gsub(/(\!true|\!false)/) { |reg| reg == "!true" ? "false" : "true" }.split(" ")
      split.each_with_index do |c,i|
        if i.odd? && !["&&","||"].includes? c
          raise "Expression error in #{cond}"
        end
      end
      response = -1
      split.each_with_index do |c,i|
        if i == 0
          response = c == "true" ? 1 : c == "false" ? 0 : -1
        elsif i.even? && split[i-1] == "&&"
          if c == "true"
          elsif c == "false"
            response = 0
          elsif response == 0
            response = 0
          else
            response = -1
          end
        elsif i.even? && split[i-1] == "||"
          if response == 1
            break
          elsif c == "true"
            response = 1
          elsif c == "false"
            response = 0
          else
            response = -1
          end
        end
      end
      response # 1=true, 0=false, -1=not checkable
    end
  end
end
