//
//  BDPAppearanceHeader.swift
//  OnSiteService
//
//  Created by baideng on 2021/6/11.
//  Copyright © 2021 baideng. All rights reserved.
//

import UIKit

class TRAppearance : NSObject {
    
    @objc public enum BDPAppearanceStyle : Int {
        case Light = 0
        case Dark = 1
    }
    
    static let instance = TRAppearance()
    /// key:ColorKey value:colorName
    fileprivate var colorDic:[String:Int] = [:]
    
    fileprivate var viewList = NSHashTable<AnyObject>(options: .weakMemory)
    
    public var currentStyle: BDPAppearanceStyle = .Light
    
    fileprivate override init() {
        super.init()
        swizzlingMethod(swizzledSelector: #selector(UIView.didMoveToWindow), originalSelector: #selector(UIView.bdpAppearance_didMoveToWindow))
        lightTheme()
    }
    
    fileprivate func swizzlingMethod(swizzledSelector: Selector, originalSelector: Selector) {
        if let swizzledMethod = class_getInstanceMethod(UIView.self, swizzledSelector), let originalMethod = class_getInstanceMethod(UIView.self, originalSelector) {
            let didAddMethod: Bool = class_addMethod(UIView.self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
            if didAddMethod {
                class_replaceMethod(UIView.self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }
        }
    }

    /// 获取颜色
    /// - Parameter key: color name
    /// - Returns: UIColor
    @objc public static func color(_ key: String)-> UIColor? {
        if let hex = TRAppearance.instance.colorDic[key] {
            return UIColor.hex(hex)
        }
        return nil
    }
    
    /// 改变主题色
    /// - Parameter color: UIColor
    @objc public static func changeTheme(_ style: BDPAppearanceStyle) {
        let instance = TRAppearance.instance
        if instance.currentStyle != style {
            instance.currentStyle = style
            style == .Dark ? instance.darkTheme() : instance.lightTheme()

            NSAllHashTableObjects(TRAppearance.instance.viewList).forEach {
                let x = $0 as? UIView
                x?.linkedList?.execBlock()
            }
        }
    }
    
    
    fileprivate func lightTheme() {
        colorDic = [
            //导航色
            "navBgColor":0xFF8C30FF,
            //主题色
            "theme":0xFF8C30FF,
            //文本颜色
            "text":0x333333FF,
            //背景
            "viewControllerBackground":0xFFFFFFFF,
            //
            "background":0xEEEEEEFF
        ]
    }
    
    fileprivate func darkTheme() {
        colorDic = [
            //导航色
            "navBgColor":0x000000FF,
            //主题色
            "theme":0x000000FF,
            //文本颜色
            "text":0xFFFFFFFF,
            //背景
            "viewControllerBackground":0x000000FF,
            
            "background":0x1D1D1DFF,
        ]
    }
}
    
typealias TRAppearanceBlock = ()->Void

fileprivate class TRAppearanceBlockLinkedList : NSObject {
    
    public var isAfter = false
    
    var first: TRAppearanceBlockNode?
    weak var last: TRAppearanceBlockNode?
    
    fileprivate class TRAppearanceBlockNode : NSObject {
        
        var next: TRAppearanceBlockNode?
        
        public weak var bindView:UIView?
        public var block: TRAppearanceBlock?
        
        init(_ e: @escaping TRAppearanceBlock, _ view:UIView) {
            super.init()
            block = e
            bindView = view
        }
    }
    
    func append(element: TRAppearanceBlockNode) {
        if let oldLast = last {
            oldLast.next = element
        } else {
            first = element
        }
        last = element
    }
    
    public func execBlock() {
        isAfter = first?.bindView?.window == nil
        if isAfter {
            return
        }
        
        first?.block?()
        
        var root = first?.next
        while let node = root {
            node.block?()
            root = node.next
        }
    }
}

extension UIView
{
    @objc func trAppearance_bindUpdater(_ block: @escaping TRAppearanceBlock) {
        block()
        if linkedList == nil {
            TRAppearance.instance.viewList.add(self)
            linkedList = TRAppearanceBlockLinkedList()
        }
        linkedList?.append(element: TRAppearanceBlockLinkedList.TRAppearanceBlockNode(block, self))
    }
    
    fileprivate struct TRAppearanceAssociatedKeys {
        static var trAppearanceLinkedList:AnyObject?
    }
    
    fileprivate var linkedList: TRAppearanceBlockLinkedList? {
        get {
            objc_getAssociatedObject(self, &TRAppearanceAssociatedKeys.trAppearanceLinkedList) as? TRAppearanceBlockLinkedList
        }
        set {
            objc_setAssociatedObject(self, &TRAppearanceAssociatedKeys.trAppearanceLinkedList, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    @objc fileprivate func bdpAppearance_didMoveToWindow() {
        guard let linkList = linkedList else {
            bdpAppearance_didMoveToWindow()
            return
        }
        if linkList.isAfter {
            linkList.execBlock()
        }
        bdpAppearance_didMoveToWindow()
    }
}

extension UIColor {
    static func hex(_ a: Int) -> UIColor {
        UIColor(
            red: CGFloat((a & 0xff000000) >> 24) / 255,
            green: CGFloat((a & 0x00ff0000) >> 16) / 255,
            blue: CGFloat((a & 0x0000ff00) >> 8) / 255,
            alpha: 1 //CGFloat(a & 0x000000ff) / 255
        )
    }
}
