//
//  CodePushPrivateManager.m
//  CodePushPrivate
//
//  Created by mbp on 2020/6/23.
//

#import "CodePushPrivateManager.h"
#import "AFHTTPSessionManager.h"
#import "SSZipArchive.h"
#import <sys/utsname.h>
#import <CommonCrypto/CommonDigest.h>

@interface CodePushPrivateManager ()

@property (nonatomic, copy) NSString *bundleRootDirectoryPath; // bundle 根目录路径
@property (nonatomic, copy) NSString *bundleLoadPath; // bundle 加载的路径
@property (nonatomic, copy) NSString *appBundleVersion;

@end

static NSString *const kReactNativeBundleRootDirectoryName = @"reactNativeBundle"; // bundle 根目录名
static NSString *const kReactNativeBundleZipName = @"ReactNativeBundle.zip"; // 压缩包的名字
static NSString *const kReactNativeJSFileName = @"main.jsbundle"; // js 文件的名字
static NSString *const kReactNativeAssetsDirectoryName = @"assets"; // assts 资源的目录名

@implementation CodePushPrivateManager

#pragma mark - public method
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static CodePushPrivateManager *instance;
    dispatch_once(&onceToken, ^{
        instance = [[CodePushPrivateManager alloc] init];
        instance.appBundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    });
    return instance;
}

/// 检测到更新的patch包 自动下载 无进度反馈 (静默更新) 下载完成后发送广播
- (void)check {
    [self checkWithLatestPatch:nil downloadProgress:^(NSProgress * _Nonnull progress) {}];
}

/// 提供发现到的更新的patch包,但是不自动下载 , 可以在block回调中调用 (void)downloadPatch:(NSDictionary *)latestPatch downloadProgress:(void (^)(NSProgress * _Nonnull))progressBlock 手动触发下载
/// @param latestPatchBlcok 回调最新的可下载安装包
- (void)checkWithLatestPatch:(nullable LatestPatchBlcok)latestPatchBlcok {
    [self checkWithLatestPatch:latestPatchBlcok downloadProgress:nil];
}


///  检测是否有最新的可用patch包,  检测到以后  如果有latestPatchBlcok则抛出最新的patch包对象, progressBlock不为空时才会触发下载, 且回调下载进度
/// @param latestPatchBlcok 回调抛出最新的patch对象
/// @param progressBlock 下载进度的回调
- (void)checkWithLatestPatch:(nullable LatestPatchBlcok)latestPatchBlcok downloadProgress:(nullable DownloadPatchProgress)progressBlock {
    if (!self.url || self.url == nil || [self.url isEqualToString: @""]) {
#ifdef DEBUG
        @throw @"未配置正确的patch接口 url";
#endif
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 删除旧数据
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *fileList = [fileManager contentsOfDirectoryAtPath:self.bundleRootDirectoryPath error:nil];
        for (NSString *fileName in fileList) {
            if ([fileName compare:self.appBundleVersion] < NSOrderedSame) {
                //  如果目录下有旧版本的包 则移除
                [fileManager removeItemAtPath:[self.bundleRootDirectoryPath stringByAppendingPathComponent:fileName] error:nil];
            }
        }
        NSArray *currentVersionPatchList = [fileManager contentsOfDirectoryAtPath:[self.bundleRootDirectoryPath stringByAppendingPathComponent:self.appBundleVersion] error:nil];
        NSString *finalPatchName = @"0";
        for (NSString *patchNames in currentVersionPatchList) {
          // 当前版本下的所有patch 挑最大的读
          if ([patchNames compare:finalPatchName] >= NSOrderedSame) {
            finalPatchName = patchNames;
          }
        }
        NSMutableDictionary *patchURLParameters = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                                  @"system_type" : @"1", // 系统 0-Android,1-IOS
                                                                                                  @"app_version" : self.appBundleVersion ?: @"", // APP版本号
                                                                                                  @"app_patch_version" : finalPatchName, // patch版本号
                                                                                                  }];
        [patchURLParameters addEntriesFromDictionary:self.parametersDictionary];
        AFHTTPSessionManager *requestOperationManager = [AFHTTPSessionManager manager];
        requestOperationManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        [requestOperationManager.responseSerializer.acceptableContentTypes setByAddingObject:@"application/x-zip-compressed"]; // zip
        [requestOperationManager.responseSerializer.acceptableContentTypes setByAddingObject:@"application/octet-stream"]; // rar
        [requestOperationManager GET:self.url
                          parameters:patchURLParameters
                             headers:nil
                            progress:nil
                             success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            NSError *error = nil;
            NSDictionary *resultDic = [NSJSONSerialization JSONObjectWithData:responseObject
                                                                      options:NSJSONReadingFragmentsAllowed
                                                                        error:&error];
            NSDictionary *dataDic = resultDic[@"data"];
            NSArray *patches = dataDic[@"patches"];
            if (!dataDic || [dataDic isKindOfClass:[NSNull class]] || !patches || patches.count < 1 ) {
                return;
            }
            NSDictionary *latestPatchDic = nil;
            for (NSDictionary *patchDic in patches) {
                // 当前版本对应的所有patch 挑最大的
                if ([patchDic[@"version"] compare: latestPatchDic[@"version"]] >= NSOrderedSame) {
                    latestPatchDic = patchDic;
                }
            }
            // 如果本地已经存在最大的patch版本号,则忽略
            NSString *highestPatch = [[self.bundleRootDirectoryPath stringByAppendingPathComponent:self.appBundleVersion] stringByAppendingPathComponent:latestPatchDic[@"version"]];
            if ([fileManager fileExistsAtPath:highestPatch]) {
               NSLog(@"本地已有最新版本的patch包");
               return;
            }
            if (latestPatchBlcok) {
                latestPatchBlcok(latestPatchDic);
            }
            if (progressBlock) {
                // progressBlock不为空 则自动下载patch包
                [self downloadPatch:latestPatchDic downloadProgress:progressBlock];
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"check online react native error: %@", error);
        }];
    });
}


