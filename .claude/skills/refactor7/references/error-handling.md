# G. 异常与错误处理

**目标:** 明确失败路径

## 目录

1. [catch Exception 什么都不做 → 显式失败](#案例1-catch-exception-什么都不做--显式失败) - Python
2. [返回 null 表示失败 → 异常或 Result](#案例2-返回-null-表示失败--异常或-result) - Python (Result pattern)
3. [多层 try-catch → 异常边界下沉](#案例3-多层-try-catch--异常边界下沉) - JavaScript

---

## 案例1: catch Exception 什么都不做 → 显式失败

**语言:** Python

### ❌ 问题代码

```python
def import_users(file_path):
    try:
        data = read_file(file_path)
    except Exception:
        pass  # 忽略异常

    try:
        users = parse_csv(data)
    except Exception as e:
        print(f"Error: {e}")  # 只打印，继续执行

    try:
        save_to_database(users)
    except Exception:
        pass  # 静默失败

    try:
        send_notification()
    except Exception:
        pass

    return True  # 总是返回成功
```

**问题:** 异常被吞掉，无法追踪错误，系统状态不一致

### ✅ 重构后代码

```python
from dataclasses import dataclass
from typing import List

@dataclass
class ImportResult:
    success: bool
    imported_count: int
    errors: List[str]

def import_users(file_path):
    errors = []

    try:
        data = read_file(file_path)
    except FileNotFoundError:
        return ImportResult(False, 0, ["File not found"])
    except Exception as e:
        return ImportResult(False, 0, [f"Failed to read file: {e}"])

    try:
        users = parse_csv(data)
    except Exception as e:
        return ImportResult(False, 0, [f"Failed to parse CSV: {e}"])

    try:
        count = save_to_database(users)
    except Exception as e:
        return ImportResult(False, 0, [f"Database error: {e}"])

    # 非关键步骤：通知发送失败可以容忍
    try:
        send_notification()
    except Exception as e:
        errors.append(f"Notification failed: {e}")

    return ImportResult(True, count, errors)
```

**改进:** 错误可追踪，关键失败会中断流程

---

## 案例2: 返回 null 表示失败 → 异常或 Result

**语言:** Python (Result pattern)

### ❌ 问题代码

```python
def find_user(user_id):
    try:
        user = database.query("SELECT * FROM users WHERE id = ?", user_id)
        if user:
            return user
        return None  # 用户不存在
    except Exception:
        return None  # 数据库错误

def load_config(file_path):
    try:
        with open(file_path) as f:
            return json.load(f)
    except FileNotFoundError:
        return None  # 文件不存在
    except json.JSONDecodeError:
        return None  # 格式错误

# 使用时无法区分失败原因
user = find_user(123)
if user is None:
    # 是用户不存在还是数据库错误?
    print("Failed")
```

**问题:** 无法区分失败原因

### ✅ 重构后代码

```python
from dataclasses import dataclass
from typing import Generic, TypeVar, Union
from enum import Enum

T = TypeVar('T')

@dataclass
class Ok(Generic[T]):
    value: T

    def is_ok(self):
        return True

    def unwrap(self):
        return self.value

@dataclass
class Err:
    error: str
    code: str

    def is_ok(self):
        return False

    def unwrap(self):
        raise ValueError(f"Called unwrap on Err: {self.error}")

Result = Union[Ok[T], Err]

def find_user(user_id) -> Result:
    try:
        user = database.query("SELECT * FROM users WHERE id = ?", user_id)
        if not user:
            return Err("User not found", "NOT_FOUND")
        return Ok(user)
    except Exception as e:
        return Err(f"Database error: {e}", "DATABASE_ERROR")

def load_config(file_path) -> Result:
    try:
        with open(file_path) as f:
            config = json.load(f)
            return Ok(config)
    except FileNotFoundError:
        return Err("Config file not found", "FILE_NOT_FOUND")
    except json.JSONDecodeError as e:
        return Err(f"Invalid JSON: {e}", "PARSE_ERROR")

# 明确的错误处理
result = find_user(123)
if result.is_ok():
    user = result.unwrap()
    process_user(user)
else:
    if result.code == "NOT_FOUND":
        print("User does not exist")
    elif result.code == "DATABASE_ERROR":
        print("Database error, retrying...")
```

**改进:** 错误类型明确，强制调用者处理错误

---

## 案例3: 多层 try-catch → 异常边界下沉

**语言:** JavaScript

### ❌ 问题代码

```javascript
async function registerUser(userData) {
    try {
        try {
            const validated = validateUserData(userData);
            try {
                const hashed = await hashPassword(validated.password);
                try {
                    const user = await createUser(validated, hashed);
                    try {
                        await sendWelcomeEmail(user.email);
                        return { success: true, user };
                    } catch (emailError) {
                        return { success: false, error: "Email failed" };
                    }
                } catch (dbError) {
                    return { success: false, error: "Database error" };
                }
            } catch (hashError) {
                return { success: false, error: "Hash failed" };
            }
        } catch (validationError) {
            return { success: false, error: "Validation failed" };
        }
    } catch (error) {
        return { success: false, error: "Unexpected error" };
    }
}
```

**问题:** 嵌套过深，难以阅读

### ✅ 重构后代码

```javascript
class RegistrationError extends Error {
    constructor(message, code) {
        super(message);
        this.code = code;
    }
}

async function validateUserData(userData) {
    if (!userData.email || !userData.password) {
        throw new RegistrationError(
            "Email and password required",
            "VALIDATION_ERROR"
        );
    }
    return userData;
}

async function hashPassword(password) {
    try {
        return await bcrypt.hash(password, 10);
    } catch (error) {
        throw new RegistrationError("Hash failed", "HASH_ERROR");
    }
}

async function createUser(validated, hashed) {
    try {
        return await db.users.create({
            ...validated,
            password: hashed
        });
    } catch (error) {
        throw new RegistrationError("Database error", "DB_ERROR");
    }
}

async function sendWelcomeEmail(email) {
    try {
        await emailService.send(email, "Welcome!");
    } catch (error) {
        // 非关键步骤，只记录不抛出
        logger.warn("Email failed", { email, error });
    }
}

// 主函数只有一层异常处理
async function registerUser(userData) {
    try {
        const validated = await validateUserData(userData);
        const hashed = await hashPassword(validated.password);
        const user = await createUser(validated, hashed);

        // 非关键步骤不阻塞流程
        await sendWelcomeEmail(user.email);

        return { success: true, user };
    } catch (error) {
        if (error instanceof RegistrationError) {
            return {
                success: false,
                error: {
                    code: error.code,
                    message: error.message
                }
            };
        }

        logger.error("Unexpected error", error);
        return {
            success: false,
            error: { code: "UNEXPECTED", message: "Unexpected error" }
        };
    }
}
```

**改进:** 异常边界清晰，业务流程线性，关键和非关键步骤分离
