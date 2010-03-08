require 'contacts'
require 'csv'
require 'iconv'

class Contacts
  class Yandex < Base
    URL                 = "http://mail.yandex.ru/"
    LOGIN_URL           = "https://passport.yandex.ru/passport?mode=auth"
    ADDRESS_BOOK_URL    = "http://mail.yandex.ru/neo/ajax/action_abook_export"
    PROTOCOL_ERROR      = "Yandex has changed its protocols, please upgrade this library first."
    
    def real_connect
      debugger
      postdata = "timestamp=&twoweeks=yes&login=#{CGI.escape(login)}&passwd=#{CGI.escape(password)}"
      
      data, resp, cookies, forward = post(LOGIN_URL, postdata)
      old_url = LOGIN_URL
      until forward.nil?
        data, resp, cookies, forward, old_url = get(forward, cookies, old_url) + [forward]
      end
      # data = Iconv.iconv("UTF8", "CP1251", data)[0]
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
      return @contacts if @contacts
      @contacts = []
      if connected?
        data, resp, cookies, forward = post(address_book_url, "tp=4&rus=0", @cookies)
        if resp.code_type != Net::HTTPOK
          raise ConnectionError, self.class.const_get(:PROTOCOL_ERROR)
        end
        
        parse data
      end
    end
    
  private

    def parse(data, options={})
      data = CSV.parse(data)
      col_names = data.shift
      @contacts = data.map do |person|
        [person[2], person[4]] unless person[4].empty?
      end.compact
    end
  

  end

  TYPES[:yandex] = Yandex
end