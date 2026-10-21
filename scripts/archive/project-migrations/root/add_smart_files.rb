#!/usr/bin/env ruby
# Add Smart feature files to Xcode project

require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get main target
target = project.targets.first

# Get groups
managers_group = project.main_group['SenseFlow']['Managers']
models_group = project.main_group['SenseFlow']['Models']
views_group = project.main_group['SenseFlow']['Views']

# Files to add
managers_files = [
  'SenseFlow/Managers/ScreenCaptureManager.swift',
  'SenseFlow/Managers/SmartToolManager.swift'
]

models_files = [
  'SenseFlow/Models/SmartContext.swift',
  'SenseFlow/Models/SmartRecommendation.swift'
]

views_files = [
  'SenseFlow/Views/SmartRecommendationView.swift'
]

# Add manager files
managers_files.each do |file_path|
  file_name = File.basename(file_path)
  next if managers_group.files.any? { |f| f.path == file_name }

  file_ref = managers_group.new_file(file_path)
  target.add_file_references([file_ref])
  puts "Added #{file_name} to Managers group"
end

# Add model files
models_files.each do |file_path|
  file_name = File.basename(file_path)
  next if models_group.files.any? { |f| f.path == file_name }

  file_ref = models_group.new_file(file_path)
  target.add_file_references([file_ref])
  puts "Added #{file_name} to Models group"
end

# Add view files
views_files.each do |file_path|
  file_name = File.basename(file_path)
  next if views_group.files.any? { |f| f.path == file_name }

  file_ref = views_group.new_file(file_path)
  target.add_file_references([file_ref])
  puts "Added #{file_name} to Views group"
end

# Save project
project.save

puts "Successfully updated Xcode project"
