//
//  ThumbnailCacher.swift
//  SDEDownloadManager
//
//  Created by seedante on 9/19/17.
//
//  Copyright (c) 2017 seedante <seedante@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import AVFoundation
/**
 Thumbnail categories and their fetch order: TypeIcon, custom thumbnail(memory only or stored file), from file self(image and video).
 TypeIcon won't be in the cache, otherwise it could be removed because of cache limit.
 */
internal class ThumbnailCacher {
    unowned let dm: SDEDownloadManager
    init(dm: SDEDownloadManager) {
        self.dm = dm
    }

    lazy var cache: NSCache<NSString, UIImage> = { () -> NSCache<NSString, UIImage> in
        let imageCache = NSCache<NSString, UIImage>.init()
        imageCache.name = self.dm.identifier
        imageCache.countLimit = 300
        return imageCache
    }()

    lazy var ImageTypeIcon: UIImage? = UIImage(named: "Image", in: DownloadManagerBundle, compatibleWith: nil)
    lazy var AudioTypeIcon: UIImage? = UIImage(named: "Audio", in: DownloadManagerBundle, compatibleWith: nil)
    lazy var MusicTypeIcon: UIImage? = UIImage(named: "Music", in: DownloadManagerBundle, compatibleWith: nil)
    lazy var VideoTypeIcon: UIImage? = UIImage(named: "Video", in: DownloadManagerBundle, compatibleWith: nil)
    lazy var DocumentTypeIcon: UIImage? = UIImage(named: "Document", in: DownloadManagerBundle, compatibleWith: nil)
    lazy var OtherTypeIcon: UIImage? = UIImage(named: "Other", in: DownloadManagerBundle, compatibleWith: nil)
    
    lazy var thumbnailFetchFailedTaskSet: Set<String> = []
    /// Source of thumbnail is short than request height, include: image file, video file, stored custom thumbnail file,
    /// it's dynamic: if source is high than request height, it will be removed.
    /// Custom thumbnail is cached in memory only, it always in the set until this custom thumbnail is removed.
    lazy var thumbnailIsSourceSet: Set<String> = []
    lazy var memoryOnlyTaskSet: Set<String> = []
    
    // MARK: Interface Used in SDEDownloadManager
    func removeThumbnailForTask(_ URLString: String){
        cache.removeObject(forKey: URLString as NSString)
        thumbnailFetchFailedTaskSet.remove(URLString)
        thumbnailIsSourceSet.remove(URLString)
        memoryOnlyTaskSet.remove(URLString)
    }
    
    func emptyCache(){
        cache.removeAllObjects()
        thumbnailFetchFailedTaskSet.removeAll()
        thumbnailIsSourceSet.removeAll()
        memoryOnlyTaskSet.removeAll()
    }
    
    
    // MARK: Helper
    func expectedHeightForSourceSize(_ sourceSize: CGSize, targetHeight: CGFloat) -> CGFloat{
        if sourceSize.width > sourceSize.height{
            return dm.cacheOriginalRatioThumbnail ? CGFloat(Int((sourceSize.height * targetHeight) / sourceSize.width)) : targetHeight
        }else{
            return dm.cacheOriginalRatioThumbnail ? targetHeight : CGFloat(Int((sourceSize.height * targetHeight) / sourceSize.width))
        }
    }

    func thumbnailSizeForSourceSize(_ sourceSize: CGSize, targetHeight: CGFloat) -> CGSize{
        let thumbnailSize: CGSize
        // Thumbnail view is square in DownloadListController.
        if dm.cacheOriginalRatioThumbnail{
            if sourceSize.width > sourceSize.height{
                /*
                 __________
                 |________|
                 |        |
                 |________|
                 |________|
                 
                 */
                thumbnailSize = sourceSize.width <= targetHeight ? sourceSize : CGSize(width: Int(targetHeight), height: Int((sourceSize.height * targetHeight) / sourceSize.width))
            }else{
                /*
                 __________
                 | |    | |
                 | |    | |
                 | |    | |
                 |_|____|_|
                 
                 */
                thumbnailSize = sourceSize.height <= targetHeight ? sourceSize : CGSize(width: Int((targetHeight * sourceSize.width) / sourceSize.height), height: Int(targetHeight))
            }
        }else{
            if sourceSize.width > sourceSize.height{
                /*
             __________________
             |   |        |   |
             |   |        |   |
             |   |        |   |
             |___|________|___|
                 
                 */
                thumbnailSize = sourceSize.height <= targetHeight ? sourceSize : CGSize(width: Int((targetHeight * sourceSize.width) / sourceSize.height), height: Int(targetHeight))
            }else{
                /*
                 __________
                 |________|
                 |        |
                 |        |
                 |        |
                 |________|
                 |________|
                 
                 */
                thumbnailSize = sourceSize.width <= targetHeight ? sourceSize : CGSize(width: Int(targetHeight), height: Int((sourceSize.height * targetHeight) / sourceSize.width))
            }
        }
        return thumbnailSize
    }
    
