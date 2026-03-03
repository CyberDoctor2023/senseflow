# F. 数据类 / 行为漂移

**目标:** 修复"伪 OO"

## 目录

1. [工具类操作数据类 → 行为移回数据](#案例1-工具类操作数据类--行为移回数据) - Java
2. [Getter/Setter 驱动逻辑 → 封装行为](#案例2-gettersetter-驱动逻辑--封装行为) - Python
3. [贫血模型 → 领域方法内聚](#案例3-贫血模型--领域方法内聚) - Java

---

## 案例1: 工具类操作数据类 → 行为移回数据

**语言:** Java

### ❌ 问题代码

```java
public class BankAccount {
    private String id;
    private double balance;
    private boolean isActive;

    // 只有getter/setter
    public double getBalance() { return balance; }
    public void setBalance(double balance) { this.balance = balance; }
    public boolean isActive() { return isActive; }
    public void setActive(boolean active) { isActive = active; }
}

public class AccountUtils {
    public static void deposit(BankAccount account, double amount) {
        if (!account.isActive()) {
            throw new IllegalStateException("Account not active");
        }
        account.setBalance(account.getBalance() + amount);
    }

    public static void withdraw(BankAccount account, double amount) {
        if (!account.isActive() || account.getBalance() < amount) {
            throw new IllegalStateException("Cannot withdraw");
        }
        account.setBalance(account.getBalance() - amount);
    }
}

// 数据和行为分离
AccountUtils.deposit(account, 100);
AccountUtils.withdraw(account, 50);
```

**问题:** 数据和行为分离，违反OO原则

### ✅ 重构后代码

```java
public class BankAccount {
    private final String id;
    private double balance;
    private boolean isActive;

    public BankAccount(String id, double initialBalance) {
        this.id = id;
        this.balance = initialBalance;
        this.isActive = true;
    }

    public void deposit(double amount) {
        if (!isActive) {
            throw new IllegalStateException("Account not active");
        }
        if (amount <= 0) {
            throw new IllegalArgumentException("Amount must be positive");
        }
        balance += amount;
    }

    public void withdraw(double amount) {
        if (!canWithdraw(amount)) {
            throw new IllegalStateException(
                "Cannot withdraw " + amount + " from account " + id
            );
        }
        balance -= amount;
    }

    public boolean canWithdraw(double amount) {
        return isActive && balance >= amount && amount > 0;
    }

    public void freeze() {
        isActive = false;
    }

    public void activate() {
        isActive = true;
    }

    // 只暴露必要的查询方法
    public String getId() { return id; }
    public double getBalance() { return balance; }
    public boolean isActive() { return isActive; }
}

// 对象自己管理行为
account.deposit(100);
account.withdraw(50);
```

**改进:** 数据和行为内聚，对象自我保护

---

## 案例2: Getter/Setter 驱动逻辑 → 封装行为

**语言:** Python

### ❌ 问题代码

```python
class ShoppingCart:
    def __init__(self):
        self.items = []
        self.discount_code = None
        self.subtotal = 0
        self.tax = 0
        self.total = 0

# 客户端代码包含业务逻辑
cart = ShoppingCart()
cart.items = [Item("Book", 20), Item("Pen", 5)]

# 手动计算
subtotal = sum(item.price for item in cart.items)
if cart.discount_code == "SAVE10":
    subtotal *= 0.9

tax = subtotal * 0.08
cart.total = subtotal + tax
```

**问题:** 业务逻辑泄漏到客户端，对象无法自我保护

### ✅ 重构后代码

```python
class ShoppingCart:
    TAX_RATE = 0.08
    DISCOUNT_CODES = {
        "SAVE10": 0.10,
        "SAVE20": 0.20,
        "WELCOME": 0.15
    }

    def __init__(self):
        self._items = []
        self._discount_code = None

    def add_item(self, item):
        self._items.append(item)

    def remove_item(self, item):
        self._items.remove(item)

    def apply_discount_code(self, code):
        if code not in self.DISCOUNT_CODES:
            raise ValueError(f"Invalid discount code: {code}")
        self._discount_code = code

    def get_subtotal(self):
        return sum(item.price for item in self._items)

    def get_discount_amount(self):
        if not self._discount_code:
            return 0
        discount_rate = self.DISCOUNT_CODES[self._discount_code]
        return self.get_subtotal() * discount_rate

    def get_discounted_subtotal(self):
        return self.get_subtotal() - self.get_discount_amount()

    def get_tax(self):
        return self.get_discounted_subtotal() * self.TAX_RATE

    def get_total(self):
        return self.get_discounted_subtotal() + self.get_tax()

    def get_summary(self):
        return {
            'items': len(self._items),
            'subtotal': self.get_subtotal(),
            'discount': self.get_discount_amount(),
            'tax': self.get_tax(),
            'total': self.get_total()
        }

# 简洁的使用方式
cart = ShoppingCart()
cart.add_item(Item("Book", 20))
cart.add_item(Item("Pen", 5))
cart.apply_discount_code("SAVE10")
print(f"Total: ${cart.get_total():.2f}")
```

**改进:** 业务逻辑封装在对象内部

---

## 案例3: 贫血模型 → 领域方法内聚

**语言:** Java

### ❌ 问题代码

```java
public class Order {
    private Long id;
    private List<OrderItem> items;
    private OrderStatus status;
    private double total;
    // 只有getter/setter...
}

public class OrderService {
    public void processOrder(Order order) {
        // 验证
        if (order.getItems() == null || order.getItems().isEmpty()) {
            throw new ValidationException("Order must have items");
        }

        // 计算总价
        double total = 0;
        for (OrderItem item : order.getItems()) {
            total += item.getPrice() * item.getQuantity();
        }
        order.setTotal(total);

        // 更新状态
        order.setStatus(OrderStatus.CONFIRMED);
        orderRepository.save(order);
    }
}
```

**问题:** 领域模型贫血，业务逻辑都在Service层

### ✅ 重构后代码

```java
public class Order {
    private final Long id;
    private final List<OrderItem> items;
    private OrderStatus status;
    private final Customer customer;

    public Order(Long id, Customer customer, List<OrderItem> items) {
        validateItems(items);
        this.id = id;
        this.customer = customer;
        this.items = new ArrayList<>(items);
        this.status = OrderStatus.PENDING;
    }

    public void confirm() {
        if (status != OrderStatus.PENDING) {
            throw new IllegalStateException("Only pending orders can be confirmed");
        }
        status = OrderStatus.CONFIRMED;
    }

    public void cancel() {
        if (!canBeCancelled()) {
            throw new IllegalStateException("Order cannot be cancelled");
        }
        status = OrderStatus.CANCELLED;
    }

    public boolean canBeCancelled() {
        return status == OrderStatus.PENDING || status == OrderStatus.CONFIRMED;
    }

    public double calculateTotal() {
        return items.stream()
            .mapToDouble(item -> item.getPrice() * item.getQuantity())
            .sum();
    }

    public int getItemCount() {
        return items.stream()
            .mapToInt(OrderItem::getQuantity)
            .sum();
    }

    private void validateItems(List<OrderItem> items) {
        if (items == null || items.isEmpty()) {
            throw new IllegalArgumentException("Order must have items");
        }
    }

    public Long getId() { return id; }
    public OrderStatus getStatus() { return status; }
    public List<OrderItem> getItems() { return new ArrayList<>(items); }
}

// Service层只负责协调
public class OrderService {
    public void processOrder(Order order) {
        order.confirm();
        orderRepository.save(order);
        emailService.sendConfirmation(order.getCustomer());
    }
}
```

**改进:** 领域逻辑内聚在领域对象中，Service层变薄
