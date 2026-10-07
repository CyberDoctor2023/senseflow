#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('SenseFlow.xcodeproj')

fixed = 0

# 递归查找所有组
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

# 修复 Models 组
models_group = find_group_by_name(project.main_group, "Models")
if models_group && models_group.path == "Models"
  puts "修复 Models 组: path=#{models_group.path} -> path=nil"
  models_group.path = nil
  fixed += 1
end

# 修复 Views 组
views_group = find_group_by_name(project.main_group, "Views")
if views_group && views_group.path == "Views"
  puts "修复 Views 组: path=#{views_group.path} -> path=nil"
  views_group.path = nil
  fixed += 1
end

# 修复 Components 组
if views_group
  components_group = find_group_by_name(views_group, "Components")
  if components_group && components_group.path == "Components"
    puts "修复 Components 组: path=#{components_group.path} -> path=nil"
    components_group.path = nil
    fixed += 1
  end
end

project.save
puts "\n✅ 修复了 #{fixed} 个组路径"
