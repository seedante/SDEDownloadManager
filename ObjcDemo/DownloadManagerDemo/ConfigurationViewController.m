//
//  ViewController.m
//  ObjcDMDemo
//
//  Created by seedante on 8/6/17.
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

#import "ConfigurationViewController.h"
#import "AppDelegate.h"

@interface ConfigurationViewController ()

@property (weak, nonatomic) IBOutlet UILabel *cellHeightLabel;
@property (weak, nonatomic) IBOutlet UILabel *scrollSpeedThresholdLabel;

@property (nonatomic) SDEDownloadManager * downloadManager;
@property (nonatomic) UIBarButtonItem * addTaskButtonItem;
@property (nonatomic) URLPickerController * URLPickerVC;
@property (nonatomic) NSArray * candidateTaskURLStringList;
@property DownloadListController * listVC;
@property BOOL listVCInitedFromStoryboard;

@end

@implementation ConfigurationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.displayContent = ListContentDownloadList;
    self.cellImageViewStyle = CellImageViewStyleThumbnail;
    self.fileThumbnailShape = ThumbnailShapeOriginal;
    self.actionButtonStyle = AccessoryButtonStyleIcon;
    
    self.allowsTrackingDownloadDetail = YES;
    self.allowsTrackingSpeed = YES;
    self.allowsTrackingProgress = YES;
    
    self.barButtonAppearanceStyle = BarButtonAppearanceStyleTitle;
    self.buttonIconFilled = YES;
    
    self.allowsStop = NO;
    self.allowsRedownload = NO;
    self.allowsDeletion = NO;
    self.allowsRestoration = NO;
    self.deleteMode = DeleteModeFileAndRecord;
    
    self.allowsEditingByEditButtonItem = NO;
    self.allowsEditingByLongPress = NO;
    
    self.allowsSwitchingSortMode = NO;
    self.shouldDisplaySortOrderInSortView = NO;
    
    self.allowsManagingAllTasksOnToolBar = NO;
    
    self.startToDownloadImmediately = YES;
    self.isTrashOpened = NO;
    
    self.cellHeight = 44;
    self.scrollSpeedThreshold = 10;
    
    self.listVCInitedFromStoryboard = YES;
}

- (void)viewWillAppear:(BOOL)animated{
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    [self.navigationController setToolbarHidden:YES animated:YES];
}

// MARK: Test URL
/*
 The follow URL strings are too long to display completely in the iPhone device, so I suggest that you build server to test.
 
 It's easy to setup a apache server in your mac to test:
 1. Put whatever files you want to test in /Library/WebServer/Documents/
 2. Lanch server: open Terminal and input command: "sudo apachectl start"
 3. Visit server by: http://localhost/ (just on your simulator) or your mac local IP like 192.168.1.xxx
 
 Actually, everytime you put file in /Library/WebServer/Documents/, system ask you for admin password, that's annoying.
 /Library/WebServer/Documents/ is the default root directory of Apache server for request, change it in file: /etc/apache2/httpd.conf.
 General softwares can't edit this file. You could edit it in terminal by vi or emacs, like: "sudo vi /etc/apache2/httpd.conf".
 
 Find the line: DocumentRoot "/Library/WebServer/Documents/", change content in “” to any directory which you want.
 If the follow content is existed, change it also:
 <Directory "/Library/WebServer/Documents/">
 xxxx
 </Directory>
 
 If apache server is lanched already, restart it: sudo apachectl restart.
 */
