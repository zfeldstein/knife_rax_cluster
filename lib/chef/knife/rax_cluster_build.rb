#=====================================================================
# Had to subclass this from knife-rackspace, neeeded to return the
# Instance data after build/bootstrap
#=====================================================================
require 'chef/knife/rackspace_server_create'
class Chef
  class Knife
    class RaxClusterBuild < RackspaceServerCreate

      include Knife::RackspaceBase

      deps do
        require 'fog'
        require 'readline'
        require 'chef/json_compat'
        require 'chef/knife/bootstrap'
        Chef::Knife::Bootstrap.load_deps
      end

      banner "knife rackspace server create (options)"

      option :flavor,
        :short => "-f FLAVOR",
        :long => "--flavor FLAVOR",
        :description => "The flavor of server; default is 2 (512 MB)",
        :proc => Proc.new { |f| Chef::Config[:knife][:flavor] = f.to_i },
        :default => 2

      option :image,
        :short => "-I IMAGE",
        :long => "--image IMAGE",
        :description => "The image of the server",
        :proc => Proc.new { |i| Chef::Config[:knife][:image] = i.to_s }

      option :server_name,
        :short => "-S NAME",
        :long => "--server-name NAME",
        :description => "The server name"

      option :chef_node_name,
        :short => "-N NAME",
        :long => "--node-name NAME",
        :description => "The Chef node name for your new node"

      option :private_network,
        :long => "--private-network",
        :description => "Use the private IP for bootstrapping rather than the public IP",
        :boolean => true,
        :default => false

      option :ssh_user,
        :short => "-x USERNAME",
        :long => "--ssh-user USERNAME",
        :description => "The ssh username; default is 'root'",
        :default => "root"

      option :ssh_password,
        :short => "-P PASSWORD",
        :long => "--ssh-password PASSWORD",
        :description => "The ssh password"

      option :identity_file,
        :short => "-i IDENTITY_FILE",
        :long => "--identity-file IDENTITY_FILE",
        :description => "The SSH identity file used for authentication"

      option :prerelease,
        :long => "--prerelease",
        :description => "Install the pre-release chef gems"

      option :bootstrap_version,
        :long => "--bootstrap-version VERSION",
        :description => "The version of Chef to install",
        :proc => Proc.new { |v| Chef::Config[:knife][:bootstrap_version] = v }

      option :distro,
        :short => "-d DISTRO",
        :long => "--distro DISTRO",
        :description => "Bootstrap a distro using a template; default is 'chef-full'",
        :proc => Proc.new { |d| Chef::Config[:knife][:distro] = d },
        :default => "chef-full"

      option :template_file,
        :long => "--template-file TEMPLATE",
        :description => "Full path to location of template to use",
        :proc => Proc.new { |t| Chef::Config[:knife][:template_file] = t },
        :default => false

      option :run_list,
        :short => "-r RUN_LIST",
        :long => "--run-list RUN_LIST",
        :description => "Comma separated list of roles/recipes to apply",
        :proc => lambda { |o| o.split(/[\s,]+/) },
        :default => []

      option :first_boot_attributes,
        :short => "-j JSON_ATTRIBS",
        :long => "--json-attributes",
        :description => "A JSON string to be added to the first run of chef-client",
        :proc => lambda { |o| JSON.parse(o) },
        :default => {}

      option :rackspace_metadata,
        :short => "-M JSON",
        :long => "--rackspace-metadata JSON",
        :description => "JSON string version of metadata hash to be supplied with the server create call",
        :proc => Proc.new { |m| Chef::Config[:knife][:rackspace_metadata] = JSON.parse(m) },
        :default => ""

      option :host_key_verify,
        :long => "--[no-]host-key-verify",
        :description => "Verify host key, enabled by default",
        :boolean => true,
        :default => true

      def tcp_test_ssh(hostname)
        tcp_socket = TCPSocket.new(hostname, 22)
        readable = IO.select([tcp_socket], nil, nil, 5)
        if readable
          Chef::Log.debug("sshd accepting connections on #{hostname}, banner is #{tcp_socket.gets}")
          yield
          true
        else
          false
        end
      rescue Errno::ETIMEDOUT
        false
      rescue Errno::EPERM
        false
      rescue Errno::ECONNREFUSED
        sleep 2
        false
      rescue Errno::EHOSTUNREACH
        sleep 2
        false
      ensure
        tcp_socket && tcp_socket.close
      end

      def run
        $stdout.sync = true

        unless Chef::Config[:knife][:image]
          ui.error("You have not provided a valid image value.  Please note the short option for this value recently changed from '-i' to '-I'.")
          exit 1
        end

        node_name = get_node_name(config[:chef_node_name] || config[:server_name])

        server = connection.servers.create(
          :name => node_name,
          :image_id => Chef::Config[:knife][:image],
          :flavor_id => locate_config_value(:flavor),
          :metadata => Chef::Config[:knife][:rackspace_metadata]
          )

        msg_pair("Instance ID", server.id)
        msg_pair("Host ID", server.host_id)
        msg_pair("Name", server.name)
        msg_pair("Flavor", server.flavor.name)
        msg_pair("Image", server.image.name)
        msg_pair("Metadata", server.metadata)

        print "\n#{ui.color("Waiting server", :magenta)}"

        # wait for it to be ready to do stuff
        server.wait_for { print "."; ready? }

        puts("\n")

        msg_pair("Public DNS Name", public_dns_name(server))
        msg_pair("Public IP Address", public_ip(server))
        msg_pair("Private IP Address", private_ip(server))
        msg_pair("Password", server.password)

        print "\n#{ui.color("Waiting for sshd", :magenta)}"

        #which IP address to bootstrap
        bootstrap_ip_address = public_ip(server)
        if config[:private_network]
          bootstrap_ip_address = private_ip(server)
        end
        Chef::Log.debug("Bootstrap IP Address #{bootstrap_ip_address}")
        if bootstrap_ip_address.nil?
          ui.error("No IP address available for bootstrapping.")
          exit 1
        end

        print(".") until tcp_test_ssh(bootstrap_ip_address) {
          sleep @initial_sleep_delay ||= 10
          puts("done")
        }
        bootstrap_for_node(server, bootstrap_ip_address).run

        puts "\n"
        msg_pair("Instance ID", server.id)
        msg_pair("Host ID", server.host_id)
        msg_pair("Name", server.name)
        msg_pair("Flavor", server.flavor.name)
        msg_pair("Image", server.image.name)
        msg_pair("Metadata", server.metadata)
        msg_pair("Public DNS Name", public_dns_name(server))
        msg_pair("Public IP Address", public_ip(server))
        msg_pair("Private IP Address", private_ip(server))
        msg_pair("Password", server.password)
        msg_pair("Environment", config[:environment] || '_default')
        msg_pair("Run List", config[:run_list].join(', '))
        ipaddress = ''
        #if not server.private_ip_address
        #  ipaddress = server.public_ip_address
        #end
        #if not ipaddress
        #  ipaddress = "false"
        #end
        return_hash = {"public_ip" => public_ip(server), "private_ip" => private_ip(server), "server_name" => server.name, "server_id" => server.id}
        return return_hash
      end
      
    end
  end
end


