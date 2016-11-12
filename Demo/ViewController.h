//
//  ViewController.h
//  Demo
//
//  Created by dom on 11/10/16.
//  Copyright © 2016 domchen. All rights reserved.
//

#import <UIKit/UIKit.h>

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height
#define VIDEO_FOLDER @"videoFolder"

@interface ViewController : UIViewController
@property (nonatomic , retain)IBOutlet UIButton *recordButton;
@property (nonatomic , retain)IBOutlet UIButton *stopButton;
@property (nonatomic , retain)IBOutlet UIView *viewContainer;
@property (nonatomic , retain)IBOutlet UIView *bottomView;
@property (nonatomic , retain)IBOutlet UILabel *timeLabel;
-(IBAction)startRecord:(id)sender;
-(IBAction)stopRecord:(id)sender;
@end

