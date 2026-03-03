#!/usr/bin/env ruby
# Clean up duplicate Smart files in Xcode project

require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get main target
target = project.targets.first

# Track file names we've seen
seen_files = {}

# Get all file references in build phase
files_to_remove = []

target.source_build_phase.files.each do |build_file|
  next unless build_file.file_ref

  file_name = build_file.file_ref.name || build_file.file_ref.path

  if seen_files[file_name]
    # Duplicate found
    files_to_remove << build_file
    puts "Found duplicate: #{file_name}"
  else
    seen_files[file_name] = build_file
  end
end

# Remove duplicates
files_to_remove.each do |build_file|
  target.source_build_phase.files.delete(build_file)
  puts "Removed duplicate build file: #{build_file.file_ref.name}"
end

# Save project
project.save

puts "\nCleaned up #{files_to_remove.count} duplicate file(s)"
puts "Xcode project updated successfully"
