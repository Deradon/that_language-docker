require "bundler/setup"
require "that_language/service"

# Wordlist tier, chosen at build time. "gem-10k" (or unset) means the
# 10k/72-language set that ships inside the that_language gem, whose default
# wordlist_path resolves relative to the gem itself. Any other value names a
# directory baked into the image at /app/wordlists/<tier>.
tier = ENV.fetch("THAT_LANGUAGE_WORDLIST_TIER", "gem-10k")

unless tier.empty? || tier == "gem-10k"
  ThatLanguage.configure do |config|
    config.wordlist_path = File.join("/app", "wordlists", tier)
  end
end

# CORS. The API is public, unauthenticated and read-only, and browsers on other
# origins are the intended callers -- the same reasoning that keeps
# Rack::Protection::JsonCsrf disabled in the service itself.
ThatLanguage::Service::Application.class_eval do
  before do
    headers "Access-Control-Allow-Origin" => "*"
  end

  options "*" do
    headers \
      "Allow" => "HEAD,GET,POST,OPTIONS",
      "Access-Control-Allow-Methods" => "HEAD,GET,POST,OPTIONS",
      "Access-Control-Allow-Headers" => "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"

    200
  end
end

# Wordlists load lazily and memoise at module level (~0.9 s cold, a few hundred
# MB resident). Pay it here, at boot, so the first request does not.
warn "[INFO] Warming the wordlist cache from #{ThatLanguage.configuration.wordlist_path}"
ThatLanguage.language_code("Hello world!")
warn "[INFO] Cache warm, #{ThatLanguage.available.size} languages available."

run ThatLanguage::Service::Application
