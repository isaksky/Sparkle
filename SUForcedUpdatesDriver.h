//
//  SUForcedUpdatesDriver.h
//  Sparkle
//
//  Created by Isak Sky on 4/16/14.
//
//

#import "SUBasicUpdateDriver.h"

@class SUStatusController;

@interface SUForcedUpdatesDriver : SUBasicUpdateDriver {
    SUStatusController *_statusController;
}

@end
