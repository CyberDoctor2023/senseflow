#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

main_target = project.targets.find { |t| t.name == 'SenseFlow' }

puts "🔧 Fixing group structure..."

# Find SenseFlow group
aiclipboard_group = project.main_group.children.find { |g| g.display_name == 'SenseFlow' }

# Remove old Infrastructure group if it exists
old_infrastructure = aiclipboard_group&.children&.find { |g| g.display_name == 'Infrastructure' }
if old_infrastructure
  old_infrastructure.remove_from_project
  puts "  ✅ Removed old Infrastructure group"
end

# Create new Infrastructure group with correct path
infrastructure_group = aiclipboard_group.new_group('Infrastructure', 'Infrastructure')
puts "  ✅ Created Infrastructure group at: Infrastructure"

# Create DI group with correct path
di_group = infrastructure_group.new_group('DI', 'DI')
puts "  ✅ Created DI group at: Infrastructure/DI"

# Add AppDependencies.swift
file_ref = di_group.new_file('AppDependencies.swift')
main_target.source_build_phase.add_file_reference(file_ref)
puts "  ✅ Added AppDependencies.swift"

project.save
puts "✅ Group structure fixed"
