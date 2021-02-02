require "./graken"
require "option_parser"

file_path = ""
server_path = ""
server_port = 0
heartbeat_timer = 0
flatten = false
validate = false
only_valid = false
export = ""
flaval = false
analyze = false
calculate = false
loglevel = 7
levels = [
  Log::Severity::Trace,
  Log::Severity::Debug,
  Log::Severity::Info,
  Log::Severity::Notice,
  Log::Severity::Warn,
  Log::Severity::Error,
  Log::Severity::Fatal,
  Log::Severity::None
]

OptionParser.parse do |parser|
  parser.banner = "Usage: graken [arguments]"
  parser.on "-i PATH", "--input=PATH", "Sets filepath" do |path|
    filepath = path
  end
  parser.on "-p PORT", "--port=PORT", "Listen to port, e.g. 3000" do |port|
    server_port = port.to_i
  end
  parser.on "-t TIMER", "--timer=TIMER", "Heartbeat timer" do |timer|
    heartbeat_timer = timer.to_i
  end
  parser.on "-s PATH", "--socket=PATH", "Listen to UNIXSocket, e.g. /tmp/graken.sock" do |path|
    server_path = path
  end
  parser.on "-f", "--flatten", "Flatten graph" do
    flatten = true
  end
  parser.on "-v", "--validate", "Flatten, then validate graph" do
    validate = true
  end
  parser.on "-o", "--only:valid", "Flatten, then validate graph for only valid edges" do
    only_valid = true
  end
  parser.on "-e PATH", "--export=PATH", "Export to PATH" do |path|
    export = path
  end
  parser.on "-a", "--analyze", "Analyze" do
    analyze = true
  end
  parser.on "-c", "--calculate", "Calculate" do
    calculate = true
  end
  parser.on "-l LEVEL", "--loglevel=LEVEL", "Loglevel" do |level|
    loglevel = level.to_i
  end
  parser.on "-h", "--help", "Show help" do
    puts parser
    print "LEVEL:"
    levels.each_with_index { |v,i| puts "\t#{i}=#{v}" }
    exit
  end
end

Log.define_formatter LogFormat, "#{severity}: #{message}"
logging_backend = Log::IOBackend.new(formatter: LogFormat)
Log.setup(levels[loglevel], logging_backend)

if File.exists? file_path
  file = File.read(file_path)
else
  file = STDIN.gets_to_end
end

graph = Graken::Importer.new(file).import

def print_state(gr)
  puts "Nodes:\t#{gr.nodes.keys.size}\tEdges:\t#{gr.edges.size}\t@#{Time.local}"
end

print_state(graph) if analyze

if calculate
  p graph.calculate
end

if validate || only_valid
  graph.flatten!
  print_state(graph) if analyze
  graph.validate! only_valid
  print_state(graph) if analyze
elsif flatten
  graph.flatten!
  print_state(graph) if analyze
end

unless export.empty?
  puts "Exporting to #{export}"
  exp = Graken::Exporter.new graph
  exp.export_dijkstra export if export.ends_with? ".dijkstra"
  exp.export_file export if export.ends_with? ".graph"
  exp.export_cypher export if export.ends_with? ".cypher"
end

if !server_path.empty? || server_port > 0
  server = Graken::Server.new(graph)
  server.run do |conf|
    conf.bind_unix server_path  unless server_path.empty?
    conf.bind_tcp "0.0.0.0", server_port unless server_port == 0
    puts "starting server"
  end
end

#Graken::Exporter.new(graph).export(output) unless output.empty?
