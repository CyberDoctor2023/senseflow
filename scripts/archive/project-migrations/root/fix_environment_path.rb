#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到主 target
main_target = project.targets.find { |t| t.name == 'SenseFlow' }

# 先删除错误的引用
wrong_file = main_target.source_build_phase.files.find do |file|
  file.file_ref&.path&.include?('EnvironmentValues+WindowLayout.swift')
end

if wrong_file
  main_target.source_build_phase.files.delete(wrong_file)
  wrong_file.file_ref.remove_from_project
  puts "✅ 已删除错误的文件引用"
end

# 创建或找到 Extensions 组
main_group = project.main_group['SenseFlow']
extensions_group = main_group['Extensions'] || main_group.new_group('Extensions')

# 添加正确的文件引用（只用文件名，不包含 Extensions/ 前缀）
file_ref = extensions_group.new_file('EnvironmentValues+WindowLayout.swift')
main_target.add_file_references([file_ref])

project.save
puts "✅ 已添加 EnvironmentValues+WindowLayout.swift 到项目（正确路径）"
