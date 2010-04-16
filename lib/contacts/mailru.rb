require 'hpricot'
require 'iconv'

class Contacts
  class Mailru < Base
    URL                 = "http://mail.ru/"
    LOGIN_URL           = "http://win.mail.ru/cgi-bin/auth"
    ADDRESS_BOOK_URL    = "http://win.mail.ru/cgi-bin/addressbook?viewmode=l"
    PROTOCOL_ERROR      = "Mail.ru has changed its protocols, please upgrade this library first."
    
    def real_connect
      postdata = "Domain=#{CGI.escape(login.split('@')[1].to_s)}&Login=#{CGI.escape(login.split('@')[0].to_s)}&Password=#{CGI.escape(password.to_s)}"
      
      data, resp, cookies, forward = post(LOGIN_URL, postdata)
      old_url = LOGIN_URL
      until forward.nil?
        data, resp, cookies, forward, old_url = get(forward, cookies, old_url) + [forward]
      end
      data = Iconv.iconv("UTF-8", "WINDOWS-1251", data)[0]
      
      if data.index("Неверное имя пользователя или пароль") || data.index("Недопустимое имя пользователя")
        raise AuthenticationError, "Username and password do not match"
      elsif cookies == ""
        raise ConnectionError, PROTOCOL_ERROR
      end
      
      if resp.code_type != Net::HTTPOK
        raise ConnectionError, PROTOCOL_ERROR
      end
      
      @cookies = cookies
    end
    
    def contacts       
      return @contacts if @contacts
      @contacts = []
      if connected?
        page = 0
        url = URI.parse(address_book_url)
        begin
          page += 1
          http = open_http(url)
          resp, data = http.get("#{url.path}?#{url.query}&page=#{page}",
            "Cookie" => @cookies
          )
          if resp.code_type != Net::HTTPOK
            raise ConnectionError, self.class.const_get(:PROTOCOL_ERROR)
          end
          data = Iconv.iconv("UTF-8", "WINDOWS-1251", data)[0]
          doc = Hpricot(data)
          tables = data.gsub(/\n/, "").gsub(/\r/, "").gsub(/<script(.*?)<\/script>/, "").scan(/<table.*?<\/table>/m)
          table_id = 1
          tables.each_index do |i|
            table_id = i if tables[i].include?('adr_book')
          end
          Hpricot(tables[table_id]).search("tr").each do |tr|
            unless tr["id"].nil?
              name  = tr.at("td.nik a").inner_text
              email = tr.at("td.mail a").inner_text
              name  = email if name.strip.empty? && !email.empty?
              @contacts << {:id => email, :name => name}
            end
          end
        end while data.include?("<a href=\"?page=#{page+1}\">Далее<b>&nbsp;&#8250;</b></a>")
        @contacts
      end
    end
    
  private
    def uncompress(resp, data)
      case resp.response['content-encoding']
      when 'gzip':
        gz = Zlib::GzipReader.new(StringIO.new(data))
        data = gz.read
        # gz.close
        resp.response['content-encoding'] = nil
      when 'deflate':
        data = Zlib::Inflate.inflate(data)
        resp.response['content-encoding'] = nil
      end

      data
    end
  

  end

  TYPES[:mailru] = Mailru
end