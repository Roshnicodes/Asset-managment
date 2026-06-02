ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

unless Object.method_defined?(:stub)
  class Object
    def stub(method_name, value)
      singleton_class = class << self; self; end
      original_method = method(method_name) if respond_to?(method_name, true)

      singleton_class.define_method(method_name) do |*args, **kwargs, &block|
        value.respond_to?(:call) ? value.call(*args, **kwargs, &block) : value
      end

      yield
    ensure
      if original_method
        singleton_class.define_method(method_name, original_method)
      else
        singleton_class.remove_method(method_name) if singleton_class.method_defined?(method_name)
      end
    end
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
