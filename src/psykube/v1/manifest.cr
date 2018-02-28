require "yaml"

class Psykube::V1::Manifest
  macro mapping(properties)
    ::YAML.mapping({{properties}}, true)
  end

  getter name : String
  @docker_context = "."

  alias VolumeMap = Hash(String, Volume | String)
  mapping({
    name:                   {type: String, getter: false},
    type:                   {type: String, default: "Deployment"},
    prefix:                 String?,
    suffix:                 String?,
    docker_context:         {type: String, default: "."},
    dockerfile:             {type: String?},
    annotations:            Hash(String, String)?,
    labels:                 Hash(String, String)?,
    replicas:               Int32?,
    completions:            Int32?,
    parallelism:            Int32?,
    registry_host:          String?,
    registry_user:          String?,
    context:                String?,
    namespace:              String?,
    init_containers:        Array(Pyrite::Api::Core::V1::Container)?,
    image:                  String?,
    image_tag:              String?,
    revision_history_limit: Int32?,
    resources:              Resources?,
    deploy_timeout:         {type: Int32, nilable: true, getter: false},
    restart_policy:         String?,
    max_unavailable:        {type: Int32 | String, nilable: true, getter: false},
    max_surge:              {type: Int32 | String, nilable: true, getter: false},
    partition:              {type: Int32, nilable: true},
    command:                Array(String) | String | Nil,
    args:                   Array(String)?,
    env:                    {type: Hash(String, Env | String), nilable: true, getter: false},
    ingress:                Ingress?,
    service:                {type: String | Service, default: "ClusterIP", nilable: true, getter: false},
    config_map:             {type: Hash(String, String), nilable: true, getter: false},
    secrets:                {type: Hash(String, String), nilable: true, getter: false},
    ports:                  {type: Hash(String, Int32), nilable: true, getter: false},
    clusters:               {type: Hash(String, Cluster), nilable: true, getter: false},
    healthcheck:            {type: Bool | Healthcheck, nilable: true, default: false, getter: false},
    readycheck:             {type: Bool | Readycheck, nilable: true, default: false, getter: false},
    volumes:                {type: VolumeMap, nilable: true},
    autoscale:              {type: Autoscale, nilable: true},
    build_args:             {type: Hash(String, String), nilable: true, getter: false},
  })

  def initialize(@name : String, @type : String = "Deployment")
  end

  def initialize(command : Psykube::CLI::Commands::Init)
    flags = command.flags
    @type = flags.type
    @name = flags.name || File.basename(Dir.current)

    # Set Docker Info
    if flags.image
      @image = flags.image
    else
      @registry_host = flags.registry_host
      @registry_user = flags.registry_user || Psykube.current_docker_user
    end

    # Set Resources
    @resources = Resources.from_flags(
      flags.cpu_request,
      flags.memory_request,
      flags.cpu_limit,
      flags.memory_limit
    )

    # Set Namespace
    @namespace = flags.namespace

    # Set Ports
    @ports = Hash(String, Int32).new.tap do |hash|
      flags.ports.each_with_index do |spec, index|
        parts = spec.split("=", 2).reverse
        port = parts[0].to_i? || raise "Invalid port format."
        name = parts[1]? || (index == 0 ? "default" : "port_#{index}")
        hash[name] = port
      end
    end unless flags.ports.empty?

    # Set ENV
    @env = flags.env.map(&.split('=')).each_with_object(Hash(String, Manifest::Env | String).new) do |(k, v), memo|
      memo[k] = v
    end unless flags.env.empty?

    # Set Cluster
    @clusters = {
      "default" => Cluster.new(context: Psykube.current_kubectl_context),
    }

    # Set Ingress
    @ingress = Ingress.new(hosts: flags.hosts, tls: flags.tls) unless flags.hosts.empty?
  end

  def generate(actor : Actor)
    Generator::List.new(self, actor).result
  end

  def healthcheck
    @healthcheck || false
  end

  def readycheck
    @readycheck || false
  end

  def ports?
    !ports.empty?
  end

  def service
    return unless ports?
    service = @service
    @service = case service
               when "true", true
                 Service.new "ClusterIP"
               when String
                 Service.new service
               when Service
                 service
               end
  end

  def deploy_timeout
    @deploy_timeout || 300
  end

  def build_args
    @build_args || {} of String => String
  end

  def max_unavailable
    @max_unavailable || "25%"
  end

  def max_surge
    @max_surge || "25%"
  end

  def ports
    @ports || {} of String => Int32
  end

  def config_map
    @config_map || {} of String => String
  end

  def secrets
    @secrets || {} of String => String
  end

  def env
    env = @env || {} of String => Env | String
    return env unless ports?
    env["PORT"] = lookup_port("default").to_s
    ports.each_with_object(env) do |(name, port), env|
      env["#{name.underscore.upcase.gsub("-", "_")}_PORT"] = port.to_s
    end
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

  def service?
    !!service
  end

  def clusters
    @clusters || {} of String => Cluster
  end

  def env=(hash : Hash(String, String))
    @env = Hash(String, Env | String).new.tap do |h|
      hash.each do |k, v|
        h[k] = hash[k]
      end
    end
  end

  def env=(hash : Hash(String, Env))
    @env = Hash(String, Env | String).new.tap do |h|
      hash.each do |k, v|
        h[k] = hash[k]
      end
    end
  end

  def get_cluster(name)
    clusters[name]? || Cluster.new
  end

  def get_build_contexts(basename : String, tag : String)
    [BuildContext.new(
      image: basename,
      tag: tag,
      args: build_args,
      context: docker_context,
      dockerfile: dockerfile
    )]
  end
end

require "./manifest/*"