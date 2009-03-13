require 'ruby2ruby'

module ToFile
  include Workbench
  def class_method(meth)
    proc = method(meth)
    (c = Class.new).class_eval { define_method :proc, proc }
    Ruby2Ruby.new.indent(Ruby2Ruby.translate(c, :proc)).gsub('def proc', "def self.#{meth}")
  end
  def instance_method(meth)
    Ruby2Ruby.new.indent(Ruby2Ruby.translate(self, meth))
  end
  def to_file
  file = File.open(RAILS_ROOT+'/app/models/'+self.to_s.underscore+'.rb','w')
  f = ""
  def f.puts args
    self << "#{args}\n"
  end
  f.puts "class " + self.name + ' < ' + self.superclass.to_s
  f.puts "  set_table_name '#{self.table_name}'" if self.singleton_methods(false).include? 'table_name'
  f.puts "  set_inheritance_column '#{self.inheritance_column}'" if self.singleton_methods(false).include? 'inheritance_column'
  f.puts "  set_primary_key '#{self.primary_key}'" if self.singleton_methods(false).include? 'primary_key'
  self.reflect_on_all_associations.sort{ |x,y| [x.macro.to_s, x.name.to_s] <=> [y.macro.to_s, y.name.to_s] }.each do |e|
    options = []
    options << (e.class_name == e.send(:derive_class_name) ? nil : ":class_name => '"+e.class_name+"'")
    options << (e.primary_key_name == e.send(:derive_primary_key_name) ? nil : (e.options[:foreign_key] ? ":foreign_key => :"+e.options[:foreign_key].to_s : nil ))
    options << ( e.options[:conditions] ? ":conditions => \"#{e.options[:conditions]}\"" : nil )
    options << ( e.options[:dependent] ? ":dependent => :#{e.options[:dependent]}" : nil )
    options << ( e.options[:finder_sql] ? "\n    :finder_sql => '#{e.options[:finder_sql]}'" : nil )
    options << ( e.options[:polymorphic] ? ":polymorphic => true" : nil )
    options << ( e.options[:through] ? ":through => :#{e.options[:through]}" : nil )
    if e.active_record == self
      options = options.compact.join(', ')
      options = ", " + options unless options.blank?
      f.puts "  " + e.macro.to_s + " :" + e.name.to_s + options
    end
  end
  self.reflect_on_all_validations.sort{ |x,y| [x.macro.to_s, x.name.to_s] <=> [y.macro.to_s, y.name.to_s] }.each do |e|
    options = []
    options << ( e.options[:only_integer] ? ":only_integer => #{e.options[:only_integer]}" : nil )
    options << ( e.options[:message] ? ":message => \"#{e.options[:message]}\"" : nil )
    options << ( e.options[:scope] ? ":scope => :#{e.options[:scope]}" : nil )
    if e.active_record == self
      options = options.compact.join(', ')
      options = ", " + options unless options.blank?
      f.puts "  " + e.macro.to_s + " :" + e.name.to_s + options
    end
  end

  eval f.gsub("class #{self.name}", "class Temp") + ";end"

  (singleton_methods(false) - Temp.singleton_methods(false) ).sort.each do |meth|
    f.puts class_method(meth)
  end

  (public_instance_methods(false) - Temp.public_instance_methods(false)).sort.each do |meth|
    f.puts instance_method(meth)
  end

  f.puts "end"
  file.puts f
  file.close
  end
  def metamodel
    f = File.open(RAILS_ROOT+'/anelis_metamodel.rb','w')
    f.puts "require 'rgen/metamodel_builder'"
    f.puts "module AnelisMetamodel"
	  f.puts "  extend RGen::MetamodelBuilder::ModuleExtension"
    classes = active_record_models
    classes.each do |c|
      f.puts "  class " + c.name + ' < ' + (c.superclass == ActiveRecord::Base ? 'RGen::MetamodelBuilder::MMBase' : c.superclass.to_s)
      f.puts "  end"
    end
    classes.each do |c|
      c.reflect_on_all_associations(:has_many).delete_if{|e|e.options[:through] or e.options[:finder_sql] or e.class_name.constantize.superclass != ActiveRecord::Base or !classes.include? e.klass}.sort{ |x,y| x.name.to_s <=> y.name.to_s }.each{|a|
        if a.name.to_s != 'thumbnails'
          f.puts "  #{c.name}.one_to_many '#{a.name.to_s}', #{a.class_name}, 'targetState'"
        end
      }
    end
    f.puts "end"
    f.close
  end
end
