module Workbench
  attr_accessor :database
  def active_record_models
    Dir.glob(File.join(RAILS_ROOT,'app','models','**','*.rb')).each do |file|
      require_dependency file
    end
    classes = ActiveRecord::Base.send(:subclasses)
    classes = classes.map{|c|c if c.table_exists? and !c.table_name['version']}.compact
  end
  def generate_fk
    sql = "SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';"
    classes = active_record_models
    classes.each do |c|
      c.reflect_on_all_associations(:has_many).delete_if{|e|e.options[:through] or e.options[:finder_sql] or e.class_name.constantize.superclass != ActiveRecord::Base or !classes.include? e.klass}.each{|a|
        if a.name != :versions
          sql << "
          ALTER TABLE `#{database}`.`#{a.class_name.constantize.table_name}`
            ADD CONSTRAINT `fk_#{c.name}_has_many_#{a.name}`
            FOREIGN KEY (`#{a.primary_key_name}` )
            REFERENCES `#{database}`.`#{c.table_name}` (`#{c.primary_key}` )
            ON DELETE NO ACTION
            ON UPDATE NO ACTION
          , ADD INDEX `fk_#{c.name}_has_many_#{a.name}` (`#{a.primary_key_name}` ASC) ;"
        else
          sql << "DROP TABLE #{c.table_name.singularize}_versions;"
        end
      }
      c.reflect_on_all_associations(:has_one).delete_if{|e|e.options[:through] or e.options[:finder_sql] or e.class_name.constantize.superclass != ActiveRecord::Base or !classes.include? e.klass}.each{|a|
        if a.name != :versions
          sql << "
          ALTER TABLE `#{database}`.`#{a.class_name.constantize.table_name}`
            ADD CONSTRAINT `fk_#{c.name}_has_one_#{a.name}`
            FOREIGN KEY (`#{a.primary_key_name}` )
            REFERENCES `#{database}`.`#{c.table_name}` (`#{c.primary_key}` )
            ON DELETE NO ACTION
            ON UPDATE NO ACTION
          , ADD INDEX `fk_#{c.name}_has_one_#{a.name}` (`#{a.primary_key_name}` ASC) ;"
        else
          sql << "DROP TABLE #{c.table_name.singularize}_versions;"
        end
      }
      c.reflect_on_all_associations(:belongs_to).delete_if{|e|e.options[:through] or e.options[:finder_sql] or e.options[:polymorphic] or e.class_name.constantize.superclass != ActiveRecord::Base or !classes.include? e.klass}.each{|a|
        unless a.class_name.constantize.reflect_on_all_associations(:has_many).detect{|b| b.class_name.constantize == c} or a.class_name.constantize.reflect_on_all_associations(:has_one).detect{|b| b.class_name.constantize == c}
          if c.columns_hash[a.primary_key_name.to_s]
            sql << "
            ALTER TABLE `#{database}`.`#{c.table_name}`
              ADD CONSTRAINT `fk_#{c.name}_belongs_to_#{a.name}`
              FOREIGN KEY (`#{a.primary_key_name}` )
              REFERENCES `#{database}`.`#{a.class_name.constantize.table_name}` (`#{a.class_name.constantize.primary_key}` )
              ON DELETE NO ACTION
              ON UPDATE NO ACTION
            , ADD INDEX `fk_#{c.name}_belongs_to_#{a.name}` (`#{a.primary_key_name}` ASC) ;"
          end
        end
      }
    end
    sql << "SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;"
    File.open("add_#{database}_constraint.sql", 'w') do |f|
      f.puts sql
    end
  end
end
