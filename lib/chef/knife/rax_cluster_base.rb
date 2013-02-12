require 'chef/knife'

  # Make sure you subclass from Chef::Knife
  
class Chef
	class Knife
		
	
		module RaxClusterBase
		
			def self.included(includer)
				includer.class_eval do
			  
				deps do
					
					require "net/https"
					require 'net/http'
					require "uri"
					#require 'chef/shef/ext'
					#require 'rubygems'
					#require 'chef/knife/rackspace_server_create'
					#require 'json'
					require 'fog'
					#require "thread"
					#require 'net/ssh/multi'
					require 'readline'
					#require 'chef/knife/bootstrap'
					require 'chef/json_compat'
			
				   Chef::Knife::Bootstrap.load_deps
				  #include Knife::RackspaceBase
				end
			
					option :rackspace_api_key,
					  :short => "-K KEY",
					  :long => "--rackspace-api-key KEY",
					  :description => "Your rackspace API key",
					  :proc => Proc.new { |key| Chef::Config[:knife][:rackspace_api_key] = key }
		  
					option :rackspace_username,
					  :short => "-A USERNAME",
					  :long => "--rackspace-username USERNAME",
					  :description => "Your rackspace API username",
					  :proc => Proc.new { |username| Chef::Config[:knife][:rackspace_username] = username }
		  
					option :rackspace_version,
					  :long => '--rackspace-version VERSION',
					  :description => 'Rackspace Cloud Servers API version',
					  :default => "v1",
					  :proc => Proc.new { |version| Chef::Config[:knife][:rackspace_version] = version }
		  
					option :rackspace_api_auth_url,
					  :long => "--rackspace-api-auth-url URL",
					  :description => "Your rackspace API auth url",
					  :default => "auth.api.rackspacecloud.com",
					  :proc => Proc.new { |url| Chef::Config[:knife][:rackspace_api_auth_url] = url }
		  
					option :rackspace_endpoint,
					  :long => "--rackspace-endpoint URL",
					  :description => "Your rackspace API endpoint",
					  :default => "https://dfw.servers.api.rackspacecloud.com/v2",
					  :proc => Proc.new { |url| Chef::Config[:knife][:rackspace_endpoint] = url }
				end
			end
			def populate_environment
				self.setup_environment_vars{ 
					rackspace_username = Chef::Config[:knife][:rackspace_username]
					rackspace_password = Chef::Config[:knife][:rackspace_password]
					rackspace_endpoint = Chef::Config[:knife][:rackspace_auth_url]
					@headers = {"x-auth-user" => rackspace_username, "x-auth-key" => rackspace_password,
								"auth_url" => rackspace_endpoint,
								"content-type" => "application/json", "Accept" => "application/json"}
					#@rax_endpoint = Chef::Config[:knife][:narciss_url] + "/" + Chef::Config[:knife][:narciss_version] + "/"
					#if rackspace_username_set
					#	@rackspace_username = rackspace_username
					#end
					#if rackspace_password_set
					#	@rackspace_password = rackspace_password				
					#end
					#if rackspace_tenant_set
					#	@rackspace_tenant = rackspace_tenant	
					#end
					#if rackspace_endpoint_set
					#	@rackspace_endpoint = rackspace_endpoint
					#end
							
				}
			end
	
			def make_web_call(httpVerb,uri,headers=nil, request_content=nil)
			  verbs =
				  {"get" => "Net::HTTP::Get.new(uri.request_uri, headers)",
				  "head" => "Net::HTTP::Head.new(uri.request_uri, headers)",
				  "put" => "Net::HTTP::Put.new(uri.request_uri, headers)",
				  "delete" => "Net::HTTP::Delete.new(uri.request_uri, headers)",
				  "post" => "Net::HTTP::Post.new(uri.request_uri, headers)"
				  }
			  #Get to work boy! This is Ruby!
			  uri = URI.parse(uri)
			  
			  http = Net::HTTP.new(uri.host, uri.port)
			  if uri.host =~ /https/
				  http.use_ssl = true
			  end
			  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
			  request = eval verbs[httpVerb]
			  if httpVerb == 'post' or httpVerb == 'put'
				 request.body = request_content
			  end
			  response = http.request(request)
			  if not ('200'..'204').include? response.code
					  puts "Error making web call"
					  puts "Response code : #{response.code}"
					  puts "Response body : #{response.body}"
					  puts "Response Headers : #{response.headers}"
					  exit(1)
			  end
			  return response
			  
			end
	
		end
	end
end