    // ± 5 points
    func notInAllowedRange(_ value: CGFloat, _ baseValue: CGFloat) -> Bool{
        return value < (baseValue - 5) || value > (baseValue + 5)
    }
    
    // MARK: Fetch Thumbnail
    func requestThumbnail(forTask URLString: String, height targetHeight: CGFloat, orLaterProvideThumbnailInHandler thumbnailHandler: @escaping (_ thumbnail: UIImage) -> Void) -> UIImage?{
        if let thumbnail = cache.object(forKey: URLString as NSString){
            let width = thumbnail.size.width
            let height = thumbnail.size.height
            let requestAgain: Bool
            let isThumbnailLargeThanRequest: Bool
            if width > height{
                isThumbnailLargeThanRequest = dm.cacheOriginalRatioThumbnail ? width > targetHeight : height > targetHeight
                if !isThumbnailLargeThanRequest && thumbnailIsSourceSet.contains(URLString){
                    requestAgain = false
                }else{
                    requestAgain = dm.cacheOriginalRatioThumbnail ? notInAllowedRange(width, targetHeight) : notInAllowedRange(height, targetHeight)
                }
            }else{
                isThumbnailLargeThanRequest = dm.cacheOriginalRatioThumbnail ? height > targetHeight : width > targetHeight
                if !isThumbnailLargeThanRequest && thumbnailIsSourceSet.contains(URLString){
                    requestAgain = false
                }else{
                    requestAgain = dm.cacheOriginalRatioThumbnail ? notInAllowedRange(height, targetHeight) : notInAllowedRange(width, targetHeight)
                }
            }
            
            if requestAgain{
                debugNSLog("No match thumbnail for \(URLString) require height: \(targetHeight). Request in the background.")
                DispatchQueue.global(qos: .background).async(execute: {
                    if isThumbnailLargeThanRequest{
                        if self.memoryOnlyTaskSet.contains(URLString) == false{
                            self.thumbnailIsSourceSet.remove(URLString)
                        }
                        thumbnailHandler(self.resizeImage(thumbnail, toHeight: targetHeight, forTask: URLString))
                    }else if let _ = self.dm.customThumbnailInfo[URLString]{
                        self.fetchCustomThumbnailForTask(URLString, height: targetHeight, thumbnailHandler: thumbnailHandler)
                    }else if let fileType = self.dm.fileType(ofTask: URLString){
                        switch fileType{
                        case ImageType:
                            self.fetchThumbnailForImageTask(URLString, height: targetHeight, completionHandler: thumbnailHandler)
                        case VideoType:
                            self.fetchThumbnailForVideoTask(URLString, height: targetHeight, completionHandler: thumbnailHandler)
                        default: break
                        }
                    }
                })
            }
            return thumbnail
        }
        
        let customThumbnailRelativePath = dm.customThumbnailInfo[URLString]
        if customThumbnailRelativePath != nil{
            DispatchQueue.global(qos: .background).async(execute: {
                self.fetchCustomThumbnailForTask(URLString, height: targetHeight, thumbnailHandler: thumbnailHandler)
            })
        }
        
        guard let fileType = self.dm.fileType(ofTask: URLString) else{return OtherTypeIcon}
        switch fileType {
        case ImageType:
            if dm.downloadState(ofTask: URLString) == .finished{
                DispatchQueue.global(qos: .background).async(execute: {
                    self.fetchThumbnailForImageTask(URLString, height: targetHeight, completionHandler: thumbnailHandler)
                })
            }
            return ImageTypeIcon
        case VideoType:
            if customThumbnailRelativePath == nil && dm.downloadState(ofTask: URLString) == .finished{
                DispatchQueue.global(qos: .background).async(execute: {
                    self.fetchThumbnailForVideoTask(URLString, height: targetHeight, completionHandler: thumbnailHandler)
                })
            }
            return VideoTypeIcon
        case AudioType:
            if let fileExtension = dm.fileExtension(ofTask: URLString){
                if musicFileExtensionMajorSet.contains(fileExtension.lowercased()){
                    return MusicTypeIcon
                }else{
                    return AudioTypeIcon
                }
            }else{
                return AudioTypeIcon
            }
        case DocumentType, OtherType:
            if let fileExtension = dm.fileExtension(ofTask: URLString){
                if let fileExtensionIcon = cache.object(forKey: fileExtension.uppercased() as NSString){
                    return fileExtensionIcon
                }else if let fileExtensionIcon = UIImage(named: fileExtension.uppercased(), in: DownloadManagerBundle, compatibleWith: nil){
                    cache.setObject(fileExtensionIcon, forKey: fileExtension.uppercased() as NSString)
                    return fileExtensionIcon
                }
            }
            return fileType == DocumentType ? DocumentTypeIcon : OtherTypeIcon
        default:
            return OtherTypeIcon
        }
    }
    
