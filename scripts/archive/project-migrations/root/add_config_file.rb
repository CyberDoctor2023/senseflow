#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到 Models 组
models_group = project.main_group['SenseFlow']['Models']

# 添加文件引用
file_ref = models_group.new_reference('ClipboardCardLayoutConfig.swift')

# 添加到编译目标
target = project.targets.first
target.add_file_references([file_ref])

project.save

puts "✅ 已添加 ClipboardCardLayoutConfig.swift 到项目"
