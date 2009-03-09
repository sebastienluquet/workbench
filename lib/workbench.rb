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
    classes.sort{ |x,y| x.class_name <=> y.class_name }.each do |c|
      c.reflect_on_all_associations(:has_many).delete_if{|e|e.options[:through] or e.options[:finder_sql] or e.class_name.constantize.superclass != ActiveRecord::Base or !classes.include? e.klass}.sort{ |x,y| x.name.to_s <=> y.name.to_s }.each{|a|
        if a.name != :versions
          if c.superclass != ActiveRecord::Base and c.superclass.reflect_on_association(a.name)

          else
            if a.klass.columns_hash[a.primary_key_name]
              sql << "
              ALTER TABLE `#{database}`.`#{a.class_name.constantize.table_name}`
                ADD CONSTRAINT `#{('fk_' + c.name.to_s + '_has_many_' + a.name.to_s).first(64)}`
                FOREIGN KEY (`#{a.primary_key_name}` )
                REFERENCES `#{database}`.`#{c.table_name}` (`#{c.primary_key}` )
                ON DELETE NO ACTION
                ON UPDATE NO ACTION
              , ADD INDEX `#{('fk_' + c.name.to_s + '_has_many_' + a.name.to_s).first(64)}` (`#{a.primary_key_name}` ASC) ;"
            end
          end
        else
          sql << "DROP TABLE #{c.table_name.singularize}_versions;"
        end
      }
      c.reflect_on_all_associations(:has_one).delete_if{|e|e.options[:through] or e.options[:finder_sql] or e.class_name.constantize.superclass != ActiveRecord::Base or !classes.include? e.klass}.sort{ |x,y| x.name.to_s <=> y.name.to_s }.each{|a|
        if a.name != :versions
          if a.klass.columns_hash[a.primary_key_name]
            sql << "
            ALTER TABLE `#{database}`.`#{a.class_name.constantize.table_name}`
              ADD CONSTRAINT `#{('fk_' + c.name.to_s + '_has_one_' + a.name.to_s).first(64)}`
              FOREIGN KEY (`#{a.primary_key_name}` )
              REFERENCES `#{database}`.`#{c.table_name}` (`#{c.primary_key}` )
              ON DELETE NO ACTION
              ON UPDATE NO ACTION
            , ADD INDEX `#{('fk_' + c.name.to_s + '_has_one_' + a.name.to_s).first(64)}` (`#{a.primary_key_name}` ASC) ;"
          end
        else
          sql << "DROP TABLE #{c.table_name.singularize}_versions;"
        end
      }
      c.reflect_on_all_associations(:belongs_to).delete_if{|e|e.options[:through] or e.options[:finder_sql] or e.options[:polymorphic] or e.class_name.constantize.superclass != ActiveRecord::Base or !classes.include? e.klass}.sort{ |x,y| x.name.to_s <=> y.name.to_s }.each{|a|
        unless a.class_name.constantize.reflect_on_all_associations(:has_many).detect{|b| b.class_name.constantize == c} or a.class_name.constantize.reflect_on_all_associations(:has_one).detect{|b| b.class_name.constantize == c}
          if c.superclass != ActiveRecord::Base and c.superclass.reflect_on_association(a.name)
            
          else
            if c.columns_hash[a.primary_key_name.to_s]
              sql << "
              ALTER TABLE `#{database}`.`#{c.table_name}`
                ADD CONSTRAINT `#{('fk_' + c.name.to_s + '_belongs_to_' + a.name.to_s).first(64)}`
                FOREIGN KEY (`#{a.primary_key_name}` )
                REFERENCES `#{database}`.`#{a.class_name.constantize.table_name}` (`#{a.class_name.constantize.primary_key}` )
                ON DELETE NO ACTION
                ON UPDATE NO ACTION
              , ADD INDEX `#{('fk_' + c.name.to_s + '_belongs_to_' + a.name.to_s).first(64)}` (`#{a.primary_key_name}` ASC) ;"
            end
          end
        end
      }
      c.reflect_on_all_associations(:has_and_belongs_to_many).delete_if{|e| e.class_name.constantize.superclass != ActiveRecord::Base or !classes.include? e.klass}.sort{ |x,y| x.name.to_s <=> y.name.to_s }.each{|a|
        if c.superclass == ActiveRecord::Base
          constraint_name = ('fk_' + c.name.to_s + '_habtm_' + a.name.to_s).first(64)
          sql << "
          ALTER TABLE `#{database}`.`#{a.options[:join_table]}`
            ADD CONSTRAINT `#{constraint_name}`
            FOREIGN KEY (`#{c.table_name.singularize}_id` )
            REFERENCES `#{database}`.`#{c.table_name}` (`#{c.primary_key}` )
            ON DELETE NO ACTION
            ON UPDATE NO ACTION
          , ADD INDEX `#{constraint_name}` (`#{a.primary_key_name}` ASC) ;"
        end
      }
    end
    sql << "DROP TABLE schema_migrations;"
    sql << "SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;"
    File.open("add_#{database}_constraint.sql", 'w') do |f|
      f.puts sql
    end
  end
end
