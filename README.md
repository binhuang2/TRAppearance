### TRAppearance
iOS App主题色切换，暗黑模式适配的轻量级框架，支持Swift和Objective-C混编调用

### 使用方法

1.view绑定block，会立即触发回调（一个view可以绑定多个block，有需要时会全部触发）
```
view.trAppearance_bindUpdater { [weak self] appearance, bindView in
            
    self?.button.setTitleColor(appearance.color("text"), for: .normal)
    
    bindView.backgroundColor = appearance.color("viewControllerBackground")
    
}
```

```
[self.view trAppearance_bindUpdater:^(TRAppearance *appearance, UIView *bindView) {
    bindView.backgroundColor = [appearance color:@"viewControllerBackground"];
}];
```

2.主题色自动或手动改变时调用
```
@objc static func changeTheme(_ style: TRAppearanceStyle)
```

### 原理
1.使用分类给UIView创建一个`linkedList`属性。（这里使用了单链表）
```
var tr_linkedList: TRAppearanceLinkedList? {
    get {
        objc_getAssociatedObject(self, &TRAppearanceCustomProperty.trAppearanceLinkedList) as? TRAppearanceLinkedList
    }
    set {
        objc_setAssociatedObject(self, &TRAppearanceCustomProperty.trAppearanceLinkedList, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
struct TRAppearanceCustomProperty {
    static var trAppearanceLinkedList:AnyObject?
}
```

```
class TRAppearanceLinkedList : NSObject {
    //头结点
    var first: TRAppearanceNode?
    //尾结点
    weak var last: TRAppearanceNode?
    //稍后调用
    public var isAfter = false
    public weak var bindView:UIView!
    
    deinit {
        //需手动释放链接节点
        var root = first
        first = nil
        DispatchQueue.global(qos: .background).async {
            while let node = root {
                root = node.next
                node.next = nil
            }
        }
    }
}
```

```
class TRAppearanceNode {
        
    var next: TRAppearanceNode?
    var block: TRAppearanceBlock?
    
    init(_ element: @escaping TRAppearanceBlock) {
        block = element
    }
}
```

2.view第一次绑定block时初始化，并且将view添加到`NSHashTable`里面，`NSHashTable`弱引用，在view销毁时元素会自动释放；block则添加到链表上
```
lazy var viewList: NSHashTable<AnyObject> = {
    NSHashTable<AnyObject>(options: .weakMemory)
}()
```

```
func append(block: @escaping TRAppearanceBlock) {
    let element = TRAppearanceNode(block)
    if let oldLast = last {
        oldLast.next = element
    } else {
        first = element
    }
    last = element
}
```


3.调用`changeTheme`时，遍历`NSHashTable`存在的view元素，判断其window是否存在，如果存在，遍历链表调用绑定的block；如果不存在将此链表设为稍后调用
```
@objc static func changeTheme(_ style: TRAppearanceStyle) {
    NSAllHashTableObjects(TRAppearance.instance.viewList).forEach {
        let x = $0 as? UIView
        x?.tr_linkedList?.execBlock(isCheckWindow: true)
    }
}
```
```
public func execBlock(isCheckWindow: Bool) {
    isAfter = isCheckWindow ? bindView?.window == nil : isCheckWindow
    if isAfter {
        return
    }
    
    first?.block?(TRAppearance.instance, bindView)
    
    var root = first?.next
    while let node = root {
        node.block?(TRAppearance.instance, bindView)
        root = node.next
    }
}
```

4.当view调用`didMoveToWindow`时，判断view的`linkedList`属性是否存在，是否被设置为稍后调用,条件成立时，遍历链接调用绑定的block
```
@objc func trAppearance_didMoveToWindow() {
    guard let linkList = tr_linkedList else {
        trAppearance_didMoveToWindow()
        return
    }
    if linkList.isAfter {
        linkList.execBlock(isCheckWindow: false)
    }
    trAppearance_didMoveToWindow()
}

//didMoveToWindow方法交换
static let swizzledidMoveToWindow: Void = {
    tr_swizzlingMethod(anyClass:UIView.self,
                       swizzledSelector: #selector(UIView.didMoveToWindow),
                       originalSelector: #selector(UIView.trAppearance_didMoveToWindow))
}()

func tr_swizzlingMethod(anyClass:AnyClass, swizzledSelector: Selector, originalSelector: Selector) {
    if let swizzledMethod = class_getInstanceMethod(anyClass, swizzledSelector), let originalMethod = class_getInstanceMethod(UIView.self, originalSelector) {
        let didAddMethod: Bool = class_addMethod(anyClass, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        if didAddMethod {
            class_replaceMethod(anyClass, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}
```