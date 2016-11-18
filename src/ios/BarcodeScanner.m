//
//  BarcodeScanner.m
//  BarcodeScanner
//
//  Created by Patrícia Gabriele Neri on 16/11/16.
//
//

#import "BarcodeScanner.h"
#import <AVFoundation/AVFoundation.h>
#import "PgnScanner.h"

#pragma mark - State

@interface BarcodeScanner ()
@property bool scanInProgress;
@property NSString *scanCallbackId;
@property PgnScanner *scanReader;

@end

#pragma mark - Synthesize

@implementation BarcodeScanner

@synthesize scanInProgress;
@synthesize scanCallbackId;
@synthesize scanReader;
UIView *_bottomPanel;
UILabel *_topTitle;
NSString *_prompt;
NSString *_orientation;
NSString *_flash;
UIButton *_backButton;
BOOL _preferFrontCamera;
BOOL _showFlipCameraButton;

#pragma mark - Cordova Plugin

- (void)pluginInitialize {
    self.scanInProgress = NO;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    return;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - Plugin API

- (void)scan: (CDVInvokedUrlCommand*)command;
{
    [[UIDevice currentDevice] performSelector:@selector(setOrientation:)
                               withObject:(__bridge id)((void*)UIInterfaceOrientationMaskPortrait)];

    if (self.scanInProgress) {
        [self.commandDelegate
         sendPluginResult: [CDVPluginResult
                            resultWithStatus: CDVCommandStatus_ERROR
                            messageAsString:@"A scan is already in progress."]
         callbackId: [command callbackId]];

    } else {

        NSDictionary* options = command.arguments.count == 0 ? [NSNull null] : [command.arguments objectAtIndex:0];

        if ([options isKindOfClass:[NSNull class]]) {
          options = [NSDictionary dictionary];
        }
        _preferFrontCamera = [options[@"preferFrontCamera"] boolValue];
        _showFlipCameraButton = [options[@"showFlipCameraButton"] boolValue];
        _prompt = options[@"prompt"];
        _orientation = options[@"orientation"];
        _flash = options[@"flash"];

        self.scanInProgress = YES;
        self.scanCallbackId = [command callbackId];
        self.scanReader = [PgnScanner new];
        self.scanReader.readerDelegate = self;
        [self.scanReader.scanner setSymbology: ZBAR_UPCA config: ZBAR_CFG_ENABLE to: 0];
        self.scanReader.readerView.zoom = 1.0;

        if ([_flash isEqualToString:@"on"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        } else if ([_flash isEqualToString:@"off"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        } else if ([_flash isEqualToString:@"auto"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
        } else {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        }

       self.scanReader.showsZBarControls = NO;

        if([_orientation  isEqual: @"landscape"]){
            [self.scanReader.view.layer addSublayer:[self createOverlayLandscape]];
        } else {
            [self.scanReader.view.layer addSublayer:[self createOverlayPortrait]];
        }

        [self.viewController presentViewController:self.scanReader animated:YES completion:nil];
    }
}

#pragma mark - Overlay

- (CALayer*)createOverlayLandscape {
    CGRect bounds = [[UIScreen mainScreen] bounds];

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake((bounds.size.width/4), 0, bounds.size.width-(bounds.size.width/2), bounds.size.height) cornerRadius:0];
    UIBezierPath *circlePath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, bounds.size.width, bounds.size.height) cornerRadius:0];
    [path appendPath:circlePath];
    [path setUsesEvenOddFillRule:YES];
    CAShapeLayer *fillLayer = [CAShapeLayer layer];
    fillLayer.path = path.CGPath;
    fillLayer.fillRule = kCAFillRuleEvenOdd;
    fillLayer.fillColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1].CGColor;
    fillLayer.opacity = 0.5;

    return fillLayer;
}


- (CALayer*)createOverlayPortrait {
    CGRect bounds = [[UIScreen mainScreen] bounds];

    int radius = bounds.size.width;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, bounds.size.width, bounds.size.height) cornerRadius:0];
    UIBezierPath *circlePath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, (bounds.size.height-bounds.size.width)/2, radius, radius) cornerRadius:0];
    [path appendPath:circlePath];
    [path setUsesEvenOddFillRule:YES];

    CAShapeLayer *fillLayer = [CAShapeLayer layer];
    fillLayer.path = path.CGPath;
    fillLayer.fillRule = kCAFillRuleEvenOdd;
    fillLayer.fillColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1].CGColor;
    fillLayer.opacity = 0.5;

    return fillLayer;
}



#pragma mark - Helpers

- (void)sendScanResult: (CDVPluginResult*)result {
    [self.commandDelegate sendPluginResult: result callbackId: self.scanCallbackId];
}

#pragma mark - ZBarReaderDelegate

- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    return;
}

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info {
    if ([self.scanReader isBeingDismissed]) {
        return;
    }

    id<NSFastEnumeration> results = [info objectForKey: ZBarReaderControllerResults];

    ZBarSymbol *symbol = nil;
    for (symbol in results) break; // get the first result

    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                               resultWithStatus: CDVCommandStatus_OK
                               messageAsString: symbol.data]];
    }];
}

- (void) imagePickerControllerDidCancel:(UIImagePickerController*)picker {
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"cancelled"]];
    }];
}

- (void) readerControllerDidFailToRead:(ZBarReaderController*)reader withRetry:(BOOL)retry {
    [self.scanReader dismissViewControllerAnimated: YES completion: ^(void) {
        self.scanInProgress = NO;
        [self sendScanResult: [CDVPluginResult
                                resultWithStatus: CDVCommandStatus_ERROR
                                messageAsString: @"Failed"]];
    }];
}



@end
