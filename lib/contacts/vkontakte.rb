require 'json'
require 'mechanize'
require 'iconv'

class Contacts
  class Vkontakte < Base
    LOGIN_URL           = 'http://vkontakte.ru'
    ADDRESS_BOOK_URL    = 'http://vkontakte.ru/friends.php'
    PROTOCOL_ERROR      = "Vkontakte.ru has changed its protocols, please upgrade this library first."
    
    def real_connect
      #
    end
    
    def contacts
      return @contacts if @contacts
      @contacts = []
      
      agent = Mechanize.new
      page = agent.get(LOGIN_URL)
      login_form = page.form('login')
      login_form.email = login
      login_form.pass  = password

      agent.submit( agent.submit(login_form, login_form.buttons.first).forms.first ) 

      names = {}
      my_friends = []
      people = {}

      my_friends_list = get_friends_list_from_page agent.get(ADDRESS_BOOK_URL).body

      if my_friends_list == {}
        raise AuthenticationError, "Username and password do not match"
      end

      my_friends_list['friends'].each do |friend|
        id = friend[0].to_s.strip.to_i
        name = friend[1].strip
        name = Iconv.iconv("UTF-8", "WINDOWS-1251", name)[0]
        @contacts << [name, id]
      end
      
      @contacts
    end
    
    private
    
      def get_friends_list_from_page page_body
        friends_json_match = page_body.match(/^\s+var friendsData = (\{.+\});$/)
        return {} if friends_json_match.nil?
        friends_json = friends_json_match[1].gsub("'","\"").gsub(/(\d+):/,"\"$1\":").gsub(/[\x00-\x19]/," ")

        begin
          JSON.parse friends_json
        rescue
          raise ConnectionError, PROTOCOL_ERROR
        end
      end
    
  end

  TYPES[:vkontakte] = Vkontakte
end