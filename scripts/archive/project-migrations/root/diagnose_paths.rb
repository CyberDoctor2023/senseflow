#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('SenseFlow.xcodeproj')

puts "=== 检查文件引用 ==="
project.files.each do |file_ref|
  next unless file_ref.path =~ /SearchBar/
  puts "File: #{file_ref.path}"
  puts "  Real path: #{file_ref.real_path}"
  puts "  Source tree: #{file_ref.source_tree}"

  # 检查父组
  parent = file_ref.parent
  while parent
    puts "  Parent: #{parent.display_name} (path: #{parent.path})" if parent.respond_to?(:display_name)
    parent = parent.parent
  end
  puts
end

puts "\n=== 检查 Models 组 ==="
project.groups.each do |group|
  if group.display_name == "Models"
    puts "Models group path: #{group.path}"
    puts "Models group hierarchy path: #{group.hierarchy_path}"
  end
end

puts "\n=== 检查 Views 组 ==="
project.groups.each do |group|
  if group.display_name == "Views"
    puts "Views group path: #{group.path}"
    puts "Views group hierarchy path: #{group.hierarchy_path}"
  end
end
