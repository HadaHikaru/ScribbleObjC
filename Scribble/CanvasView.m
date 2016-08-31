//
//  CanvasView.m
//  Scribble
//
//  Created by Hikaru Hada on 2016/08/09.
//  Copyright © 2016年 Hikaru Hada. All rights reserved.
//

#import "CanvasView.h"



@interface CanvasView()
{
	// Parameters
	CGFloat defaultLineWidth;
	CGFloat forceSensitivity;
	CGFloat tiltThreshold;
	CGFloat minLineWidth;
	UIImage *drawingImage;

	UIColor *drawColor;
	UIColor *pencilTexture;
	UIColor *eraserColor;
}


@end




@implementation CanvasView

- (void)initParams
{
	defaultLineWidth = 6;
	forceSensitivity = 4.0;
	tiltThreshold = M_PI / 6;
	minLineWidth = 5;
	
	drawingImage = nil;
	drawColor = [UIColor redColor];
	pencilTexture = [UIColor colorWithPatternImage:[UIImage imageNamed:@"PencilTexture"]];
	eraserColor = self.backgroundColor ? self.backgroundColor : [UIColor whiteColor];
}

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		[self initParams];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self) {
		[self initParams];
	}
	return self;
}




- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event
{
	NSArray<UITouch *> *allObjects = [touches allObjects];
	UITouch *touch = allObjects ? [allObjects objectAtIndex:0] : nil;
	if (touch == nil)	return;

	UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0.0);
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	// Draw previous image into context
	if (drawingImage) {
		[drawingImage drawInRect:self.bounds];
	}
	
	//drawStroke(context, touch: touch)
	// 1
	NSArray <UITouch *> *touches2 = [NSArray <UITouch *> array];
	
	// Coalesce Touches
	// 2
	NSArray <UITouch *> *coalescedTouches = [event coalescedTouchesForTouch:touch];
	if (coalescedTouches) {
		touches2 = coalescedTouches;
	} else {
		[touches2 arrayByAddingObject:touch];
	}


	// 4
	for (UITouch *touch2 in touches2) {
		[self drawStroke:context touch:touch2];
	}
	
	// 1
	drawingImage = UIGraphicsGetImageFromCurrentImageContext();
	// 2
	NSArray <UITouch *> *predictedTouches = [event predictedTouchesForTouch:touch];
	if (predictedTouches) {
		for (UITouch *touch2 in predictedTouches) {
			[self drawStroke:context touch:touch2];
		}
	}
	
	
	// Update image
	self.image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event
{
	self.image = drawingImage;
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event
{
	self.image = drawingImage;
}


-(void) drawStroke:(CGContextRef)context
			 touch:(UITouch *)touch
{
	CGPoint previousLocation = [touch previousLocationInView:self];
	CGPoint location = [touch locationInView:self];
	
	// Calculate line width for drawing stroke
	CGFloat lineWidth = defaultLineWidth;
	if (touch.type == UITouchTypeStylus) {
		if (touch.altitudeAngle < tiltThreshold) {
			lineWidth = [self lineWidthForShading:context touch:touch];
		} else {
			lineWidth = [self lineWidthForDrawing:context touch:touch];
		}
		// Set color
		[pencilTexture setStroke];
	} else {
		// Erase with finger
		lineWidth = touch.majorRadius / 2;
		[eraserColor setStroke];
	}
	
	// Set color
	//[drawColor setStroke];
	
	if (context) {
		// Configure line
		CGContextSetLineWidth(context, lineWidth);
		CGContextSetLineCap(context, kCGLineCapRound);
		
		// Set up the points
		CGContextMoveToPoint(context, previousLocation.x, previousLocation.y);
		CGContextAddLineToPoint(context, location.x, location.y);
		
		// Draw the stroke
		CGContextStrokePath(context);
	}
}


-(CGFloat) lineWidthForShading:(CGContextRef)context
						 touch:(UITouch *)touch
{
	// 1
	CGPoint previousLocation = [touch previousLocationInView:self];
	CGPoint location = [touch locationInView:self];
	
	// 2 - vector1 is the pencil direction
	CGVector vector1 = [touch azimuthUnitVectorInView:self];
	
	// 3 - vector2 is the stroke direction
	CGPoint vector2 = CGPointMake(location.x - previousLocation.x, location.y - previousLocation.y);
	
	// 4 - Angle difference between the two vectors
	CGFloat angle = fabs(atan2(vector2.y, vector2.x) - atan2(vector1.dy, vector1.dx));
	
	// 5
	if (angle > M_PI) {
		angle = 2 * M_PI - angle;
	}
	if (angle > M_PI / 2) {
		angle = M_PI - angle;
	}
	
	// 6CGFLOAT_MAX
	CGFloat minAngle = 0;
	CGFloat maxAngle = M_PI / 2;
	CGFloat normalizedAngle = (angle - minAngle) / (maxAngle - minAngle);
	
	// 7
	CGFloat maxLineWidth = 60;
	CGFloat lineWidth = maxLineWidth * normalizedAngle;
	
	// 1 - modify lineWidth by altitude (tilt of the Pencil)
	// 0.25 radians means widest stroke and TiltThreshold is where shading narrows to line.
	
	CGFloat minAltitudeAngle = 0.25;
	CGFloat maxAltitudeAngle = tiltThreshold;
	
	// 2
	CGFloat altitudeAngle = touch.altitudeAngle < minAltitudeAngle ? minAltitudeAngle : touch.altitudeAngle;
	
	// 3 - normalize between 0 and 1
	CGFloat normalizedAltitude = 1 - ((altitudeAngle - minAltitudeAngle) / (maxAltitudeAngle - minAltitudeAngle));
	// 4
	lineWidth = lineWidth * normalizedAltitude + minLineWidth;
	
	// Set alpha of shading using force
	CGFloat minForce = 0.0;
	CGFloat maxForce = 5;
	
	// Normalize between 0 and 1
	CGFloat normalizedAlpha = (touch.force - minForce) / (maxForce - minForce);
	
	if (context) {
		CGContextSetAlpha(context, normalizedAlpha);
	}

	return lineWidth;
}


-(CGFloat) lineWidthForDrawing:(CGContextRef)context
						 touch:(UITouch *)touch
{
	CGFloat lineWidth = defaultLineWidth;
	
	if ([touch force] > 0) {  // If finger, touch.force = 0
		lineWidth = [touch force] * forceSensitivity;
	}
	
	return lineWidth;
}


- (void)clearCanvas:(BOOL)animated
{
	if (animated) {
		[UIView animateWithDuration:0.5 animations:^{
			self.alpha = 0;
		} completion:^(BOOL finished) {
			self.alpha = 1;
			self.image = nil;
			drawingImage = nil;
		}];
	} else {
		self.image = nil;
		drawingImage = nil;
	}
}


@end
