require "log"
require "../src/graken"
require "../spec/testing"
require "benchmark"

testset = Testing.testset
logging_backend = Log::IOBackend.new
Log.setup(:none, logging_backend)

testset.each_with_index do |test,i|
  puts "\n==========================\n"
  puts "Starting Test: #{test.name}"
  log = {} of String => String
  log["#{test.name}-initial"] = "#{test.graph.nodes.keys.size}\tnodes\t#{test.graph.edges.size}\tedges"
  Benchmark.bm do |x|
    x.report("flatten:") {
      test.graph.flatten!
      log["#{test.name}-flatten"] = "#{test.graph.nodes.keys.size}\tnodes\t#{test.graph.edges.size}\tedges"
    }
    x.report("validate:") {
      test.graph.validate!
      log["#{test.name}-validate"] = "#{test.graph.nodes.keys.size}\tnodes\t#{test.graph.edges.size}\tedges"
    }
  end
  log.each { |k,v| puts "#{k}\t#{v}" }
end
