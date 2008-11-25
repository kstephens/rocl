
module ROCL
  module SQL

    # Represents a system of classes and associations
    # mapped to tables in a SQL/table oriented database.
    class System
      attr_accessor :name, :model, :schema       
      def initialize(name = nil, model = nil, schema = nil)
        name = self
        model ||= Model.new(name)
        schema ||= Schema.new(name)
        @model, @schema = model, schema
      end

    end


    ############################################
    # Relational model.
    #

    # Represents a SQL type.
    class Type < Named
      attr_accessor :name, :cls, :sql
      def initialize(name, type, sql)
        @name, @cls, @sql = name, type, sql
      end
    end


    # Represents tables and relationships between them.
    class Schema < Named
      attr_accessor :name, :table, :relation, :type
      
      def initialize(name = nil)
        @name = name
        @table = [ ]
        @relation = [ ]
        @type = [ ]

        init_types
      end
      
      def add_type(name, cls, sql)
        type << ::ROCL::SQL::Type.new(name, cls, sql)
      end

      def init_types
        add_type(:integer, Integer, 'INTEGER')
        add_type(:float,   Float,   'FLOAT')
        add_type(:text,    String,  'TEXT')
        add_type(:string,  String,  'VARCHAR(255)')
        add_type(:boolean, TrueClass, 'TINYINY(1)')
        add_type(:boolean, FalseClass, 'TINYINY(1)')
      end


      def get_sql_type(x)
        result = type.select{|t| t.name == x}.first
        result ||= type.select{|t| t.cls == x}.first
        result ||= get_sql_type(:integer) if x.kind_of?(::Class)
        result = result && result.sql
        result ||= x
        # puts "  get_sql_type(#{x.inspect}) => #{result.inspect}"
        result
      end


      def add_table(table)
        table = Table.new(table) unless table.kind_of?(Table)
        @table << table
        table.schema = self
        table
      end
      
      def get_table(name, or_create = false)
        name = name.name if name.kind_of?(Named)
        x = @table.select{|c| c.name == name}.first
        x ||= add_table(name) if or_create
        x
      end

      def add_relation(relation)
        @relation << relation
        relation.schema = self
        relation
      end
      
      def sql_definition
        out = ''
        out += table.collect{|t| t.sql_definition}.join("\n\n")
        out
      end
      
      
      class Table < Named
        attr_accessor :name, :schema, :column, :primary
        
        def initialize(name, schema = nil)
          @name, @schema = name, schema
          @column = [ ]
        end
        
        def add_column(col, type = nil)
          col = Column.new(col, type) unless col.kind_of?(Column)
          
          @primary = col if col.primary
          @column << col
          col.table = self
          col
        end
        alias :<< :add_column
        
        def get_column(name, type = nil)
          name = name.name if name.kind_of?(Named)
          x = @column.select{|c| c.name == name}.first
          x ||= add_column(name, type) if type
          x
        end
        alias :[] :get_column

        def alias
          @name
        end
        
        def sql_from(fmt = '%s')
          fmd % @name
        end
        
        def sql_definition
          out = ''
          out += "CREATE TABLE #{@name} (\n  "
          out += column.collect{|c| c.sql_definition}.join(",\n  ")
          out += "\n);"
          out
        end
        
      end
      
    
      class Column < Named
        attr_accessor :name, :type, :default, :primary, :table
        
        def initialize(name, type = :integer)
          @name, @type = name, type
          @type ||= :integer
          @relation = [ ]
        end
        
        def primary=(x)
          @table.primary = x ? self : nil if @table
          self
        end
        
        def bind(table)
          c = self.clone
          c.table = table
          c
        end
        
        def __sql_expr
          "#{@table.alias}.#{@name}"
        end
        
        def sql_type
          table.schema.get_sql_type(type)
        end

        def sql_definition
          "#{name} #{sql_type} #{default && (" DEFAULT " + default.to_s)}"
        end
        
      end
      
      
      class Relation
        attr_accessor :c1, :c2, :schema
        
        def initialize(c1, c2)
          @c1, @c2 = c1, c2      
        end
        
        
        def __sql_expr
          "#{@c1.__sql_expr} = #{@c2.__sql_expr}"
        end
      end

    end # class Schema
  end # module SQL


  module Interpreter
    # Represents a SQL interpreter of ROCL expressions.
    # Can be used to generate a SQL SELECT statement.
    class SQL
      attr_accessor :model, :schema, :select

      def initialize(model, schema)
        @model, @schema = model, schema
        @select = Select.new(self)
        @table_binding = [ ]
        @table_alias_index = 0
      end

      def clone
        super.deepen
      end

      def deepen
        @select = @select.clone
        @select.interp = self
        self
      end

      def proxy(cls)
        cls = model.get_class(cls) if cls.kind_of?(::Class)
        Class.new(self, cls)
      end
      

      def table_bind(table)
        return nil unless table
        tb = TableBinding.new(table, @table_alias_index += 1)
        @table_binding << tb
        @select.add_from tb
        tb
      end


      def expr(x, *args)
        Expr.new(self, x, *args)
      end


      def expr_cast(x, *args)
        x = expr(x, *args) unless x.kind_of?(ExprBase)
        x
      end

      
      def expr_sql(x)
        @select.expr_sql(x)
      end


      def sql(expr, where = nil)
        @select.sql(expr, where)
      end

      def _?(name = nil)
        @select.arg(name)
      end



      class Select
        def initialize(*args)
          @expr = [ ]
          @from = [ ]
          @where = [ ]
          @inner_join = [ ]
          @outer_join = [ ]
          @arg = { }
          @arg_id = 0
        end
 
        def clone
          super.deepen
        end

        def deepen
          @expr = @expr.clone
          @from = @from.clone
          @where = @where.clone
          @inner_join = @inner_join.clone
          @outer_join = @outer_join.clone
          @arg = { }
          self
        end

        def add_expr(x, *args)
          x = Expr.new(x, *args) unless x.respond_to?(:__sql_expr)
          @expr << x
        end
        
        def add_from(x)
          @from << x
        end
        
        def add_where(x)
          @where << x
        end

        def add_inner_join(c1, c2)
          @inner_join << [ c1, c2 ]
        end

        def add_outer_join(c1, c2)
          @outer_join << [ c1, c2 ]
        end

        def arg(name = nil)
          name ||= "_#{@arg_id + 1}"
          name = name.to_s.intern unless name.kind_of?(Symbol)
          @arg[name] ||= Arg.new(name, @arg_id += 1)
        end

        def expr_sql(x)
          case x
          when String
            # FIXME
            x = "\"#{x}\""
          else
            x = x.__sql_expr if x.respond_to?(:__sql_expr)
          end

          x
        end

        def expr_str(x)
          case x
          when false, true, nil
            x.inspect
          else
            x.inspect
          end
        end


        def sql(expr = nil, where = nil)
          expr ||= @expr

          where = where ? where.clone : [ ]
          where.push(*@where)
          where = where.collect{|x| "#{expr_sql(x)}"}

          inner_join = @inner_join.collect{|x| "(#{expr_sql(x[0])} = #{expr_sql(x[1])})"}
          inner_join[0] = "-- inner joins\n  " + inner_join[0] if inner_join[0]
          where.push(*inner_join)

          if where.empty?
            where = ''
          else
            where = "WHERE\n  " + where.join(" AND \n  ")
          end

          # puts "expr = #{expr.inspect}"

          "SELECT 
  #{expr.collect{|x| expr_sql(x) + '  -- ' + expr_str(x)}.join("\n  ,")} 
