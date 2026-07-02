# A tiny documented library used to smoke-test the docset pipeline and app.
module Fixture
  # Greets people. Used by CI to verify search and rendering end to end.
  class Greeter
    # The default greeting word.
    DEFAULT_GREETING = "Hello"

    # @return [String] the name being greeted
    attr_reader :name

    # Creates a greeter for +name+.
    def initialize(name)
      @name = name
    end

    # Returns a greeting string, e.g. <tt>"Hello, Ada!"</tt>.
    def greet
      "#{DEFAULT_GREETING}, #{name}!"
    end

    # Maps each character of the name, demonstrating a method named +map+.
    def map(&block)
      name.chars.map(&block)
    end

    # Builds a greeter from a hash payload.
    def self.from_h(payload)
      new(payload.fetch(:name))
    end
  end
end
