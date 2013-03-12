require 'chef/knife/rax_cluster_base'
class Chef
  class Knife
    class RaxClusterList < Knife
      attr_accessor :headers, :rax_endpoint, :lb_id 
      include Knife::RaxClusterBase

      banner "knife rax cluster list -r lb_region"
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
      

=begin
Looks for lb's named $variable_cluster and lists them
=end
      def run
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
        lb_url = lb_url + "/loadbalancers"
        lb_list = make_web_call("get", lb_url, headers)
        lb_list = JSON.parse(lb_list.body)
        lb_list['loadBalancers'].each {|lb|
          if (lb['name'] =~ /_cluster/i)
            msg_pair("LB Details for #{lb['name']}", " ")
            msg_pair("\s\s\s\sLB ID", "#{lb['id']}")
            msg_pair("\s\s\s\sLB Port", "#{lb['port']}")
            msg_pair("\s\s\s\sLB Algorithm", "#{lb['algorithm']}")
            msg_pair("\s\s\s\sLB Protocol", "#{lb['protocol']}")
            msg_pair("\s\s\s\sLB Node Count", "#{lb['nodeCount']}")
            ui.msg "\n\n"
          end
          }
        
      end


    end
  end
end
