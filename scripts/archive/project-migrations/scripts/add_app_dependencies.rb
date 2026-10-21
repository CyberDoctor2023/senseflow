#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

main_target = project.targets.find { |t| t.name == 'SenseFlow' }

unless main_target
  puts "❌ Main target not found"
  exit 1
end

puts "🔧 Adding AppDependencies.swift to Xcode project..."

# Find or create SenseFlow group
aiclipboard_group = project.main_group.children.find { |g| g.display_name == 'SenseFlow' }

unless aiclipboard_group
  puts "❌ SenseFlow group not found"
  exit 1
end

# Find or create Infrastructure group
infrastructure_group = aiclipboard_group.children.find { |g| g.display_name == 'Infrastructure' }

unless infrastructure_group
  infrastructure_group = aiclipboard_group.new_group('Infrastructure', 'SenseFlow/Infrastructure')
  puts "  ✅ Created Infrastructure group"
end

# Find or create DI group
di_group = infrastructure_group.children.find { |g| g.display_name == 'DI' }

unless di_group
  di_group = infrastructure_group.new_group('DI', 'SenseFlow/Infrastructure/DI')
  puts "  ✅ Created DI group"
end

# Add AppDependencies.swift
file_ref = di_group.new_file('SenseFlow/Infrastructure/DI/AppDependencies.swift')
main_target.source_build_phase.add_file_reference(file_ref)
puts "  ✅ Added AppDependencies.swift"

project.save
puts "✅ Xcode project updated"
