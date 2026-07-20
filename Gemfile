source "https://rubygems.org"

# Declaring only the service is correct now, and was not before. The service
# gem's own gemspec pins `that_language ~> 0.2`, and gemspec dependencies *are*
# transitive -- so Bundler resolves the revived core gem on its own. Until
# that_language 0.2.0 was published, this file had to name both gems from git,
# because the service's `~> 0.1` landed on the broken published 0.1.2.
gem "that_language-service", "~> 0.2"

# The service gem deliberately declares no web server -- it is a library, and
# the deployment picks the server. This is that pick.
gem "puma", "~> 7.0"
gem "rackup", "~> 2.2"
