module Testing
  struct Size
    property nodes, edges
    def initialize(@nodes : Int32, @edges : Int32)
    end
  end

  class Test
    getter :name, :times, :graph, :size, :flat, :valid
    setter :graph
    def initialize(@name : String, @times : Int32, @graph : Graken::Graph, @size : Size, @flat : Size, @valid : Size)
    end
  end

  def self.testset
    [
      Test.new("simple",1,scxml_import("./spec/testmodel/simple.scxml"),Size.new(11,9),Size.new(6,14),Size.new(6,14)),
      Test.new("medium",1,scxml_import("./spec/testmodel/medium.scxml"),Size.new(22,18),Size.new(13,60),Size.new(13,60)),
      Test.new("SD-ES",1,scxml_import("./spec/testmodel/SD-ES.scxml"),Size.new(13,10),Size.new(7,15),Size.new(7,11)),
      Test.new("SD-ES",1,scxml_import("./spec/testmodel/SD-ES-flat.scxml"),Size.new(11,9),Size.new(7,15),Size.new(7,11)),
      Test.new("cell",1,scxml_import("./spec/testmodel/cell.scxml"),Size.new(53,49),Size.new(7,15),Size.new(7,11)),
      Test.new("cell-extended",1,scxml_import("./spec/testmodel/cell-extended.scxml"),Size.new(53,49),Size.new(7,15),Size.new(7,11)),
    ]
  end

  def self.scxml_import(scxml="./spec/testmodel/simple.scxml")
    Graken::Importer.new(File.read(scxml)).import
  end
end
