module ROCL
  module Object

    ############################################
    # Object model.
    #
    
    class Model < Named
      attr_accessor :name, :cls
      def initialize(name = nil)
        @name = name
        @cls = [ ]
      end
      
      def add_class(cls)
        cls = Class.new(cls) unless cls.kind_of?(::ROCL::Object::Model::Class)
        @cls << cls
        cls.model = self
        cls
      end
      
      def get_class(cls)
        x = @cls.select{|c| c.cls == cls}.first
        x
      end
      
      
      class Class < Named
        attr_accessor :cls, :model, :property, :map
        def initialize(cls, model = nil)
          @cls, @model = cls, model
          @property = [ ]
        end
        
        def add_property(prop, type = nil, multi = nil)
          prop = Property.new(prop, type, multi) unless prop.kind_of?(Property)
          @property << prop
          prop.cls = self
          prop
        end
        
        def get_property(name)
          x = @property.select{|x| x.name == name}.first
          x
        end
        alias :[] :get_property

        def name
          @cls.name
        end
      end
      
      
      class Property < Named
        attr_accessor :name, :type, :multi, :cls, :map
        def initialize(name, type = Object, multi = 1, cls = nil)
          multi = ::ROCL::Multiplicity.new(multi)
          @name, @type, @multi, @cls = name, type, multi, cls
        end
      end
      
      
      class Association < Named
        attr_accessor :name, :connection
        def initialize(name, *args)
          @name = name
          @connection = [ ]
        end

        def add_connection(x)
          @connection << x
          x.association = self
          x
        end
      end


      class AssociationEnd < Named
        attr_accessor :name, :participant, :association
        def initialize(particpant)
          @participant = particpant
          @participant.add_association(self)
        end
      end
    end
    
  end # module
end # module
