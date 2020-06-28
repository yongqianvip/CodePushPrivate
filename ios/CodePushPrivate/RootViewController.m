//
//  RootViewController.m
//  CodePushPrivate
//
//  Created by mbp on 2020/6/23.
//

#import "RootViewController.h"
#import <React/RCTBundleURLProvider.h>
#import <React/RCTRootView.h>
#import "CodePushPrivateManager.h"


@interface RootViewController ()

@end

@implementation RootViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(codePushDone:) name:kNotificationCodePushDone object:nil];
  [self.view setBackgroundColor:[UIColor orangeColor]];
  [self setupReactNative];
  
}
-(void)setupReactNative{
  for (UIView *rootV in self.view.subviews) {
    if ([rootV isKindOfClass:[RCTRootView class]]) {
      [rootV removeFromSuperview];
    }
  }
  
  RCTRootView *rootView = [[RCTRootView alloc] initWithBundleURL:[self getJsCodeLocation]
                                                      moduleName:@"CodePushPrivate"
                                               initialProperties:nil
                                                   launchOptions:self.launchOptions];
  [rootView setFrame:[UIScreen mainScreen].bounds];
  [self.view addSubview:rootView];
}
/**
 监听热更新的通知 Hot Reload
 @param notify jsbundlePath notify
 */
- (void)codePushDone:(NSNotification *)notify  {
  NSLog(@"done");
  dispatch_async(dispatch_get_main_queue(), ^{
    [self setupReactNative];
  });
}
- (NSURL *)getJsCodeLocation {
  NSURL *jsCodeLocation;
//#ifdef DEBUG
//  jsCodeLocation = [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index" fallbackResource:nil];
//#else
  CodePushPrivateManager *manager = [CodePushPrivateManager sharedInstance];
//  manager.isDebug = YES;
  [manager setUrl:@"http://localhost:8082/patch"];
  [manager checkWithLatestPatch:^(NSDictionary * _Nonnull latestPatch) {
    NSLog(@"最新的可用下载对象 %@", latestPatch);
  } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
    NSLog(@"下载进度 %lld, %lld ", downloadProgress.completedUnitCount, downloadProgress.totalUnitCount);
  }];
  [manager checkWithLatestPatch:^(NSDictionary * _Nonnull latestPatch) {
    NSLog(@"检测到新版本,但是需要手动去下载%@",latestPatch);
  }];
  
  jsCodeLocation = [manager bundleURL];
//#endif
  return jsCodeLocation;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
