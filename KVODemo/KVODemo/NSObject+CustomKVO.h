//
//  NSObject+CustomKVO.h
//  KVODemo
//
//  Created by lee on 2019/7/4.
//  Copyright © 2019 Onlyou. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (CustomKVO)

- (void)lh_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context;

@end

NS_ASSUME_NONNULL_END
