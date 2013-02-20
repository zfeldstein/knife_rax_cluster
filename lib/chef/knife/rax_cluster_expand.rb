require 'chef/knife/rax_cluster_base'
require 'chef/knife/rackspace_server_delete'

class Chef
  class Knife
    class RaxClusterExpand < Knife
      attr_accessor :headers, :rax_endpoint, :lb_id 
      include Knife::RaxClusterBase
      banner "knife rax cluster expand (load_balancer_id) -B template_file.json"
      deps do
        require 'fog'
        require 'readline'
        require 'chef/json_compat'
        require 'chef/knife/bootstrap'
        Chef::Knife::Bootstrap.load_deps
      end
	  
	  option :blue_print,
	  :short => "-B Blue_print_file",
	  :long => "--map blue_print_file",
	  :description => "Path to blue Print json file",
	  :proc => Proc.new { |i| Chef::Config[:knife][:blue_print] = i.to_s }
      
      option :port,
      :short => "-lb_port port",
      :long => "--load-balancer-port port",
      :description => "Load balancer port",
      :proc => Proc.new { |port| Chef::Config[:knife][:port] = port},
      :default => "80"
	  
      option :lb_region,
      :short => "-r lb_region",
      :long => "--load-balancer-region lb_region",
      :description => "Load balancer region (only supports ORD || DFW)",
      :proc => Proc.new { |lb_region| Chef::Config[:knife][:lb_region] = lb_region},
      :default => "ORD"
#================================================================
# This will take a blueprint file and call the raxClusterCreate
# Class to handle parsing and building the nodes. It will then
# update the LB ID passed on the CLI with the nodes and meta data
#================================================================
	  def expand_cluster
        rs_cluster = RaxClusterCreate.new
        rs_cluster.config[:blue_print]  = config[:blue_print]
        rs_cluster.lb_name = @name_args[0]
        instance_return = rs_cluster.deploy(config[:blue_print],'update_cluster')
        lb_auth = authenticate()
        puts lb_auth['auth_token']
        headers = {"x-auth-token" => lb_auth['auth_token'], "content-type" => "application/json"}
        lb_url = ""
        lb_auth['lb_urls'].each {|lb|
          if config[:lb_region].to_s.downcase ==  lb['region'].to_s.downcase
            lb_url = lb['publicURL']
            break
          end
          lb_url = lb['publicURL']
          }
        meta_data_request = {
          "metadata" => []        
        }
        node_data_request = {
          "nodes" => []
        }
        meta_url = lb_url + "/loadbalancers/#{@lb_id}/metadata"
        node_url = lb_url + "/loadbalancers/#{@lb_id}/nodes"
        
        instance_return.each {|inst|
          node_data_request['nodes'] << {"address" => inst['ip_address'], 'port' =>Chef::Config[:knife][:port] || '80', "condition" => "ENABLED" }          
          meta_data_request['metadata'] << {"key" => inst['server_name'], "value" => inst['uuid']} 
          }
        meta_request = make_web_call("post", meta_url, headers, meta_data_request.to_json)
        lb_status = lb_url + "/loadbalancers/#{@lb_id}"
        lb_stats = make_web_call("get", lb_status, headers)
        lb_stats = JSON.parse(lb_stats.body)

        while lb_stats['loadBalancer']['status'].to_s.downcase != 'active'
          sleep(5)
          lb_stats = make_web_call("get", lb_status, headers)
          lb_stats = JSON.parse(lb_stats.body)
        end
        node_request = make_web_call("post", node_url, headers, node_data_request.to_json)        
        ui.msg "Load balancer id #{@lb_id} has been updated"
        
	  end
	  
	  def run
        if @name_args.empty?
          ui.fatal "Please specify Load balancer ID to add nodes too"
          exit(1)
        end
        if !config[:blue_print]
          ui.fatal "Please specify a blue print file to parse with -B"
          exit(1)
        end
        
        if config[:blue_print]
          @lb_id = @name_args[0]
          expand_cluster
        end
        
	  end
      



    end
  end
end
