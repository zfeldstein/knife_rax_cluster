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
      
      def run
        puts "#{Chef::Config[:knife][:rackspace_endpoint]}"
        
         
      end
    
      
    end
  end
end
