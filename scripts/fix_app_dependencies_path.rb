#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

main_target = project.targets.find { |t| t.name == 'SenseFlow' }

puts "🔧 Fixing AppDependencies.swift path..."

# Remove all references to AppDependencies.swift
main_target.source_build_phase.files.each do |file|
  if file.file_ref&.path&.include?('AppDependencies.swift')
    main_target.source_build_phase.files.delete(file)
    puts "  ✅ Removed incorrect reference"
  end
end

# Find the file reference in the project
project.files.each do |file|
  if file.path&.include?('AppDependencies.swift')
    file.remove_from_project
    puts "  ✅ Removed file reference"
  end
end

# Find SenseFlow group
aiclipboard_group = project.main_group.children.find { |g| g.display_name == 'SenseFlow' }

# Find Infrastructure/DI group
infrastructure_group = aiclipboard_group&.children&.find { |g| g.display_name == 'Infrastructure' }
di_group = infrastructure_group&.children&.find { |g| g.display_name == 'DI' }

if di_group
  # Add file with correct relative path
  file_ref = di_group.new_file('Infrastructure/DI/AppDependencies.swift')
  main_target.source_build_phase.add_file_reference(file_ref)
  puts "  ✅ Added AppDependencies.swift with correct path"
else
  puts "  ❌ Could not find DI group"
  exit 1
end

project.save
puts "✅ Path fixed"
