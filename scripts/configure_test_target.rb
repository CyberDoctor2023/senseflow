#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find targets
main_target = project.targets.find { |t| t.name == 'SenseFlow' }
test_target = project.targets.find { |t| t.name == 'SenseFlowTests' }

unless main_target && test_target
  puts "❌ Could not find required targets"
  exit 1
end

puts "🔧 Configuring test target dependencies..."

# Add dependency on main target
unless test_target.dependencies.any? { |d| d.target == main_target }
  test_target.add_dependency(main_target)
  puts "  ✅ Added dependency: SenseFlowTests → SenseFlow"
end

# Configure test host
test_target.build_configurations.each do |config|
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/SenseFlow.app/Contents/MacOS/SenseFlow'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  puts "  ✅ #{config.name}: Configured test host"
end

# Save project
project.save

puts "✅ Test target configuration complete"
