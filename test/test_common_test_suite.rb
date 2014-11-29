require File.expand_path('../test_helper', __FILE__)
require 'webmock'
require 'json'

class CommonTestSuiteTest < Minitest::Test
  TEST_DIR = File.expand_path('../test-suite/tests', __FILE__)

  # These are test files which we know fail spectacularly, either because we
  # don't support that functionality or because they require external
  # dependencies.  To allow finer-grained control over which tests to run,
  # you can replace `:all` with an array containing the names of individual
  # tests to skip.
  IGNORED_TESTS = Hash.new { |h,k| h[k] = [] }.merge({
    "draft3/optional/jsregex.json" => :all,
    "draft3/optional/format.json" => [
      "validation of regular expressions",
      "validation of e-mail addresses",
      "validation of URIs",
      "validation of host names",
      "validation of CSS colors"
    ],
    "draft4/optional/format.json" => [
      "validation of URIs",
      "validation of e-mail addresses",
      "validation of host names"
    ]
  })

  include WebMock::API

  def setup
    WebMock.enable!

    Dir["#{TEST_DIR}/../remotes/**/*.json"].each do |path|
      schema = path.sub(%r{^.*/remotes/}, '')
      stub_request(:get, "http://localhost:1234/#{schema}").
        to_return(:body => File.read(path), :status => 200)
    end
  end

  def teardown
    WebMock.disable!
    WebMock.reset!
  end

  Dir["#{TEST_DIR}/*"].each do |suite|
    version = File.basename(suite).to_sym
    Dir["#{suite}/**/*.json"].each do |tfile|
      test_list = JSON.parse(File.read(tfile))
      rel_file = tfile[TEST_DIR.length+1..-1]

      test_list.each do |test|
        schema = test["schema"]
        base_description = test["description"]

        test["tests"].each do |t|
          next if IGNORED_TESTS[rel_file] == :all
          next if IGNORED_TESTS[rel_file].any? { |test|
            base_description == test || "#{base_description}/#{t['description']}" == test
          }

          err_id = "#{rel_file}: #{base_description}/#{t['description']}"
          define_method("test_#{err_id}") do
            errors = JSON::Validator.fully_validate(schema,
              t["data"],
              :validate_schema => true,
              :version => version
            )
            assert_equal t["valid"], errors.empty?, "Common test suite case failed: #{err_id}"
          end
        end
      end
    end
  end
end
