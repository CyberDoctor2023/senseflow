#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 需要修复的错误路径
wrong_paths = {
  'SenseFlow/Views/Views/Components/SearchBarContainer.swift' => 'SenseFlow/Views/Components/SearchBarContainer.swift',
  'SenseFlow/Views/Views/Components/SearchBarButton.swift' => 'SenseFlow/Views/Components/SearchBarButton.swift',
  'SenseFlow/Models/Models/SearchBarConfig.swift' => 'SenseFlow/Models/SearchBarConfig.swift'
}

fixed_count = 0

# 递归遍历所有对象
project.objects.each do |obj|
  if obj.respond_to?(:path) && obj.path && wrong_paths.key?(obj.path)
    puts "修复 path: #{obj.path} -> #{wrong_paths[obj.path]}"
    obj.path = wrong_paths[obj.path]
    fixed_count += 1
  end

  if obj.respond_to?(:source_tree) && obj.respond_to?(:path)
    # 检查完整路径
    full_path = obj.path
    if full_path && wrong_paths.key?(full_path)
      puts "修复 full_path: #{full_path} -> #{wrong_paths[full_path]}"
      obj.path = wrong_paths[full_path]
      fixed_count += 1
    end
  end
end

# 检查 build files
project.targets.each do |target|
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref && build_file.file_ref.path
      path = build_file.file_ref.path
      if wrong_paths.key?(path)
        puts "修复 build_file: #{path} -> #{wrong_paths[path]}"
        build_file.file_ref.path = wrong_paths[path]
        fixed_count += 1
      end
    end
  end
end

project.save
puts "\n✅ 修复了 #{fixed_count} 个路径引用"
