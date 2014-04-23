//
//  SUForcedUpdatesDriver.m
//  Sparkle
//
//  Created by Isak Sky on 4/16/14.
//
//

#import "SUForcedUpdatesDriver.h"

#import "SUStatusController.h"

//#import "SUUpdateAlert.h"
#import "SUUpdater_Private.h"
#import "SUHost.h"
#import "SUStatusController.h"
#import "SUConstants.h"
#import "SUPasswordPrompt.h"

@implementation SUForcedUpdatesDriver

- (void)didFindValidUpdate
{
	if ([[updater delegate] respondsToSelector:@selector(updater:didFindValidUpdate:)])
		[[updater delegate] updater:updater didFindValidUpdate:updateItem];
    	
    _statusController = [[SUStatusController alloc] initWithHost:host];
    [_statusController beginActionWithTitle:SULocalizedString(@"Downloading update...", @"Take care not to overflow the status window.") maxProgressValue:0.0 statusText:nil];
    [_statusController setButtonTitle:SULocalizedString(@"Cancel", nil) target:self action:@selector(cancelDownload:) isDefault:NO];
    [_statusController setButtonEnabled:NO];
    [_statusController showWindow:self];
    [self downloadUpdate];
}

- (void)didNotFindUpdate
{
	if ([[updater delegate] respondsToSelector:@selector(updaterDidNotFindUpdate:)])
		[[updater delegate] updaterDidNotFindUpdate:updater];
	[[NSNotificationCenter defaultCenter] postNotificationName:SUUpdaterDidNotFindUpdateNotification object:updater];
	
	[self abortUpdate];
}

- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response
{
	[_statusController setMaxProgressValue:[response expectedContentLength]];
}   

- (NSString *)humanReadableSizeFromDouble:(double)value
{
	if (value < 1000)
		return [NSString stringWithFormat:@"%.0lf %@", value, SULocalizedString(@"B", @"the unit for bytes")];
	
	if (value < 1000 * 1000)
		return [NSString stringWithFormat:@"%.0lf %@", value / 1000.0, SULocalizedString(@"KB", @"the unit for kilobytes")];
	
	if (value < 1000 * 1000 * 1000)
		return [NSString stringWithFormat:@"%.1lf %@", value / 1000.0 / 1000.0, SULocalizedString(@"MB", @"the unit for megabytes")];
	
	return [NSString stringWithFormat:@"%.2lf %@", value / 1000.0 / 1000.0 / 1000.0, SULocalizedString(@"GB", @"the unit for gigabytes")];
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{
	[_statusController setProgressValue:[_statusController progressValue] + (double)length];
	if ([_statusController maxProgressValue] > 0.0)
		[_statusController setStatusText:[NSString stringWithFormat:SULocalizedString(@"%@ of %@", nil), [self humanReadableSizeFromDouble:[_statusController progressValue]], [self humanReadableSizeFromDouble:[_statusController maxProgressValue]]]];
	else
		[_statusController setStatusText:[NSString stringWithFormat:SULocalizedString(@"%@ downloaded", nil), [self humanReadableSizeFromDouble:[_statusController progressValue]]]];
}

- (IBAction)cancelDownload: (id)sender
{
	if (download)
		[download cancel];
	[self abortUpdate];
}

- (void)extractUpdate
{
	// Now we have to extract the downloaded archive.
	[_statusController beginActionWithTitle:SULocalizedString(@"Extracting update...", @"Take care not to overflow the status window.") maxProgressValue:0.0 statusText:nil];
	[super extractUpdate];
}

- (void)unarchiver:(SUUnarchiver *)ua extractedLength:(unsigned long)length
{
	// We do this here instead of in extractUpdate so that we only have a determinate progress bar for archives with progress.
	if ([_statusController maxProgressValue] == 0.0)
	{
		NSDictionary * attributes;
		attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:downloadPath error:nil];
		[_statusController setMaxProgressValue:[[attributes objectForKey:NSFileSize] doubleValue]];
	}
	[_statusController setProgressValue:[_statusController progressValue] + (double)length];
}

- (void)unarchiverDidFinish:(SUUnarchiver *)ua
{
    [self installAndRestart:nil];
}

- (void)unarchiver:(SUUnarchiver *)unarchiver requiresPasswordReturnedViaInvocation:(NSInvocation *)invocation
{
    SUPasswordPrompt *prompt = [[SUPasswordPrompt alloc] initWithHost:host];
    NSString *password = nil;
    if([prompt run])
    {
        password = [prompt password];
    }
    [prompt release];
    [invocation setArgument:&password atIndex:2];
    [invocation invoke];
}

- (void)installAndRestart: (id)sender
{
    [self installWithToolAndRelaunch:YES];
}

- (void)installWithToolAndRelaunch:(BOOL)relaunch
{
	[_statusController beginActionWithTitle:SULocalizedString(@"Installing update...", @"Take care not to overflow the status window.") maxProgressValue:0.0 statusText:nil];
	[_statusController setButtonEnabled:NO];
	[super installWithToolAndRelaunch:relaunch];
}

- (void)abortUpdateWithError:(NSError *)error
{
	NSAlert *alert = [NSAlert alertWithMessageText:SULocalizedString(@"Update Error!", nil) defaultButton:SULocalizedString(@"Cancel Update", nil) alternateButton:nil otherButton:nil informativeTextWithFormat: @"%@", [error localizedDescription]];
	[self showModalAlert:alert];
	[super abortUpdateWithError:error];
}

- (void)abortUpdate
{
	if (_statusController)
	{
		[_statusController close];
		[_statusController autorelease];
		_statusController = nil;
	}
	[super abortUpdate];
}

- (void)showModalAlert:(NSAlert *)alert
{
	if ([[updater delegate] respondsToSelector:@selector(updaterWillShowModalAlert:)])
		[[updater delegate] updaterWillShowModalAlert: updater];
    
	// When showing a modal alert we need to ensure that background applications
	// are focused to inform the user since there is no dock icon to notify them.
	if ([host isBackgroundApplication]) { [NSApp activateIgnoringOtherApps:YES]; }
	
	[alert setIcon:[host icon]];
	[alert runModal];
	
	if ([[updater delegate] respondsToSelector:@selector(updaterDidShowModalAlert:)])
		[[updater delegate] updaterDidShowModalAlert: updater];
}

@end
