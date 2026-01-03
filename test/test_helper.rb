ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include ActiveJob::TestHelper

    # Add more helper methods to be used by all tests here...
    def with_stubbed_storage_client(fake)
      singleton = class << StorageClient; self; end
      original = StorageClient.method(:new)
      singleton.send(:define_method, :new) { fake }
      yield
    ensure
      singleton.send(:define_method, :new, original)
    end
  end
end
