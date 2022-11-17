//
//  UIViewController++.swift
//  MethodSwizing
//
//  Created by Joy on 17/11/22.
//
///https://www.innominds.com/blog/method-swizzling-in-ios-development
///
import Foundation
import UIKit

extension UIViewController{
    @objc dynamic func _tracked_viewWillAppear(_ animated : Bool){
        NSLog("Enter Screen : \(type(of: self))")
        //this will not cause infinity loop
        _tracked_viewWillAppear(animated)
    }
    static func swizzle(){
        if self != UIViewController.self{
            return
        }
        let _ : () = {
            let originalSelector = #selector(UIViewController.viewWillAppear(_:))
            let swizzledSelector = #selector(UIViewController._tracked_viewWillAppear(_:))
            let originalMethod = class_getInstanceMethod(self, originalSelector)
            let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
            guard let originalMethod = originalMethod, let swizzledMethod = swizzledMethod else{
                return
            }
            let isMethodeExist = !class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
            if isMethodeExist{
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }else{
                class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
            }
            
        }()
        
    }
}
