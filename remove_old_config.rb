#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到并删除旧配置文件的引用
target = project.targets.first
old_file = target.source_build_phase.files.find do |file|
  file.file_ref&.path == 'ClipboardCardLayoutConfig.swift'
end

if old_file
  target.source_build_phase.files.delete(old_file)
  old_file.file_ref.remove_from_project
  puts "✅ 已删除 ClipboardCardLayoutConfig.swift 的引用"
else
  puts "⚠️  未找到文件引用"
end

project.save
