# A. 长函数 & 可读性

**目标：** 降低认知负担，是所有重构的入口

## 目录

1. [长函数 → 提炼函数（顺序流程）](#案例1-长函数--提炼函数顺序流程) - Python
2. [长函数 → 提炼函数（含 early return）](#案例2-长函数--提炼函数含-early-return) - Python
3. [长函数 → 提炼函数（含异常处理）](#案例3-长函数--提炼函数含异常处理) - Java
4. [嵌套层级过深 → 提炼条件函数](#案例4-嵌套层级过深--提炼条件函数) - JavaScript
5. [混合"计算 + IO" → 拆分纯函数](#案例5-混合计算--io--拆分纯函数) - Python
6. [业务流程写成脚本 → 用命名函数表达意图](#案例6-业务流程写成脚本--用命名函数表达意图) - JavaScript

---

## 案例1: 长函数 → 提炼函数（顺序流程）

**语言:** Python

### ❌ 问题代码

```python
def process_order(order):
    # 验证
    if not order or not order.items:
        raise ValueError("Invalid order")
    if not order.customer:
        raise ValueError("Customer required")

    # 计算总价
    subtotal = sum(item.price * item.qty for item in order.items)
    tax = subtotal * 0.08
    shipping = 0 if subtotal > 100 else 10
    order.total = subtotal + tax + shipping

    # 检查库存
    for item in order.items:
        product = product_repo.find(item.product_id)
        if product.stock < item.qty:
            raise Exception(f"Insufficient stock: {product.name}")

    # 扣减库存
    for item in order.items:
        product = product_repo.find(item.product_id)
        product.stock -= item.qty
        product_repo.save(product)

    # 保存订单
    order.status = "confirmed"
    order_repo.save(order)

    # 发送通知
    send_email(order.customer.email, f"Order #{order.id} confirmed")
```

**问题：** 30+行，职责不清，难以测试单个步骤

### ✅ 重构后代码

```python
def process_order(order):
    validate_order(order)
    calculate_total(order)
    check_inventory(order)
    deduct_inventory(order)
    save_order(order)
    send_confirmation(order)

def validate_order(order):
    if not order or not order.items:
        raise ValueError("Invalid order")
    if not order.customer:
        raise ValueError("Customer required")

def calculate_total(order):
    subtotal = sum(item.price * item.qty for item in order.items)
    tax = subtotal * TAX_RATE
    shipping = 0 if subtotal > FREE_SHIPPING_MIN else SHIPPING_FEE
    order.total = subtotal + tax + shipping

def check_inventory(order):
    for item in order.items:
        product = product_repo.find(item.product_id)
        if product.stock < item.qty:
            raise InsufficientStockError(product.name)

def deduct_inventory(order):
    for item in order.items:
        product_repo.decrease_stock(item.product_id, item.qty)

def save_order(order):
    order.status = "confirmed"
    order_repo.save(order)

def send_confirmation(order):
    send_email(order.customer.email, f"Order #{order.id} confirmed")
```

**改进：** 主函数清晰，每个函数职责单一，易测试

---

## 案例2: 长函数 → 提炼函数（含 early return）

**语言:** Python

### ❌ 问题代码

```python
def apply_discount(user, cart):
    if user:
        if user.is_premium:
            if cart.total >= 100:
                if not user.discount_used_this_month:
                    return cart.total * 0.8  # 20% off
                else:
                    return cart.total  # Already used
            else:
                return cart.total  # Below minimum
        else:
            if cart.total >= 50:
                return cart.total * 0.9  # 10% off
            else:
                return cart.total  # Below minimum
    else:
        return cart.total  # Not logged in
```

**问题：** 嵌套5层，正常路径被埋在深处

### ✅ 重构后代码

```python
def apply_discount(user, cart):
    if not user:
        return cart.total

    if user.is_premium:
        return apply_premium_discount(user, cart)
    else:
        return apply_regular_discount(cart)

def apply_premium_discount(user, cart):
    if cart.total < 100:
        return cart.total
    if user.discount_used_this_month:
        return cart.total
    return cart.total * 0.8

def apply_regular_discount(cart):
    if cart.total < 50:
        return cart.total
    return cart.total * 0.9
```

**改进：** early return 减少嵌套，失败路径清晰

---

## 案例3: 长函数 → 提炼函数（含异常处理）

**语言:** Java

### ❌ 问题代码

```java
public String exportUserData(long userId) {
    try {
        User user = userService.find(userId);
        if (user == null) return "User not found";

        StringBuilder sb = new StringBuilder();
        sb.append("Name: " + user.getName() + "\n");

        try {
            List<Order> orders = orderService.findByUser(userId);
            for (Order order : orders) {
                sb.append("Order #" + order.getId() + "\n");
            }
        } catch (Exception e) {
            sb.append("Orders: Failed to load\n");
        }

        try {
            List<Address> addresses = addressService.findByUser(userId);
            for (Address addr : addresses) {
                sb.append("Address: " + addr.getStreet() + "\n");
            }
        } catch (Exception e) {
            sb.append("Addresses: Failed to load\n");
        }

        return sb.toString();
    } catch (Exception e) {
        return "Export failed: " + e.getMessage();
    }
}
```

**问题：** 异常处理和业务逻辑混杂

### ✅ 重构后代码

```java
public String exportUserData(long userId) {
    try {
        User user = findUserOrThrow(userId);
        return buildUserReport(user);
    } catch (Exception e) {
        return "Export failed: " + e.getMessage();
    }
}

private String buildUserReport(User user) {
    StringBuilder sb = new StringBuilder();
    appendBasicInfo(sb, user);
    appendOrdersSafely(sb, user.getId());
    appendAddressesSafely(sb, user.getId());
    return sb.toString();
}

private void appendOrdersSafely(StringBuilder sb, long userId) {
    try {
        List<Order> orders = orderService.findByUser(userId);
        orders.forEach(o -> sb.append("Order #" + o.getId() + "\n"));
    } catch (Exception e) {
        sb.append("Orders: Failed to load\n");
    }
}

private void appendAddressesSafely(StringBuilder sb, long userId) {
    try {
        List<Address> addrs = addressService.findByUser(userId);
        addrs.forEach(a -> sb.append("Address: " + a.getStreet() + "\n"));
    } catch (Exception e) {
        sb.append("Addresses: Failed to load\n");
    }
}
```

**改进：** 异常处理隔离，核心逻辑清晰

---

## 案例4: 嵌套层级过深 → 提炼条件函数

**语言:** JavaScript

### ❌ 问题代码

```javascript
function canAccessResource(user, resource) {
    if (user !== null) {
        if (user.isActive) {
            if (user.role === 'admin' ||
                (user.role === 'editor' && resource.type === 'doc') ||
                (user.role === 'viewer' && resource.isPublic)) {
                if (resource.status === 'published' ||
                    (resource.status === 'draft' && user.id === resource.ownerId)) {
                    if (!resource.isDeleted && user.hasPermission('read')) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}
```

**问题：** 嵌套6层，逻辑难以理解

### ✅ 重构后代码

```javascript
function canAccessResource(user, resource) {
    if (!isValidUser(user)) return false;
    if (!hasRolePermission(user, resource)) return false;
    if (!canAccessStatus(user, resource)) return false;
    if (!isResourceAvailable(resource)) return false;
    if (!hasReadPermission(user)) return false;
    return true;
}

function isValidUser(user) {
    return user !== null && user.isActive;
}

function hasRolePermission(user, resource) {
    if (user.role === 'admin') return true;
    if (user.role === 'editor' && resource.type === 'doc') return true;
    if (user.role === 'viewer' && resource.isPublic) return true;
    return false;
}

function canAccessStatus(user, resource) {
    if (resource.status === 'published') return true;
    if (resource.status === 'draft' && user.id === resource.ownerId) return true;
    return false;
}

function isResourceAvailable(resource) {
    return !resource.isDeleted;
}

function hasReadPermission(user) {
    return user.hasPermission('read');
}
```

**改进：** 扁平化，每个条件语义清晰

---

## 案例5: 混合"计算 + IO" → 拆分纯函数

**语言:** Python

### ❌ 问题代码

```python
def generate_report(month):
    # IO: 查询数据库
    orders = db.query("SELECT * FROM orders WHERE month = ?", month)

    # 计算
    total = sum(o['amount'] for o in orders)

    # IO: 查询上月
    last_orders = db.query("SELECT * FROM orders WHERE month = ?", month - 1)
    last_total = sum(o['amount'] for o in last_orders)

    # 计算增长率
    growth = (total - last_total) / last_total * 100 if last_total > 0 else 0

    # 格式化
    report = f"Month {month}\nRevenue: ${total}\nGrowth: {growth:.1f}%"

    # IO: 保存文件
    with open(f"report_{month}.txt", "w") as f:
        f.write(report)

    # IO: 发送邮件
    send_email("manager@co.com", "Report", report)

    return report
```

**问题：** 计算和IO混合，难以测试计算逻辑

### ✅ 重构后代码

```python
# 纯函数：只计算
def calculate_total(orders):
    return sum(o['amount'] for o in orders)

def calculate_growth(current, previous):
    if previous == 0:
        return 0
    return (current - previous) / previous * 100

def format_report(month, total, growth):
    return f"Month {month}\nRevenue: ${total}\nGrowth: {growth:.1f}%"

# IO协调
def generate_report(month):
    orders = db.query("SELECT * FROM orders WHERE month = ?", month)
    last_orders = db.query("SELECT * FROM orders WHERE month = ?", month - 1)

    total = calculate_total(orders)
    last_total = calculate_total(last_orders)
    growth = calculate_growth(total, last_total)

    report = format_report(month, total, growth)

    save_report(month, report)
    send_report_email(report)

    return report

def save_report(month, report):
    with open(f"report_{month}.txt", "w") as f:
        f.write(report)

def send_report_email(report):
    send_email("manager@co.com", "Report", report)
```

**改进：** 纯函数易测试，IO操作集中

---

## 案例6: 业务流程写成脚本 → 用命名函数表达意图

**语言:** JavaScript

### ❌ 问题代码

```javascript
async function handlePayment(request) {
    // 验证
    if (request.amount <= 0) throw new Error("Invalid amount");
    if (!request.cardNumber) throw new Error("Card required");

    // 加密
    const encrypted = encrypt(request.cardNumber);

    // 调用支付网关
    const response = await fetch('https://gateway.com/charge', {
        method: 'POST',
        body: JSON.stringify({
            amount: request.amount,
            card: encrypted,
            merchant_id: MERCHANT_ID
        })
    });
    const result = await response.json();

    // 保存记录
    const payment = await db.payments.create({
        amount: request.amount,
        status: result.status,
        transaction_id: result.transaction_id
    });

    // 更新订单
    const order = await db.orders.findById(request.orderId);
    if (result.status === 'success') {
        order.status = 'PAID';
        order.paymentId = payment.id;
    } else {
        order.status = 'PAYMENT_FAILED';
    }
    await order.save();

    // 发送通知
    if (result.status === 'success') {
        await sendNotification(order.customerId,
            `Payment successful for order #${order.id}`);
    }
}
```

**问题：** 注释才能理解意图，实现细节混杂

### ✅ 重构后代码

```javascript
async function handlePayment(request) {
    validatePaymentRequest(request);

    const encryptedCard = encryptCardNumber(request.cardNumber);
    const gatewayResponse = await chargePaymentGateway(request, encryptedCard);

    const payment = await recordPayment(request, gatewayResponse);
    await updateOrderStatus(request.orderId, payment);

    if (payment.isSuccessful) {
        await notifyPaymentSuccess(request.orderId);
    }
}

function validatePaymentRequest(request) {
    if (request.amount <= 0) throw new Error("Invalid amount");
    if (!request.cardNumber) throw new Error("Card required");
}

function encryptCardNumber(cardNumber) {
    return encrypt(cardNumber);
}

async function chargePaymentGateway(request, encryptedCard) {
    const response = await fetch('https://gateway.com/charge', {
        method: 'POST',
        body: JSON.stringify({
            amount: request.amount,
            card: encryptedCard,
            merchant_id: MERCHANT_ID
        })
    });
    return response.json();
}

async function recordPayment(request, gatewayResponse) {
    return db.payments.create({
        amount: request.amount,
        status: gatewayResponse.status,
        transactionId: gatewayResponse.transaction_id,
        isSuccessful: gatewayResponse.status === 'success'
    });
}

async function updateOrderStatus(orderId, payment) {
    const order = await db.orders.findById(orderId);
    if (payment.isSuccessful) {
        order.markAsPaid(payment.id);
    } else {
        order.markAsPaymentFailed();
    }
    await order.save();
}

async function notifyPaymentSuccess(orderId) {
    const order = await db.orders.findById(orderId);
    await sendNotification(order.customerId,
        `Payment successful for order #${order.id}`);
}
```

**改进：** 函数名表达意图，无需注释，流程清晰
