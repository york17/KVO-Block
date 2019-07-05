//
//  NSObject+CustomKVO.m
//  KVODemo
//
//  Created by lee on 2019/7/4.
//  Copyright © 2019 Onlyou. All rights reserved.
//

#import "NSObject+CustomKVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

const NSString *LH_OBSERVER = @"LH_OBSERVER";
const NSString *LH_SETTER = @"LH_SETTER";
const NSString *LH_GETTER = @"LH_GETTER";

@implementation NSObject (CustomKVO)

- (void)lh_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context
{
    //获取类名称
    NSString *className = NSStringFromClass([self class]);
    NSString *subClassName = [NSString stringWithFormat:@"LHKVONotifying_%@", className];
    
    Class cls = objc_getClass(subClassName.UTF8String);
    
    if ( !cls ) {
        //创建一个新类
        cls = objc_allocateClassPair([self class], subClassName.UTF8String, 0);
        objc_registerClassPair(cls);
    }
    
    //添加setter方法
    NSString *setterFuncName = [NSString stringWithFormat:@"set%@:", [keyPath capitalizedString]];
    SEL sel = NSSelectorFromString(setterFuncName);
    class_addMethod(cls, sel, (IMP)setterMethod, "v@:@");
    
    //更改isa指针指向
    object_setClass(self, cls);
    
    //将observer,setter,getter保存下来，以供setterMethod使用
    objc_setAssociatedObject(self, &LH_OBSERVER, observer, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(self, &LH_SETTER, setterFuncName, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &LH_GETTER, keyPath, OBJC_ASSOCIATION_COPY_NONATOMIC);

}

void setterMethod(id self, SEL _cmd, id newValue){
    
    //获取setter,getter的方法名称，以及observer
    NSString *setterFuncName = objc_getAssociatedObject(self, &LH_SETTER);
    NSString *getterFuncName = objc_getAssociatedObject(self, &LH_GETTER);
    id observer = objc_getAssociatedObject(self, &LH_OBSERVER);
    
    //获取之前的值
    id oldValue = ((id(*)(id, SEL))objc_msgSend)(self, NSSelectorFromString(getterFuncName));
    
    //调用父类的setter方法
    Class cls = [self class];
    //将当前的类指向原来的类
    object_setClass(self, class_getSuperclass(cls));
    ((id(*)(id, SEL, id))objc_msgSend)(self, NSSelectorFromString(setterFuncName), newValue);
    
    NSMutableDictionary *change = [@{} mutableCopy];
    if ( oldValue ) {
        change[NSKeyValueChangeOldKey] = oldValue;
    }
    
    if ( newValue ) {
        change[NSKeyValueChangeNewKey] = newValue;
    }
    
    ((id(*)(id, SEL, id, id, id, id))objc_msgSend)(observer, @selector(observeValueForKeyPath:ofObject:change:context:), getterFuncName, self, change, nil);
    
    //最后再将isa在指向中间类
    object_setClass(self, cls);
}

@end
