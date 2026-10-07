#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('SenseFlow.xcodeproj')

fixed = 0

project.files.each do |file_ref|
  # 修复 SearchBarConfig - 从 "Models/SearchBarConfig.swift" 改为 "SearchBarConfig.swift"
  if file_ref.path == "Models/SearchBarConfig.swift"
    puts "修复: #{file_ref.path} -> SearchBarConfig.swift"
    file_ref.path = "SearchBarConfig.swift"
    fixed += 1
  end

  # 修复 SearchBarButton - 从 "Views/Components/..." 改为 "Components/..."
  if file_ref.path == "Views/Components/SearchBarButton.swift"
    puts "修复: #{file_ref.path} -> Components/SearchBarButton.swift"
    file_ref.path = "Components/SearchBarButton.swift"
    fixed += 1
  end

  # 修复 SearchBarContainer
  if file_ref.path == "Views/Components/SearchBarContainer.swift"
    puts "修复: #{file_ref.path} -> Components/SearchBarContainer.swift"
    file_ref.path = "Components/SearchBarContainer.swift"
    fixed += 1
  end
end

project.save
puts "\n✅ 修复了 #{fixed} 个文件路径"
