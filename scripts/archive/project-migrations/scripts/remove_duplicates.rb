#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

main_target = project.targets.find { |t| t.name == 'SenseFlow' }

puts "🔧 Removing duplicate AppDependencies references..."

# Count and remove all AppDependencies build file references
count = 0
main_target.source_build_phase.files.to_a.each do |file|
  if file.file_ref&.path&.include?('AppDependencies')
    main_target.source_build_phase.files.delete(file)
    count += 1
  end
end

puts "  ✅ Removed #{count} build file references"

# Find the file reference
aiclipboard_group = project.main_group.children.find { |g| g.display_name == 'SenseFlow' }
infrastructure_group = aiclipboard_group&.children&.find { |g| g.display_name == 'Infrastructure' }
di_group = infrastructure_group&.children&.find { |g| g.display_name == 'DI' }

if di_group
  file_ref = di_group.children.find { |f| f.path == 'AppDependencies.swift' }

  if file_ref
    # Add it back ONCE
    main_target.source_build_phase.add_file_reference(file_ref)
    puts "  ✅ Added AppDependencies.swift once"
  else
    puts "  ❌ Could not find AppDependencies.swift file reference"
    exit 1
  end
else
  puts "  ❌ Could not find DI group"
  exit 1
end

project.save
puts "✅ Duplicates removed"
