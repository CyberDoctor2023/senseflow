#!/usr/bin/env ruby
# 批量替换 SenseFlow 为 SenseFlow

require 'fileutils'

# 需要替换的文件模式
PATTERNS = [
  'SenseFlow/**/*.swift',
  'SenseFlow/**/*.plist',
  'docs/**/*.md',
  'openspec/**/*.md',
  '.claude/**/*.md',
  '.claude/**/*.sh',
  'README.md',
  'CLAUDE.md'
]

# 排除的文件
EXCLUDE_PATTERNS = [
  '.git',
  'build',
  'DerivedData',
  '.xcodeproj',
  'backup'
]

def should_process?(file)
  return false if File.directory?(file)
  return false if EXCLUDE_PATTERNS.any? { |pattern| file.include?(pattern) }
  true
end

def replace_in_file(file)
  return unless should_process?(file)

  content = File.read(file, encoding: 'UTF-8')
  original_content = content.dup

  # 替换 "SenseFlow" 为 "SenseFlow"
  content.gsub!(/SenseFlow/, 'SenseFlow')

  # 只在内容有变化时写入
  if content != original_content
    File.write(file, content, encoding: 'UTF-8')
    puts "✅ #{file}"
    return true
  end

  false
end

# 主逻辑
changed_files = []

PATTERNS.each do |pattern|
  Dir.glob(pattern).each do |file|
    if replace_in_file(file)
      changed_files << file
    end
  end
end

puts "\n📊 统计:"
puts "修改文件数: #{changed_files.count}"
puts "\n修改的文件:"
changed_files.each { |f| puts "  - #{f}" }
