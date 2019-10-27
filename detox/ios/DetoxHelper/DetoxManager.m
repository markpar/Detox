//
//  DetoxManager.m
//  DetoxHelper
//
//  Created by Leo Natan (Wix) on 9/18/19.
//

#import "DetoxManager.h"
#import "DetoxIPCAPI.h"
#import "UIDatePicker+TestSupport.h"
#import <DetoxIPC/DTXIPCConnection.h>
#import <DetoxSync/DetoxSync.h>
@import ObjectiveC;
@import Darwin;

@interface DetoxManager () <DetoxHelper>
{
	DTXIPCConnection* _runnerConnection;
}

@end

@implementation DetoxManager

+ (void)load
{
	@autoreleasepool
	{
		[self.sharedManager connect];
	}
}

+ (instancetype)sharedManager
{
	static DetoxManager* manager;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		manager = [DetoxManager new];
	});
	
	return manager;
}

- (void)notifyOnCrashWithDetails:(NSDictionary*)details;
{
	[_runnerConnection.remoteObjectProxy notifyOnCrashWithDetails:details];
}

- (void)connect
{	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSString* serviceName = NSProcessInfo.processInfo.environment[@"DetoxRunnerServiceName"];
		_runnerConnection = [[DTXIPCConnection alloc] initWithServiceName:serviceName];
		_runnerConnection.exportedInterface = [DTXIPCInterface interfaceWithProtocol:@protocol(DetoxHelper)];
		_runnerConnection.exportedObject = self;
		_runnerConnection.remoteObjectInterface = [DTXIPCInterface interfaceWithProtocol:@protocol(DetoxTestRunner)];
		CLANG_IGNORE(-Warc-retain-cycles)
		_runnerConnection.invalidationHandler = ^ {
			[self endDelayingTimePickerEventsWithCompletionHandler:nil];
		};
		CLANG_POP
		
		__block BOOL waitForDebugger;
		__block NSDictionary<NSString*, id>* userNotificationData;
		__block NSDictionary<NSString*, id>* userActivityData;
		__block NSURL* openURL;
		__block NSString* sourceApp;
		[[_runnerConnection synchronousRemoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
			NSLog(@"%@", error);
		}] getLaunchArgumentsWithCompletionHandler:^(BOOL _waitForDebugger, NSDictionary<NSString *,id> *_userNotificationData, NSDictionary<NSString *,id> *_userActivityData, NSURL *_openURL, NSString *_sourceApp) {
			waitForDebugger = _waitForDebugger;
			userNotificationData = _userNotificationData;
			userActivityData = _userActivityData;
			openURL = _openURL;
			sourceApp = _sourceApp;
		}];
		
		NSLog(@"");
	});
}

- (void)waitForIdleWithCompletionHandler:(dispatch_block_t)completionHandler
{
	[DTXSyncManager enqueueIdleBlock:^{
		completionHandler();
	}];
}

- (void)beginDelayingTimePickerEvents
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[UIDatePicker dtx_beginDelayingTimePickerEvents];
	});
}

- (void)endDelayingTimePickerEventsWithCompletionHandler:(dispatch_block_t)completionHandler
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[UIDatePicker dtx_endDelayingTimePickerEventsWithCompletionHandler:completionHandler];
	});
}

@end
