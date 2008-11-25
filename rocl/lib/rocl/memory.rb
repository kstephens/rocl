
module ROCL
  module Interpreter
    class Memory
      def initialize(objects = nil)
        @objects = objects
      end

      def execute_invariant(inv)
        @failed = [ ]

        if @objects
          @objects.each do |obj|
            next unless @object.kind_of(inv.cls)
            execute_invariant_on_object(inv, obj)
          end
        else
          ObjectSpace.each_object(inv.cls) do |obj| 
            execute_invariant_on_object(inv, obj)
          end
        end
        
        @failed
      end
      
      def execute_invariant_on_object(inv, obj)
        # puts "\n  Testing: #{obj}"
        
        # Bind Invariant bindings to object.
        inv._ = Value.new(obj)
        inv.__ = obj
        
        # Bind Invariant to us.
        inv.interp = self
        
        unless inv.instance_eval(&(inv.blk))
          puts "\nExecuting: inv: #{inv.name}" if @failed.empty?
          puts "  Failed: #{obj.inspect}"
          @failed << obj
        end
        
        inv.interp = nil

        @failed
      end


      def invariant_method_missing(inv, sel, args, blk)
        Value.new(inv._).send(sel, *args, &blk)
      end


      class Escape
        def initialize(val)
          @val = val
        end
        
        def forAll(&block)
          case block.arity
          when 0, -1
            result = @val.all? do |e|
              e.all? do |ee|
                Value.new(ee).instance_eval &block
              end
            end
          when 1
            result = @val.all? do |e|
              e.all? do |ee|
                yield Value.new(ee)
              end
            end
          when 2
            result = @val.all? do |e1|
              e1_ = Value.new(e1)
              @val.all? do |e2|
                e2_ = Value.new(e2)
                yield e1_, e2_
              end
            end
          else
            raise "too many block args: #{block.arity}"
          end

          #puts "  forAll: val=#{@val.inspect} => #{result}\n"
          result = Value.new(result)
          result
        end
        

        def exists(&block)
          # puts "  exists: val=#{@val.inspect}\n"
          
          case block.arity
          when 0, -1
            result = @val.any? do |e|
              e.any do |ee|
                Value.new(ee).instance_eval &block
              end
            end
          when 1
            result = @val.any? do |e|
              e.any? do |ee|
                # puts "  exists: e = #{ee}"
                block.call(Value.new(ee))
              end
            end
          else
            raise "too many block args: #{block.arity}"
          end

          #puts "  exists: val=#{@val.inspect} => #{result}\n"
          result = Value.new(result)
          result
        end
        

        def select(&block)
          case block.arity
          when 0, -1
            result = @val.select do |e|
              Value.new(e).instance_eval &block
            end
          when 1
            result = @val.select do |e|
              block.call(value.new(e))
            end
          else
            raise "too many block args: #{block.arity}"
          end
          
          Value.new(result)
        end
        
        
        def reject(&block)
          case block.arity
          when 0, -1
            result = @val.reject do |e|
              Value.new(e).instance_eval &block
            end
          when 1
            result = @val.reject do |e|
              block.call(Value.new(e))
            end
          else
            raise "too many block args: #{block.arity}"
          end
          
          Value.new(result)
        end
        
        
        def union(*args)
          result = @val.clone
          
          args.each do |a|
            result.push(*(a.__rocl_value))
          end
          
          Value.new(result.unique)
        end
        
        
        def includes(x)
          x = x.__rocl_value.first
          result = @val.all? { |e| e.include?(x) }
          result = Value.new(result)
        end
        
        
        def implies(&block)
          @val.each do |e|
            if e
              # puts "  implies => "
              return false unless yield.true?
            end
          end
          
          result = Value.new(result)
        end
        

        def ==(x)
          @val.all?{|e| e == x}
        end
        def >(x)
          @val.all?{|e| e > x}
        end
        def <(x)
          @val.all?{|e| e < x}
        end
        def >=(x)
          @val.all?{|e| e >= x}
        end
        def <=(x)
          @val.all?{|e| e <= x}
        end

        def true?
          @val.all?{|x| ! ! x}
        end

        def false?
          @val.all?{|x| ! x}
        end
      end
      
      
      class Value
        include Comparable

        def self.new(val)
          val = super unless val.kind_of?(self)
          val
        end
        
        
        def initialize(val)
          val = [ val ] unless val.kind_of?(Enumerable)
          @val = val
        end
        
        
        def <=>(x)
          x = x.__rocl_value
          result = (@val <=> x)

          # puts "   #{@val.inspect} <=> #{x.inspect} => #{result}"
          result
        end

        def ==(x)
          x = x.__rocl_value
          result = (@val == x)

          # puts "   #{@val.inspect} == #{x.inspect} => #{result}"
          result
        end

        def __rocl_value
          @val
        end
        
        def _
          Escape.new(@val)
        end
        
        
        def to_s
          @val.collect{|x| x.to_s}.join(', ')
        end
        
        def inspect
          "<#{self.class.name} @val.collect{|x| x.inspect}, join(', ')}>"
        end
        
        def method_missing(sel, *args, &block)
          self.class.new(@val.collect{|x| x.send(sel, *args, &block)})
        end
      end
    end
  end

end


