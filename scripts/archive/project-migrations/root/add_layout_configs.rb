#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到 Models 组
models_group = project.main_group['SenseFlow']['Models']

# 添加两个配置文件
['BackgroundLayoutConfig.swift', 'CardAreaLayoutConfig.swift'].each do |filename|
  file_ref = models_group.new_reference(filename)
  project.targets.first.add_file_references([file_ref])
  puts "✅ 已添加 #{filename}"
end

project.save
