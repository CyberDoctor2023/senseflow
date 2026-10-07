# I. 类职责过重 & 资源管理

**目标:** 为架构演进铺路 + 生产稳定性

## 目录

1. [God Class → Extract Class](#案例1-god-class--extract-class) - Python
2. [Service 同时做计算 + 持久化 → 分层](#案例2-service-同时做计算--持久化--分层) - Python (分层架构)
3. [Manager/Util 泛化类 → 明确子职责](#案例3-managerutil-泛化类--明确子职责) - JavaScript
4. [手动资源关闭 → RAII / try-with-resources](#案例4-手动资源关闭--raii--try-with-resources) - Python (with语句资源管理)

---

## 案例1: God Class → Extract Class

**语言:** Python

### ❌ 问题代码

```python
class UserManager:
    def __init__(self, db, email_service, storage):
        self.db = db
        self.email_service = email_service
        self.storage = storage

    # 用户CRUD
    def create_user(self, email, password): pass
    def get_user(self, user_id): pass
    def update_user(self, user): pass
    def delete_user(self, user_id): pass

    # 认证
    def login(self, email, password): pass
    def logout(self, token): pass
    def verify_token(self, token): pass

    # 权限
    def grant_permission(self, user, perm): pass
    def revoke_permission(self, user, perm): pass

    # 文件
    def upload_avatar(self, user, file): pass
    def get_avatar(self, user): pass

    # 通知
    def send_welcome_email(self, user): pass
    def send_reset_email(self, email): pass

    # ... 30+ methods
```

**问题:** 职责过多，难以维护

### ✅ 重构后代码

```python
class UserRepository:
    def __init__(self, db):
        self.db = db

    def save(self, user):
        return self.db.execute("INSERT INTO users ...", user)

    def find_by_id(self, user_id):
        return self.db.query("SELECT * FROM users WHERE id = ?", user_id)

    def find_by_email(self, email):
        return self.db.query("SELECT * FROM users WHERE email = ?", email)

class AuthenticationService:
    def __init__(self, user_repo, password_hasher, token_generator):
        self.user_repo = user_repo
        self.password_hasher = password_hasher
        self.token_generator = token_generator

    def login(self, email, password):
        user = self.user_repo.find_by_email(email)
        if not user or not self.password_hasher.verify(password, user.password_hash):
            raise AuthenticationError("Invalid credentials")

        token = self.token_generator.generate(user)
        return AuthToken(user, token)

    def logout(self, token):
        self.token_generator.revoke(token)

    def verify_token(self, token):
        return self.token_generator.validate(token)

class AuthorizationService:
    def __init__(self, permission_repo):
        self.permission_repo = permission_repo

    def grant_permission(self, user, permission):
        self.permission_repo.add(user.id, permission)

    def revoke_permission(self, user, permission):
        self.permission_repo.remove(user.id, permission)

    def has_permission(self, user, resource):
        return self.permission_repo.check(user.id, resource)

class UserProfileService:
    def __init__(self, user_repo, storage):
        self.user_repo = user_repo
        self.storage = storage

    def upload_avatar(self, user, file):
        url = self.storage.upload(file, f"avatars/{user.id}")
        user.avatar_url = url
        self.user_repo.save(user)

    def get_avatar(self, user):
        return self.storage.download(user.avatar_url)
```

**改进:** 职责清晰，每个类只做一件事

---

## 案例2: Service 同时做计算 + 持久化 → 分层

**语言:** Python (分层架构)

### ❌ 问题代码

```python
class OrderService:
    def __init__(self, db):
        self.db = db

    def process_order(self, order_data):
        # 查询数据库
        customer = self.db.query("SELECT * FROM customers WHERE id = ?",
                                 order_data['customer_id'])

        # 计算价格
        total = sum(item['price'] * item['qty'] for item in order_data['items'])

        # 计算折扣
        discount = total * 0.1 if customer['tier'] == 'gold' else 0

        # 插入订单
        order_id = self.db.execute(
            "INSERT INTO orders (customer_id, total, discount) VALUES (?, ?, ?)",
            customer['id'], total, discount
        )

        return order_id
```

**问题:** 业务逻辑、计算和数据访问混在一起

### ✅ 重构后代码

```python
# 领域模型层
class Order:
    TAX_RATE = 0.08

    def __init__(self, customer, items):
        self.customer = customer
        self.items = items

    def calculate_subtotal(self):
        return sum(item.price * item.quantity for item in self.items)

    def calculate_discount(self):
        subtotal = self.calculate_subtotal()
        return subtotal * self.customer.get_discount_rate()

    def calculate_total(self):
        subtotal = self.calculate_subtotal()
        discount = self.calculate_discount()
        tax = (subtotal - discount) * self.TAX_RATE
        return subtotal - discount + tax

class Customer:
    def __init__(self, id, tier):
        self.id = id
        self.tier = tier

    def get_discount_rate(self):
        rates = {'gold': 0.1, 'silver': 0.05, 'bronze': 0.0}
        return rates.get(self.tier, 0.0)

# 仓储层
class CustomerRepository:
    def __init__(self, db):
        self.db = db

    def find_by_id(self, customer_id):
        row = self.db.query("SELECT * FROM customers WHERE id = ?", customer_id)
        return Customer(row['id'], row['tier'])

class OrderRepository:
    def __init__(self, db):
        self.db = db

    def save(self, order):
        return self.db.execute(
            "INSERT INTO orders (customer_id, total, discount) VALUES (?, ?, ?)",
            order.customer.id,
            order.calculate_total(),
            order.calculate_discount()
        )

# 应用服务层
class OrderApplicationService:
    def __init__(self, customer_repo, order_repo):
        self.customer_repo = customer_repo
        self.order_repo = order_repo

    def process_order(self, order_request):
        customer = self.customer_repo.find_by_id(order_request['customer_id'])
        items = [Item(i['name'], i['price'], i['qty']) for i in order_request['items']]

        order = Order(customer, items)
        order_id = self.order_repo.save(order)

        return order_id
```

**改进:** 分层清晰，业务逻辑、数据访问和编排分离

---

## 案例3: Manager/Util 泛化类 → 明确子职责

**语言:** JavaScript

### ❌ 问题代码

```javascript
class StringUtils {
    static isEmpty(str) { /* ... */ }
    static trim(str) { /* ... */ }
    static capitalize(str) { /* ... */ }
    static isEmail(str) { /* ... */ }
    static isPhone(str) { /* ... */ }
    static formatCurrency(amount) { /* ... */ }
    static parseDate(str) { /* ... */ }
    static formatDate(date) { /* ... */ }
    static encodeBase64(str) { /* ... */ }
    static md5(str) { /* ... */ }
    static sanitizeHtml(html) { /* ... */ }
    // ... 50+ methods
}
```

**问题:** 工具类成为垃圾桶

### ✅ 重构后代码

```javascript
class StringOperations {
    static isEmpty(str) {
        return !str || str.trim().length === 0;
    }

    static trim(str) {
        return str ? str.trim() : null;
    }

    static capitalize(str) {
        if (this.isEmpty(str)) return str;
        return str.charAt(0).toUpperCase() + str.slice(1);
    }
}

class Validator {
    static EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    static PHONE_PATTERN = /^\d{10}$/;

    static isEmail(str) {
        return str && this.EMAIL_PATTERN.test(str);
    }

    static isPhone(str) {
        return str && this.PHONE_PATTERN.test(str);
    }
}

class Formatter {
    static formatCurrency(amount) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(amount);
    }

    static formatDate(date) {
        return new Intl.DateTimeFormat('en-US').format(date);
    }
}

class Encoder {
    static encodeBase64(str) {
        return btoa(str);
    }

    static decodeBase64(str) {
        return atob(str);
    }
}

class HashUtils {
    static async md5(str) {
        // MD5 implementation
    }

    static async sha256(str) {
        // SHA-256 implementation
    }
}
```

**改进:** 职责明确，易于查找和使用

---

## 案例4: 手动资源关闭 → RAII / try-with-resources

**语言:** Python (with语句资源管理)

### ❌ 问题代码

```python
def read_file(path):
    file = None
    try:
        file = open(path, 'r')
        content = file.read()
        return content
    except IOError as e:
        raise RuntimeError(f"Failed to read: {path}")
    finally:
        if file:
            try:
                file.close()
            except:
                pass

def copy_file(source, dest):
    src = None
    dst = None
    try:
        src = open(source, 'rb')
        dst = open(dest, 'wb')
        dst.write(src.read())
    except IOError as e:
        raise RuntimeError(f"Failed to copy: {source}")
    finally:
        if src:
            try: src.close()
            except: pass
        if dst:
            try: dst.close()
            except: pass
```

**问题:** 资源管理代码冗长，容易遗漏关闭

### ✅ 重构后代码

```python
def read_file(path):
    try:
        with open(path, 'r') as file:
            return file.read()
    except IOError as e:
        raise RuntimeError(f"Failed to read: {path}") from e

def copy_file(source, dest):
    try:
        with open(source, 'rb') as src, open(dest, 'wb') as dst:
            dst.write(src.read())
    except IOError as e:
        raise RuntimeError(f"Failed to copy: {source} to {dest}") from e

# 自定义资源管理器
class DatabaseConnection:
    def __init__(self, connection_string):
        self.connection_string = connection_string
        self.conn = None

    def __enter__(self):
        self.conn = connect(self.connection_string)
        return self.conn

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.conn:
            self.conn.close()
        return False

# 使用自定义资源管理器
def query_data(query):
    with DatabaseConnection("connection_string") as conn:
        return conn.execute(query)
    # 连接自动关闭
```

**改进:** 资源自动管理，代码简洁，不会泄漏资源
