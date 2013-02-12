require 'chef/knife/rax_cluster_base'

class Chef
  class Knife
    class RaxClusterCreate < Knife
      attr_accessor :headers, :rax_endpoint 
      include Knife::RaxClusterBase
      banner "knife rax cluster create (cluster_name) [options]"
      deps do
        require 'fog'
        require 'readline'
        require 'chef/json_compat'
        require 'chef/knife/bootstrap'
        Chef::Knife::Bootstrap.load_deps
      end

      option :algorithm,
      :short => "-a Load_balacner_algorithm",
      :long => "--algorithm algorithm",
      :description => "Load balancer algorithm",
      :proc => Proc.new { |algorithm| Chef::Config[:knife][:algorithm] = algorithm }
      
      option :port,
      :short => "-lb_port port",
      :long => "--load-balancer-port port",
      :description => "Load balancer port",
      :proc => Proc.new { |port| Chef::Config[:knife][:port] = port}
      
      option :timeout,
      :short => "-t timeout",
      :long => "--load-balancer-timeout timeout",
      :description => "Load balancer timeout",
      :proc => Proc.new { |timeout| Chef::Config[:knife][:timeout] = timeout}
      
      option :session_persistence,
      :short => "-S on_or_off",
      :long => "--session-persistence session_persistence_on_or_off",
      :description => "Load balancer session persistence on or off",
      :proc => Proc.new { |session_persistence| Chef::Config[:knife][:session_persistence] = session_persistence}

      def run
        
        if @name_args.empty? or @name_args.size > 1
		  ui.fatal "Please specify a single name for your cluster"
		  exit(1)
        end
        
        
        
        
         
      end
    
      
    end
  end
end