/// 根据传入的最新可以patch对象 下载最新的patch包, 并通过progressBlock回调进度
/// @param latestPatch 最新的可用patch对象
/// @param progressBlock 进度回调
- (void)downloadPatch:(NSDictionary *)latestPatch downloadProgress:(void (^)(NSProgress * _Nonnull))progressBlock {
    NSString *patchUrl = latestPatch[@"src"];
    NSString *patchMd5 = latestPatch[@"md5"];
    NSString *patchVersion = (NSString *)latestPatch[@"version"];
    if (patchUrl && patchUrl.length > 0 && patchVersion && patchVersion.length > 0) {
        AFHTTPSessionManager *requestOperationManager = [AFHTTPSessionManager manager];
        requestOperationManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        [requestOperationManager.responseSerializer.acceptableContentTypes setByAddingObject:@"application/x-zip-compressed"]; // zip
        [requestOperationManager.responseSerializer.acceptableContentTypes setByAddingObject:@"application/octet-stream"]; // rar
        [requestOperationManager GET:patchUrl
                          parameters:nil
                             headers:nil
                            progress:^(NSProgress * _Nonnull downloadProgress) {
            if (progressBlock) progressBlock(downloadProgress);
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                // 根据版本号创建相应目录
                NSFileManager *fileManager = [NSFileManager defaultManager];
                
                NSString *zipDirectoryPath = [[self.bundleRootDirectoryPath stringByAppendingPathComponent: self.appBundleVersion] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", patchVersion]];
                
                if (![fileManager fileExistsAtPath:zipDirectoryPath]) {
                    [fileManager createDirectoryAtPath:zipDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
                }

                // 保存Zip包到创建的目录中
                NSString *zipFilePath = [zipDirectoryPath stringByAppendingPathComponent:kReactNativeBundleZipName];
                [fileManager createFileAtPath:zipFilePath contents:responseObject attributes:nil];
                if (patchMd5 && patchMd5.length > 0) {
                    // md5 校验包的完整性
                    NSString *MD5 = [self calculateFileMd5WithFilePath:zipFilePath];
                    if(![MD5 isEqualToString:patchMd5]){
                        // md5不匹配 删除压缩包所在的文件夹，跳出patch流程
                        [self deletePath:zipDirectoryPath];
                        #ifdef DEBUG
                            @throw @"md5不匹配 删除压缩包所在的文件夹";
                        #endif
                        return;
                    }
                }
                // 解压缩Zip包到当前Zip包对应的目录
                [SSZipArchive unzipFileAtPath:zipFilePath toDestination:zipDirectoryPath progressHandler:nil completionHandler:^(NSString * _Nonnull path, BOOL succeeded, NSError * _Nullable error) {
                    if (succeeded) {
                        NSString *jsFilePath = [zipDirectoryPath stringByAppendingPathComponent:kReactNativeJSFileName];
                        // 解压后 判断是否有main.jsbundle 文件
                        BOOL isJsBundleExist = [[NSFileManager defaultManager] fileExistsAtPath:jsFilePath isDirectory:false];
                        if (isJsBundleExist) {
                            // 更新bundle加载路径；根据接口数据判断是否要马上reload
                            self.bundleLoadPath = zipDirectoryPath;
                            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCodePushDone object:@{@"jsbundlePath": [zipDirectoryPath stringByAppendingPathComponent:kReactNativeJSFileName]}];
                        }else{
                            [self deletePath:zipDirectoryPath];
                        }
                        // 删除Zip包
                        [self deletePath:zipFilePath];
                    } else {
                        // 解压缩失败，删除整个目录
                        [self deletePath:zipDirectoryPath];
                    }
                }];
            });
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            NSLog(@"download react native zip error: %@", error);
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPatchDownloadFailed object:nil];
        }];
    }
}

#pragma mark - private method
- (void)deletePath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:path error:nil];
}

