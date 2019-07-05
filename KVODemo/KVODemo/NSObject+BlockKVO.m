//
//  NSObject+BlockKVO.m
//  KVODemo
//
//  Created by lee on 2019/7/5.
//  Copyright © 2019 Onlyou. All rights reserved.
//

#import "NSObject+BlockKVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

//关联LHObserver对象数组
const NSString *LHOBSERVER_ARRAY_ASSOCIATED_KEY = @"LHOBSERVER_ARRAY_ASSOCIATED_KEY";
//中间类的前缀名称
const NSString *KVO_CLASS_NAME_PREFIX = @"LHKVONotifying_";
//getter方法名称
const NSString *LH_GETTER_FUNCTION_NAME = @"LH_GETTER_FUNCTION_NAME";

@interface LHObserver : NSObject

@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, copy) NSString *observerKey;
@property (nonatomic, weak) id context;
@property (nonatomic, copy) LH_ObserverHandler observerHandler;

@end

@implementation LHObserver

- (instancetype)initWithObersver:(NSObject *)observer
                     observerKey:(NSString *)observerKey
                 observerHandler:(LH_ObserverHandler)observerHandler
                         context:(nullable id)context
{
    self = [super init];
    
    if ( self ) {
        
        self.observer = observer;
        self.observerKey = observerKey;
        self.observerHandler = observerHandler;
        self.context = context;
        
    }
    
    return self;
}

@end

