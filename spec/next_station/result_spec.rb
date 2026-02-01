require "spec_helper"

RSpec.describe NextStation::Result do
  describe "successful result" do
    subject { NextStation::Result::Success.new({ foo: "bar" }) }

    it "is successful" do
      expect(subject.success?).to be true
      expect(subject.failure?).to be false
    end

    it "has a value" do
      expect(subject.value).to eq({ foo: "bar" })
    end

    it "has no error" do
      expect(subject.error).to be_nil
    end
  end

  describe "failed result" do
    let(:error) { NextStation::Result::Error.new(type: :invalid, message: "Oops", details: { code: 422 }) }
    subject { NextStation::Result::Failure.new(error) }

    it "is failed" do
      expect(subject.success?).to be false
      expect(subject.failure?).to be true
    end

    it "has an error" do
      expect(subject.error).to eq(error)
      expect(subject.error.type).to eq(:invalid)
      expect(subject.error.message).to eq("Oops")
      expect(subject.error.details).to eq({ code: 422 })
    end

    it "has no value" do
      expect(subject.value).to be_nil
    end
  end
end
