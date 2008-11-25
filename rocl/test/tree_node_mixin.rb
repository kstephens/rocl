module ROCL
  module Test
  end
end


module ROCL::Test::TreeNode
  def get_child(name)
    @child.select{|x| x.name == name }.first
  end


  def print(indent = '', visited = [ ])
    puts "#{'%-15s' % (indent + name.to_s) } #{'%-20s' % path_name} parent: #{parent && parent.path_name}"

    if visited.include?(self)
      return
    end
    visited << self

    i = indent + '  '
    child.each{ |x| x.print(i, visited) }
  end


  def all_children
    x = [ ]
    visited = [ ]

    stack = child.clone
    until stack.empty?
      n = stack.pop

      next if visited.include?(n)
      visited << n

      x << n
      stack.push(*(n.child))
    end

    x
  end
  

  def path
    x = [ ]
    visited = [ ]

    p = self
    while p
      if visited.include?(p)
        x.unshift("<LOOP>")
        break
      end
      visited << p

      x.unshift(p.name)
      p = p.parent
    end

    x
  end


  def path_name
    path.join('/')
  end


  def inspect
    "#<#{self.class.name} #{object_id} #{path_name}>"
  end


  def to_s
    "<#{self.class.name} #{path_name}> "
  end


  def method_missing(sel, *args, &blk)
    return get_child(sel) if args.empty?
    super
  end
end



module ROCL::Test::NodeData
  def inspect
    "#<#{self.class.name} #{object_id} #{content.inspect}>"
  end


  def to_s
    "<#{self.class.name} #{content.inspect}> "
  end
end


module ROCL::Test::Keyword
end
