# Method Swizzling in iOS Development
Most of the use cases we have found for method swizzling involve extending the functionality of an existing method. Meaning, there is some method that you can’t modify directly, but would like to add additional functionality to (e.g. logging, tracking analytics, injecting JavaScript in WebViews to find JS errors, etc.). It might seem like subclassing would be the most preferred way to do this, and for most scenarios, it probably is, though there are places where swizzling makes more sense to intercept the methods. To get a feel of what those scenarios would look like, let’s look at an example.

Method Swizzling Use case Example

Suppose we want analytics each time the user views a screen, the app should call the API requests for page views tracking.

We could subclass UIViewController with a TrackingViewController and use that as our new base class for view controllers. While this approach is usually reasonable, it may be undesirable for several reasons:

We would need to shim in subclasses for UIViewController, and all of the other controllers that extend it (e.g., UITableViewController, UINavigationViewController, etc.) to ensure that all viewWillAppear calls are tracked.
In order to make use of your tracking functionality, other projects would have to shim in a TrackingViewController as well (e.g., this solution is not easily extensible to other projects). Imagine a situation where you provide an analytics library and the developer will have to subclass your SDK class for every UIViewController.
We have limited ability to hook into the code of 3rd party libraries if necessary. In that case, we can't add our requirement of tracking analytics.
Method swizzling can solve this problem in quite a simple way. All we have to do is to write a custom function _tracked_viewWillAppear then swap it with the original function viewWillAppear 

At run time, calling viewWillAppear on UIViewController calls_tracked_viewWillAppear method where we will have the notification logic.

Now, in the child classes of UIViewControllers, super.ViewWillAppear, Calls the _tracked_viewWillAppear. Now since all the extended/derived controllers like UITableViewController and UINavigationController are subclasses of UIViewController, the same gets called for all the different classes.

To achieve this, we can do the following:

How to Swizzle a Method?

The main function we need to remember is method_exchangeImplementations:

func method_exchangeImplementations(_ originalMethod: Method, _ swizzledMethod: Method)
As the name reflects, the implementations of originalMethod and swizzledMethod get swapped after calling this function. It means that an invocation to originalMethod actually executes the code inside swizzledMethod and vice versa.

Create a category/extension

It’s a standard practice to create a category method when using method swizzling to extend the existing functionality. For our tracking example, let’s create a UIViewController+Tracking category on UIViewController.

Write the additional functionality

The next step is to write a category method inside of our UIViewController+Tracking class that includes the functionality we wish to add tracking (in our example). To do this we’ll write a method called _tracked_viewWillAppear.

Swift

@objc dynamic func _tracked_viewWillAppear(_ animated: Bool) {
    NSLog("Enter screen: \(type(of: self))")
    _tracked_viewWillAppear(animated)
}
Objective-C

- (void) _tracked_viewWillAppear:(BOOL)animated {
    NSLog(@"Enter screen: %@", [self class]);
    [self _tracked_viewWillAppear:animated];
}
Note: It may seem this method will run infinitely, but it won’t. Because at runtime _tracked_viewWillAppear: selector would point on viewWillAppear. Then we have an NSLog to log our command. In short, when the view is about to be displayed, the program prints a log, for example, Enter screen: SampleViewController and does what it is supposed to do.

Now for any viewWillAppear call on UIViewController from our code or from a framework, our swizzled method will be executed.

Swizzle the methods

The last step is to write the code that actually swaps the memory locations that the two selectors correspond to. This is typically done in the load class method and wrapped in a dispatch_once. In our UIViewController+Tracking class, we’ll add the following.

Objective-C

#import <objc/runtime.h>
#import "UIViewController+Tracking.h"

@implementation UIViewController (Tracking)
+ (void)load {
    static dispatch_once_t once_token;
    dispatch_once(&once_token, ^{
        Class class = [self class];
        SEL defaultSelector = @selector(viewWillAppear:);
        SEL swizzledSelector = @selector(_tracked_viewWillAppear:);
        // 1) The IMP of default method will point on UIViewController's
        //viewWillAppear implementation
        Method defaultMethod =
        	class_getInstanceMethod(class, defaultSelector);
        Method swizzledMethod = 
        	class_getInstanceMethod(class, swizzledSelector);
        // 2) Here we add the method defaultSelector with the IMP to point
        //on swizzledMethod's implementation.
        BOOL isMethodExists = 
        	!class_addMethod(class, defaultSelector,
            	method_getImplementation(swizzledMethod),
                method_getTypeEncoding(swizzledMethod));
        if (isMethodExists) {
            method_exchangeImplementations(defaultMethod, swizzledMethod);
        }
        else {
            // 3) We replace swizzledSelector method with the method that
            //defaultMethod was pointing
            //(The initial value which points on UIViewController's
            //viewWillAppear IMP). 
            //Note that if we run class_getInstanceMethod
            //(class, swizzledSelector);
            //will get the method 
            //that we add point 2 instead of the initial.
            class_replaceMethod(class, swizzledSelector,
            	method_getImplementation(defaultMethod),
                method_getTypeEncoding(defaultMethod));
        	}
    });
}
- (void) _tracked_viewWillAppear:(BOOL)animated {
    NSLog(@"Enter screen: %@", [self class]);
    [self _tracked_viewWillAppear:animated];
}
@end
Swift

