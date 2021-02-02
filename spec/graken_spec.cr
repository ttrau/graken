require "spec"
require "../src/graken"
require "./testing"

describe Graken do
  Testing.testset.each_with_index do |test,i|
    it "import Testset ##{i}: #{test.name}", tags: "fast" do
        test.graph.should_not be_nil
        test.graph.nodes.size.should eq(test.size.nodes)
        test.graph.edges.size.should eq(test.size.edges)
    end
  end

  Testing.testset.each_with_index do |test,i|
    it "calculate Testset ##{i}: #{test.name}", tags: "fast" do
      calc = test.graph.calculate
      calc[0].should eq(test.flat.nodes)
      calc[1].should eq(test.flat.edges)
    end
  end

  Testing.testset.each_with_index do |test,i|
    it "flatten! Testset ##{i}: #{test.name}", tags: "fast" do
      test.graph.flatten!
      test.graph.should_not be_nil
      test.graph.nodes.size.should eq(test.flat.nodes)
      test.graph.edges.size.should eq(test.flat.edges)
    end
  end

  Testing.testset.each_with_index do |test,i|
    it "validate! Testset ##{i}: #{test.name}", tags: "fast" do
      test.graph.flatten!
      test.graph.validate!
      test.graph.should_not be_nil
      test.graph.nodes.size.should eq(test.valid.nodes)
      test.graph.edges.size.should eq(test.valid.edges)
    end
  end
end
