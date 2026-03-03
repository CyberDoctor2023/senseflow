# B. 重复代码

**目标：** 消灭腐烂源头

## 目录

1. [if/else 中的重复逻辑 → 提炼公共函数](#案例1-ifelse-中的重复逻辑--提炼公共函数) - Python
2. [多处复制校验逻辑 → Validator 抽取](#案例2-多处复制校验逻辑--validator-抽取) - JavaScript
3. [不同类中相似算法 → 模板方法](#案例3-不同类中相似算法--模板方法) - Python
4. [测试中的重复 setup → 测试夹具提炼](#案例4-测试中的重复-setup--测试夹具提炼) - JavaScript

---

## 案例1: if/else 中的重复逻辑 → 提炼公共函数

**语言:** Python

### ❌ 问题代码

```python
def process_premium_user(user):
    if not user.email or not user.is_verified:
        raise ValueError("Invalid user")

    send_email(user.email, "Welcome to Premium!",
               f"Hello {user.name}, welcome to premium.")

    logger.info(f"Premium user {user.id} processed")

    user.membership = "premium"
    user.premium_since = datetime.now()
    db.save(user)

def process_trial_user(user):
    if not user.email or not user.is_verified:
        raise ValueError("Invalid user")

    send_email(user.email, "Start Your Trial!",
               f"Hello {user.name}, your trial started.")

    logger.info(f"Trial user {user.id} processed")

    user.membership = "trial"
    user.trial_started = datetime.now()
    db.save(user)
```

**问题：** 验证、日志、邮件逻辑重复

### ✅ 重构后代码

```python
def process_premium_user(user):
    validate_user(user)
    send_welcome_email(user, "premium")
    log_processing(user, "premium")
    upgrade_to_premium(user)

def process_trial_user(user):
    validate_user(user)
    send_welcome_email(user, "trial")
    log_processing(user, "trial")
    start_trial(user)

def validate_user(user):
    if not user.email or not user.is_verified:
        raise ValueError("Invalid user")

def send_welcome_email(user, tier):
    templates = {
        "premium": ("Welcome to Premium!",
                   f"Hello {user.name}, welcome to premium."),
        "trial": ("Start Your Trial!",
                 f"Hello {user.name}, your trial started.")
    }
    subject, body = templates[tier]
    send_email(user.email, subject, body)

def log_processing(user, tier):
    logger.info(f"{tier.capitalize()} user {user.id} processed")

def upgrade_to_premium(user):
    user.membership = "premium"
    user.premium_since = datetime.now()
    db.save(user)

def start_trial(user):
    user.membership = "trial"
    user.trial_started = datetime.now()
    db.save(user)
```

**改进：** 公共逻辑集中，修改只需改一处

---

## 案例2: 多处复制校验逻辑 → Validator 抽取

**语言:** JavaScript

### ❌ 问题代码

```javascript
// UserController.js
createUser(req) {
    if (!req.email || !req.email.match(/^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/)) {
        throw new Error("Invalid email");
    }
    if (!req.password || req.password.length < 8) {
        throw new Error("Password too short");
    }
    userService.create(req);
}

// ProfileController.js
updateProfile(userId, req) {
    if (!req.email || !req.email.match(/^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/)) {
        throw new Error("Invalid email");
    }
    profileService.update(userId, req);
}

// AdminController.js
inviteUser(req) {
    if (!req.email || !req.email.match(/^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/)) {
        throw new Error("Invalid email");
    }
    adminService.sendInvite(req);
}
```

**问题：** 校验规则在多处重复，难以统一修改

### ✅ 重构后代码

```javascript
// UserValidator.js
class UserValidator {
    static EMAIL_PATTERN = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    static MIN_PASSWORD_LENGTH = 8;

    static validateEmail(email) {
        if (!email || !email.match(this.EMAIL_PATTERN)) {
            throw new Error("Invalid email");
        }
    }

    static validatePassword(password) {
        if (!password || password.length < this.MIN_PASSWORD_LENGTH) {
            throw new Error("Password too short");
        }
    }

    static validateUserCreation(req) {
        this.validateEmail(req.email);
        this.validatePassword(req.password);
    }

    static validateProfileUpdate(req) {
        this.validateEmail(req.email);
    }

    static validateInvitation(req) {
        this.validateEmail(req.email);
    }
}

// UserController.js
createUser(req) {
    UserValidator.validateUserCreation(req);
    userService.create(req);
}

// ProfileController.js
updateProfile(userId, req) {
    UserValidator.validateProfileUpdate(req);
    profileService.update(userId, req);
}

// AdminController.js
inviteUser(req) {
    UserValidator.validateInvitation(req);
    adminService.sendInvite(req);
}
```

**改进：** 规则集中，易于修改和测试

---

## 案例3: 不同类中相似算法 → 模板方法

**语言:** Python

### ❌ 问题代码

```python
class PDFReportGenerator:
    def generate(self, data):
        # 过滤数据
        filtered = [d for d in data if d['amount'] > 0]

        # 生成PDF
        report = create_pdf()
        report.add_title("Sales Report")
        for item in filtered:
            report.add_line(f"{item['product']}: ${item['amount']}")

        # 保存
        filename = f"report_{datetime.now():%Y%m%d}.pdf"
        report.save(filename)
        logger.info(f"PDF report: {filename}")
        return filename

class ExcelReportGenerator:
    def generate(self, data):
        # 过滤数据（重复）
        filtered = [d for d in data if d['amount'] > 0]

        # 生成Excel
        report = create_excel()
        report.add_title("Sales Report")
        for row, item in enumerate(filtered):
            report.set_cell(row, 0, item['product'])
            report.set_cell(row, 1, item['amount'])

        # 保存（重复）
        filename = f"report_{datetime.now():%Y%m%d}.xlsx"
        report.save(filename)
        logger.info(f"Excel report: {filename}")
        return filename
```

**问题：** 过滤、保存、日志逻辑重复

### ✅ 重构后代码

```python
from abc import ABC, abstractmethod

class ReportGenerator(ABC):
    def generate(self, data):
        filtered = self._filter_data(data)
        report = self._create_report()
        self._add_title(report)
        self._add_content(report, filtered)
        filename = self._save(report)
        self._log(filename)
        return filename

    def _filter_data(self, data):
        return [d for d in data if d['amount'] > 0]

    def _add_title(self, report):
        report.add_title("Sales Report")

    def _save(self, report):
        ext = self._get_extension()
        filename = f"report_{datetime.now():%Y%m%d}.{ext}"
        report.save(filename)
        return filename

    def _log(self, filename):
        logger.info(f"{self._get_format()} report: {filename}")

    @abstractmethod
    def _create_report(self): pass

    @abstractmethod
    def _add_content(self, report, data): pass

    @abstractmethod
    def _get_extension(self): pass

    @abstractmethod
    def _get_format(self): pass

class PDFReportGenerator(ReportGenerator):
    def _create_report(self):
        return create_pdf()

    def _add_content(self, report, data):
        for item in data:
            report.add_line(f"{item['product']}: ${item['amount']}")

    def _get_extension(self):
        return "pdf"

    def _get_format(self):
        return "PDF"

class ExcelReportGenerator(ReportGenerator):
    def _create_report(self):
        return create_excel()

    def _add_content(self, report, data):
        for row, item in enumerate(data):
            report.set_cell(row, 0, item['product'])
            report.set_cell(row, 1, item['amount'])

    def _get_extension(self):
        return "xlsx"

    def _get_format(self):
        return "Excel"
```

**改进：** 公共流程在基类，子类只实现差异

---

## 案例4: 测试中的重复 setup → 测试夹具提炼

**语言:** JavaScript

### ❌ 问题代码

```javascript
describe('OrderService', () => {
    test('create order', () => {
        // 重复的测试数据
        const customer = { id: 1, name: 'John', email: 'john@test.com' };
        const product1 = { id: 1, name: 'Item A', price: 10 };
        const product2 = { id: 2, name: 'Item B', price: 20 };
        const items = [
            { product: product1, qty: 2 },
            { product: product2, qty: 1 }
        ];

        const order = orderService.create(customer, items);
        expect(order.total).toBe(40);
    });

    test('cancel order', () => {
        // 又是重复的测试数据
        const customer = { id: 1, name: 'John', email: 'john@test.com' };
        const product1 = { id: 1, name: 'Item A', price: 10 };
        const product2 = { id: 2, name: 'Item B', price: 20 };
        const items = [
            { product: product1, qty: 2 },
            { product: product2, qty: 1 }
        ];
        const order = orderService.create(customer, items);

        orderService.cancel(order.id);
        expect(order.status).toBe('CANCELLED');
    });
});
```

**问题：** 测试数据大量重复

### ✅ 重构后代码

```javascript
class TestDataBuilder {
    defaultCustomer() {
        return { id: 1, name: 'John', email: 'john@test.com' };
    }

    customerWith(overrides) {
        return { ...this.defaultCustomer(), ...overrides };
    }

    defaultProducts() {
        return [
            { id: 1, name: 'Item A', price: 10 },
            { id: 2, name: 'Item B', price: 20 }
        ];
    }

    defaultOrderItems() {
        const [p1, p2] = this.defaultProducts();
        return [
            { product: p1, qty: 2 },
            { product: p2, qty: 1 }
        ];
    }

    createDefaultOrder() {
        return orderService.create(
            this.defaultCustomer(),
            this.defaultOrderItems()
        );
    }
}

describe('OrderService', () => {
    let testData;

    beforeEach(() => {
        testData = new TestDataBuilder();
    });

    test('create order', () => {
        const order = orderService.create(
            testData.defaultCustomer(),
            testData.defaultOrderItems()
        );
        expect(order.total).toBe(40);
    });

    test('cancel order', () => {
        const order = testData.createDefaultOrder();

        orderService.cancel(order.id);
        expect(order.status).toBe('CANCELLED');
    });

    test('premium customer gets discount', () => {
        const premiumCustomer = testData.customerWith({
            tier: 'premium'
        });

        const order = orderService.create(
            premiumCustomer,
            testData.defaultOrderItems()
        );
        expect(order.discount).toBeGreaterThan(0);
    });
});
```

**改进：** 测试数据集中，灵活定制，测试代码简洁
