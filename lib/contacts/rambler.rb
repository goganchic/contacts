require 'hpricot'

class Contacts
  class Rambler < Base
    URL                 = "http://mail.rambler.ru/"
    LOGIN_URL           = "http://id.rambler.ru/script/auth.cgi"
    ADDRESS_BOOK_URL    = "http://mail.rambler.ru/mail/contacts.cgi"
    PROTOCOL_ERROR      = "Rambler has changed its protocols, please upgrade this library first."
    
    def real_connect
      postdata = "back=#{CGI.escape(ADDRESS_BOOK_URL)}&login=#{CGI.escape(login.split('@')[0].to_s)}&long_session=on&passw=#{CGI.escape(password.to_s)}&submit=Войти&url=7"
      
      data, resp, cookies, forward = post(LOGIN_URL, postdata)
      data = Iconv.iconv("UTF8", "CP1251", data)[0]
      
      if data.include?("Пожалуйста, представьтесь, чтобы получить доступ к персональным службам Рамблера") || data.include?("Неправильное имя или пароль")
        raise AuthenticationError, "Username and password do not match"
      elsif cookies == ""
        raise ConnectionError, PROTOCOL_ERROR
      end
      
      data, resp, cookies, forward = get(forward, cookies, LOGIN_URL)
      data, resp, cookies, forward = get(forward, cookies, LOGIN_URL)
      
      if resp.code_type != Net::HTTPOK
        raise ConnectionError, PROTOCOL_ERROR
      end
      
      @cookies = cookies
    end
    
    def contacts     
      return @contacts if @contacts
      @contacts = []
      if connected?
        url = URI.parse(address_book_url)
        http = open_http(url)
        resp, data = http.get("#{url.path}?#{url.query}", "Cookie" => @cookies)
        if resp.code_type != Net::HTTPOK
          raise ConnectionError, self.class.const_get(:PROTOCOL_ERROR)
        end
        doc = Hpricot(data)
        doc.at("#contacts-list").search("tr.vcard").each do |tr|
          @contacts << [tr.at("td.fn").inner_text.blank? ? nil : tr.at("td.fn").inner_text, tr.at("a.email").inner_text]
        end
        @contacts
      end
    end
    
  private
    # def uncompress(resp, data)
    #   case resp.response['content-encoding']
    #   when 'gzip':
    #     gz = Zlib::GzipReader.new(StringIO.new(data))
    #     data = gz.read
    #     # gz.close
    #     resp.response['content-encoding'] = nil
    #   when 'deflate':
    #     data = Zlib::Inflate.inflate(data)
    #     resp.response['content-encoding'] = nil
    #   end
    # 
    #   data
    # end
  

  end

  TYPES[:rambler] = Rambler
end