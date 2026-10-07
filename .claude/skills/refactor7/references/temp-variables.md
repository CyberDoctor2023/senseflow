# E. 临时变量 & 状态污染

**目标:** 提升可推理性

## 目录

1. [临时变量滥用 → Replace Temp with Query](#案例1-临时变量滥用--replace-temp-with-query) - JavaScript
2. [方法依赖外部可变状态 → 显式传参](#案例2-方法依赖外部可变状态--显式传参) - Python
3. [函数修改入参 → 返回新对象](#案例3-函数修改入参--返回新对象) - JavaScript

---

## 案例1: 临时变量滥用 → Replace Temp with Query

**语言:** JavaScript

### ❌ 问题代码

```javascript
function calculatePrice(product, quantity) {
    const basePrice = product.price * quantity;
    const discount = basePrice > 1000 ? basePrice * 0.1 : 0;
    const discountedPrice = basePrice - discount;
    const tax = discountedPrice * 0.08;
    const shipping = basePrice > 500 ? 0 : 15;
    const total = discountedPrice + tax + shipping;

    console.log(`Base: $${basePrice}`);
    console.log(`Discount: $${discount}`);
    console.log(`Tax: $${tax}`);
    console.log(`Total: $${total}`);

    return total;
}
```

**问题:** 临时变量过多，难以重用单个计算逻辑

### ✅ 重构后代码

```javascript
class PriceCalculator {
    constructor(product, quantity) {
        this.product = product;
        this.quantity = quantity;
    }

    getBasePrice() {
        return this.product.price * this.quantity;
    }

    getDiscount() {
        return this.getBasePrice() > 1000 ? this.getBasePrice() * 0.1 : 0;
    }

    getDiscountedPrice() {
        return this.getBasePrice() - this.getDiscount();
    }

    getTax() {
        return this.getDiscountedPrice() * 0.08;
    }

    getShipping() {
        return this.getBasePrice() > 500 ? 0 : 15;
    }

    getTotal() {
        return this.getDiscountedPrice() + this.getTax() + this.getShipping();
    }

    printBreakdown() {
        console.log(`Base: $${this.getBasePrice()}`);
        console.log(`Discount: $${this.getDiscount()}`);
        console.log(`Tax: $${this.getTax()}`);
        console.log(`Total: $${this.getTotal()}`);
    }
}

// 使用
const calculator = new PriceCalculator(product, quantity);
calculator.printBreakdown();
return calculator.getTotal();
```

**改进:** 每个计算都可独立测试和重用

---

## 案例2: 方法依赖外部可变状态 → 显式传参

**语言:** Python

### ❌ 问题代码

```python
class DataProcessor:
    def __init__(self):
        self.data = []
        self.filters = {}
        self.current_page = 0
        self.page_size = 10

    def load_data(self, source):
        self.data = fetch_from_source(source)

    def apply_filters(self, filters):
        self.filters = filters
        self.data = [item for item in self.data
                     if self._matches(item)]

    def paginate(self, page):
        self.current_page = page
        start = page * self.page_size
        self.data = self.data[start:start + self.page_size]

    def _matches(self, item):
        return all(item.get(k) == v for k, v in self.filters.items())

# 结果依赖调用顺序
processor = DataProcessor()
processor.load_data('db')
processor.apply_filters({'status': 'active'})
processor.paginate(0)
```

**问题:** 依赖隐式状态，难以理解和测试

### ✅ 重构后代码

```python
from dataclasses import dataclass
from typing import List, Dict, Any

@dataclass
class QueryOptions:
    filters: Dict[str, Any]
    page: int
    page_size: int

class DataProcessor:
    def process(self, source: str, options: QueryOptions) -> List[Dict]:
        raw_data = self._load_data(source)
        filtered_data = self._apply_filters(raw_data, options.filters)
        paginated_data = self._paginate(filtered_data, options.page, options.page_size)
        return paginated_data

    def _load_data(self, source: str) -> List[Dict]:
        return fetch_from_source(source)

    def _apply_filters(self, data: List[Dict], filters: Dict[str, Any]) -> List[Dict]:
        return [item for item in data if self._matches(item, filters)]

    def _matches(self, item: Dict, filters: Dict[str, Any]) -> bool:
        return all(item.get(k) == v for k, v in filters.items())

    def _paginate(self, data: List[Dict], page: int, page_size: int) -> List[Dict]:
        start = page * page_size
        return data[start:start + page_size]

# 清晰的使用方式
processor = DataProcessor()
options = QueryOptions(
    filters={'status': 'active'},
    page=0,
    page_size=10
)
result = processor.process('db', options)
```

**改进:** 依赖显式，函数可独立测试，结果可预测

---

## 案例3: 函数修改入参 → 返回新对象

**语言:** JavaScript

### ❌ 问题代码

```javascript
function normalizeUser(user) {
    user.email = user.email.toLowerCase();
    user.name = user.name.trim();

    if (user.age < 18) {
        user.isMinor = true;
    }

    if (!user.roles) {
        user.roles = ['user'];
    }

    user.updatedAt = new Date();

    return user;
}

// 调用产生副作用
const originalUser = {
    email: 'John@Example.COM',
    name: '  John Doe  ',
    age: 16
};

const normalized = normalizeUser(originalUser);
// originalUser 也被修改了！
console.log(originalUser.email);  // 'john@example.com'
```

**问题:** 修改入参产生副作用，难以追踪数据变化

### ✅ 重构后代码

```javascript
function normalizeUser(user) {
    return {
        ...user,
        email: normalizeEmail(user.email),
        name: normalizeName(user.name),
        isMinor: user.age < 18,
        roles: user.roles || ['user'],
        updatedAt: new Date()
    };
}

function normalizeEmail(email) {
    return email.toLowerCase();
}

function normalizeName(name) {
    return name.trim();
}

// 无副作用的调用
const originalUser = {
    email: 'John@Example.COM',
    name: '  John Doe  ',
    age: 16
};

const normalized = normalizeUser(originalUser);

// originalUser 保持不变
console.log(originalUser.email);  // 'John@Example.COM'
console.log(normalized.email);    // 'john@example.com'

// 深层嵌套对象也可以保持不可变性
function updateAddress(user, newAddress) {
    return {
        ...user,
        profile: {
            ...user.profile,
            address: {
                ...user.profile.address,
                ...newAddress
            }
        }
    };
}
```

**改进:** 无副作用，易于测试，数据流清晰
