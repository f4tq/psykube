require "admiral"
require "./concerns/*"

class Psykube::Commands::Delete < Admiral::Command
  include Kubectl
  include KubectlAll

  define_help description: "Delete the kubernetes manifests."

  define_flag confirm : Bool,
    description: "Don't ask for confirmation.",
    long: yes,
    short: y

  private def confirm?
    return true if flags.confirm
    print "Are you sure you want to delete the assets for #{generator.manifest.name}? (y/n) "
    gets("\n").to_s.strip == "y"
  end

  def run
    if confirm?
      puts "Deleting Kubernetes Manifests...".colorize(:yellow)
      kubectl_run(command: "delete", manifest: generator.result)
    end
  rescue e : Generator::ValidationError
    panic "Error: #{e.message}".colorize(:red)
  end
end