- (NSArray *)candidateTaskURLStringList{
    if (!_candidateTaskURLStringList) {
        _candidateTaskURLStringList = @[
                                        // Auth: ServerTrust
                                        @"https://developer.apple.com/sample-code/wwdc/2015/downloads/Advanced-NSOperations.zip",
                                        @"https://codeload.github.com/seedante/OptimizationForOffscreenRender/zip/master",
                                        
                                        // LOGO
                                        @"https://developer.apple.com/wwdc/images/wwdc17-og.jpg",
                                        
                                        // WWDC 2016
                                        @"http://devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/images/402_734x413.jpg",
                                        @"http://devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_whats_new_in_swift.pdf",
                                        @"http://devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_hd_whats_new_in_swift.mp4?dl=1",
                                        @"http://devstreaming.apple.com/videos/wwdc/2016/402h429l9d0hy98c9m6/402/402_sd_whats_new_in_swift.mp4?dl=1",
                                        
                                        @"http://devstreaming.apple.com/videos/wwdc/2016/711tlraheg74mofg3uq/711/images/711_734x413.jpg",
                                        @"http://devstreaming.apple.com/videos/wwdc/2016/711tlraheg74mofg3uq/711/711_nsurlsession_new_features_and_best_practices.pdf",
                                        @"http://devstreaming.apple.com/videos/wwdc/2016/711tlraheg74mofg3uq/711/711_hd_nsurlsession_new_features_and_best_practices.mp4?dl=1",
                                        @"http://devstreaming.apple.com/videos/wwdc/2016/711tlraheg74mofg3uq/711/711_sd_nsurlsession_new_features_and_best_practices.mp4?dl=1",
                                        
                                        // WWDC 2015
                                        @"http://devstreaming.apple.com/videos/wwdc/2015/106z3yjwpfymnauri96m/106/images/106_734x413.jpg",
                                        @"http://devstreaming.apple.com/videos/wwdc/2015/106z3yjwpfymnauri96m/106/106_whats_new_in_swift.pdf?dl=1",
                                        @"http://devstreaming.apple.com/videos/wwdc/2015/106z3yjwpfymnauri96m/106/106_hd_whats_new_in_swift.mp4?dl=1",
                                        @"http://devstreaming.apple.com/videos/wwdc/2015/106z3yjwpfymnauri96m/106/106_sd_whats_new_in_swift.mp4?dl=1",
                                        
                                        @"http://devstreaming.apple.com/videos/wwdc/2015/711y6zlz0ll/711/images/711_734x413.jpg",
                                        @"http://devstreaming.apple.com/videos/wwdc/2015/711y6zlz0ll/711/711_networking_with_nsurlsession.pdf?dl=1",
                                        @"http://devstreaming.apple.com/videos/wwdc/2015/711y6zlz0ll/711/711_hd_networking_with_nsurlsession.mp4?dl=1",
                                        @"http://devstreaming.apple.com/videos/wwdc/2015/711y6zlz0ll/711/711_sd_networking_with_nsurlsession.mp4?dl=1",
                                        
                                        @"http://devstreaming.apple.com/videos/wwdc/2015/2267p2ni281ba/226/images/226_734x413.jpg",
                                        @"http://devstreaming.apple.com/videos/wwdc/2015/2267p2ni281ba/226/226_advanced_nsoperations.pdf?dl=1",
                                        @"http://devstreaming.apple.com/videos/wwdc/2015/2267p2ni281ba/226/226_hd_advanced_nsoperations.mp4?dl=1",
                                        @"http://devstreaming.apple.com/videos/wwdc/2015/2267p2ni281ba/226/226_sd_advanced_nsoperations.mp4?dl=1",
                                        @"https://developer.apple.com/sample-code/wwdc/2015/downloads/Advanced-NSOperations.zip",
                                        
                                        // WWDC 2014
                                        @"http://devstreaming.apple.com/videos/wwdc/2014/402xxgg8o88ulsr/402/402_introduction_to_swift.pdf",
                                        @"http://devstreaming.apple.com/videos/wwdc/2014/402xxgg8o88ulsr/402/402_hd_introduction_to_swift.mov",
                                        @"http://devstreaming.apple.com/videos/wwdc/2014/402xxgg8o88ulsr/402/402_sd_introduction_to_swift.mov",
                                        
                                        @"http://devstreaming.apple.com/videos/wwdc/2014/707xx1o5tdjnvg9/707/707_whats_new_in_foundation_networking.pdf",
                                        @"http://devstreaming.apple.com/videos/wwdc/2014/707xx1o5tdjnvg9/707/707_hd_whats_new_in_foundation_networking.mov",
                                        @"http://devstreaming.apple.com/videos/wwdc/2014/707xx1o5tdjnvg9/707/707_sd_whats_new_in_foundation_networking.mov",
                                        ];
    }
    return _candidateTaskURLStringList;
}

