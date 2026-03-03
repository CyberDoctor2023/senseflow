#!/usr/bin/env ruby
# 添加 AppConstants.swift 到 Xcode 项目

require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到 SenseFlow target
target = project.targets.find { |t| t.name == 'SenseFlow' }

unless target
  puts "❌ 找不到 SenseFlow target"
  exit 1
end

# 找到 Constants 组
constants_group = project.main_group['SenseFlow']['Constants']

unless constants_group
  puts "❌ 找不到 Constants 组"
  exit 1
end

# 检查文件是否已存在
existing_file = constants_group.files.find { |f| f.path == 'AppConstants.swift' }

if existing_file
  puts "⚠️  AppConstants.swift 已存在于项目中"
else
  # 添加文件引用
  file_ref = constants_group.new_file('AppConstants.swift')

  # 添加到 target 的编译阶段
  target.add_file_references([file_ref])

  puts "✅ 已添加 AppConstants.swift 到项目"
end

# 保存项目
project.save

puts "✅ 项目已保存"
