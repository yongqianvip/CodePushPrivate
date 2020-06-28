//
//  CodePushPrivateManager.h
//  CodePushPrivate
//
//  Created by mbp on 2020/6/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString * _Nonnull const kNotificationCodePushDone = @"code_push_done_notification";//文件下载解压完毕
static NSString * _Nonnull const kNotificationPatchDownloadFailed = @"code_push_patch_download_failed_notification";//文件下载解压完毕
typedef void (^LatestPatchBlcok)(NSDictionary *latestPatch);
typedef void (^DownloadPatchProgress)(NSProgress *progress);

@interface CodePushPrivateManager : NSObject

// 请求url  GET请求
@property (nonatomic, copy) NSString *url;

// 请求参数（已经有：系统、APP版本号、设备名、系统版本号、uuid）
@property (nonatomic, strong) NSDictionary *parametersDictionary;

// 加载的 bundle 的 URL
@property (nonatomic, strong) NSURL *bundleURL;

+ (instancetype)sharedInstance;

// 检查更新 并自动下载
- (void)check;

//检查更新并回调最新的可用patch对象(NSDictionary)  注意: 这个方法不会自动下载, 需要在block回调中调用  downPatch: downloadProgress: 方法去下载
- (void)checkWithLatestPatch:(nullable LatestPatchBlcok)latestPatchBlock;

// 接受最新的可用patch对象, 下载 并在blcok中回调进度
- (void)downloadPatch:(NSDictionary *)latestPatch downloadProgress:(nullable DownloadPatchProgress)progressBlock;

// 检查更新并附带最新的patch对象和下载进度回调
- (void)checkWithLatestPatch:(nullable LatestPatchBlcok)latestPatchBlcok downloadProgress:(nullable DownloadPatchProgress)progressBlock;

@end

NS_ASSUME_NONNULL_END
