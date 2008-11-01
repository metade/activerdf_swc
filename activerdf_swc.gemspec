Gem::Specification.new do |s|
  s.name = "activerdf_swc"
  s.version = "0.0.1"
  s.date = "2008-10-22"
  s.summary = "ActiveRDF Semantic Web Client adapter"
  s.email = "metade@gmail.com"
  s.homepage = "http://github.com/metade/activerdf_swc"
  s.description = "An ActiveRDF RDFLite Semantic Web Client adapter."
  s.has_rdoc = true
  s.authors = ['Patrick Sinclair']
  s.files = ["README", "Rakefile", "activerdf_swc.gemspec", "lib/activerdf_swc.rb"]  
  s.test_files = ["spec/activerdf_reddy_swc.rb"]
  #s.rdoc_options = ["--main", "README.txt"]
  #s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.add_dependency("activerdf")
  s.add_dependency("activerdf_rdflite")
end