require 'chef/knife/rax_cluster_base'
require 'chef/knife/rackspace_server_delete'

class Chef
  class Knife
    class RaxClusterDelete < Knife
      attr_accessor :headers, :rax_endpoint, :lb_name 
      include Knife::RaxClusterBase
      banner "knife rax cluster delete (load_balancer_id) [options]"
      deps do
        require 'fog'
        require 'readline'
        require 'chef/json_compat'
        require 'chef/knife/bootstrap'
        Chef::Knife::Bootstrap.load_deps
      end
      
      option :lb_region,
      :short => "-r lb_region",
      :long => "--load-balancer-region lb_region",
      :description => "Load balancer region (only supports ORD || DFW)",
      :proc => Proc.new { |lb_region| Chef::Config[:knife][:lb_region] = lb_region},
      :default => "ORD"

      def delete_cluster
        lb_authenticate = authenticate()
        lb_url = ""
        puts config[:lb_region]
        headers = {"x-auth-token" => lb_authenticate['auth_token'], "content-type" => "application/json"}
        lb_authenticate['lb_urls'].each {|lb|
          if config[:lb_region].to_s.downcase ==  lb['region'].to_s.downcase
            lb_url = lb['publicURL']
            break
          end
          lb_url = lb['publicURL']
        }
        @name_args.each {|arg|
          server_uuids = []
          lb_url = lb_url + "/loadbalancers/#{arg}"
          get_uuids = make_web_call("get", lb_url, headers )
          if get_uuids.code == '404'
            ui.msg "Make sure you specify the -r flag to specify what region the LB is located"
            exit(1)
          end
          lb_data =  JSON.parse(get_uuids.body)
          lb_data['loadBalancer']['metadata'].each{|meta|
            server_uuids << {'uuid' => meta['value'], 'server_name' => meta['key'] }
            }
          server_uuids.each { |uuid|
            rs_delete = RackspaceServerDelete.new
            rs_delete.config[:yes] = 'yes'
            rs_delete.name_args = [ uuid['uuid'] ]
            rs_delete.config[:purge] = true
            rs_delete.config[:chef_node_name] = uuid['server_name']
            rs_delete.run
          }
          delete_lb_call = make_web_call("delete", lb_url, headers)
          puts "Deleted loadbalancer id #{arg}"
          
          
        }
      end
        
      def run
        if @name_args.empty?
          ui.fatal "Please specify a Load balancer ID to delete"
        end
        delete_cluster
      end
      


    end
  end
end
