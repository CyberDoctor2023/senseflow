#!/usr/bin/env ruby
# fix_constants_path.rb
# Fix Constants.swift file reference path in Xcode project

require 'xcodeproj'

project_path = '/Users/jack/Documents/AI_clipboard/SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find Constants.swift file reference
constants_ref = nil
project.main_group.recursive_children.each do |item|
  if item.is_a?(Xcodeproj::Project::Object::PBXFileReference) && item.path == 'Constants.swift'
    constants_ref = item
    break
  end
end

if constants_ref
  puts "Found Constants.swift reference"
  puts "Current path: #{constants_ref.real_path}"

  # The path should be relative to the Styles group
  # which is at SenseFlow/Styles/
  constants_ref.path = 'Constants.swift'

  # Make sure it's in the Styles group
  styles_group = project.main_group['SenseFlow']&.[]('Styles')
  if styles_group && !styles_group.children.include?(constants_ref)
    puts "Adding to Styles group"
    styles_group << constants_ref
  end

  project.save
  puts "✅ Fixed Constants.swift path"
else
  puts "❌ Constants.swift reference not found in project"
end
