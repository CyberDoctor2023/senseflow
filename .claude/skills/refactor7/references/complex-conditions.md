# C. 条件复杂 / 分支爆炸

**目标：** 减少 if-else 树

## 目录

1. [类型判断 if-else → 多态](#案例1-类型判断-if-else--多态) - JavaScript
2. [策略切换 if-else → Strategy](#案例2-策略切换-if-else--strategy) - Python
3. [复杂布尔条件 → 语义化函数](#案例3-复杂布尔条件--语义化函数) - JavaScript
4. [switch + 魔法数 → 枚举 + 行为](#案例4-switch--魔法数--枚举--行为) - Java
5. [条件嵌套 → Guard Clause](#案例5-条件嵌套--guard-clause) - Python

---

## 案例1: 类型判断 if-else → 多态

**语言:** JavaScript

### ❌ 问题代码

```javascript
function processPayment(payment) {
    if (payment.type === 'credit_card') {
        const fee = payment.amount * 0.029;
        chargeCard(payment.cardNumber, payment.amount + fee);
        return { success: true, fee: fee };
    } else if (payment.type === 'paypal') {
        const fee = payment.amount * 0.035;
        paypalAPI.charge(payment.email, payment.amount + fee);
        return { success: true, fee: fee };
    } else if (payment.type === 'crypto') {
        const fee = payment.amount * 0.01;
        sendCrypto(payment.wallet, payment.amount + fee);
        return { success: true, fee: fee };
    } else if (payment.type === 'bank_transfer') {
        initiateTransfer(payment.account, payment.amount);
        return { success: true, fee: 0 };
    }
    throw new Error('Unknown payment type');
}
```

**问题：** 类型判断重复，添加新支付方式需修改函数

### ✅ 重构后代码

```javascript
class CreditCardPayment {
    constructor(cardNumber, amount) {
        this.cardNumber = cardNumber;
        this.amount = amount;
    }

    getFee() {
        return this.amount * 0.029;
    }

    process() {
        chargeCard(this.cardNumber, this.amount + this.getFee());
        return { success: true, fee: this.getFee() };
    }
}

class PayPalPayment {
    constructor(email, amount) {
        this.email = email;
        this.amount = amount;
    }

    getFee() {
        return this.amount * 0.035;
    }

    process() {
        paypalAPI.charge(this.email, this.amount + this.getFee());
        return { success: true, fee: this.getFee() };
    }
}

class CryptoPayment {
    constructor(wallet, amount) {
        this.wallet = wallet;
        this.amount = amount;
    }

    getFee() {
        return this.amount * 0.01;
    }

    process() {
        sendCrypto(this.wallet, this.amount + this.getFee());
        return { success: true, fee: this.getFee() };
    }
}

// 使用多态
function processPayment(payment) {
    return payment.process();
}
```

**改进：** 添加新支付方式无需修改现有代码，符合开闭原则

---

## 案例2: 策略切换 if-else → Strategy

**语言:** Python

### ❌ 问题代码

```python
def compress_file(file_path, format):
    if format == "zip":
        with zipfile.ZipFile(f"{file_path}.zip", "w") as zf:
            zf.write(file_path)
        return f"{file_path}.zip"
    elif format == "tar":
        with tarfile.open(f"{file_path}.tar", "w") as tf:
            tf.add(file_path)
        return f"{file_path}.tar"
    elif format == "gz":
        with gzip.open(f"{file_path}.gz", "wb") as gf:
            with open(file_path, "rb") as f:
                gf.write(f.read())
        return f"{file_path}.gz"
    elif format == "7z":
        subprocess.run(["7z", "a", f"{file_path}.7z", file_path])
        return f"{file_path}.7z"
    else:
        raise ValueError(f"Unsupported format: {format}")
```

**问题：** 添加新压缩格式需修改函数

### ✅ 重构后代码

```python
from abc import ABC, abstractmethod

class CompressionStrategy(ABC):
    @abstractmethod
    def compress(self, file_path):
        pass

class ZipCompression(CompressionStrategy):
    def compress(self, file_path):
        output = f"{file_path}.zip"
        with zipfile.ZipFile(output, "w") as zf:
            zf.write(file_path)
        return output

class TarCompression(CompressionStrategy):
    def compress(self, file_path):
        output = f"{file_path}.tar"
        with tarfile.open(output, "w") as tf:
            tf.add(file_path)
        return output

class GzipCompression(CompressionStrategy):
    def compress(self, file_path):
        output = f"{file_path}.gz"
        with gzip.open(output, "wb") as gf:
            with open(file_path, "rb") as f:
                gf.write(f.read())
        return output

class FileCompressor:
    def __init__(self):
        self.strategies = {
            "zip": ZipCompression(),
            "tar": TarCompression(),
            "gz": GzipCompression()
        }

    def compress(self, file_path, format):
        strategy = self.strategies.get(format)
        if not strategy:
            raise ValueError(f"Unsupported format: {format}")
        return strategy.compress(file_path)
```

**改进：** 添加新策略只需添加新类，无需修改现有代码

---

## 案例3: 复杂布尔条件 → 语义化函数

**语言:** JavaScript

### ❌ 问题代码

```javascript
function canPublishPost(user, post) {
    if (user.role === 'admin' ||
        (user.role === 'editor' && user.department === post.department) ||
        (user.id === post.authorId && post.status === 'draft' &&
         user.postsPublishedThisMonth < 10 && !post.isDeleted &&
         post.wordCount >= 300 && post.wordCount <= 5000)) {

        if (post.hasRequiredTags && post.hasFeaturedImage &&
            !post.containsProhibitedWords && post.passedSpellCheck) {
            return true;
        }
    }
    return false;
}
```

**问题：** 条件复杂，难以理解业务规则

### ✅ 重构后代码

```javascript
function canPublishPost(user, post) {
    return hasPublishPermission(user, post) &&
           meetsQualityStandards(post);
}

function hasPublishPermission(user, post) {
    return isAdmin(user) ||
           isDepartmentEditor(user, post) ||
           canAuthorPublish(user, post);
}

function isAdmin(user) {
    return user.role === 'admin';
}

function isDepartmentEditor(user, post) {
    return user.role === 'editor' &&
           user.department === post.department;
}

function canAuthorPublish(user, post) {
    return user.id === post.authorId &&
           post.status === 'draft' &&
           !hasReachedPublishLimit(user) &&
           isPostValid(post) &&
           isWithinWordCountLimits(post);
}

function hasReachedPublishLimit(user) {
    return user.postsPublishedThisMonth >= 10;
}

function isPostValid(post) {
    return !post.isDeleted;
}

function isWithinWordCountLimits(post) {
    return post.wordCount >= 300 && post.wordCount <= 5000;
}

function meetsQualityStandards(post) {
    return post.hasRequiredTags &&
           post.hasFeaturedImage &&
           !post.containsProhibitedWords &&
           post.passedSpellCheck;
}
```

**改进：** 每个条件都有清晰的业务语义

---

## 案例4: switch + 魔法数 → 枚举 + 行为

**语言:** Java

### ❌ 问题代码

```java
public class TaskProcessor {
    public void processTask(Task task) {
        switch (task.getStatus()) {
            case 0: // pending
                task.setStartTime(new Date());
                task.setStatus(1);
                break;
            case 1: // running
                task.execute();
                task.setStatus(2);
                break;
            case 2: // completed
                task.sendNotification();
                break;
            case 3: // failed
                task.retry();
                task.setStatus(1);
                break;
        }
    }
}
```

**问题：** 魔法数难以理解，添加状态需修改switch

### ✅ 重构后代码

```java
public enum TaskStatus {
    PENDING {
        @Override
        public void process(Task task) {
            task.setStartTime(new Date());
            task.transitionTo(RUNNING);
        }
    },

    RUNNING {
        @Override
        public void process(Task task) {
            task.execute();
            task.transitionTo(COMPLETED);
        }
    },

    COMPLETED {
        @Override
        public void process(Task task) {
            task.sendNotification();
        }
    },

    FAILED {
        @Override
        public void process(Task task) {
            task.retry();
            task.transitionTo(RUNNING);
        }
    };

    public abstract void process(Task task);
}

public class Task {
    private TaskStatus status;

    public void process() {
        status.process(this);
    }

    void transitionTo(TaskStatus newStatus) {
        this.status = newStatus;
    }
}
```

**改进：** 状态和行为封装在枚举中，类型安全

---

## 案例5: 条件嵌套 → Guard Clause

**语言:** Python

### ❌ 问题代码

```python
def transfer_money(from_account, to_account, amount):
    if from_account is not None:
        if to_account is not None:
            if from_account.is_active and to_account.is_active:
                if amount > 0:
                    if from_account.balance >= amount:
                        if amount <= from_account.daily_limit:
                            from_account.balance -= amount
                            to_account.balance += amount
                            log_transfer(from_account, to_account, amount)
                            return True
    return False
```

**问题：** 嵌套层级深，正常路径被埋在深处

### ✅ 重构后代码

```python
def transfer_money(from_account, to_account, amount):
    if from_account is None or to_account is None:
        raise ValueError("Invalid account")

    if not from_account.is_active or not to_account.is_active:
        raise ValueError("Account not active")

    if amount <= 0:
        raise ValueError("Invalid amount")

    if from_account.balance < amount:
        raise ValueError("Insufficient funds")

    if amount > from_account.daily_limit:
        raise ValueError("Exceeds daily limit")

    # Happy path: clear and visible
    from_account.balance -= amount
    to_account.balance += amount
    log_transfer(from_account, to_account, amount)
    return True
```

**改进：** 异常情况提前返回，正常流程清晰
