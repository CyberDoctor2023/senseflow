#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'SenseFlow.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find main target
main_target = project.targets.find { |t| t.name == 'SenseFlow' }

unless main_target
  puts "❌ Main target not found"
  exit 1
end

puts "🔧 Adding missing package products to main target..."

# Package products to add
missing_products = [
  'OpenTracingShim-experimental',
  'GoogleGenerativeAI',
  'OpenTelemetryProtocolExporter',
  'OpenTelemetryProtocolExporterHTTP',
  'SQLite',
  'OpenAI'
]

missing_products.each do |product_name|
  # Check if already added
  already_added = main_target.frameworks_build_phase.files.any? do |file|
    file.display_name == product_name
  end

  if already_added
    puts "  ℹ️  #{product_name} already added"
    next
  end

  # Find the package product reference
  package_product = project.root_object.project_references.flat_map do |ref|
    ref[:product_group].children
  end.find { |product| product.display_name == product_name }

  if package_product
    main_target.frameworks_build_phase.add_file_reference(package_product)
    puts "  ✅ Added #{product_name}"
  else
    puts "  ⚠️  #{product_name} not found in project"
  end
end

# Save project
project.save

puts "✅ Package products configuration complete"
