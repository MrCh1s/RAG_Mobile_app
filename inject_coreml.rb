require 'xcodeproj'

project_path = 'apps/ios_app/MLCChat/MLCChat.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'MLCChat' }
group = project.main_group.find_subpath('MLCChat', true)

# 1. Add swift-transformers SPM package
package_url = "https://github.com/huggingface/swift-transformers"
requirement = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference::Requirement.upToNextMajorVersion('0.1.7')

package_ref = project.root_object.package_references.find { |p| p.repositoryURL == package_url }
if package_ref.nil?
    package_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    package_ref.repositoryURL = package_url
    package_ref.requirement = requirement
    project.root_object.package_references << package_ref
end

dependency = target.package_product_dependencies.find { |d| d.product_name == 'Transformers' }
if dependency.nil?
    dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    dependency.product_name = 'Transformers'
    dependency.package = package_ref
    
    build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.product_ref = dependency
    
    target.frameworks_build_phase.files << build_file
    target.package_product_dependencies << dependency
end

# 2. Add VietnameseSBERT.mlpackage
file_ref = group.files.find { |f| f.path == 'VietnameseSBERT.mlpackage' }
if file_ref.nil?
    file_ref = group.new_file('VietnameseSBERT.mlpackage')
    build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.file_ref = file_ref
    target.sources_build_phase.files << build_file
end

# 3. Add VietnameseSBERT_Tokenizer folder reference
tokenizer_ref = group.files.find { |f| f.path == 'VietnameseSBERT_Tokenizer' }
if tokenizer_ref.nil?
    tokenizer_ref = group.new_reference('VietnameseSBERT_Tokenizer')
    build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.file_ref = tokenizer_ref
    target.resources_build_phase.files << build_file
end

project.save
puts "Successfully injected swift-transformers, VietnameseSBERT.mlpackage, and Tokenizer into Xcode project."
