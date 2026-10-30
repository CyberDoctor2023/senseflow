#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('SenseFlow.xcodeproj')

# 递归查找组
def find_group_by_name(group, name)
  return group if group.display_name == name
  group.children.each do |child|
    if child.is_a?(Xcodeproj::Project::Object::PBXGroup)
      result = find_group_by_name(child, name)
      return result if result
    end
  end
  nil
end

# 检查 Models 组
models_group = find_group_by_name(project.main_group, "Models")
if models_group
  puts "Models 组:"
  puts "  path: #{models_group.path.inspect}"
  puts "  source_tree: #{models_group.source_tree}"
  puts "  子文件:"
  models_group.files.each do |file|
    puts "    - #{file.path} (real: #{file.real_path})"
  end
end

puts "\n" + "="*50 + "\n"

# 检查 Views 组
views_group = find_group_by_name(project.main_group, "Views")
if views_group
  puts "Views 组:"
  puts "  path: #{views_group.path.inspect}"

  components_group = find_group_by_name(views_group, "Components")
  if components_group
    puts "\nComponents 子组:"
    puts "  path: #{components_group.path.inspect}"
    puts "  子文件:"
    components_group.files.each do |file|
      puts "    - #{file.path} (real: #{file.real_path})"
    end
  end
end
