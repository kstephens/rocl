require 'tree_node_mixin'


class TreeNode < ActiveRecord::Base
  include ROCL::Test::TreeNode

  def add(*args)
    child << *args
  end
  alias :<< :add
 
  def remove(*args)
    child.remove(*args)
  end

  def get_child(name)
    child.select{|x| x.name == name }.first
  end
end


class NodeData
  include ROCL::Test::NodeData

  def add_name(x)
    unless self.name.include?(x)
      self.name << x
    end
    x
  end


  def remove_name(x)
    self.name.remove!(x)
  end
end


class Keyword
  include ROCL::Test::Keyword

  def add_node_data(x)
    unless self.node_data.include?(x)
      self.node_data << x
    end

    x
  end

  def remove_node_data(x)
    self.node_data.remove!(x)
  end

end
  
