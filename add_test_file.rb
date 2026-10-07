#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到测试 target
test_target = project.targets.find { |t| t.name == 'SenseFlowTests' }

if test_target.nil?
  puts "❌ 找不到 SenseFlowTests target"
  exit 1
end

# 创建或找到 Tests 组
main_group = project.main_group
tests_group = main_group['Tests'] || main_group.new_group('Tests')

# 添加测试文件
file_ref = tests_group.new_file('Tests/WindowLayoutConfigTests.swift')
test_target.add_file_references([file_ref])

project.save
puts "✅ 已添加 WindowLayoutConfigTests.swift 到测试 target"