@implementation NSObject (BlockKVO)

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
       observerHandler:(LH_ObserverHandler)observerHandler
{
    
    /*
     1.创建一个中间类；
     2.isa指针指向中间类；
     3.重写setter方法；
     */
    
    //先获取原先类的setter方法
    SEL setter = [self setterSELWithObserverKey:observerKey];
    Method setterMethod = class_getInstanceMethod([self class], setter);
    
    //保存getter名称
    objc_setAssociatedObject(self, &LH_GETTER_FUNCTION_NAME, observerKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
    
    //1.创建一个中间类, 2.并且isa指针指向中间类；
    Class kvoClass = [self createKVOClassWithOriginalClass:[self class]];
    
    //2.isa指针指向中间类；
    object_setClass(self, kvoClass);

    //3.重写setter方法；
    //(1)获取setter方法 - 上面已经先获取了
    //（2）判断中间类是否存在setter方法
    if ( ![self hasSelectorWithClass:kvoClass sel:setter] ) {
        //（3）不存在就添加setter方法
        class_addMethod(kvoClass, setter, (IMP)setterIMP, method_getTypeEncoding(setterMethod));
    }
    
    //存储LHObserver的对象的可变数组
    NSMutableArray *observers = objc_getAssociatedObject(self, &LHOBSERVER_ARRAY_ASSOCIATED_KEY);
    if ( !observers ) {
        observers = [NSMutableArray array];
    }
    //初始化LHObserver的实例对象
    LHObserver *observerInfo = [[LHObserver alloc] initWithObersver:observer
                                                      observerKey:observerKey
                                                  observerHandler:observerHandler
                                                          context:context];
    [observers addObject:observerInfo];
    
    objc_setAssociatedObject(self, &LHOBSERVER_ARRAY_ASSOCIATED_KEY, observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/**
 移除观察者
 
 @param observer 观察者
 @param observerKey 观察的名称
 */
- (void)lh_removeObserver:(NSObject *)observer forObserverKey:(NSString *)observerKey
{
    NSMutableArray *observers = objc_getAssociatedObject(self, &LHOBSERVER_ARRAY_ASSOCIATED_KEY);
    if ( !observers ) {
        return;
    }
    
    LHObserver *tempObserverObject = nil;
    for (LHObserver *observerObject in observers) {
        if ( observerObject.observer == observer && [observerObject.observerKey isEqualToString:observerKey] ) {
            tempObserverObject = observerObject;
            break;
        }
    }
    
    //移除
    if ( tempObserverObject ) {
        [observers removeObject:tempObserverObject];
    }
}

/**
 创建中间类

 @param originalClass 原先的类
 @return 中间类
 */
- (Class)createKVOClassWithOriginalClass:(Class)originalClass
{
    //获取原先类的名称
    NSString *originalClassName = [NSString stringWithUTF8String:object_getClassName(originalClass)];
    //拼接中间类的名称
    NSString *kvoClassName = [NSString stringWithFormat:@"%@%@", KVO_CLASS_NAME_PREFIX, originalClassName];
    
    //判断中间类是否存在，如果存在直接返回即可
    Class kvoClass = objc_getClass(kvoClassName.UTF8String);
    
    if ( kvoClass ) {
        return kvoClass;
    }
    
    //不存在的话，就开始初始化与注册类
    kvoClass = objc_allocateClassPair([self class], kvoClassName.UTF8String, 0);
    objc_registerClassPair(kvoClass);
    
    //添加class的方法，返回父类
    Method classMethod = class_getInstanceMethod(originalClass, @selector(class));
    class_addMethod(kvoClass, NSSelectorFromString(@"class"), (IMP)getKVOClass, method_getTypeEncoding(classMethod));
//    NSLog(@"%d", [self hasSelectorWithClass:kvoClass sel:@selector(class)]);
    
    return kvoClass;
}

/**
 获取setter方法

 @param observerKey 观察的名称
 @return setter SEL
 */
- (SEL)setterSELWithObserverKey:(NSString *)observerKey
{
    //比如observerKey的值为name，那么setter的方法名称就是 setName:  冒号不要忘记咯~
    return NSSelectorFromString([NSString stringWithFormat:@"set%@:", [observerKey capitalizedString]]);
}


/**
 是否已经存在sel方法

 @param cls 类
 @param sel sel方法
 @return YES：存在  NO:不存在
 */
-(BOOL)hasSelectorWithClass:(Class)cls sel:(SEL)sel
{
    unsigned int outCount = 0;
    Method *methodList = class_copyMethodList(cls, &outCount);
    for (int i = 0; i < outCount; ++i) {
        Method method = methodList[i];
        SEL selector = method_getName(method);
        if ( selector == sel ) {
            free(methodList);
            return YES;
        }
    }
    free(methodList);
    return NO;
}


void setterIMP(id self, SEL _cmd, id newValue)
{
    /*
     1.willChangeValueForKey
     2.[super setter]
     3.didChangeValueForKey
     */

    //获取getter方法名称
    NSString *getterFuncName = objc_getAssociatedObject(self, &LH_GETTER_FUNCTION_NAME);
    
    //先将当前中间类保存下来
    Class kvoClass = object_getClass(self);
    
    //先将isa指针指向父类,注意之前已经实现过class方法
    Class cls = [self class];
    object_setClass(self, cls);
    
    //获取旧数据
    id oldValue = ((id(*)(id, SEL))objc_msgSend)(self, NSSelectorFromString(getterFuncName));
    
    //调用父类的setter
    ((id(*)(id, SEL, id))objc_msgSend)(self, _cmd, newValue);
    
    //拼凑数据
    NSMutableDictionary *change = [@{} mutableCopy];
    //这里要根据自己的需求来定，如果对应的value是空的话，直接赋值空字符串
    if ( oldValue ) {
        change[NSKeyValueChangeOldKey] = oldValue;
    } else {
        change[NSKeyValueChangeOldKey] = @"";
    }
    
    if ( newValue ) {
        change[NSKeyValueChangeNewKey] = newValue;
    } else {
        change[NSKeyValueChangeNewKey] = @"";
    }
    
    //再将isa指针指向中间类
    object_setClass(self, kvoClass);
    
    NSMutableArray *observers = objc_getAssociatedObject(self, &LHOBSERVER_ARRAY_ASSOCIATED_KEY);
    if ( !observers || observers.count <= 0 ) {
        return;
    }
    //循环获取observerObject，然后执行block
    for (LHObserver *observerObject in observers) {
        if ( [observerObject.observerKey isEqualToString:getterFuncName] ) {
            if ( observerObject.observerHandler ) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    //这里是在子线程
                    observerObject.observerHandler(observerObject.observer, observerObject.observerKey, self, change, observerObject.context);
                });
            }
            break;
        }
    }
}


/**
 返回父类

 @param self self
 @param _cmd _cmd
 @return 父类
 */
Class getKVOClass(id self, SEL _cmd)
{
    return class_getSuperclass(object_getClass(self));
}

@end
