require 'tree_node_mixin'


class TreeNode
  include ROCL::Test::TreeNode

  attr_accessor :name, :parent, :child, :node_data

  def initialize(name)
    @name = name
    @parent = nil
    @child = [ ]
    @inode = nil
  end


  def node_data=(x)
    @node_data.remove_name(self) if @node_data
    @node_data = x
    x.add_name(self) if x
  end


  def add(*args)
    args = args.collect{ |x| x.kind_of?(self.class) ? x : self.class.new(x) }
    @child.push *args
    args.each{|c| c.parent = self }
    args.size == 1 ? args.first : args
  end
  alias :<< :add
 
  def remove(*args)
    args = args.collect{ |x| x.kind_of?(self.class) ? x : self.get_child(x) }
 
    args.each do |c| 
      @child.reject! { |x| x == c }
      c.parent = nil
    end

    args
  end
end


class NodeData
  include ROCL::Test::NodeData
  
  attr_accessor :content, :name

  def initialize(content)
    @content = content
    @name = [ ]
  end


  def add_name(x)
    unless @name.include?(x)
      @name << x
      x.inode = self
    end
    x
  end


  def remove_name(x)
    @name.remove!(x)
    x.inode = nil if x
  end
end


class Keyword
  include ROCL::Test::Keyword

  attr_accessor :content, :node_data

  def initialize(content)
    @content = content
    @node_data = [ ]
  end

  def add_node_data(x)
    unless @node_data.include?(x)
      @node_data << x
      x.remove_keyword(self)
    end
    x
  end

  def remove_node_data(x)
    @node_data.remove!(x)
    x.remove_keyword(self) if x
  end
end
  
