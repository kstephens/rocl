require 'tree_node_memory'
require 'rocl'
require 'rocl/sql'


##########################################
# Define Model
#

model = ROCL::Object::Model.new(:TreeNode)

tree_node_c = model.add_class(TreeNode)
tree_node_c.add_property(:name, String)
tree_node_c.add_property(:parent, TreeNode)
tree_node_c.add_property(:child, TreeNode, '*')
tree_node_c.add_property(:node_data, NodeData)

node_data_c = model.add_class(NodeData)
node_data_c.add_property(:node_data)
node_data_c.add_property(:contents, String)
node_data_c.add_property(:name, TreeNode, '*')
node_data_c.add_property(:keyword, Keyword, '*')

keyword_c = model.add_class(Keyword)
keyword_c.add_property(:node_data)
keyword_c.add_property(:contents, String, '*')


##########################################
# Define Schema
#

schema = ROCL::SQL::Schema.new(:tree_node)

tree_node_t = schema.add_table(:tree_node)
tree_node_t.add_column(:id).primary = true
tree_node_t.add_column(:type, 'VARCHAR(32)')
tree_node_t.add_column(:name, 'VARCHAR(32)')
tree_node_t.add_column(:parent_id)
tree_node_t.add_column(:node_data_id)

node_data_t = schema.add_table(:node_data)
node_data_t.add_column(:id).primary = true
node_data_t.add_column(:contents, :text)

keyword_t = schema.add_table(:keyword)
keyword_t.add_column(:id).primary = true
keyword_t.add_column(:contents, 'VARCHAR(32)')


##########################################
# Define Model Schema Mapping.
#

tree_node_c.map = tree_node_t
tree_node_c.map_type = tree_node_t[:type] # STI
node_data_c.map = node_data_t
keyword_c.map = keyword_t

tree_node_c[:name].map = :name
tree_node_c[:parent].map = :parent_id
tree_node_c[:child].map = :parent_id
tree_node_c[:node_data].map = :node_data_id

node_data_c[:name].map = tree_node_t[:node_data_id]
node_data_c[:contents].map = :contents

node_data_c[:keyword].map = [ :node_data_keyword ]

keyword_c[:contents].map = :contents
keyword_c[:node_data].map = [ :node_data_keyword ]

puts schema.sql_definition

##########################################
# Generate SQL query.
#

interp = ROCL::Interpreter::SQL.new(model, schema)

tree_node = interp.proxy(TreeNode)
expr = tree_node.parent.name.size > 0

puts interp.sql([ tree_node, tree_node.name, tree_node.parent.name ], [ expr ])


interp = ROCL::Interpreter::SQL.new(model, schema)

node_data = interp.proxy(NodeData)

puts interp.sql([ node_data.name, node_data.keyword.contents ], [ node_data.name.name == "name" ] )


