//
//  ViewController.m
//  KVODemo
//
//  Created by lee on 2019/7/2.
//  Copyright © 2019 Onlyou. All rights reserved.
//

#import "ViewController.h"
#import "Person.h"
#import "NSObject+BlockKVO.h"

@interface ViewController ()

@property (nonatomic, strong) Person *p1, *p2;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.p1 = [Person new];
    
    [self.p1 setName:@"1"];
    
    [self.p1 lh_addObserver:self
             forObserverKey:@"name"
                    options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
                    context:@"123"
            observerHandler:^(id  _Nonnull observerObject, NSString * _Nonnull observerKey, id  _Nonnull object, NSDictionary<NSKeyValueChangeKey,id> * _Nonnull change, id  _Nonnull context) {
                NSLog(@"%@, context:%@", change, context);
            }];
    
    
    [self.p1 setName:@"3"];
    
    [self.p1 lh_removeObserver:self forObserverKey:@"name"];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.p1 setName:@"hui"];
}


- (void)dealloc
{
    NSLog(@"%@ dealloc", [self class]);
}

@end