// MARK: Display Download List
- (IBAction)displayDownloadActivity:(id)sender {
    if (self.listVCInitedFromStoryboard) {
        [self performSegueWithIdentifier:@"Segue" sender:self];
    }else{
        [self presentListVCProgrammatically];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    self.listVC = (DownloadListController *)segue.destinationViewController;
    self.listVC.downloadManager = self.downloadManager;
    [self configurateListVC];
}

- (void)presentListVCProgrammatically{
    self.listVC = [[DownloadListController alloc] initWithDownloadManager:self.downloadManager tableViewStyle:UITableViewStylePlain configureCell:nil];
    [self configurateListVC];
    [self.navigationController pushViewController:self.listVC animated:YES];
}

- (void)configurateListVC{
    self.listVC.displayContent = self.displayContent;
    if (self.listVC.downloadManager.isDataLoaded) {
        if (self.listVC.downloadManager.maxDownloadCount == NSOperationQueueDefaultMaxConcurrentOperationCount) {
            self.listVC.title = @"Max: ∞";
        }else{
            self.listVC.title = [NSString stringWithFormat:@"Max: %ld", (long)self.listVC.downloadManager.maxDownloadCount];
        }
        
        if (self.displayContent == ListContentSubsection) {
            self.listVC.subsectionIndex = arc4random_uniform((UInt32)self.listVC.downloadManager.sectionCount);
        }
    }
    // other options not listed
    self.downloadManager.sectioningAddTimeList = true;
    self.downloadManager.indexingFileNameList = false;
    self.downloadManager.sectioningFileSizeList = true;
    self.listVC.allowsEditingSectionTitle = true;
    self.listVC.allowsInsertingSection = true;
    self.listVC.allowsRenamingFile = true;
    self.listVC.shouldExitEditModeAfterConfirmAction = true;
    self.listVC.shouldRemoveEmptySection = false;

    // cell appearance
    self.listVC.cellImageViewStyle = self.cellImageViewStyle;
    self.listVC.fileThumbnailShape = self.fileThumbnailShape;
    self.listVC.cellAccessoryButtonStyle = self.actionButtonStyle;
    
    // track download activity
    self.listVC.allowsTrackingDownloadDetail = self.allowsTrackingDownloadDetail;
    self.listVC.allowsTrackingSpeed = self.allowsTrackingSpeed;
    self.listVC.allowsTrackingProgress = self.allowsTrackingProgress;
    
    // button appearance
    self.listVC.buttonIconFilled = self.buttonIconFilled;
    self.listVC.barButtonAppearanceStyle = self.barButtonAppearanceStyle;
    
    // features in swipe gesture
    self.listVC.allowsStop = self.allowsStop;
    self.listVC.allowsRedownload = self.allowsRedownload;
    self.listVC.allowsDeletion = self.allowsDeletion;
    self.listVC.allowsRestoration = self.allowsRestoration;
    self.listVC.deleteMode = self.deleteMode;
    
    // multiple task management
    self.listVC.allowsEditingByEditButtonItem = self.allowsEditingByEditButtonItem;
    self.listVC.allowsEditingByLongPress = self.allowsEditingByLongPress;
    self.listVC.allowsManagingAllTasksOnToolBar = self.allowsManagingAllTasksOnToolBar;
    
    // scroll perfermance
    self.listVC.tableView.rowHeight = self.cellHeight;
    self.listVC.scrollSpeedThresholdForPerformance = self.scrollSpeedThreshold;
    
    // download manager setting
    self.listVC.downloadManager.downloadNewFileImmediately = self.startToDownloadImmediately;
    self.listVC.downloadManager.isTrashOpened = self.isTrashOpened;
    
    // handle background launch. Don't test on simulator.
    __weak typeof(self) weakSelf = self;
    self.listVC.downloadManager.backgroundSessionDidFinishEventsHandler = ^(NSURLSession * session){
        NSLog(@"backgroundSession did finish events.");
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        notification.alertBody = @"Download is over.";
        notification.alertTitle = @"OCDMDemo";
        
        [UIApplication.sharedApplication presentLocalNotificationNow:notification];
        
        AppDelegate * appDelegate = (AppDelegate *) UIApplication.sharedApplication.delegate;
        if (appDelegate.updateScreenshotHandler != NULL) {
            [NSOperationQueue.mainQueue addOperationWithBlock: ^{
                [weakSelf.listVC.tableView reloadData];
                appDelegate.updateScreenshotHandler();
            }];
        }
    };
    
    // resumeAll, pauseAll, stopAll, deleteAll
    self.listVC.toolBarActionRawValues = @[@0, @1, @2, @3];
    
    if (self.displayContent == ListContentDownloadList) {
        self.listVC.navigationItem.rightBarButtonItems = @[self.listVC.sortButtonItem, self.listVC.adjustButtonItem, self.addTaskButtonItem];
    }
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}
// MARK: Download Manager
- (SDEDownloadManager *)downloadManager{
    if (!_downloadManager) {
        _downloadManager = [SDEDownloadManager managerWithIdentifier:@"DM-OC-Demo" manualMode:NO];
    }
    return _downloadManager;
}

// MARK: Add Download Task
- (void)addDownloadTask: (UIBarButtonItem *)buttonItem{
    self.URLPickerVC.preferredContentSize = CGSizeMake(UIScreen.mainScreen.bounds.size.width - 20, UIScreen.mainScreen.bounds.size.height - 50);
    self.URLPickerVC.modalPresentationStyle = UIModalPresentationPopover;
    self.URLPickerVC.popoverPresentationController.barButtonItem = buttonItem;
    self.URLPickerVC.popoverPresentationController.delegate = self.listVC;
    self.URLPickerVC.adjustsCellFontSizeToFitWidth = true;
    self.URLPickerVC.isFileNamePriorThanURL = true;
    self.URLPickerVC.shouldDisplayTinyURLAtCellTop = true;
    
    [self.listVC presentViewController:self.URLPickerVC animated:YES completion:nil];
}

- (UIBarButtonItem *)addTaskButtonItem{
    if (!_addTaskButtonItem) {
        _addTaskButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addDownloadTask:)];
    }
    return _addTaskButtonItem;
}

