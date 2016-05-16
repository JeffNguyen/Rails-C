class Errors
  def initialize(model_type)
    @errors = Hash.new { |hash, key| hash[key] = [] }
    model_type.columns.each do |col|
      @errors[col.to_sym] = []
    end
  end

  def [](key)
    @errors[key.to_sym]
  end

  def []=(key, value)
    @errors[key.to_sym] = value
  end

  def any?
    !full_messages.empty?
  end

  def full_messages
    all_messages = []
    @errors.each do |type, messages|
      messages.each do |message|
        all_messages << type.to_s.capitalize + " " + message
      end
    end

    all_messages
  end
end
