class CreatePopos < ActiveRecord::Migration
  def self.up
    create_table :papas do |t|
      t.string :name
      t.integer :entity_id

      t.timestamps
    end
  end

  def self.down
    drop_table :papas
  end
end
