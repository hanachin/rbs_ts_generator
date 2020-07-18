$:.push File.expand_path("lib", __dir__)

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "rbs_ts_generator"
  spec.version     = '0.1.0'
  spec.authors     = ["Seiei Miyagi"]
  spec.email       = ["hanachin@gmail.com"]
  spec.homepage    = "https://github.com/hanachin/rbs_ts_generator"
  spec.summary     = "Generate TypeScript that includes routes definition and request / response JSON type from type signature of Rails controller actions."
  spec.license     = "MIT"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "<= 6.1.0.alpha", ">= 6.0.3.1"
  spec.add_dependency "rbs", "< 0.7.0", ">= 0.6.0"

  spec.add_development_dependency "sqlite3"
end
