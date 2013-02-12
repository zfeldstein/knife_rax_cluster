module MyKnifePlugins
  # Make sure you subclass from Chef::Knife
  class OverRide < Chef::Knife
    
    
    banner "Cloud Builder"
      deps do
       
       require 'chef/knife/rackspace/rackspace_server_create'
       require 'json'
       require 'fog'
       require "thread"
       require 'chef/knife/rackspace/rackspace_base'
       require 'net/ssh/multi'
       require 'readline'
       require 'chef/knife/bootstrap'
       require 'chef/json_compat'
       Chef::Knife::Bootstrap.load_deps
      #include Knife::RackspaceBase
      end
        option :server_map,
        :short => "-M MAP_File",
        :long => "--map Map_File",
        :description => "Path to Server Map json file",
        :proc => Proc.new { |i| Chef::Config[:knife][:server_map] = i.to_s }
        
        option :provider,
        :short => "-P Provider",
        :long => "--provider provider",
        :description => "Specify RAX, open_stack",
        :default => 'RAX'
        #:proc => Proc.new { |i| Chef::Config[:knife][:server_map] = i.to_s }
        
        option :generate_map_template,
        :short => "-G",
        :long  => "--generate_map_template",
        :description => "Generate server map Template in current dir named map_template.json"
        
        #option :image,
        #:short => "-I IMAGE",
        #:long => "--image IMAGE",
        #:description => "The image of the server",
        #:proc => Proc.new { |i| Chef::Config[:knife][:image] = i.to_s }



        
    # This method will be executed when you run this knife command.
    def generate_map_template
      file_name = "./map_template.json"
      template = %q(
      {
        "servers" : [
          {
              "name_convention" : "web",
              "run_list" : [
                "role[base]",
                "role[narciss]"
              ],
              "quantity" : 2,
              "chef_env" : "dev",
              "image_ref" : "c195ef3b-9195-4474-b6f7-16e5bd86acd0",
              "flavor" : 2
              
          }
        ]
      })
      File.open(file_name, 'w') { |file| file.write(template)}
    end
    #Populates server_calls with map data
    def parse_server_map(map_file)
      map_contents = JSON.parse(File.read(map_file))
      server_calls = {}
      if map_contents.has_key?("servers")
        for i in map_contents['servers']
          server_calls[i['name_convention']] = {
                            "run_list" =>  i['run_list'] ,
                            "quantity" => i['quantity'], "chef_env" => i['chef_env'],
                            "image_ref" => i['image_ref']
          }
          #i['quantity'].times do
              run_list = i['run_list'].join(', ')
            #Thread.new {
              create_server = Chef::Knife::RackspaceServerCreate.new
              #create_server.config[:image] = i['image_ref']
              Chef::Config[:knife][:image] = i['image_ref']
              create_server.config[:server_name] = i['name_convention']
              create_server.config[:environment] = i['chef_env']
              create_server.config[:run_list] = i['run_list']
              #create_server.config[:flavor] = i['flavor']
              Chef::Config[:knife][:flavor] = i['flavor']
              create_server.run
          ##}
          #end
        
        end

      else
        ui.fatal "JSON file incorrect format"
      end
    end
  
  
    def launch_build
      yield
      
    end

    def run
      #Generate template config
      if config[:generate_map_template]
        generate_map_template()
      end
      #Parses Map and takes action
      if config[:server_map]
        parse_server_map(config[:server_map])

        
      end
      
      

    end
 
  end
end