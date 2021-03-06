require 'csv'
require 'iconv'

class Contacts
  class Yandex < Base
    URL                 = "http://mail.yandex.ru/"
    LOGIN_URL           = "https://passport.yandex.ru/passport?mode=auth"
    ADDRESS_BOOK_URL    = "http://mail.yandex.ru/neo/ajax/action_abook_export"
    PROTOCOL_ERROR      = "Yandex has changed its protocols, please upgrade this library first."
    
    def real_connect
      postdata = "timestamp=&twoweeks=yes&login=#{CGI.escape(login)}&passwd=#{CGI.escape(password)}"
      
      data, resp, cookies, forward = post(LOGIN_URL, postdata)
      old_url = LOGIN_URL
      until forward.nil?
        data, resp, cookies, forward, old_url = get(forward, cookies, old_url) + [forward]
      end
      
      if data.index("Неправильная пара логин-пароль!")
        raise AuthenticationError, "Username and password do not match"
      elsif cookies == ""
        raise ConnectionError, PROTOCOL_ERROR
      elsif resp.code_type != Net::HTTPOK
        raise ConnectionError, PROTOCOL_ERROR
      end
      
      @cookies = cookies
    end
    
    def contacts       
      @contacts = []
      if connected?
        data, resp, cookies, forward = post(address_book_url, "tp=4&rus=0", @cookies)
        if resp.code_type != Net::HTTPOK
          raise ConnectionError, self.class.const_get(:PROTOCOL_ERROR)
        end
        
        parse data
      end
      
      @contacts.sort! { |a,b| a[:name] <=> b[:name] } if @contacts
      return @contacts if @contacts
    end
    
  private

    def parse(data, options={})
      data = CSV.parse(data)
      col_names = data.shift
      @contacts = data.map do |person|
        email = person[4]
        name  = person[2].to_s.strip
        name  = email if name.empty? && !email.empty?
        {:id => email, :name => name} unless email.empty?
      end.compact
    end
  

  end

  TYPES[:yandex] = Yandex
end
