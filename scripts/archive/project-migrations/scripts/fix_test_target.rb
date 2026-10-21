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

puts "🔧 Configuring test target build settings..."

# Configure build settings for all configurations
test_target.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.aiclipboard.SenseFlowTests'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['ENABLE_TESTING_SEARCH_PATHS'] = 'YES'

  puts "  ✅ #{config.name}: Swift 6.0, auto-generated Info.plist"
end

# Save project
project.save

puts "✅ Test target configuration complete"
