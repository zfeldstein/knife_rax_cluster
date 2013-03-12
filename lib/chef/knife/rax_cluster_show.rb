require 'chef/knife/rax_cluster_base'
class Chef
  class Knife
    class RaxClusterShow < Knife

      include Knife::RaxClusterBase

      banner "knife rax cluster show LB_ID -r lb_region"
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
      
      def run
        if @name_args.empty?
          ui.fatal "Please specify Load balancer ID to add nodes too"
          exit(1)
        end
        lb_auth = authenticate
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
          lb_url = lb_url + "/loadbalancers/#{arg}.json"
          lb_data = make_web_call("get", lb_url, headers)
          lb_data = JSON.parse(lb_data.body)
          lb = lb_data['loadBalancer']
            msg_pair("LB Details for #{lb['name']}", " ")
            msg_pair("\s\s\s\sLB ID", "#{lb['id']}")
            msg_pair("\s\s\s\sLB Port", "#{lb['port']}")
            msg_pair("\s\s\s\sLB Algorithm", "#{lb['algorithm']}")
            msg_pair("\s\s\s\sLB Status", "#{lb['status']}")
            msg_pair("\s\s\s\sLB timeout", "#{lb['timeout']}")
            msg_pair("\s\s\s\sVirtual IPs", " ")
            lb['virtualIps'].each {|ip|
              msg_pair("\s\s\s\s\s\s\s\sAddress", "#{ip['address']}")
              msg_pair("\s\s\s\s\s\s\s\sType", "#{ip['type']}")
              ui.msg "\n"
              }
            msg_pair("\s\s\s\sNodes", " ")
            lb['nodes'].each {|node|
              msg_pair("\s\s\s\s\s\s\s\sNode Address", "#{node['address']}")
              msg_pair("\s\s\s\s\s\s\s\sType", "#{node['type']}")
              msg_pair("\s\s\s\s\s\s\s\sCondition", "#{node['condition']}")
              msg_pair("\s\s\s\s\s\s\s\sPort", "#{node['port']}")
              msg_pair("\s\s\s\s\s\s\s\sStatus", "#{node['status']}")
              ui.msg "\n"
              }
          
        }
        
      end

    end
  end
end
