
module ROCL
  class Named
    def to_s
      "#<#{self.class.name} #{name.inspect}>"
    end
  end

  class Multiplicity < Named
    include Comparable
    
    MAX = 9999
    def initialize(x = nil)
      x ||= 1
      x = MAX if x == '*'
      @x = x
    end
    
    
    def <=>(x)
      x = MAX if x == '*'
      @x <=> x
    end
    
    
    def name
      to_s
    end
    
    
    def to_s
      (@x >= MAX ? '*' : @x).to_s
    end
    
  end
      

  class System < Named
    attr_accessor :name
    def initialize(name = nil, &blk)
      @context = { }
      if blk
        self.instance_eval &blk
      end
    end

    def context(cls, &blk)
      context = @context[cls] ||= Context.new(cls)
      if blk
        context.instance_eval &blk
      end
      context
    end

    def execute(interp = nil)
      @context.values.each do |cntx|
        cntx.execute(interp)
      end
    end
  end


  class Context < Named
    attr_accessor :name, :inv

    def initialize(cls)
      @cls = cls
      @inv = [ ]
    end

    def inv(name = nil, &blk)
      inv = Invariant.new(@cls, blk, name)
      @inv << inv
      inv
    end

    def execute(interp = nil)
      interp ||= Interpreter::Memory
      interp = interp.new if interp.kind_of?(Class)

      @inv.each do |inv|
        interp.execute_invariant(inv)
      end
    end

  end


  class Invariant < Named
    attr_accessor :cls, :name, :blk, :_, :__, :interp

    def initialize(cls, blk, name = nil)
      @cls = cls
      @name = name
      @blk = blk
    end

    def method_missing(sel, *args, &block)
      @interp.invariant_method_missing(self, sel, args, block)
    end
  end


  module Interpreter
  end

end


require 'rocl/object'
require 'rocl/core_extensions'
