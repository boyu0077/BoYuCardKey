#import <UIKit/UIKit.h>

#define API_URL @"http://154.37.214.65/api/verify/check"
#define CARD_KEY_STORAGE @"com.BoYu.cardkey"

// 获取设备唯一标识
static NSString *getDeviceID() {
    return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}

// 获取系统版本
static NSString *getSystemVersion() {
    return [[UIDevice currentDevice] systemVersion];
}

// 发送日志到服务器
static void sendLog(NSString *cardKey, NSString *action, NSString *extra) {
    NSDictionary *params = @{
        @"card_key": cardKey ?: @"",
        @"device_code": getDeviceID(),
        @"user_ip": @"",
        @"platform": @"ios",
        @"action": action,
        @"extra_info": extra ?: @""
    };
    
    NSURL *url = [NSURL URLWithString:API_URL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSError *error = nil;
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:params options:0 error:&error]];
    
    if (!error) {
        [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:nil] resume;
    }
}

// Hook AppDelegate
%hook AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // 获取保存的卡密
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:CARD_KEY_STORAGE];
    
    // 如果没有卡密，显示输入界面
    if (!savedKey) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"需要卡密" 
                                                                           message:@"请输入授权卡密才能使用本应用" 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                textField.placeholder = @"请输入卡密";
                textField.secureTextEntry = NO;
                textField.keyboardType = UIKeyboardTypeASCIIAbility;
            }];
            
            UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定" 
                                                                    style:UIAlertActionStyleDefault 
                                                                  handler:^(UIAlertAction *action) {
                UITextField *textField = alert.textFields.firstObject;
                NSString *inputKey = textField.text;
                
                if (inputKey.length > 0) {
                    // 保存卡密
                    [[NSUserDefaults standardUserDefaults] setObject:inputKey forKey:CARD_KEY_STORAGE];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    
                    // 显示加载提示
                    UIAlertController *loadingAlert = [UIAlertController alertControllerWithTitle:@"验证中..." 
                                                                                          message:nil 
                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                    [self.window.rootViewController presentViewController:loadingAlert animated:YES completion:nil];
                    
                    // 发送验证请求
                    NSDictionary *params = @{
                        @"card_key": inputKey,
                        @"device_code": getDeviceID(),
                        @"user_ip": @"",
                        @"platform": @"ios",
                        @"action": @"verify",
                        @"extra_info": [NSString stringWithFormat:@"iOS %@", getSystemVersion()]
                    };
                    
                    NSURL *url = [NSURL URLWithString:API_URL];
                    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                    [request setHTTPMethod:@"POST"];
                    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
                    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:params options:0 error:nil]];
                    
                    [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [loadingAlert dismissViewControllerAnimated:YES completion:^{
                                if (error) {
                                    UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"网络错误" 
                                                                                                            message:@"请检查网络连接" 
                                                                                                     preferredStyle:UIAlertControllerStyleAlert];
                                    [errAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                                    [self.window.rootViewController presentViewController:errAlert animated:YES completion:nil];
                                    return;
                                }
                                
                                NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                                if ([result[@"code"] integerValue] == 200) {
                                    // 验证成功，记录进入日志
                                    sendLog(inputKey, @"enter_app", [NSString stringWithFormat:@"iOS %@", getSystemVersion()]);
                                    
                                    // 启动心跳
                                    dispatch_async(dispatch_get_global_queue(0, 0), ^{
                                        while (1) {
                                            [NSThread sleepForTimeInterval:300]; // 5分钟一次
                                            sendLog(inputKey, @"heartbeat", @"");
                                        }
                                    });
                                } else {
                                    // 验证失败
                                    UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"验证失败" 
                                                                                                            message:result[@"message"] 
                                                                                                     preferredStyle:UIAlertControllerStyleAlert];
                                    [errAlert addAction:[UIAlertAction actionWithTitle:@"重试" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                        // 清除卡密，重新输入
                                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CARD_KEY_STORAGE];
                                        [[NSUserDefaults standardUserDefaults] synchronize];
                                        [self application:application didFinishLaunchingWithOptions:launchOptions];
                                    }]];
                                    [self.window.rootViewController presentViewController:errAlert animated:YES completion:nil];
                                }
                            }];
                        });
                    }] resume;
                } else {
                    // 卡密为空，重新输入
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CARD_KEY_STORAGE];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [self application:application didFinishLaunchingWithOptions:launchOptions];
                }
            }];
            
            [alert addAction:confirmAction];
            [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
        return YES;
    }
    
    // 已有卡密，发送进入日志
    sendLog(savedKey, @"enter_app", [NSString stringWithFormat:@"iOS %@", getSystemVersion()]);
    
    // 验证卡密
    NSDictionary *params = @{
        @"card_key": savedKey,
        @"device_code": getDeviceID(),
        @"user_ip": @"",
        @"platform": @"ios",
        @"action": @"verify",
        @"extra_info": @""
    };
    
    NSURL *url = [NSURL URLWithString:API_URL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:params options:0 error:nil]];
    
    __block BOOL shouldExit = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || [data length] == 0) {
            shouldExit = YES;
            dispatch_semaphore_signal(sema);
            return;
        }
        
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([result[@"code"] integerValue] != 200) {
            shouldExit = YES;
        } else {
            // 启动心跳
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                while (1) {
                    [NSThread sleepForTimeInterval:300];
                    sendLog(savedKey, @"heartbeat", @"");
                }
            });
        }
        dispatch_semaphore_signal(sema);
    }] resume;
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    if (shouldExit) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"验证失败" 
                                                                           message:@"卡密无效或已过期" 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:CARD_KEY_STORAGE];
                [[NSUserDefaults standardUserDefaults] synchronize];
                exit(0);
            }]];
            [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
        return YES;
    }
    
    return %orig;
}

// 应用退出时发送日志
- (void)applicationWillTerminate:(UIApplication *)application {
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:CARD_KEY_STORAGE];
    sendLog(savedKey, @"exit", @"");
    %orig;
}

%end
 
