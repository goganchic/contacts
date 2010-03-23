require 'hpricot'

class Contacts
  class Livejournal < Base
    URL                 = "http://livejournal.com/"
    LOGIN_URL           = "http://www.livejournal.com/mobile/login.bml"
    ADDRESS_BOOK_URL    = "http://www.livejournal.com/friends/edit.bml"
    PROTOCOL_ERROR      = "Livejournal.com has changed its protocols, please upgrade this library first."
    
    def real_connect
      postdata = "user=#{CGI.escape(login.split('@')[0].to_s)}&password=#{CGI.escape(password.to_s)}"
      
      data, resp, cookies, forward = post(LOGIN_URL, postdata)
      old_url = LOGIN_URL
      until forward.nil?
        data, resp, cookies, forward, old_url = get(forward, cookies, old_url) + [forward]
      end
      
      if data.index("Invalid username") || data.index("Bad password")
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
        url = URI.parse(address_book_url)
        http = open_http(url)
        resp, data = http.get("#{url.path}?#{url.query}", "Cookie" => @cookies)
        if resp.code_type != Net::HTTPOK
          raise ConnectionError, self.class.const_get(:PROTOCOL_ERROR)
        end
        doc = Hpricot(data)
        doc.at("#editfriends").search("span.ljuser").each do |span|
          user = span.inner_text
          @contacts << [user, "#{user}@livejournal.com"]
        end
        @contacts
      end
    end
    
  end

  TYPES[:livejournal] = Livejournal
end