require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 找到所有本地包引用
local_packages = project.root_object.package_references.select do |ref|
  ref.isa == 'XCLocalSwiftPackageReference'
end

puts "找到 #{local_packages.count} 个本地包引用:"
local_packages.each do |pkg|
  puts "  - #{pkg.relative_path}"
end

if local_packages.any?
  # 收集所有需要移除的产品依赖
  products_to_remove = []

  local_packages.each do |pkg|
    # 找到这个包的所有产品
    project.root_object.project_references.each do |proj_ref|
      if proj_ref[:project_ref] == pkg
        products_to_remove << proj_ref
      end
    end
  end

  # 移除所有 target 中的本地包产品依赖
  project.targets.each do |target|
    target.package_product_dependencies.dup.each do |dep|
      if dep.package == local_packages.first || dep.product_name == 'PeekabooAutomationKit'
        puts "从 target #{target.name} 移除 #{dep.product_name}"
        target.package_product_dependencies.delete(dep)
        dep.remove_from_project
      end
    end
  end

  # 移除所有本地包引用
  local_packages.each do |pkg|
    puts "移除本地包: #{pkg.relative_path}"
    project.root_object.package_references.delete(pkg)
    pkg.remove_from_project
  end

  project.save
  puts "\n✅ 已移除所有本地包引用"
else
  puts "未找到本地包引用"
end
