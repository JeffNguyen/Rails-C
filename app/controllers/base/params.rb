class Params
  def initialize(req, route_params = {})
    query_string = req.query_string || ""
    body = req.body || ""
    query_params = parse_www_encoded_form(query_string)
    post_body_params = parse_www_encoded_form(body)
    @params = route_params.merge(query_params).merge(post_body_params)
  end

  def [](key)
    @params.with_indifferent_access[key]
  end

  def each(&prc)
    @params.each(&prc)
  end

  def permit(*keys)
    @params.delete_if { |k,_| !keys.include?(k) }
    @params
  end

  def to_s
    @params.to_s
  end

  def require(key)
    raise AttributeNotFoundError if @params[key].nil?
    @params = @params[key]
    self
  end

  private

  def parse_www_encoded_form(string)
    parsed = Hash.new {{}}
    string.gsub!(/\%5B/, "[")
    string.gsub!(/\%5D/, "]")
    string.split("&").each do |param|
      key, value = param.split('=')
      parsed_keys = parse_key(key)
      hashify(parsed, parsed_keys, value)
    end
    parsed
  end

  def parse_key(key)
    key.split(/\]\[|\[|\]/)
  end

  def hashify(current, keys, value)
    first = keys.first.to_sym
    if keys.length == 1
      current.merge!({first => value})
    else
      current[first] ||= {}
      current[first] = current[first].merge!(
          hashify(current[first], keys.drop(1), value)
      )
    end
    current
  end
end
