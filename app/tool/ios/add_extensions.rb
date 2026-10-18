# Adds the iOS home-screen widget and "Share → Unstuck" extensions to
# ios/Runner.xcodeproj, plus the App Group they share with the app.
# Already applied and committed; kept so the project file can be rebuilt
# after `flutter create` or a hand edit gone wrong. Idempotent.
#
#   gem install xcodeproj   # once
#   ruby tool/ios/add_extensions.rb   (from app/)
require 'xcodeproj'

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
xcconfig = {
  'Debug' => project.files.find { |f| f.path == 'Flutter/Debug.xcconfig' },
  'Release' => project.files.find { |f| f.path == 'Flutter/Release.xcconfig' },
  'Profile' => project.files.find { |f| f.path == 'Flutter/Release.xcconfig' },
}

runner.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
unless project.main_group['Runner'].files.any? { |f| f.path == 'Runner.entitlements' }
  project.main_group['Runner'].new_file('Runner.entitlements')
end

embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
unless embed
  embed = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed.name = 'Embed Foundation Extensions'
  embed.symbol_dst_subfolder_spec = :plug_ins
  # Before Flutter's script phases, or Xcode reports a dependency cycle.
  index = runner.build_phases.index(runner.frameworks_build_phase) + 1
  runner.build_phases.insert(index, embed)
end

def add_extension(project, runner, embed, xcconfig, name, suffix, sources, frameworks)
  return if project.targets.any? { |t| t.name == name }

  target = project.new_target(:app_extension, name, :ios, '15.0', nil, :swift)
  group = project.main_group.new_group(name, name)
  refs = sources.map { |s| group.new_file(s) }
  target.add_file_references(refs)
  group.new_file('Info.plist')
  group.new_file("#{name}.entitlements")
  target.add_system_frameworks(frameworks)

  target.build_configurations.each do |c|
    c.base_configuration_reference = xcconfig[c.name] || xcconfig['Release']
    s = c.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = "com.adhdtax.adhdTax.#{suffix}"
    s['PRODUCT_NAME'] = '$(TARGET_NAME)'
    s['INFOPLIST_FILE'] = "#{name}/Info.plist"
    s['GENERATE_INFOPLIST_FILE'] = 'NO'
    s['CODE_SIGN_ENTITLEMENTS'] = "#{name}/#{name}.entitlements"
    s['CODE_SIGN_STYLE'] = 'Automatic'
    s['SWIFT_VERSION'] = '5.0'
    s['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    s['TARGETED_DEVICE_FAMILY'] = '1,2'
    s['SKIP_INSTALL'] = 'YES'
    s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
    s['LD_RUNPATH_SEARCH_PATHS'] = [
      '$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'
    ]
  end

  runner.add_dependency(target)
  file = embed.add_file_reference(target.product_reference, true)
  file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

add_extension(project, runner, embed, xcconfig, 'UnstuckWidget', 'Widget',
              ['UnstuckWidget.swift'], ['WidgetKit', 'SwiftUI'])
add_extension(project, runner, embed, xcconfig, 'UnstuckShare', 'Share',
              ['ShareViewController.swift'], ['Social', 'UniformTypeIdentifiers'])

# A Profile configuration for the extensions too (Flutter's third config).
project.targets.each do |t|
  next if t.build_configurations.any? { |c| c.name == 'Profile' }
  release = t.build_configurations.find { |c| c.name == 'Release' }
  next unless release
  profile = t.add_build_configuration('Profile', :release)
  profile.build_settings = release.build_settings.dup
  profile.base_configuration_reference = release.base_configuration_reference
end

project.save
puts 'ios/Runner.xcodeproj updated'
