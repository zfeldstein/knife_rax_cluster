require 'chef/knife/rax_cluster_base'

class Chef
  class Knife
    class RaxClusterChange < Knife
      attr_accessor :headers, :rax_endpoint, :lb_id 
      include Knife::RaxClusterBase

      banner "knife rax cluster change LB_ID (chef_options)"
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

      option :run_list,
      :long => "--run-list run_list",
      :description => "Pass a comma delimted run list --run-list 'recipe[apt],role[base]'",
      :proc => Proc.new { |run_list| Chef::Config[:knife][:run_list] = run_list}
      
      option :chef_env,
      :long => "--chef-env environment",
      :description => "Pass a comma delimted run list --run-list 'recipe[apt],role[base]'",
      :proc => Proc.new { |chef_env| Chef::Config[:knife][:chef_env] = chef_env}
=begin
Takes an array of hashes of instance data and a block that provides
what work should be done. This function will look up the chef object
For the node and pass that object into the calling block. 
=end
      def change_chef_vars(instances, &block)
        instances.each { |inst|
          query = "name:#{inst['server_name']}"
          query_nodes = Chef::Search::Query.new
          query_nodes.search('node', query) do |node_item|
            yield node_item
          end
        }
      end
=begin
Looks up the LB meta data and grabs the server name for every node
In the LB pool
Looks them up in chef and changes there run_list or chef_env
=end
      def run
        if !config[:run_list] and !config[:chef_env]
          ui.fatal "Please specify either --run-list or --chef-env to change on your cluster"
          exit(1)
        end
        if @name_args.empty?
          ui.fatal "Please specify a load balancer ID to update"
          exit(1)
        end
        lb_auth = authenticate()
        headers = {"x-auth-token" => lb_auth['auth_token'], "content-type" => "application/json"}
        lb_url = ""
        lb_auth['lb_urls'].each {|lb|
          if config[:lb_region].to_s.downcase ==  lb['region'].to_s.downcase
            lb_url = lb['publicURL']
            break
          end
          lb_url = lb['publicURL']
          }
        @name_args.each {|arg|
          lb_url = lb_url + "/loadbalancers/#{arg}"
          lb_data = make_web_call("get", lb_url, headers)
          lb_data = JSON.parse(lb_data.body)          
          instances = []
          lb_data['loadBalancer']['metadata'].each{|md|
            instances << {"server_name" => md['key'], "uuid" => md['uuid']}
            }
          
          if config[:run_list]
            config[:run_list] = config[:run_list].split(",")
            change_chef_vars(instances) { |node_item|
              ui.msg "Changing #{node_item.name} run list to #{config[:run_list]}"
              node_item.run_list(config[:run_list])
              node_item.save
            }
          end
          if config[:chef_env]
            change_chef_vars(instances){|node_item|
              ui.msg "Changing #{node_item.name} chef environment to #{config[:chef_env]}"
              node_item.chef_environment(config[:chef_env])
              node_item.save
              
              }
          end
          
        }
        
      end
      
      

    end
  end
end
