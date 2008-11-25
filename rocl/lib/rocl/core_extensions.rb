class Object
  def __rocl_value
    [ self ]
  end
end


true.class.class_eval do
  def true?
    true
  end
  def false?
    false
  end
end


false.class.class_eval do
  def false?
    true
  end
  def true?
    false
  end
end


