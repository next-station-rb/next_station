require 'net/http'
require 'uri'
require 'json'
require_relative '../lib/next_station'

# --- The Plugin Definition ---
module HttpClientPlugin
  module ClassMethods
    def self.extended(base)
      base.extend Dry::Configurable
      base.instance_eval do
        setting :http_client do
          setting :base_url, default: "https://example.com"
          setting :timeout, default: 5
        end
      end
    end
  end

  module InstanceMethods
    def http_get(path)
      uri = URI.parse(self.class.config.http_client.base_url)
      uri = URI.join(uri, path)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.read_timeout = self.class.config.http_client.timeout
      
      request = Net::HTTP::Get.new(uri)
      http.request(request)
    rescue StandardError => e
      # In a real plugin, we would use error definitions, 
      # but for this example, we'll return a minimal object
      Struct.new(:code, :body).new("500", e.message)
    end
  end

  module State
    def response_received?
      !self[:response].nil?
    end

    def last_response_code
      self[:response]&.code
    end
  end
end

# Register the plugin manually for this standalone test
NextStation::Plugins.register(:http_client, HttpClientPlugin)

# --- The Operation Definition ---
class FetchExamplePage < NextStation::Operation
  plugin :http_client

  # Configure the plugin
  config.http_client.base_url = "https://www.example.com"
  config.http_client.timeout = 10

  # Tell NextStation where to find the result in the state
  result_at :content_length

  process do
    step :call_api
    step :process_response
  end

  def call_api(state)
    publish_log :info, "Calling API with: #{self.class.config.http_client.base_url}"
    response = http_get("/")
    state[:response] = response
    state
  end

  def process_response(state)
    # Using the State extension defined in the plugin
    if state.response_received? && state.last_response_code == "200"
      publish_log :info, "Success! Response code: #{state.last_response_code}"
      publish_log :info, "Body length: #{state[:response].body.length}"
      # In NextStation, you just return the state (or a hash that will be merged into state)
      # To signal success with data, the operation's result_key must match what we return or what's in state.
      state[:content_length] = state[:response].body.length
      state
    else
      puts "Failed! Response code: #{state.last_response_code || 'N/A'}"
      # If we want to fail explicitly, we can use error! or just return something that isn't state/success
      error!(type: :api_error, details: { message: "Response was #{state.last_response_code}" })
    end
  end
end

# --- Execution ---
puts "Starting Operation..."
result = FetchExamplePage.call

puts "\nFinal Result: #{result.success? ? 'SUCCESS' : 'FAILURE'}"
if result.success?
  puts "Value: #{result.value.inspect}"
else
  puts "Error: #{result.error.inspect}"
  puts "Details: #{result.error.details.inspect}" if result.error.respond_to?(:details)
end