- (NSArray *)sectionTitles{
    return @[@"Metal Gear Solid ",  @"TitanFall ", @"Uncharted ", @"Call of Duty ", @"Tomb Raider ", @"Halo ", @"Final Fantasy ", @"Grand Theft Auto ", @"龍が如く ", @"Assassin’s Creed "];
}

- (NSArray *)splitIntoTwoPartsWithURLStrings: (NSArray<NSString *> *)URLStrings {
    if (URLStrings.count == 0) {
        return @[];
    }else if (URLStrings.count == 1){
        NSString * title = [NSString stringWithFormat:@"RandomTitle: %@%d", self.sectionTitles[arc4random_uniform(10)], arc4random_uniform(15)];
        return @[@[URLStrings], title];
    }else{
        NSString * title1 = [NSString stringWithFormat:@"RandomTitle: %@%d", self.sectionTitles[arc4random_uniform(10)], arc4random_uniform(15)];
        NSString * title2 = [NSString stringWithFormat:@"RandomTitle: %@%d", self.sectionTitles[arc4random_uniform(10)], arc4random_uniform(15)];
        NSInteger splitSeed = arc4random_uniform((UInt32)URLStrings.count);
        NSInteger splitIndex = splitSeed == 0 ? 1 : splitSeed;
        NSInteger length1 = splitIndex;
        NSInteger length2 = URLStrings.count - length1;
        NSArray<NSString *> * part1 = [URLStrings objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, length1)]];
        NSArray<NSString *> * part2 = [URLStrings objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(splitIndex, length2)]];
        return @[@[part1, part2], @[title1, title2]];
    }
}

