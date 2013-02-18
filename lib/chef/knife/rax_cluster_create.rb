require 'chef/knife/rax_cluster_base'
require 'chef/knife/rax_cluster_build'

class Chef
  class Knife
    class RaxClusterCreate < Knife
      attr_accessor :headers, :rax_endpoint, :lb_name 
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
      :proc => Proc.new { |algorithm| Chef::Config[:knife][:algorithm] = algorithm },
      :default => "ROUND_ROBIN"
      
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
      
      option :timeout,
      :short => "-t timeout",
      :long => "--load-balancer-timeout timeout",
      :description => "Load balancer timeout",
      :proc => Proc.new { |timeout| Chef::Config[:knife][:timeout] = timeout},
      :default => "30"
      
      option :lb_region,
      :short => "-r lb_region",
      :long => "--load-balancer-region lb_region",
      :description => "Load balancer region (only supports ORD || DFW)",
      :proc => Proc.new { |lb_region| Chef::Config[:knife][:lb_region] = lb_region},
      :default => "ORD"
      
      option :protocol,
      :short => "-p protocol",
      :long => "--load-balancer-protocol protocol",
      :description => "Load balancer protocol",
      :proc => Proc.new { |protocol| Chef::Config[:knife][:protocol] = protocol},
      :default => 'HTTP'
      
      option :generate_map_template,
      :short => "-G",
      :long => "--generate_map_template",
      :description => "Generate server map Template in current dir named map_template.json"
      
      #option :session_persistence,
      #:short => "-S on_or_off",
      #:long => "--session-persistence session_persistence_on_or_off",
      #:description => "Load balancer session persistence on or off",
      #:proc => Proc.new { |session_persistence| Chef::Config[:knife][:session_persistence] = session_persistence}

      def generate_map_template
           file_name = "./map_template.json"
           template = %q(
           {
             "blue_print" : 
               {
                   "name_convention" : "web",
                   "run_list" : [
                     "recipe[apt]"
                   ],
                   "quantity" : 1,
                   "chef_env" : "dev",
                   "image_ref" : "a9753ff4-f46c-427d-9498-1358564f622f",
                   "flavor" : 2
                   }
             
     
           }
     )
     
           File.open(file_name, 'w') { |file| file.write(template)}
      end
      def create_lb(instances)
        lb_request = {
          "loadBalancer" => {
            "name" => @lb_name,
            "port" => config[:port] || '80',
            "protocol" => config[:protocol] || 'HTTP',
            "algorithm" => config[:algorithm] || 'ROUND_ROBIN',
            "virtualIps" => [
              {
                "type" => "PUBLIC"
              }
            ],
            "nodes" => [],
            "metadata" => []
          }
        }
        
        instances.each {|inst|
          lb_request['loadBalancer']['nodes'] << {"address" => inst['ip_address'], 'port' =>Chef::Config[:knife][:port] || '80', "condition" => "ENABLED" }
          lb_request['loadBalancer']['metadata'] << {"key" => inst['server_name'], "value" => inst['uuid']}
          }
        lb_authenticate = authenticate()
        lb_url = ""
        lb_authenticate['lb_urls'].each {|lb|
          if config[:lb_region].to_s.downcase ==  lb['region'].to_s.downcase
            lb_url = lb['publicURL']
            break
          end
          lb_url = lb['publicURL']
          }
        lb_url = lb_url + "/loadbalancers"
        
        headers = {'Content-type' => 'application/json', 'x-auth-token' => lb_authenticate['auth_token']}
        create_lb_call = make_web_call("post",lb_url, headers, lb_request.to_json )
        lb_details = JSON.parse(create_lb_call.body)
        ui.msg "Load Balancer Cluster Sucesfully Created"
        ui.msg "Load Balancer ID: #{lb_details['loadBalancer']['id']}"
        ui.msg "Load Balancer Name: #{lb_details['loadBalancer']['name']}"
        lb_ip = ""
        lb_details['loadBalancer']['virtualIps'].each {|lb| (lb['ipVersion'] == "IPV4") ? lb_ip = lb['address'] : "not_found"}
        ui.msg "Load Balancer IP Address: #{lb_ip}"
      end
      
      
      def deploy(blue_print,update_cluster=nil)
        (File.exist?(blue_print)) ? map_contents = JSON.parse(File.read(blue_print)) : map_contents = JSON.parse(blue_print)
        sleep_interval = 1
        instances = []
        if map_contents.has_key?("blue_print")
          bp_values = map_contents['blue_print']
          bootstrap_nodes = []
          quantity = bp_values['quantity'].to_i
              quantity.times do |node_name|
                  node_name  = rand(900000000)
                  create_server = Chef::Knife::RaxClusterBuild.new
                  #create_server.config[:identity_file] = config[:identity_file]
                  Chef::Config[:knife][:image] = bp_values['image_ref'] 
                  create_server.config[:chef_node_name] = bp_values['name_convention'] + node_name.to_s 
                  create_server.config[:environment] = bp_values['chef_env'] 
                  Chef::Config[:environment] = bp_values['chef_env']
                  create_server.config[:run_list] = bp_values['run_list']
                  Chef::Config[:knife][:flavor] = bp_values['flavor']
                  begin
                    bootstrap_nodes << Thread.new { Thread.current['server_return'] = create_server.run }
                  rescue
                    ui.msg "Bootstrapping failed"
                  end
                  
              end
              quantity.times do |times|
                if quantity > 20
                  sleep_interval = 3
                end
                sleep(sleep_interval)
                bootstrap_nodes[times].join              
                instances << {"server_name" => bootstrap_nodes[times]['server_return']['server_name'],
                              "ip_address" => bootstrap_nodes[times]['server_return']['private_ip'],
                              "uuid" => bootstrap_nodes[times]['server_return']['server_id'],
                              "name_convention" => bp_values['name_convention'],
                              "chef_env" => bp_values['chef_env'],
                              "run_list" => bp_values['run_list']
                              }
              end
        end
        if update_cluster
          return instances
        else
          create_lb(instances)
        end
        
        
        
      end

      def run
        #Generate template config
		if config[:generate_map_template]
		  generate_map_template()
		  ui.msg "Map template saved as ./map_template.json"
		  exit()
		end
        
        
        if @name_args.empty? or @name_args.size > 1
		  ui.fatal "Please specify a single name for your cluster"
		  exit(1)
        end
        #Set load balancer name
        @lb_name = @name_args[0]
        
        if config[:blue_print]
          deploy(config[:blue_print])
      
        end
        
      end
    
      
    end
  end
end
