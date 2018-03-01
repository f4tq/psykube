class Psykube::V2::Manifest::Shared::Container
  Macros.mapping({
    image:         {type: String, nilable: true},
    tag:           {type: String, nilable: true},
    build_context: {type: String, default: "."},
    build_args:    {type: StringMap, default: StringMap.new},
    healthcheck:   {type: Bool | V1::Manifest::Healthcheck, nilable: true, default: false},
    readycheck:    {type: Bool | V1::Manifest::Readycheck, nilable: true, default: false},
    ports:         {type: PortMap, default: PortMap.new},
    volumes:       {type: VolumeMap, default: VolumeMap.new},
    resources:     {type: V1::Manifest::Resources, nilable: true},
    env:           {type: Hash(String, V1::Manifest::Env | String), nilable: true, getter: false},
    command:       {type: Array(String) | String, nilable: true},
    args:          {type: Array(String), nilable: true},
  })

  def env
    env = @env || {} of String => V1::Manifest::Env | String
    return env unless ports?
    env["PORT"] = lookup_port("default").to_s
    ports.each_with_object(env) do |(name, port), env|
      env["#{name.underscore.upcase.gsub(/(-\.)/, "_")}_PORT"] = port.to_s
    end
  end

  def ports?
    !ports.empty?
  end

  def lookup_port(port : Int32)
    port
  end

  def lookup_port(port_name : String)
    if port_name.to_i?
      port_name.to_i
    elsif port_name == "default" && !ports.key?("default")
      ports.values.first
    else
      ports[port_name]? || raise "Invalid port #{port_name}"
    end
  end
end