- (NSString *)bundleRootDirectoryPath {
    if (!_bundleRootDirectoryPath) {
        _bundleRootDirectoryPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:kReactNativeBundleRootDirectoryName];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:_bundleRootDirectoryPath]) {
            [fileManager createDirectoryAtPath:_bundleRootDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }

    return _bundleRootDirectoryPath;
}

- (NSString *)bundleLoadPath {
    if (!_bundleLoadPath) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *basePatchName = @"0";
        NSArray *currentVersionPatchList = [fileManager contentsOfDirectoryAtPath:[self.bundleRootDirectoryPath stringByAppendingPathComponent:self.appBundleVersion] error:nil];
        // 首先 0 文件夹必须要有,没有的话去拷贝
        NSString *baseBundlePath = [[self.bundleRootDirectoryPath stringByAppendingPathComponent:self.appBundleVersion] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", basePatchName, kReactNativeJSFileName]];
        BOOL baseBundlePathExist = [fileManager fileExistsAtPath:baseBundlePath];
        if (currentVersionPatchList.count > 0 && baseBundlePathExist) {
            //本地有patch 就读patch
            NSString *finalPatchName = @"0";
            for (NSString *patchName in currentVersionPatchList) {
                // 当前版本下的所有patch 挑最大的读
                NSString *newPatchBundlePath = [[self.bundleRootDirectoryPath stringByAppendingPathComponent:self.appBundleVersion] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", patchName, kReactNativeJSFileName]];
                BOOL newPatchBundlePathExist = [fileManager fileExistsAtPath:newPatchBundlePath];
                if ([patchName compare:finalPatchName] >= NSOrderedSame && newPatchBundlePathExist) {
                    finalPatchName = patchName;
                }
                if (!newPatchBundlePathExist) {
                    [self deletePath:[[self.bundleRootDirectoryPath stringByAppendingPathComponent:self.appBundleVersion] stringByAppendingPathComponent:patchName]];
                }
            }
            // 这里判断有当前版本的patch就读
            _bundleLoadPath = [[self.bundleRootDirectoryPath stringByAppendingPathComponent: self.appBundleVersion] stringByAppendingPathComponent: finalPatchName];
        } else {
            // 新的原生版本 拷贝bundle中的main.jsbundle和assets到 路径'/1.0/0/'下  (路径： /appVersion/patchName/)
            NSString *defaultBundleDirectoryPath = [[self.bundleRootDirectoryPath stringByAppendingPathComponent:self.appBundleVersion] stringByAppendingPathComponent:basePatchName];
            // 路径 /1.0/0/ 不存在 则创建
            if (![fileManager fileExistsAtPath:defaultBundleDirectoryPath]) {
              [fileManager createDirectoryAtPath:defaultBundleDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
            }
            NSString *jsBundlePath = [[NSBundle mainBundle] pathForResource:@"main" ofType:@"jsbundle"];
            NSString *assetsBundlePath = [[NSBundle mainBundle] pathForResource:@"assets" ofType:nil];
            NSString *defaultJSFilePath = [defaultBundleDirectoryPath stringByAppendingPathComponent:kReactNativeJSFileName];
            NSString *defaultAssetsPath = [defaultBundleDirectoryPath stringByAppendingPathComponent:kReactNativeAssetsDirectoryName];
            if (![fileManager fileExistsAtPath:defaultJSFilePath]) {//如果不存在 取bundle中的main.jsbundle
                if (jsBundlePath) {
                    [fileManager copyItemAtPath:jsBundlePath toPath:defaultJSFilePath error:nil];
                }
            }
            if (![fileManager fileExistsAtPath:defaultAssetsPath]) {
                if (assetsBundlePath) {
                    [fileManager copyItemAtPath:assetsBundlePath toPath:defaultAssetsPath error:nil];
                }
            }
            if (!jsBundlePath) {
                NSLog(@"没有jsbundle");
            }
            if (!assetsBundlePath) {
                NSLog(@"没有assets");
            }
            _bundleLoadPath = defaultBundleDirectoryPath;
        }
    }
    return _bundleLoadPath;
}


- (NSURL *)bundleURL {
    NSString *jsBundleFileLoadPath = [self.bundleLoadPath stringByAppendingPathComponent:kReactNativeJSFileName];
    return [NSURL URLWithString:jsBundleFileLoadPath];
}

- (NSString *)calculateFileMd5WithFilePath:(NSString *)filePath
{
    //生成文件的MD5   校验的是压缩包的MD5  判断下载是否正确
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    if( handle == nil ) {
        NSLog(@"文件出错");
    }
    
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    BOOL done = NO;
    while(!done)
    {
        NSData* fileData = [handle readDataOfLength: 256 ];
        CC_MD5_Update(&md5, [fileData bytes], (CC_LONG)[fileData length]);
        if( [fileData length] == 0 ) done = YES;
    }
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &md5);
    NSString *fileMD5 = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                         digest[0], digest[1],
                         digest[2], digest[3],
                         digest[4], digest[5],
                         digest[6], digest[7],
                         digest[8], digest[9],
                         digest[10], digest[11],
                         digest[12], digest[13],
                         digest[14], digest[15]];
    return fileMD5;
}

@end
