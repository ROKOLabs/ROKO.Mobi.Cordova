#import <UIKit/UIKit.h>
#import "RMPShareManager.h"
#import <ROKOMobi/ROKOMobi.h>
#import <ROKOMobi/ROKOShareViewController.h>

NSString *const kDisplayMessageKey = @"displayMessage";
NSString *const kContentTitleKey = @"contentTitle";
NSString *const kContentIdKey = @"contentId";
NSString *const kChannelTypeKey = @"channelType";
NSString *const kShareLinkIdKey = @"linkId";


@interface RMPShareManager () <ROKOShareDelegate> {
    ROKOShare *_shareManager;
}
@end

@implementation RMPShareManager

- (void)pluginInitialize {
    [super pluginInitialize];
    _shareManager = [[ROKOShare alloc] init];
    _shareManager.delegate = self;
}

- (void)share:(CDVInvokedUrlCommand *)command {
    [self share:command andUI:NO];
}

- (void)shareWithUI:(CDVInvokedUrlCommand *)command {
    [self share:command andUI:YES];
}

- (void)parameters:(NSDictionary *)parameters forShareManager:(ROKOShare *)shareManager {
	if (parameters) {
		if (parameters[@"text"]) {
			shareManager.text = parameters[@"text"];
		}
		
		if (parameters[kContentTitleKey]) {
			shareManager.contentTitle = parameters[kContentTitleKey];
		}
		
		id url = parameters[@"contentURL"];
		
		if (url && url != [NSNull null] && [url isKindOfClass:[NSURL class]]) {
			shareManager.contentURL = parameters[@"contentURL"];
		}
		
		if (parameters[@"ShareChannelTypeFacebook"]) {
			[shareManager setText:parameters[@"ShareChannelTypeFacebook"] forShareChannel:ROKOShareChannelTypeFacebook];
		}
		
		if (parameters[@"ShareChannelTypeTwitter"]) {
			[shareManager setText:parameters[@"ShareChannelTypeTwitter"] forShareChannel:ROKOShareChannelTypeTwitter];
		}
		
		if (parameters[@"ShareChannelTypeMessage"]) {
			[shareManager setText:parameters[@"ShareChannelTypeMessage"] forShareChannel:ROKOShareChannelTypeMessage];
		}
	}
}

- (void)share:(CDVInvokedUrlCommand *)command andUI:(BOOL)usingUI {
    [self parseCommand:command];
    NSDictionary *params = command.arguments[0];
	
	if (params) {
        if (usingUI) {
            NSString *contentIdString = params[kContentIdKey];
            
            if (!contentIdString) {
               contentIdString = [[NSUUID UUID] UUIDString];
            }
            
            ROKOShareViewController *controller = [ROKOShareViewController buildControllerWithContentId: contentIdString];
			[self parameters:params forShareManager:controller.shareManager];
            if (params[kDisplayMessageKey]) {
                controller.displayMessage = params[kDisplayMessageKey];
            }

            [self.viewController presentViewController:controller animated:YES completion:nil];
        } else {
			[self parameters:params forShareManager:_shareManager];
            ROKOShareChannelType channelType = ROKOShareChannelTypeUnknown;
            NSString *channelTypeString = params[kChannelTypeKey];
            
            if (channelTypeString) {
                channelType = [self shareChannelType:channelTypeString];
            }
            
            NSString *contentIdString = params[kContentIdKey];
            
            if (contentIdString) {
                _shareManager.contentId = contentIdString;
            } else {
                _shareManager.contentId = [[NSUUID UUID] UUIDString];
            }
            
            _shareManager.presentingController = self.viewController;
            [_shareManager shareWithChannelType:channelType];
        }
    }
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Done"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.command.callbackId];
}

- (void)shareCompleteForChannel:(CDVInvokedUrlCommand *)command {
    [self parseCommand:command];
    NSDictionary *params = command.arguments[0];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Bad params"];
    
    if (params) {
        NSString *contentIdString = params[kContentIdKey];
        ROKOShare *shareManager = [[ROKOShare alloc] init];
        
        if (contentIdString && contentIdString.length > 0) {
            shareManager.contentId = contentIdString;
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"contentId field should be not empty"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId: self.command.callbackId];
            return;
        }
        
        NSNumber *linkId = params[kShareLinkIdKey];
        if (linkId) {
            shareManager.linkId = linkId;
        }
        
        ROKOShareChannelType channelType = ROKOShareChannelTypeUnknown;
        NSString *channelTypeString = params[kChannelTypeKey];
        
        if (channelTypeString) {
            channelType = [self shareChannelType:channelTypeString];
        }
        
        NSError *error = [shareManager shareCompleteForChannel:channelType];
        
        if (error) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error description]];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Done"];
        }
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.command.callbackId];
}

- (void)shareManager:(ROKOShare *)manager didFinishWithActivityType:(ROKOShareChannelType)activityType result:(ROKOSharingResult)result {
    CDVPluginResult *pluginResult = nil;
    
    switch (result) {
    case ROKOSharingResultDone:
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Done"];
        break;
        
    case ROKOSharingResultCancelled:
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Canceled"];
        break;
        
    case ROKOSharingResultFailed:
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Failed"];
        break;
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.command.callbackId];
}

- (void)shareManager:(ROKOShare *)shareManager willApplyScheme:(ROKOShareScheme *)scheme {

}

- (void)shareManager:(ROKOShare *)shareManager willShowSharingMessageComposer:(id)messageComposer forShareChannelType:(ROKOShareChannelType)channelType {

}

- (ROKOShareChannelType)shareChannelType:(NSString *)channelType {
    if ([channelType isEqualToString:@"sms"]) {
        return ROKOShareChannelTypeMessage;
    }
    
    if ([channelType isEqualToString:@"twitter"]) {
        return ROKOShareChannelTypeTwitter;
    }
    
    if ([channelType isEqualToString:@"facebook"]) {
        return ROKOShareChannelTypeFacebook;
    }
    
    if ([channelType isEqualToString:@"email"]) {
        return ROKOShareChannelTypeEmail;
    }
    
    if ([channelType isEqualToString:@"copy"]) {
        return ROKOShareChannelTypeCopy;
    }
    
    return ROKOShareChannelTypeUnknown;
}

@end
