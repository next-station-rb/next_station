# frozen_string_literal: true

require 'spec_helper'
require 'next_station/logging/formatters/json'

RSpec.describe NextStation::Logging::Formatter::Json do
  let(:formatter) { described_class.new }
  # Create a time with microseconds: 2023-10-27 10:00:00.123456 UTC
  let(:time) { Time.utc(2023, 10, 27, 10, 0, 0, 123456) }
  let(:severity) { "INFO" }
  let(:progname) { "test" }
  let(:msg) { "test message" }

  it "formats time as %Y-%m-%dT%H:%M:%S.%6N" do
    result = formatter.call(severity, time, progname, msg)
    json_result = JSON.parse(result)
    
    # The expected format does NOT include 'Z' at the end based on the strftime string provided
    expect(json_result["time"]).to eq("2023-10-27T10:00:00.123456")
  end
end
