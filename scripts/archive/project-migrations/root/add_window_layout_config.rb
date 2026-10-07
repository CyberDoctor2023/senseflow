#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到 Models 组
models_group = project.main_group['SenseFlow']['Models']

# 添加新文件
file_ref = models_group.new_file('WindowLayoutConfig.swift')

# 添加到 target
target = project.targets.first
target.add_file_references([file_ref])

project.save
puts "✅ 已添加 WindowLayoutConfig.swift 到项目"
