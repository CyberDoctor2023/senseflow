#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

main_target = project.targets.find { |t| t.name == 'SenseFlow' }

puts "🔧 Completely removing and re-adding AppDependencies.swift..."

# Remove all build file references
main_target.source_build_phase.files.to_a.each do |file|
  if file.file_ref&.path&.include?('AppDependencies')
    main_target.source_build_phase.files.delete(file)
    puts "  ✅ Removed build file reference"
  end
end

# Remove all file references from project
project.files.to_a.each do |file|
  if file.path&.include?('AppDependencies')
    file.remove_from_project
    puts "  ✅ Removed file reference from project"
  end
end

# Find groups
aiclipboard_group = project.main_group.children.find { |g| g.display_name == 'SenseFlow' }
infrastructure_group = aiclipboard_group&.children&.find { |g| g.display_name == 'Infrastructure' }
di_group = infrastructure_group&.children&.find { |g| g.display_name == 'DI' }

if di_group
  puts "  DI group path: #{di_group.real_path}"

  # Add file with just the filename (group already has the path)
  file_ref = di_group.new_file('AppDependencies.swift')
  file_ref.source_tree = '<group>'

  main_target.source_build_phase.add_file_reference(file_ref)
  puts "  ✅ Added AppDependencies.swift (filename only)"
else
  puts "  ❌ Could not find DI group"
  exit 1
end

project.save
puts "✅ Fixed"
