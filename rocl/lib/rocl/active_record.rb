require 'rocl/sql'

class ROCL::SQL::System

  def interpret_active_record_schema
    ObjectSpace.each_object do |obj|
      next unless obj.kind_of?(::Class)
      if obj.ancestors.include?(ActiveRecord::Base)
        interpret_active_record_class(obj)
      end
    end
  end

  def interpret_active_record_class(cls)
    # Add tables.
    m_cls = model.add_class(cls)

    columns = cls.columns
    columns.each do |col|
      m_col = m_cls.add_column(col.name.intern, col.sql_type)
      if col.primary
        m_col.primary = true
      end
    end

    # Add reflections.
    reflections = cls.reflections
    reflections.each do |k,v|
      puts " reflection r = #{k.inspect} => #{v.inspect}"
    end

    m_cls
  end

end # class
