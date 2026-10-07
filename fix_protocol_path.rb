#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到或创建 Protocols 组
main_group = project.main_group['SenseFlow']
protocols_group = main_group['Protocols'] || main_group.new_group('Protocols')

# 先删除错误的引用
target = project.targets.first
wrong_file = target.source_build_phase.files.find do |file|
  file.file_ref&.path == 'WindowLayoutConfigurable.swift'
end

if wrong_file
  target.source_build_phase.files.delete(wrong_file)
  wrong_file.file_ref.remove_from_project
  puts "✅ 已删除错误的文件引用"
end

# 添加正确的文件引用（包含 Protocols/ 路径）
file_ref = protocols_group.new_file('Protocols/WindowLayoutConfigurable.swift')
target.add_file_references([file_ref])

project.save
puts "✅ 已添加 WindowLayoutConfigurable.swift 到项目（正确路径）"
