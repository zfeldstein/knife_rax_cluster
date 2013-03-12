Gem::Specification.new do |s|
  s.name = 'knife-rackspace-cluster'
  s.version = '0.0.8'
  s.date = '2013-02-19'
  s.summary = "Knife rax cluster"
  s.description = "Creates rax clusters"
  s.authors = ["zack feldstein"]
  s.email = 'pcguru419@yahoo.com'
  s.files = Dir.glob("{lib}/**/*")
  s.homepage = "http://github.com/jrcloud/knife_rax_cluster"
  s.add_dependency "fog", "= 1.8.0"
  s.add_dependency "knife-rackspace"
end



