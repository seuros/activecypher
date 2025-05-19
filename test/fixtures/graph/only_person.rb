# frozen_string_literal: true

node :lucy,  PersonNode,  name: 'Lucy', age: 29
node :mike,  PersonNode,  name: 'Mike', age: 34
relationship :friends, :lucy, :FRIENDS_WITH, :mike, since: 2020
