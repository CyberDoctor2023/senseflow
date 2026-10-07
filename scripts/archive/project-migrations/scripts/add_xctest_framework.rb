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

puts "🔧 Adding XCTest framework to test target..."

# Find XCTest framework
xctest_framework = project.frameworks_group.files.find { |f| f.path =~ /XCTest\.framework/ }

unless xctest_framework
  # Add XCTest framework reference
  xctest_framework = project.frameworks_group.new_file('Platforms/MacOSX.platform/Developer/Library/Frameworks/XCTest.framework')
  xctest_framework.source_tree = 'DEVELOPER_DIR'
  puts "  ✅ Created XCTest framework reference"
end

# Add to frameworks build phase if not already there
frameworks_phase = test_target.frameworks_build_phase
unless frameworks_phase.files.any? { |f| f.file_ref == xctest_framework }
  frameworks_phase.add_file_reference(xctest_framework)
  puts "  ✅ Added XCTest to frameworks build phase"
else
  puts "  ℹ️  XCTest already in frameworks build phase"
end

# Save project
project.save

puts "✅ XCTest framework configuration complete"
