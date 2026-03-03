#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到 Views 组
views_group = project.main_group['SenseFlow']['Views']

# 添加新文件
file_ref = views_group.new_file('EmptyBackgroundView.swift')

# 添加到 target
target = project.targets.first
target.add_file_references([file_ref])

project.save
puts "✅ 已添加 EmptyBackgroundView.swift 到项目"