    func resizeImage(_ originalImage: UIImage, toHeight height: CGFloat, forTask URLString: String) -> UIImage{
        // use Int size to avoid pixel lack.
        let contextSize: CGSize = thumbnailSizeForSourceSize(originalImage.size, targetHeight: height)
        UIGraphicsBeginImageContextWithOptions(contextSize, false, UIScreen.main.scale)
        originalImage.draw(in: CGRect(origin: CGPoint.zero, size: contextSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        cache.setObject(thumbnail!, forKey: URLString as NSString)
        return thumbnail!
    }
    
    func fetchCustomThumbnailForTask(_ URLString: String, height: CGFloat, thumbnailHandler: (_ thumbnail: UIImage) -> Void){
        let thumbnailPath = NSHomeDirectory() + "/" + dm.customThumbnailInfo[URLString]!
        if let originalImage = UIImage(contentsOfFile: thumbnailPath){
            if originalImage.size.height > expectedHeightForSourceSize(originalImage.size, targetHeight: height){
                thumbnailHandler(resizeImage(originalImage, toHeight: height, forTask: URLString))
            }else{
                thumbnailIsSourceSet.insert(URLString)
                cache.setObject(originalImage, forKey: URLString as NSString)
                thumbnailHandler(originalImage)
            }
        }else{
            dm.customThumbnailInfo[URLString] = nil
        }
    }

    func fetchThumbnailForImageTask(_ URLString: String, height: CGFloat, completionHandler: (_ thumbnail: UIImage) -> Void){
        if let filePath = dm.filePath(ofTask: URLString), let originalImage = UIImage(contentsOfFile: filePath){
            if originalImage.size.height > expectedHeightForSourceSize(originalImage.size, targetHeight: height){
                completionHandler(resizeImage(originalImage, toHeight: height, forTask: URLString))
            }else{
                thumbnailIsSourceSet.insert(URLString)
                cache.setObject(originalImage, forKey: URLString as NSString)
                completionHandler(originalImage)
            }
        }
    }
    
    func fetchThumbnailForVideoTask(_ URLString: String, height: CGFloat, completionHandler: (_ thumbnail: UIImage) -> Void){
        guard thumbnailFetchFailedTaskSet.contains(URLString) == false else {
            debugNSLog("Can't fetch thumbnail from video file: %@", URLString)
            return}
        
        if let fileLocation = dm.fileURL(ofTask: URLString), (fileLocation as NSURL).checkResourceIsReachableAndReturnError(nil) == true{
            let asset = AVAsset(url: fileLocation as URL)
            let exactTime = CMTimeMultiplyByFloat64(asset.duration, 0.1)
            
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.maximumSize = CGSize(width: height * 3, height: height)
            
            do {
                let imageRef = try imageGenerator.copyCGImage(at: exactTime, actualTime: nil)
                let originalImage: UIImage = UIImage(cgImage: imageRef)
                if originalImage.size.height < expectedHeightForSourceSize(originalImage.size, targetHeight: height){
                    thumbnailIsSourceSet.insert(URLString)
                    cache.setObject(originalImage, forKey: URLString as NSString)
                    completionHandler(originalImage)
                }else{
                    completionHandler(resizeImage(originalImage, toHeight: height, forTask: URLString))
                }
            }catch let copyError as NSError{
                debugNSLog("Fail to fetch thumbnail from video file of %@: %@" , URLString, copyError.description)
                self.thumbnailFetchFailedTaskSet.insert(URLString)
            }
        }
    }
}
