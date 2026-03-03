#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到测试 target
test_target = project.targets.find { |t| t.name == 'SenseFlowTests' }

# 创建或找到 Tests/Mocks 组
tests_group = project.main_group['Tests'] || project.main_group.new_group('Tests')
mocks_group = tests_group['Mocks'] || tests_group.new_group('Mocks')

# 添加 Mock 文件
file_ref = mocks_group.new_file('Tests/Mocks/MockWindowLayoutConfig.swift')
test_target.add_file_references([file_ref])

project.save
puts "✅ 已添加 MockWindowLayoutConfig.swift 到测试 target"
