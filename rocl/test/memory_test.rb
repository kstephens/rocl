require 'tree_node_memory'
require 'rocl'
require 'rocl/memory'

#####################################
# Create a Tree.
#

root = TreeNode.new('ROOT')
root.add(:usr, :bin, :etc, :home)
root.usr.add(:bin)
root.home.add(:kurt, :bruce)

data = NodeData.new("YooHoo")
# data_nil = NodeData.new(nil)

#####################################
# Define invariants
#

system = ROCL::System.new() {
  context(TreeNode) {
    inv("A Node's children must have the Node as parent.") {
      # ._. escapes out from object syntax to ROCL syntax.
      # _ stands for the current object of the context.
      child._.forAll{|c| c.parent == _ }
    }
    
    inv("A Node must be its parent's child.") {
      parent._.implies {
        parent.child._.exists{ |n| n == _ }
      }
    }
    
    inv("A Node cannot be its own descendent.") { 
      all_children._.includes(_).false?
    }
    
    inv("A Node cannot have the same name as a sibling.") {
      parent._.implies { 
        parent.child._.exists{ |n| n != _ and n.name == _.name }.false?
      }
    }

    inv("A Node must have NodeData") {
      node_data._.true?
    }
  }

  context(NodeData) {
    inv("A NodeData's content cannot be nil") {
      content._.true?
    }

    inv("A NodeData must be used by at least one TreeNode.") {
      _.name.size._ > 0
    }
  }
}


puts "\n################################################"
puts "Check invariant:"

root.print
system.execute

puts "\n################################################"
puts "Break invariant:"
puts "Create child with no parent."

x = root.add(:foo)
x.parent = nil
root.print

system.execute

root.remove(x) # cleanup

puts "\n################################################"
puts "Break invariant:"
puts "Add another /home/bruce."

x = root.home.bruce.parent.add(:bruce)
root.print

system.execute

x.parent.remove(x) # cleanup

puts "\n################################################"
puts "Break invariant:"
puts "Put root under one of its own children"

root.home.bruce.add(root)
root.print

system.execute

root.home.parent.remove(x) # cleanup


#####################################
