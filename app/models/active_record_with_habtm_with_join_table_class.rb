class ActiveRecordWithHabtmWithJoinTableClass < ActiveRecordBaseClass
  has_and_belongs_to_many :habtms, :join_table => 'foo'
end
