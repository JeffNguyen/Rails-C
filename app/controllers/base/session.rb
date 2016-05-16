class Session
  attr_reader :flash

  def initialize(req)
    app_cookie = req.cookies.select do |cook|
      cook.name == '_rails_lite_app'
    end.first

    if app_cookie.nil?
      @cookie = {}.with_indifferent_access
    else
      @cookie = JSON.parse(app_cookie.value).with_indifferent_access
    end
    @cookie[:form_authenticity_token] ||= SecureRandom.urlsafe_base64
    @flash = Flash.new(@cookie[:flash])
  end

  def [](key)
    cookie[key] || flash[key]
  end

  def []=(key, val)
    cookie[key] = val
  end

  def to_s
    cookie.to_s
  end

  def store_session(res)
    if flash.new_cookie.empty?
      cookie.try { delete(:flash) } #to avoid extraneous cookies in browser
    else
      cookie[:flash] =  flash.new_cookie #will overwrite old flash cookies
    end

    cook = WEBrick::Cookie.new("_rails_lite_app", cookie.to_json)
    cook.path = "/"
    res.cookies << cook
  end

  private
  attr_reader :cookie
end

class Flash
  attr_accessor :now
  ##Is there any way to make this private to outside world but not to Session?
  attr_reader :new_cookie

  def initialize(old_cookie)
    @old_cookie = old_cookie || {}.with_indifferent_access
    @new_cookie = {}.with_indifferent_access
    @now = {}.with_indifferent_access
  end

  def []=(key, value)
    new_cookie[key] = value
  end

  def [](key)
    new_cookie[key] || now[key] || old_cookie[key]
  end

  def to_s
    old_cookie.merge(new_cookie).to_s
  end

  private
  attr_reader :old_cookie
end
