//
//  ViewController.m
//  Scribble
//
//  Created by Hikaru Hada on 2016/08/09.
//  Copyright © 2016年 Hikaru Hada. All rights reserved.
//

#import "ViewController.h"
#import "CanvasView.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [canvasView clearCanvas:false];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)motionEnded:(UIEventSubtype)motion
          withEvent:(UIEvent *)event
{
    [canvasView clearCanvas:true];
}


@end