- (URLPickerController *)URLPickerVC{
    if (!_URLPickerVC) {
        _URLPickerVC = [[URLPickerController alloc] initWithURLStrings: self.candidateTaskURLStringList pickCompletionHandler:^(NSArray<NSString *> * selectedURLStrings){
            if (self.downloadManager.sortType == ComparisonTypeManual) {
                if (self.downloadManager.sectionCount == 0) {
                    NSString * title = [NSString stringWithFormat:@"RandomTitle: %@%d", self.sectionTitles[arc4random_uniform(10)], arc4random_uniform(15)];
                    [self.listVC downloadFilesAtURLStrings:selectedURLStrings inManualModeAtSection:0 sectionTitle:title];
                    return;
                }
                
                NSInteger insertSection = arc4random_uniform((UInt32)self.downloadManager.sectionCount);
                switch (arc4random_uniform(100) % 2) {
                    case 0:{
                        NSLog(@"Add A New Section");
                        NSArray * tasksAndTitles = [self splitIntoTwoPartsWithURLStrings:selectedURLStrings];
                        NSArray<NSArray<NSString *>*> * tasks = tasksAndTitles.firstObject;
                        NSArray<NSString *> * titles = tasksAndTitles.lastObject;
                        [self.listVC downloadFilesList:tasks inManualModeAtSection:insertSection sectionTitles:titles];
                        break;
                    }
                    case 1:{
                        NSLog(@"Insert into a existed section");
                        NSInteger rowSeed = [self.downloadManager taskCountInSection:insertSection];
                        NSInteger insertRow = arc4random_uniform((UInt32)rowSeed);
                        NSIndexPath * indexPath = [NSIndexPath indexPathForRow:insertRow inSection:insertSection];
                        [self.listVC downloadFilesAtURLStrings:selectedURLStrings inManualModeAt:indexPath];
                        break;
                    }
                    default: break;
                }
                
                
            }else{
                [self.listVC downloadFilesAtURLStrings:selectedURLStrings];
            }
        } pickButtonTitle:nil];
    }
    return _URLPickerVC;
}

// MARK: - Custom DownloadListController
// MARK: Select Display Content
- (IBAction)switchDisplayContent:(UISegmentedControl *)segmenter {
    switch (segmenter.selectedSegmentIndex) {
        case 0:
            self.displayContent = ListContentDownloadList;
            break;
        case 1:
            self.displayContent = ListContentUnfinishedList;
            break;
        case 2:
            self.displayContent = ListContentToDeleteList;
            break;
        case 3:
            self.displayContent = ListContentSubsection;
            break;
        default:
            break;
    }
}

// MARK: Cell Appearance: imageView, accessoryView
- (IBAction)switchImageViewStyle:(UISegmentedControl *)segmenter {
    switch (segmenter.selectedSegmentIndex) {
        case 0:
            self.cellImageViewStyle = CellImageViewStyleThumbnail;
            break;
        case 1:
            self.cellImageViewStyle = CellImageViewStyleIndex;
            break;
        case 2:
            self.cellImageViewStyle = CellImageViewStyleNone;
            break;
        default:
            break;
    }
}

- (IBAction)switchThumbnailShape:(UISegmentedControl *)segmenter {
    switch (segmenter.selectedSegmentIndex) {
        case 0:
            self.fileThumbnailShape = ThumbnailShapeOriginal;
            break;
        case 1:
            self.fileThumbnailShape = ThumbnailShapeSquare;
            break;
        default:
            break;
    }
}

