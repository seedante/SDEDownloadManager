Pod::Spec.new do |s|
  s.name         = 'SDEDownloadManager'
  s.version      = '0.9.0'
  s.summary      = 'A pure Swift implemented library to download file from the web.'
  s.description  = <<-DESC

                   SDEDownloadManager is a download management library, which is written with Swift and is
                   compatible with Objective-C.

                   The same name class SDEDownloadManager provides download management features. And,
                   a UITableViewController subclass, DownloadListController, coordinates with
                   SDEDownloadManager to display and manage download tasks, and track download activity.

                   DESC

  s.homepage     = 'https://github.com/seedante/SDEDownloadManager'

  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'seedante' => 'seedante@gmail.com' }
  s.platform     = :ios, '8.0'
  s.swift_version = '4.0'

  s.source       = { :git => "https://github.com/seedante/SDEDownloadManager.git", :tag => s.version }
  s.source_files = ['SDEDownloadManager/**/*.swift', 'SDEDownloadManager/SDEDownloadManager.h']
  s.exclude_files = 'SDEDownloadManager/FeatureTests'
  s.resources = ['SDEDownloadManager/Assets/*.xcassets', 'SDEDownloadManager/LocalizableFiles/**/*.strings']
  s.public_header_files = 'SDEDownloadManager/SDEDownloadManager.h'

end
