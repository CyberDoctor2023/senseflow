# D. 参数与数据结构问题

**目标:** 接口稳定性

## 目录

1. [参数列表过长 → 参数对象](#案例1-参数列表过长--参数对象) - Java (Builder pattern)
2. [多个 boolean 参数 → 枚举/配置对象](#案例2-多个-boolean-参数--枚举配置对象) - Python
3. [Map<String, Object> → 明确类型对象](#案例3-mapstring-object--明确类型对象) - TypeScript
4. [同时传入相关参数 → Value Object](#案例4-同时传入相关参数--value-object) - JavaScript

---

## 案例1: 参数列表过长 → 参数对象

**语言:** Java (Builder pattern)

### ❌ 问题代码

```java
public class ReportGenerator {
    public Report generate(
            String title,
            Date startDate,
            Date endDate,
            String format,
            boolean includeCharts,
            boolean includeRawData,
            String emailRecipient,
            int maxRows,
            String sortBy,
            boolean ascending) {
        // Generate report...
    }
}

// 调用时参数难以理解
Report report = generator.generate(
    "Sales Report",
    startDate,
    endDate,
    "PDF",
    true,   // includeCharts?
    false,  // includeRawData?
    "manager@company.com",
    1000,
    "date",
    false   // ascending?
);
```

**问题:** 参数过多，调用时难以理解，易出错

### ✅ 重构后代码

```java
public class ReportRequest {
    private final String title;
    private final Date startDate;
    private final Date endDate;
    private final String format;
    private final boolean includeCharts;
    private final boolean includeRawData;
    private final String emailRecipient;
    private final int maxRows;
    private final String sortBy;
    private final boolean ascending;

    private ReportRequest(Builder builder) {
        this.title = builder.title;
        this.startDate = builder.startDate;
        this.endDate = builder.endDate;
        this.format = builder.format;
        this.includeCharts = builder.includeCharts;
        this.includeRawData = builder.includeRawData;
        this.emailRecipient = builder.emailRecipient;
        this.maxRows = builder.maxRows;
        this.sortBy = builder.sortBy;
        this.ascending = builder.ascending;
    }

    public static class Builder {
        private String title;
        private Date startDate;
        private Date endDate;
        private String format = "PDF";
        private boolean includeCharts = true;
        private boolean includeRawData = false;
        private String emailRecipient;
        private int maxRows = 1000;
        private String sortBy = "date";
        private boolean ascending = true;

        public Builder withTitle(String title) {
            this.title = title;
            return this;
        }

        public Builder withDateRange(Date start, Date end) {
            this.startDate = start;
            this.endDate = end;
            return this;
        }

        public Builder withFormat(String format) {
            this.format = format;
            return this;
        }

        public Builder includeCharts(boolean include) {
            this.includeCharts = include;
            return this;
        }

        public Builder sendToEmail(String email) {
            this.emailRecipient = email;
            return this;
        }

        public ReportRequest build() {
            return new ReportRequest(this);
        }
    }
}

// 清晰的调用方式
Report report = generator.generate(
    new ReportRequest.Builder()
        .withTitle("Sales Report")
        .withDateRange(startDate, endDate)
        .withFormat("PDF")
        .includeCharts(true)
        .sendToEmail("manager@company.com")
        .build()
);
```

**改进:** 参数意图清晰，易于扩展，有默认值

---

## 案例2: 多个 boolean 参数 → 枚举/配置对象

**语言:** Python

### ❌ 问题代码

```python
def export_data(
    user_id,
    include_profile,
    include_orders,
    include_payments,
    anonymize,
    compress,
    encrypt
):
    data = {}
    if include_profile:
        data['profile'] = get_profile(user_id)
    if include_orders:
        data['orders'] = get_orders(user_id)
    if include_payments:
        data['payments'] = get_payments(user_id)

    if anonymize:
        data = anonymize_data(data)
    if compress:
        data = compress_data(data)
    if encrypt:
        data = encrypt_data(data)

    return data

# 调用时容易混淆
export_data(123, True, True, False, True, False, True)
```

**问题:** 多个 boolean 易混淆，顺序难记

### ✅ 重构后代码

```python
from dataclasses import dataclass
from enum import Flag, auto

class ExportSection(Flag):
    PROFILE = auto()
    ORDERS = auto()
    PAYMENTS = auto()
    ALL = PROFILE | ORDERS | PAYMENTS

class ProcessingOption(Flag):
    NONE = 0
    ANONYMIZE = auto()
    COMPRESS = auto()
    ENCRYPT = auto()

@dataclass
class ExportConfig:
    sections: ExportSection
    processing: ProcessingOption = ProcessingOption.NONE

def export_data(user_id, config: ExportConfig):
    data = {}

    if ExportSection.PROFILE in config.sections:
        data['profile'] = get_profile(user_id)
    if ExportSection.ORDERS in config.sections:
        data['orders'] = get_orders(user_id)
    if ExportSection.PAYMENTS in config.sections:
        data['payments'] = get_payments(user_id)

    if ProcessingOption.ANONYMIZE in config.processing:
        data = anonymize_data(data)
    if ProcessingOption.COMPRESS in config.processing:
        data = compress_data(data)
    if ProcessingOption.ENCRYPT in config.processing:
        data = encrypt_data(data)

    return data

# 清晰的调用方式
config = ExportConfig(
    sections=ExportSection.PROFILE | ExportSection.ORDERS,
    processing=ProcessingOption.ANONYMIZE | ProcessingOption.ENCRYPT
)
export_data(123, config)
```

**改进:** 意图清晰，类型安全，支持组合

---

## 案例3: Map<String, Object> → 明确类型对象

**语言:** TypeScript

### ❌ 问题代码

```typescript
function createUser(userData: Record<string, any>) {
    const user = {
        name: userData['name'],
        email: userData['email'],
        age: userData['age'] as number,
        role: userData['role'] as string
    };
    return database.save(user);
}

function updateUser(userId: number, updates: Record<string, any>) {
    const user = database.findById(userId);
    user.name = updates['name'];
    user.age = updates['age'];  // 可能类型错误
    return database.save(user);
}

// 调用时容易出错
createUser({
    name: "John",
    email: "john@example.com",
    age: "30",  // 应该是数字，但传了字符串
    role: "admin"
});
```

**问题:** 类型不安全，IDE无法提示，容易出错

### ✅ 重构后代码

```typescript
interface UserData {
    name: string;
    email: string;
    age: number;
    role: 'admin' | 'user' | 'guest';
}

interface UserUpdateData {
    name?: string;
    email?: string;
    age?: number;
    role?: 'admin' | 'user' | 'guest';
}

class User {
    constructor(
        public id: number,
        public name: string,
        public email: string,
        public age: number,
        public role: string
    ) {}

    update(updates: UserUpdateData): void {
        if (updates.name !== undefined) this.name = updates.name;
        if (updates.email !== undefined) this.email = updates.email;
        if (updates.age !== undefined) this.age = updates.age;
        if (updates.role !== undefined) this.role = updates.role;
    }
}

function createUser(userData: UserData): User {
    const user = new User(
        0,
        userData.name,
        userData.email,
        userData.age,
        userData.role
    );
    return database.save(user);
}

function updateUser(userId: number, updates: UserUpdateData): User {
    const user = database.findById(userId);
    user.update(updates);
    return database.save(user);
}

// 类型安全的调用
createUser({
    name: "John",
    email: "john@example.com",
    age: 30,  // 类型检查，必须是数字
    role: "admin"
});
```

**改进:** 类型安全，IDE自动补全，编译时检查

---

## 案例4: 同时传入相关参数 → Value Object

**语言:** JavaScript

### ❌ 问题代码

```javascript
function createRectangle(x, y, width, height, color) {
    return {
        x: x,
        y: y,
        width: width,
        height: height,
        color: color
    };
}

function drawRectangle(ctx, x, y, width, height, color) {
    ctx.fillStyle = color;
    ctx.fillRect(x, y, width, height);
}

function isPointInside(pointX, pointY, rectX, rectY, rectWidth, rectHeight) {
    return pointX >= rectX && pointX <= rectX + rectWidth &&
           pointY >= rectY && pointY <= rectY + rectHeight;
}

// 调用时容易搞混参数
const rect = createRectangle(10, 20, 100, 50, 'red');
drawRectangle(ctx, 10, 20, 100, 50, 'red');
isPointInside(30, 40, 10, 20, 100, 50);
```

**问题:** 相关参数分散，参数顺序易混淆

### ✅ 重构后代码

```javascript
class Point {
    constructor(x, y) {
        this.x = x;
        this.y = y;
    }

    distanceTo(other) {
        const dx = other.x - this.x;
        const dy = other.y - this.y;
        return Math.sqrt(dx * dx + dy * dy);
    }
}

class Size {
    constructor(width, height) {
        this.width = width;
        this.height = height;
    }

    get area() {
        return this.width * this.height;
    }
}

class Rectangle {
    constructor(position, size, color) {
        this.position = position;
        this.size = size;
        this.color = color;
    }

    draw(ctx) {
        ctx.fillStyle = this.color;
        ctx.fillRect(
            this.position.x,
            this.position.y,
            this.size.width,
            this.size.height
        );
    }

    contains(point) {
        return point.x >= this.position.x &&
               point.x <= this.position.x + this.size.width &&
               point.y >= this.position.y &&
               point.y <= this.position.y + this.size.height;
    }

    get area() {
        return this.size.area;
    }
}

// 清晰的调用方式
const rect = new Rectangle(
    new Point(10, 20),
    new Size(100, 50),
    'red'
);
rect.draw(ctx);
rect.contains(new Point(30, 40));
```

**改进:** 相关数据聚合，语义清晰，行为内聚
