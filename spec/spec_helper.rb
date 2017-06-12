require "rspec"
require "foodcritic"
require "shellwords"
require "rspec_command"
require "simplecov"
require 'pry'

SimpleCov.start do
  add_filter "/spec/"
end

module FunctionalHelpers
  extend RSpec::Matchers::DSL

  matcher :violate_rule do |rule_id = nil|
    match do |cmd|
      if location
        cmd.stdout =~ /^#{expected}:.*: \.\/#{location}/
      else
        cmd.stdout =~ /^#{expected}:/
      end
    end
    chain :in, :location
    failure_message do |cmd|
      "expected a violation of rule #{expected}#{location && " in #{location}"}, output was:\n#{cmd.stdout}"
    end
    failure_message_when_negated do |cmd|
      "expected no violation of rule #{expected}#{location && " in #{location}"}, output was:\n#{cmd.stdout}"
    end
    # Override the default behavior from RSpec for the expected value, use
    # define_method insetad of def so we can see the _rule_id variable in closure.
    define_method(:expected) do
      # Fill in the top-level example group description as the rule ID if not specified.
      rule_id || method_missing(:class).parent_groups.last.description
    end
  end

  def foodcritic_command(*args)
    output = StringIO.new
    error = StringIO.new
    begin
      # Don't use the block form of chdir because for some reason it can't be
      # nested.
      cwd = Dir.pwd
      Dir.chdir(temp_path)
      $stderr = error
      exitstatus = FoodCritic::CommandLine.main(args, output)
    ensure
      $stderr = STDERR
      Dir.chdir(cwd)
    end
    RSpecCommand::OutputString.new(output.string, error.string).tap do |out|
      out.define_singleton_method(:exitstatus) { exitstatus }
    end
  end

  module ClassMethods
    def foodcritic_command(*args)
      metadata[:foodcritic_command] = true
      subject do |example|
        foodcritic_command(*args)
      end
    end

    def attributes_file(*args, &block)
      file("attributes/default.rb", *args, &block)
    end

    def resource_file(*args, &block)
      file("resources/my_resource.rb", *args, &block)
    end

    def library_file(*args, &block)
      file("libraries/helper.rb", *args, &block)
    end

    def recipe_file(*args, &block)
      file("recipes/default.rb", *args, &block)
    end

    def metadata_file(*args, &block)
      file("metadata.rb", *args, &block)
    end

    def cookbook_file(file, *args, &block)
      file(file, *args, &block)
    end

    def included(klass)
      super
      klass.extend ClassMethods
      # Set a default subject command, can be overridden if needed.
      klass.foodcritic_command("--chef-version", "13.0.133", "--no-progress", ".", "--include", "/Users/dmw/cookbooks/sous-chefs/sc-foodcritic-rules/lib/foodcritic")

      puts "current dir #{Dir.pwd}"

    end
  end

  extend ClassMethods
end

RSpec.configure do |config|
  # Basic configuraiton
  config.run_all_when_everything_filtered = true
  config.filter_run(:focus) unless ENV["CI"]
  config.order = "random"

  # Set some metadata based on test folders.
  # config.define_derived_metadata(file_path: %r{spec/unit}) do |metadata|
  #   metadata[:unit] = true
  # end
  config.define_derived_metadata(file_path: %r{spec/functional}) do |metadata|
    metadata[:functional] = true
  end
  # config.define_derived_metadata(file_path: %r{spec/regression}) do |metadata|
  #   metadata[:regression] = true
  # end
  config.include RSpecCommand
  config.include FunctionalHelpers#, functional: true
end

puts "current dir #{Dir.pwd}"

require_relative "../lib/foodcritic/rules"
