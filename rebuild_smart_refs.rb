#!/usr/bin/env ruby
# Completely rebuild Smart file references in Xcode project

require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get main target
target = project.targets.first

# Remove ALL existing Smart file references
smart_files = [
  'ScreenCaptureManager.swift',
  'SmartToolManager.swift',
  'SmartContext.swift',
  'SmartRecommendation.swift',
  'SmartRecommendationView.swift'
]

# Remove from build phase
target.source_build_phase.files.to_a.each do |build_file|
  if build_file.file_ref && smart_files.include?(build_file.file_ref.name || build_file.file_ref.path)
    target.source_build_phase.files.delete(build_file)
    puts "Removed build file: #{build_file.file_ref.name}"
  end
end

# Remove file references from groups
managers_group = project.main_group['SenseFlow']['Managers']
models_group = project.main_group['SenseFlow']['Models']
views_group = project.main_group['SenseFlow']['Views']

[managers_group, models_group, views_group].each do |group|
  group.files.to_a.each do |file_ref|
    if smart_files.include?(file_ref.name || file_ref.path)
      file_ref.remove_from_project
      puts "Removed file reference: #{file_ref.name}"
    end
  end
end

# Now add them back correctly
manager_files = {
  'ScreenCaptureManager.swift' => managers_group,
  'SmartToolManager.swift' => managers_group
}

model_files = {
  'SmartContext.swift' => models_group,
  'SmartRecommendation.swift' => models_group
}

view_files = {
  'SmartRecommendationView.swift' => views_group
}

# Add managers
manager_files.each do |filename, group|
  file_ref = group.new_reference(filename)
  file_ref.set_source_tree('<group>')
  target.add_file_references([file_ref])
  puts "Added #{filename} to Managers"
end

# Add models
model_files.each do |filename, group|
  file_ref = group.new_reference(filename)
  file_ref.set_source_tree('<group>')
  target.add_file_references([file_ref])
  puts "Added #{filename} to Models"
end

# Add views
view_files.each do |filename, group|
  file_ref = group.new_reference(filename)
  file_ref.set_source_tree('<group>')
  target.add_file_references([file_ref])
  puts "Added #{filename} to Views"
end

# Save project
project.save

puts "\nSuccessfully rebuilt all Smart file references"