- (IBAction)switchActionButtonStyle:(UISegmentedControl *)segmenter {
    switch (segmenter.selectedSegmentIndex) {
        case 0:
            self.actionButtonStyle = AccessoryButtonStyleIcon;
            break;
        case 1:
            self.actionButtonStyle = AccessoryButtonStyleTitle;
            break;
        case 2:
            self.actionButtonStyle = AccessoryButtonStyleNone;
            break;
        case 3:
            self.actionButtonStyle = AccessoryButtonStyleCustom;
            break;
        default:
            break;
    }
}

// MARK: Track Download Activity in Cell
- (IBAction)switchTrackProgressInfoFeature:(UISwitch *)switcher {
    self.allowsTrackingDownloadDetail = switcher.on;
}

- (IBAction)switchTrackSpeedFeature:(UISwitch *)switcher {
    self.allowsTrackingSpeed = switcher.on;
}

- (IBAction)switchTrackProgressValueFeature:(UISwitch *)switcher {
    self.allowsTrackingProgress = switcher.on;
}

// MARK: Button Appearance
- (IBAction)switchButtonIconStyle:(UISegmentedControl *)segmenter {
    self.buttonIconFilled = segmenter.selectedSegmentIndex == 0 ? NO : YES;
}

- (IBAction)switchBarButtonItemStyle:(UISegmentedControl *)segmenter {
    self.barButtonAppearanceStyle = segmenter.selectedSegmentIndex == 0 ? BarButtonAppearanceStyleIcon : BarButtonAppearanceStyleTitle;
}

// MARK: Features in Swipe Gesture
- (IBAction)switchStopInCellSwipe:(UISwitch *)switcher {
    self.allowsStop = switcher.on;
}

- (IBAction)switchRedownloadInCellSwipe:(UISwitch *)switcher {
    self.allowsRedownload = switcher.on;
}

- (IBAction)switchDeleteInCellSwipe:(UISwitch *)switcher {
    self.allowsDeletion = switcher.on;
}

- (IBAction)switchRestoreInCellSwipe:(UISwitch *)switcher {
    self.allowsRestoration = switcher.on;
}

- (IBAction)switchDeleteTaskType:(UISegmentedControl *)segmenter {
    switch (segmenter.selectedSegmentIndex) {
        case 0:
            self.deleteMode = DeleteModeFileAndRecord;
            break;
        case 1:
            self.deleteMode = DeleteModeOnlyFile;
            break;
        case 2:
            self.deleteMode = DeleteModeOptional;
            break;
        default:
            break;
    }
}

// MARK: Multiple Task Management
- (IBAction)switchEditModeByEditButtonItem:(UISwitch *)switcher {
    self.allowsEditingByEditButtonItem = switcher.on;
}

- (IBAction)switchEditModeByLongPress:(UISwitch *)switcher {
    self.allowsEditingByLongPress = switcher.on;
}

- (IBAction)switchSortMode:(UISwitch *)switcher {
    self.allowsSwitchingSortMode = switcher.on;
}


- (IBAction)switchSortOrder:(UISwitch *)switcher {
    self.shouldDisplaySortOrderInSortView = switcher.on;
}


- (IBAction)switchToolBarFeature:(UISwitch *)switcher {
    self.allowsManagingAllTasksOnToolBar = switcher.on;
}

// MARK: Scroll Performance
- (IBAction)changeCellHeight:(UISlider *)slider {
    self.cellHeight = (CGFloat)((int)(slider.value));
    self.cellHeightLabel.text = [NSString stringWithFormat:@"CellHeight: %.0f", slider.value];
}

- (IBAction)changeScrollSpeedThreshold:(UISlider *)slider {
    self.scrollSpeedThreshold = (int)slider.value;
    self.scrollSpeedThresholdLabel.text = [NSString stringWithFormat:@"ScrollThreshold: %.0f", slider.value];
}


// MARK: - DownloadManager Settings
- (IBAction)downloadImmediatelyOrNot:(UISegmentedControl *)segmenter {
    self.startToDownloadImmediately = segmenter.selectedSegmentIndex;
}

- (IBAction)switchTrash:(UISegmentedControl *)segmenter {
    self.isTrashOpened = segmenter.selectedSegmentIndex;
}

@end
