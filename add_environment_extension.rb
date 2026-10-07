#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到主 target
main_target = project.targets.find { |t| t.name == 'SenseFlow' }

# 创建或找到 Extensions 组
main_group = project.main_group['SenseFlow']
extensions_group = main_group['Extensions'] || main_group.new_group('Extensions')

# 添加 Environment 扩展文件
file_ref = extensions_group.new_file('Extensions/EnvironmentValues+WindowLayout.swift')
main_target.add_file_references([file_ref])

project.save
puts "✅ 已添加 EnvironmentValues+WindowLayout.swift 到项目"
