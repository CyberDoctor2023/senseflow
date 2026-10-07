#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find test target
test_target = project.targets.find { |t| t.name == 'SenseFlowTests' }

unless test_target
  puts "❌ Test target not found"
  exit 1
end

puts "🔧 Explicitly disabling code coverage in test target..."

# Disable code coverage for all configurations
test_target.build_configurations.each do |config|
  config.build_settings['CLANG_ENABLE_CODE_COVERAGE'] = 'NO'
  config.build_settings['GCC_INSTRUMENT_PROGRAM_FLOW_ARCS'] = 'NO'
  config.build_settings['GCC_GENERATE_TEST_COVERAGE_FILES'] = 'NO'
  puts "  ✅ #{config.name}: Code coverage disabled"
end

# Save project
project.save

puts "✅ Code coverage settings updated"
