class Psykube::V1::Manifest::Ingress
  alias HostHash = Hash(String, Host)
  alias HostnameList = Array(String)

  Macros.mapping({
    annotations: {type: StringMap, nilable: true},
    tls:         {type: Tls | Bool, nilable: true},
    host:        {type: String, nilable: true},
    hosts:       {type: HostnameList | HostHash, nilable: true, getter: false},
  })

  def initialize(hosts : Array(String), @tls : Bool? = nil)
    if hosts.size == 1
      @host = hosts.first
    elsif hosts.size > 1
      @hosts = hosts
    end
  end

  def hosts?
    !@hosts.nil?
  end

  def hosts
    hosts = @hosts
    host = @host
    host_hash = case hosts
                when HostHash
                  hosts
                when HostnameList
                  hosts.each_with_object(HostHash.new) do |hostname, host_hash|
                    host_hash[hostname] = Host.new
                  end
                else
                  HostHash.new
                end
    host_hash[host] = Host.new if host
    host_hash
  end
end

require "./ingress/*"
