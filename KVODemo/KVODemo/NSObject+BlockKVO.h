//
//  NSObject+BlockKVO.h
//  KVODemo
//
//  Created by lee on 2019/7/5.
//  Copyright © 2019 Onlyou. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/**
 监听属性变化

 @param observerObject 观察者
 @param observerKey 观察的名称
 @param object 被观察者
 @param change 监听返回的信息
 @param context 上下文
 */
typedef void(^LH_ObserverHandler)(id observerObject, NSString *observerKey, id object, NSDictionary<NSKeyValueChangeKey,id> *change, id context);

@interface NSObject (BlockKVO)


/**
 监听属性

 @param observer 观察者
 @param observerKey 观察的名称
 @param options 新旧值
 @param context 上下文
 @param observerHandler 监听属性变化Block
 */
- (void)lh_addObserver:(NSObject *)observer
        forObserverKey:(NSString *)observerKey
               options:(NSKeyValueObservingOptions)options
               context:(nullable id)context
       observerHandler:(LH_ObserverHandler)observerHandler;


/**
 移除观察者

 @param observer 观察者
 @param observerKey 观察的名称
 */
- (void)lh_removeObserver:(NSObject *)observer forObserverKey:(NSString *)observerKey;

@end

NS_ASSUME_NONNULL_END
