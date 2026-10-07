#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 创建或找到 Protocols 组
main_group = project.main_group['SenseFlow']
protocols_group = main_group['Protocols'] || main_group.new_group('Protocols')

# 添加新文件
file_ref = protocols_group.new_file('WindowLayoutConfigurable.swift')

# 添加到 target
target = project.targets.first
target.add_file_references([file_ref])

project.save
puts "✅ 已添加 WindowLayoutConfigurable.swift 到项目"