FROM 
  #{@from.collect{|x| x.sql_from('%-20s')}.join(",\n  ")} 
#{where};\n\n"
        end

        class Arg < Named
          attr_accessor :name, :index
          
          def initialize(name, index)
            @name, @index = name, index
          end
          
          def __sql_expr
            " ?#{@name.inspect} "
          end
        end
      end # class
      



      # Maps concrete table names to unique table aliases.
      class TableBinding < Named
        @@alias_index = 0
        
        attr_accessor :table, :alias

        def initialize(table, index = nil)
          @table = table
          index ||= (@@alias_index += 1)
          @alias = 't' + index.to_s
          @col = { }
        end

        # Return SQL for the SELECT FROM clause.
        def sql_from(fmt = '%s')
          "#{fmt % @table.name} AS #{@alias}"
        end
        
        def name
          sql_from
        end

        # Returns a Column bound to this TableBinding.
        def bind(col)
          @col[col] ||= col.bind(self)
        end

        # Return the primary Column bound to this TableBinding.
        def primary
          @primary ||= bind(@table.primary)
        end

      end
      

      # Base class for expressions.
      class ExprBase
        def initialize(interp, *args)
          @interp = interp
          @expr = { }
        end

        def __sql_interp
          @interp
        end

        def self.binop(rop, sop = nil, type = :boolean)
          sop ||= rop
          class_eval <<"__end__", __FILE__, __LINE__
