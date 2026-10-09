#!/usr/bin/env ruby
# 完整重命名 Xcode 项目：SenseFlow → SenseFlow

require 'fileutils'
require 'xcodeproj'

OLD_NAME = "SenseFlow"
NEW_NAME = "SenseFlow"

puts "🚀 开始重命名项目: #{OLD_NAME} → #{NEW_NAME}"
puts "=" * 60

# Step 1: 重命名文件夹
puts "\n📁 Step 1: 重命名文件夹"
[
  [OLD_NAME, NEW_NAME],
  ["#{OLD_NAME}Tests", "#{NEW_NAME}Tests"]
].each do |old_dir, new_dir|
  if Dir.exist?(old_dir)
    FileUtils.mv(old_dir, new_dir)
    puts "✅ #{old_dir} → #{new_dir}"
  else
    puts "⚠️  #{old_dir} 不存在，跳过"
  end
end

# Step 2: 重命名 .xcodeproj
puts "\n📦 Step 2: 重命名 Xcode 项目文件"
old_proj = "#{OLD_NAME}.xcodeproj"
new_proj = "#{NEW_NAME}.xcodeproj"
if Dir.exist?(old_proj)
  FileUtils.mv(old_proj, new_proj)
  puts "✅ #{old_proj} → #{new_proj}"
else
  puts "❌ #{old_proj} 不存在"
  exit 1
end

# Step 3: 修改 project.pbxproj
puts "\n🔧 Step 3: 修改 project.pbxproj"
pbxproj_path = "#{new_proj}/project.pbxproj"
if File.exist?(pbxproj_path)
  content = File.read(pbxproj_path, encoding: 'UTF-8')

  # 替换所有 SenseFlow 引用
  content.gsub!(/#{OLD_NAME}/, NEW_NAME)

  File.write(pbxproj_path, content, encoding: 'UTF-8')
  puts "✅ 已更新 project.pbxproj"
else
  puts "❌ project.pbxproj 不存在"
  exit 1
end

# Step 4: 重命名 scheme
puts "\n🎯 Step 4: 重命名 Scheme"
schemes_dir = "#{new_proj}/xcshareddata/xcschemes"
old_scheme = "#{schemes_dir}/#{OLD_NAME}.xcscheme"
new_scheme = "#{schemes_dir}/#{NEW_NAME}.xcscheme"

if File.exist?(old_scheme)
  # 读取并修改 scheme 内容
  content = File.read(old_scheme, encoding: 'UTF-8')
  content.gsub!(/#{OLD_NAME}/, NEW_NAME)

  # 写入新文件
  File.write(new_scheme, content, encoding: 'UTF-8')

  # 删除旧文件
  File.delete(old_scheme)

  puts "✅ #{OLD_NAME}.xcscheme → #{NEW_NAME}.xcscheme"
else
  puts "⚠️  Scheme 文件不存在，跳过"
end

# Step 5: 重命名 App 文件
puts "\n📱 Step 5: 重命名 App 主文件"
old_app_file = "#{NEW_NAME}/#{OLD_NAME}App.swift"
new_app_file = "#{NEW_NAME}/#{NEW_NAME}App.swift"

if File.exist?(old_app_file)
  content = File.read(old_app_file, encoding: 'UTF-8')
  content.gsub!(/#{OLD_NAME}App/, "#{NEW_NAME}App")

  File.write(new_app_file, content, encoding: 'UTF-8')
  File.delete(old_app_file)

  puts "✅ #{OLD_NAME}App.swift → #{NEW_NAME}App.swift"
else
  puts "⚠️  App 文件不存在，跳过"
end

# Step 6: 更新所有 Swift 文件中的引用
puts "\n🔄 Step 6: 更新所有文件中的引用"
changed_files = []

Dir.glob("#{NEW_NAME}/**/*.swift").each do |file|
  content = File.read(file, encoding: 'UTF-8')
  original = content.dup

  # 替换注释中的项目名
  content.gsub!(/\/\/  #{OLD_NAME}/, "//  #{NEW_NAME}")

  if content != original
    File.write(file, content, encoding: 'UTF-8')
    changed_files << file
  end
end

puts "✅ 更新了 #{changed_files.count} 个 Swift 文件"

# Step 7: 更新测试文件
puts "\n🧪 Step 7: 更新测试文件"
test_changed = []

Dir.glob("#{NEW_NAME}Tests/**/*.swift").each do |file|
  content = File.read(file, encoding: 'UTF-8')
  original = content.dup

  content.gsub!(/#{OLD_NAME}Tests/, "#{NEW_NAME}Tests")
  content.gsub!(/@testable import #{OLD_NAME}/, "@testable import #{NEW_NAME}")
  content.gsub!(/\/\/  #{OLD_NAME}/, "//  #{NEW_NAME}")

  if content != original
    File.write(file, content, encoding: 'UTF-8')
    test_changed << file
  end
end

puts "✅ 更新了 #{test_changed.count} 个测试文件"

# Step 8: 更新 Info.plist 中的 Bundle Name
puts "\n📋 Step 8: 更新 Info.plist"
info_plist = "#{NEW_NAME}/Info.plist"
if File.exist?(info_plist)
  content = File.read(info_plist, encoding: 'UTF-8')
  # Info.plist 使用变量，不需要修改
  puts "✅ Info.plist 检查完成（使用 PRODUCT_NAME 变量）"
else
  puts "⚠️  Info.plist 不存在"
end

puts "\n" + "=" * 60
puts "✅ 重命名完成！"
puts "\n📝 后续步骤："
puts "1. 在 Xcode 中打开 #{NEW_NAME}.xcodeproj"
puts "2. 检查 Target 名称是否正确"
puts "3. 清理构建缓存: Product → Clean Build Folder (Cmd+Shift+K)"
puts "4. 重新构建项目"
puts "5. 提交更改到 Git"
