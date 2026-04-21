#import <UIKit/UIKit.h>

#define API_URL @"http://154.37.214.65/api/verify/check"

%hook AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"需要卡密" message:@"请输入授权卡密" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"输入卡密";
    }];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *key = alert.textFields.firstObject.text;
        if (key.length > 0) {
            [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"BoYuCardKey"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }];
    
    [alert addAction:okAction];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
    
    return %orig;
}

%end
