require "spec_helper"

# Dummy smoke test
describe Backblaze do
  it "has a version number" do
    expect(Backblaze::VERSION).not_to be nil
  end
end
