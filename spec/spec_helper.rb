# frozen_string_literal: true

if ENV['COVERAGE'] == 'true'
  require 'simplecov'

  SimpleCov.start do
    command_name 'spec:unit'

    add_filter 'config'
    add_filter 'spec'
    add_filter 'vendor'
    add_filter 'test_app'
    add_filter 'lib/mutant.rb' # simplecov bug not seeing default block is executed

    minimum_coverage 100
  end
end

# Require warning support first in order to catch any warnings emitted during boot
require_relative './support/warning'
$stderr = MutantSpec::Warning::EXTRACTOR

require 'tempfile'
require 'concord'
require 'anima'
require 'adamantium'
require 'devtools/spec_helper'
require 'unparser/cli'
require 'mutant'
require 'mutant/meta'

$LOAD_PATH << File.join(TestApp.root, 'lib')

require 'test_app'

module Fixtures
  TEST_CONFIG = Mutant::Config::DEFAULT.with(reporter: Mutant::Reporter::Null.new)
  TEST_ENV    = Mutant::Env::Bootstrap.call(Mutant::WORLD, TEST_CONFIG)
end # Fixtures

module ParserHelper
  def generate(node)
    Unparser.unparse(node)
  end

  def parse(string)
    Unparser::Preprocessor.run(Unparser.parse(string))
  end

  def parse_expression(string)
    Mutant::Config::DEFAULT.expression_parser.(string)
  end
end # ParserHelper

module XSpecHelper
  def verify_events
    expectations = raw_expectations
      .map(&XSpec::MessageExpectation.method(:parse))

    XSpec::ExpectationVerifier.verify(self, expectations) do
      yield
    end
  end

  def undefined
    double('undefined')
  end
end # XSpecHelper

RSpec.configure do |config|
  config.extend(SharedContext)
  config.include(ParserHelper)
  config.include(Mutant::AST::Sexp)
  config.include(XSpecHelper)

  config.after(:suite) do
    $stderr = STDERR

    # The warning mechanism cannot currently make individual specs fail.
    # Instead the warning mechanism causes a nonzero killfork exit without
    # making specs fail. This gets detected as a valid isolation error.
    #
    # Before we can make warnings kill mutations we need to change the
    # warning mechanism to cause individual spec failures.
    unless $ARGV.include?('--zombie')
      MutantSpec::Warning.assert_no_warnings
    end
  end
end