static func swizzle() {
        //Make sure This isn't a subclass of UIViewController,
        //So that It applies to all UIViewController childs
        if self != UIViewController.self {
            return
        }
        let _: () = {
            let originalSelector = 
            	#selector(UIViewController.viewWillAppear(_:))
            let swizzledSelector = 
            	#selector(UIViewController._tracked_viewWillAppear(_:))
            let originalMethod = 
            	class_getInstanceMethod(self, originalSelector)
            let swizzledMethod = 
            	class_getInstanceMethod(self, swizzledSelector)
            method_exchangeImplementations(originalMethod!, swizzledMethod!);
        }()
    }
Note: Unlike in Swift3x, in swift 4, we cannot write this swizzling in the initialise method, so we need to write the one static method and we can call it in AppDelegate didFinishLaunchingWithOptions method.

There are two cases that need to be handled:

Need to check whether the method we're swizzling is actually defined in a superclass by using class_addMethod to the target class. If it returns true, then we can use class_replaceMethod to replace with the superclass' implementation so our new version will be able to rightly call the old one.
If the method is defined in the target class, then class_addMethod will fail so we need to use method_exchangeImplementations to just swap the new and old versions.
This code swizzles the method implementation for viewWillAppear with the implementation for _tracked_viewWillAppear. To get this to compile, you need to import objc/runtime.h. Putting it all together, our UIViewController+Tracking class looks like this:

Objective-C

#import <objc/runtime.h>
#import "UIViewController+Tracking.h"

@implementation UIViewController (Tracking)
+ (void)load {
    static dispatch_once_t once_token;
    dispatch_once( &once_token, ^{
        Class class = [self class];
        SEL defaultSelector = @selector(viewWillAppear:);
        SEL swizzledSelector = @selector(_tracked_viewWillAppear:);
        // 1) The IMP of default method will point on UIViewController's 
        //viewWillAppear implementation
        Method defaultMethod = 
        	class_getInstanceMethod(class, defaultSelector);
        Method swizzledMethod = 
        	class_getInstanceMethod(class, swizzledSelector);
        // 2) Here we add the method defaultSelector with the IMP to point
        //on swizzledMethod's implementation.
        BOOL isMethodExists = !class_addMethod(class, defaultSelector,
			method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod));
        if (isMethodExists) {
            method_exchangeImplementations(defaultMethod, swizzledMethod);
        }
        else {
            // 3) We replace swizzledSelector method with the method that 
            //defaultMethod was pointing
            //(The initial value which points on UIViewController's
            //viewWillAppear IMP).
            //Note that if we run class_getInstanceMethod
            //(class, swizzledSelector);
            //will get the method that we add point 
            //2 instead of the initial.
            class_replaceMethod(class, swizzledSelector,
				method_getImplementation(defaultMethod),
                method_getTypeEncoding(defaultMethod));
        	}
    	});
}
- (void) _tracked_viewWillAppear:(BOOL)animated {
    NSLog(@"Enter screen: %@", [self class]);
    [self _tracked_viewWillAppear:animated];
}
@end
Swift

import UIKit
extension UIViewController {
    @objc dynamic func _tracked_viewWillAppear(_ animated: Bool) {
        NSLog("Enter screen: \(type(of: self))")
        _tracked_viewWillAppear(animated)
    }

    static func swizzle() {
        //Make sure This isn't a subclass of UIViewController,
        // So that It applies to all UIViewController childs
        if self != UIViewController.self {
            return
        }
        let _: () = {
            let originalSelector = 
            	#selector(UIViewController.viewWillAppear(_:))
            let swizzledSelector =
            	#selector(UIViewController._tracked_viewWillAppear(_:))
            let originalMethod = 
            	class_getInstanceMethod(self, originalSelector)
            let swizzledMethod = 
            	class_getInstanceMethod(self, swizzledSelector)
            method_exchangeImplementations
            	(originalMethod!, swizzledMethod!);
        }()
    }
}

In AppDelegate we need to call this method in Swift


func application( _ application: UIApplication, 
			didFinishLaunchingWithOptions 
			launchOptions: [UIApplication.LaunchOptionsKey: Any]?
            ) -> Bool {
			   UIViewController.swizzle()
				// Override point for customization after 
                // application launch.
		   	 return true
}
