source "https://rubygems.org"

# Both git sources are declared on purpose.
#
# A Gemfile is not transitive: Bundler resolves that_language-service from its
# *gemspec* (`that_language ~> 0.1`), not from the service's own Gemfile, and
# that lands on the published that_language 0.1.2 -- which predates the Ruby 3+
# fixes and raises on File.exists? the first time a wordlist is loaded. Without
# the line below the image builds fine and fails on the first request.
#
# Drop it once that_language 0.1.3 is published to rubygems.org.
gem "that_language", git: "https://github.com/Deradon/that_language.git"
gem "that_language-service", git: "https://github.com/Deradon/that_language-service.git"

# The service gem deliberately declares no web server -- it is a library, and
# the deployment picks the server. This is that pick.
gem "puma", "~> 7.0"
gem "rackup", "~> 2.2"
