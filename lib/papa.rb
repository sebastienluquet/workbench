class Papa
  include ArBase
#  def self.descends_from_active_record?
#    if ((not (superclass == Object)) and superclass.abstract_class?) then
#      superclass.descends_from_active_record?
#    else
#      ((superclass == Base) or (not columns_hash.include?(inheritance_column)))
#    end
#  end
end
