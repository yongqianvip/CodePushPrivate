# CodePushPrivate（Android）
...
-

# CodePushPrivate（iOS）

这是一个RN工程，运行这个工程之前需要：  

  	$ npm install  
    $ cd ios/ && pod install
    $ nodemon Server.js // 启用一个express服务


## Installation

通过 [CocoaPods](http://cocoapods.org) 集成  

	$ pod 'CodePushPrivate'
	
## Usage

#### 检查和获取bundle路径

    #import <CodePushPrivateManager.h>
    ...
    NSURL *jsCodeLocation = nil;
    CodePushPrivateManager *manager = [CodePushPrivateManager sharedInstance];
    [manager check];  
    jsCodeLocation = [manager bundleURL];  

#### 配置项：

- `url` 设置检查更新的接口 


#### 资源引入
	
	- main.jsbundle
	- assets
	这两个文件需要能打进bundle包中,所以导入工程的时候要勾选 
	
	[x] Copy items if needed 
	[x] Create floder references

		
#### 操作完成后的通知

* 最新补丁文件下载解压完毕后会发系统通知`kNotificationCodePushDone`，监听这个通知做响应处理

* 补丁下载失败时会发送 `kNotificationPatchDownloadFailed`的通知

## Author

yongqainvip@163.com


## License

CodePushPrivate is available under the MIT license. See the LICENSE file for more info.
