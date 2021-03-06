# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"
require "socket" # for Socket.gethostname

# Perform an LDAP Search
#
# Example:
#
#     input {
#        LDAPSearch {
#         host => "myLDAPServer"
#         dn => "myDN"
#         password => "myPassword"
#         filter => "myldapfilter"
#         base => "ou=people,dc=univ,dc=fr"
#         attrs => ['myattrubteslist']
#        }
#    }

class LogStash::Inputs::LDAPSearch < LogStash::Inputs::Base
  config_name "LDAPSearch"

  # If undefined, Logstash will complain, even if codec is unused.
  default :codec, "plain" 

  # LDAP parameters
  config :host, :validate => :string, :required => true
  config :dn, :validate => :string, :required => true
  config :password, :validate => :password, :required => true
  config :filter, :validate => :string, :required => true
  config :base, :validate => :string, :required => true
  config :port, :validate => :number, :default => 389
	config :usessl, :validate => :boolean, :default => false
  config :attrs, :validate => :array, :default => ['uid']

  public
  def register
    require 'base64'
    require 'rubygems'
    require 'ldap'
  end # def register

  public
  def run(queue)
      
    @host = Socket.gethostbyname(@host).first
    #attrs = ['uid', 'sn', 'cn', 'eduPersonPrimaryAffiliation']
    scope = LDAP::LDAP_SCOPE_SUBTREE #LDAP::LDAP_SCOPE_ONELEVEL
    begin
			conn = ( @usessl == true ) ? LDAP::SSLConn.new(@host,@port) : LDAP::Conn.new(@host, @port)
			conn.bind(@dn, @password.value)
      @logger.debug("Executing LDAP search base='#{@base}' filter='#{@filter}'")
      conn.search(base, scope, filter, attrs) { |entry|
        # print distinguished name
        # p entry.dn
        event = LogStash::Event.new
        decorate(event)
        event.set("host", @host)
        entry.get_attributes.each do |attr|
					#values = entry.get_values(attr).first
					values = entry.get_values(attr)
					values = values.map { |value|
            (/[^[:print:]]/ =~ value).nil? ? value : Base64.strict_encode64(value)
					}
					event.set(attr,values);
				end
				#event["attr"] = entry.attrs
				queue << event
			}
		rescue LDAP::Error => ex
			@logger.error("Ldap connect failed: #{ex}\n#{ex.backtrace}")
			exit
		rescue LDAP::ResultError => ex
			@logger.error("LDAP search error: #{ex}\n#{ex.backtrace}")
			exit
    end
		# no finished in 2.1, instead stop method is called
    # finished
  end # def run

end # class LogStash::Inputs::LDAPSearch
