# H. 命名 & 表达力

**目标:** 减少注释依赖

## 目录

1. [魔法数 → 命名常量](#案例1-魔法数--命名常量) - JavaScript
2. [注释解释逻辑 → 命名函数](#案例2-注释解释逻辑--命名函数) - Python
3. [模糊变量名 → 领域名词](#案例3-模糊变量名--领域名词) - JavaScript

---

## 案例1: 魔法数 → 命名常量

**语言:** JavaScript

### ❌ 问题代码

```javascript
function calculateMembership(user, months) {
    let price = 9.99;

    if (months >= 12) {
        price = price * 0.8;  // 20% off
    } else if (months >= 6) {
        price = price * 0.9;  // 10% off
    }

    if (user.isPremium) {
        price = price * 0.85;  // 15% off
    }

    let total = price * months;
    total = total * 1.08;  // tax

    if (total < 5.0) {
        total = 5.0;  // minimum
    }

    return total;
}
```

**问题:** 魔法数意义不明确

### ✅ 重构后代码

```javascript
const MEMBERSHIP = {
    BASE_PRICE: 9.99,
    TAX_RATE: 0.08,
    MINIMUM_CHARGE: 5.0,

    ANNUAL_MONTHS: 12,
    ANNUAL_DISCOUNT: 0.20,

    SEMI_ANNUAL_MONTHS: 6,
    SEMI_ANNUAL_DISCOUNT: 0.10,

    PREMIUM_DISCOUNT: 0.15
};

function calculateMembership(user, months) {
    const monthlyPrice = getMonthlyPrice(months);
    const discountedPrice = applyMemberDiscount(monthlyPrice, user);
    const subtotal = discountedPrice * months;
    const withTax = applyTax(subtotal);

    return ensureMinimumCharge(withTax);
}

function getMonthlyPrice(months) {
    if (months >= MEMBERSHIP.ANNUAL_MONTHS) {
        return MEMBERSHIP.BASE_PRICE * (1 - MEMBERSHIP.ANNUAL_DISCOUNT);
    }
    if (months >= MEMBERSHIP.SEMI_ANNUAL_MONTHS) {
        return MEMBERSHIP.BASE_PRICE * (1 - MEMBERSHIP.SEMI_ANNUAL_DISCOUNT);
    }
    return MEMBERSHIP.BASE_PRICE;
}

function applyMemberDiscount(price, user) {
    if (user.isPremium) {
        return price * (1 - MEMBERSHIP.PREMIUM_DISCOUNT);
    }
    return price;
}

function applyTax(amount) {
    return amount * (1 + MEMBERSHIP.TAX_RATE);
}

function ensureMinimumCharge(amount) {
    return Math.max(amount, MEMBERSHIP.MINIMUM_CHARGE);
}
```

**改进:** 常量命名清晰表达业务含义

---

## 案例2: 注释解释逻辑 → 命名函数

**语言:** Python

### ❌ 问题代码

```python
def process_payment(order, card):
    # Check if order is valid
    if order.total <= 0 or len(order.items) == 0:
        return False

    # Verify card not expired
    now = datetime.now()
    if card.exp_year < now.year or \
       (card.exp_year == now.year and card.exp_month < now.month):
        return False

    # Calculate fee (2.9% + $0.30)
    fee = order.total * 0.029 + 0.30
    total = order.total + fee

    # Charge card
    card.balance -= total

    # Update order
    order.status = "paid"
    order.paid_at = datetime.now()

    return True
```

**问题:** 依赖注释才能理解意图

### ✅ 重构后代码

```python
class PaymentProcessor:
    TRANSACTION_FEE_RATE = 0.029
    TRANSACTION_FEE_FIXED = 0.30

    def process_payment(self, order, card):
        if not self._is_valid_order(order):
            raise InvalidOrderError("Order is not valid")

        if self._is_card_expired(card):
            raise ExpiredCardError("Card has expired")

        total_charge = self._calculate_total_charge(order.total)

        if not self._has_sufficient_funds(card, total_charge):
            raise InsufficientFundsError("Insufficient funds")

        self._charge_card(card, total_charge)
        self._mark_order_as_paid(order)

        return True

    def _is_valid_order(self, order):
        return order.total > 0 and len(order.items) > 0

    def _is_card_expired(self, card):
        now = datetime.now()
        return (card.exp_year < now.year or
                (card.exp_year == now.year and card.exp_month < now.month))

    def _has_sufficient_funds(self, card, amount):
        return card.balance >= amount

    def _calculate_total_charge(self, order_total):
        fee = order_total * self.TRANSACTION_FEE_RATE + self.TRANSACTION_FEE_FIXED
        return order_total + fee

    def _charge_card(self, card, amount):
        card.balance -= amount

    def _mark_order_as_paid(self, order):
        order.status = "paid"
        order.paid_at = datetime.now()
```

**改进:** 函数名表达意图，无需注释

---

## 案例3: 模糊变量名 → 领域名词

**语言:** JavaScript

### ❌ 问题代码

```javascript
function processData(data) {
    let result = [];

    for (let item of data) {
        let temp = item.value * 1.08;
        let info = {
            id: item.id,
            val: temp,
            flag: temp > 100
        };

        if (info.flag) {
            result.push({ ...info, extra: "premium" });
        } else {
            result.push(info);
        }
    }

    return result;
}

function getData(req) {
    let params = req.query;
    let opts = {
        limit: params.limit || 10,
        offset: params.offset || 0
    };

    let data = db.query("SELECT * FROM items", opts);
    return { items: data, count: data.length };
}
```

**问题:** 变量名太通用，无法表达业务含义

### ✅ 重构后代码

```javascript
const TAX_RATE = 0.08;
const PREMIUM_THRESHOLD = 100;

function calculatePricesWithTax(products) {
    return products.map(product => {
        const priceWithTax = calculatePriceWithTax(product.price);
        const isPremiumProduct = priceWithTax > PREMIUM_THRESHOLD;

        return {
            productId: product.id,
            finalPrice: priceWithTax,
            isPremium: isPremiumProduct,
            category: isPremiumProduct ? "premium" : "standard"
        };
    });
}

function calculatePriceWithTax(price) {
    return price * (1 + TAX_RATE);
}

function fetchProducts(request) {
    const pagination = extractPaginationParams(request.query);
    const products = queryProducts(pagination);

    return {
        products: products,
        totalCount: products.length
    };
}

function extractPaginationParams(queryParams) {
    const DEFAULT_PAGE_SIZE = 10;
    const DEFAULT_OFFSET = 0;

    return {
        pageSize: queryParams.limit || DEFAULT_PAGE_SIZE,
        offset: queryParams.offset || DEFAULT_OFFSET
    };
}

function queryProducts(pagination) {
    return db.query("SELECT * FROM products", pagination);
}
```

**改进:** 变量名反映业务领域，代码自解释