def #{rop.to_s}(x)
  @interp.expr("(\#{self.__sql_expr} #{sop.to_s} \#{@interp.expr_sql(x)})", #{type.inspect})
end
__end__
        end

        binop :&, :AND
        binop :|, :OR
        binop :==, '='
        binop :ne, '<>'
        binop :<
        binop :>
        binop :<=
        binop :>=

        def not
          @interp.expr("NOT #{self.__sql_expr})", :boolean)
        end
        
        def size
          @interp.expr("LENGTH(#{self.__sql_expr})", :integer)
        end

        def count
          @interp.expr("COUNT(#{self.__sql_expr})", :integer)
        end

        def empty?
          size == 0
        end

        def nil?
          @interp.expr("(#{self.__sql_expr} IS NULL)", :boolean)
        end

        def _
          Escape.new(self)
        end

        def _?(name = nil)
          @interp.select.arg(name)
        end

        def method_missing(sel, *args, &blk)
          result = nil

          if args.empty?
            return result if result = @expr[sel]

            if @cls && @table && prop = @cls.get_property(sel)
              if  (target_cls = @interp.model.get_class(prop.type)) &&
                  (target_table = target_cls.map)
                
                target_table = @interp.table_bind(target_table)
                prop_map = prop.map

                if prop_map.kind_of?(::ROCL::SQL::Schema::Relation)
                  # From source PK
                  src_col = @table.primary

                  # Join table.
                  raise "Relation cannot span tables." if prop_map.c1.table != prop_map.c2.table
                  join_table = @interp.table_bind(prop_map.c1.table)

                  # To source c1
                  c1_col = join_table.bind(prop_map.c1)

                  # To source K2
                  c2_col = join_table.bind(prop_map.c2)

                  # To target PK
                  dst_col = target_table.primary

                  # Add join through interstital_table
                  @interp.select.add_inner_join(src_col, c1_col)
                  @interp.select.add_inner_join(c2_col, dst_col)

                  result = @interp.expr(dst_col, prop.type, target_table)
                else
                  if prop.multi <= 1
                    # From source FK.
                    src_col = @table.bind(prop_map)
                    
                    # To target PK.
                    dst_col = target_table.primary
                    
                  else
                    # From source PK.
                    src_col = @table.primary
                    
                    # To target FK.
                    dst_col = target_table.bind(prop_map)
                  end
                  
                  # Add join.
                  @interp.select.add_inner_join(src_col, dst_col)
                  
                  # Create new expression.
                  result = @interp.expr(dst_col, prop.type, target_table)
                end
=begin

                puts "  sel => #{sel.inspect}"
                puts "  prop => #{prop.name} : #{prop.type} #{prop.multi} #{prop.multi > 1}"
                puts "  target_cls => #{target_cls}"
                puts "  target_table => #{target_table}"

                puts "  src_col => #{src_col}"
                puts "  dst_col => #{dst_col}"

=end

              else
                # Plain expression.
                column = prop.map.bind(@table)
                
                result = @interp.expr(column, column.type)
              end
            else
              raise NameError, sel.to_s      
            end

            @expr[sel] = result
          else
            raise NameError, sel.to_s
          end
          
          result
        end

      end # class


      class Expr < ExprBase
        def initialize(interp, x, type = nil, table = nil)
          super
          x = x.__sql_expr if x.respond_to?(:__sql_expr)
          @x = x
          @type = type || :any
          @cls = @type && @interp.model.get_class(@type)
          @table = table || (@cls && @interp.table_bind(@cls.map))
        end
        
        def __sql_expr
          @x.to_s
        end
      end
      
      
      class Class < ExprBase
        def initialize(interp, cls)
          super
          @cls = cls
          @table = @interp.table_bind(@cls.map)
        end
        
        def __sql_expr
          @table.primary.__sql_expr
        end

      end # class
      
     end

    class Escape
      def initialize(expr)
        @expr = expr
      end

      def forAll(&block)
        interp = @expr.__sql_interp
        count = interp.sql([ @expr.count ], [ @expr ])
        count = "(#{count})"
        
      end

    end
    
  end
end



class ROCL::Object::Model::Class
  def map=(x)
    @map = x
  end

  def map_type=(x)
    @map_type = x
  end
end

class ROCL::Object::Model::Property
  def map=(column_or_relation)
    result = column_or_relation
    
    if result.kind_of?(::Enumerable)
      table, c1, c2 = *result
      if table && table.kind_of?(Symbol)
        table = cls.map ? cls.map.schema.get_table(table, :or_create) : table

        # Infer column names based on target class table names.
        unless c1 
          c1 = "#{cls.map.name}_id".intern
        end
        if ! c2 && (type_cls = cls.model.get_class(type))
          # puts "type_cls = #{type_cls.inspect}"
          c2 = "#{type_cls.map.name}_id".intern
        end
        # puts "table = #{table}, c1 = #{c1}, c2 = #{c2}, type = #{type}"

        c1 = table.get_column(c1, :integer)
        c2 = table.get_column(c2, :integer)
      else
        c1, c2 = *result
      end
      
      result = ::ROCL::SQL::Schema::Relation.new(c1, c2)
      cls.map && cls.map.schema.add_relation(result)
    else
      result = cls.map && cls.map.get_column(result) unless result.kind_of?(::ROCL::SQL::Schema::Column)
    end
    
    @map = result
  end
end

