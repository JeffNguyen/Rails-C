require 'erb'

def link_to(name, url)
  "<a href='#{url}'>#{name}</a>"
end

def button_to(name, url, options)
  method = options[:method] || "POST"
  <<-SQL
    <form action='#{url}' method='post'>
      <input type='hidden' name='authenticity_token' value='#{ form_authenticity_token}'>
      <input type='hidden' name='_method' value='#{method.to_s.upcase}'>
      <input type='submit' value='#{name}'>
    </form>
  SQL
end
