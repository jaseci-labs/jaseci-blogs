---
date: 2025-10-25
authors:
  - mars
categories:
  - Jac Programming
  - Fixing the Broken
slug: dataclasses-and-jac-objects
---

# Dataclasses: Python's Admission That Classes Are Broken (And How Jac Fixes It Properly)

Python's traditional class syntax has a problem: defining any class with fields requires excessive boilerplate. After decades of developers writing the same `__init__`, `__repr__`, and `__eq__` methods, Python 3.7 introduced dataclasses ([PEP 557](https://peps.python.org/pep-0557/)) as a decorator-based solution. But dataclasses are a retrofit—what if dataclass semantics were built into the language from the start?

<!-- more -->

Jac explores this question by providing two archetype keywords: `class` for traditional Python semantics and `obj` for dataclass-style semantics as a first-class language feature.

## The Boilerplate Problem

Here's a simple Python class with three fields:

<div class="code-block" data-lang="python">
```python
class Person:
    def __init__(self, name: str, age: int, email: str):
        self.name = name
        self.age = age
        self.email = email

    def __repr__(self):
        return f"Person(name={self.name!r}, age={self.age!r}, email={self.email!r})"

    def __eq__(self, other):
        if not isinstance(other, Person):
            return False
        return (self.name == other.name and
                self.age == other.age and
                self.email == other.email)

print(Person(name="Alice", age=30, email="alice@example.com"))
```
</div>

We wrote each field name **nine times**. Add a fourth field? Update three methods. Forget one? Silent bugs. This violates DRY (Don't Repeat Yourself) at a fundamental level.

PEP 557 identifies this exact problem, noting that before dataclasses, developers relied on `collections.namedtuple`, `typing.NamedTuple`, or third-party libraries like `attrs`, each with limitations. The PEP argues that *"with the addition of PEP 526, Python has a concise way to specify the type of class members,"* making it possible to automatically generate boilerplate methods from type-annotated class variables.

## Python's Solution: Dataclasses

Python 3.7 introduced the `@dataclass` decorator to generate boilerplate:

<div class="code-block" data-lang="python">
```python
from dataclasses import dataclass

# Automatically generates: __init__, __repr__, __eq__
@dataclass
class Person:
    name: str
    age: int
    email: str

print(Person(name="Alice", age=30, email="alice@example.com"))
```
</div>

From 15+ lines to 4 lines. The field definitions become the single source of truth. Dataclasses can be thought of as *"mutable namedtuples with defaults"* (PEP 557).

### Dataclass Features

Dataclasses support defaults, immutability (`frozen=True`), ordering (`order=True`), and post-initialization:

<div class="code-block" data-lang="python">
```python
from dataclasses import dataclass, field

@dataclass
class Product:
    name: str
    price: float
    quantity: int = 0
    total_value: float = field(init=False)

    def __post_init__(self):
        self.total_value = self.price * self.quantity

    def restock(self, amount: int):
        self.quantity += amount
        self.total_value = self.price * self.quantity


print(Product(name="Widget", price=9.99, quantity=10).total_value)
```
</div>

This works well, but several limitations emerge from the decorator-based approach:

1. **Runtime Transformation** - The decorator transforms the class at definition time, complicating static analysis
2. **Mutable Default Trap** - Must use `field(default_factory=list)` for mutable defaults; `items: list = []` would be shared across instances
3. **Limited Validation** - No built-in field validation; PEP 557 explicitly scopes dataclasses as *"a code generator for these methods based on annotations,"* not a validation framework
4. **Mixing Generated and Manual Code** - Overriding one method while keeping others auto-generated increases cognitive overhead

PEP 557 explicitly states that dataclasses should *"not interfere with any usage of the class"*—they remain "truly normal Python classes." This constraint reflects Python's need for backward compatibility.

## Jac's Design-First Approach

Rather than retrofitting dataclass semantics onto traditional classes, Jac provides two distinct archetype keywords:

| Archetype | Semantics | Self Parameter | Field Behavior | Use Case |
|-----------|-----------|----------------|----------------|----------|
| **`class`** | Traditional Python | Explicit with type annotation | `has` fields with defaults become class variables | Class variables or traditional behavior needed |
| **`obj`** | Dataclass built-in | Implicit (available in body) | All `has` fields are instance variables | Common case where classes have fields |

Here's the same `Person` in Jac:

!!! example "Person Object"
    === "Jac"
        <div class="code-block">
        ```jac
        obj Person {
            has name: str;
            has age: int;
            has email: str;
        }

        with entry {
            print(Person(name="Alice", age=30, email="alice@example.com"));
            # Person(name='Alice', age=30, email='alice@example.com')
        }
        ```
        </div>

    === "Python + Jac Library"
        <div class="code-block" data-lang="python">
        ```python
        from __future__ import annotations
        from jaclang.lib import Obj

        class Person(Obj):
            name: str
            age: int
            email: str

        print(Person(name='Alice', age=30, email='alice@example.com'))
        # Person(name='Alice', age=30, email='alice@example.com')
        ```
        </div>

No decorator, no import, just clean declaration. The `obj` keyword signals dataclass semantics as a language-level construct.

### Key Differences from Python

!!! example "Counter with Methods"
    === "Jac"
        <div class="code-block">
        ```jac
        obj Counter {
            has count: int = 0;

            def increment {  # No self parameter in signature
                self.count += 1;  # But self is available in body
            }

            def get_count -> int {
                return self.count;
            }
        }

        with entry {
            c1 = Counter();
            c1.increment();
            c1.increment();

            c2 = Counter();
            c2.increment();

            print(f"c1: {c1.get_count()}, c2: {c2.get_count()}");
            # c1: 2, c2: 1
        }
        ```
        </div>

    === "Python + Jac Library"
        <div class="code-block" data-lang="python">
        ```python
        from __future__ import annotations
        from jaclang.lib import Obj

        class Counter(Obj):
            count: int = 0

            def increment(self) -> None:
                self.count += 1

            def get_count(self) -> int:
                return self.count

        c1 = Counter()
        c1.increment()
        c1.increment()

        c2 = Counter()
        c2.increment()

        print(f'c1: {c1.get_count()}, c2: {c2.get_count()}')
        # c1: 2, c2: 1
        ```
        </div>

Each instance maintains independent state—`c1` and `c2` don't interfere because `obj` fields are instance variables by default.

??? note "Jac's optional () syntax sugar"
    Jac makes empty parentheses `()` optional in function/method declarations—`def increment` works the same as `def increment()`. Additionally, the return type annotation defaults to `-> None` if not specified, which is particularly clean for functions that don't return values. You can write `def increment { ... }` instead of `def increment() -> None { ... }`.

### The `Product` Example in Jac

!!! example "Product with Post-Initialization"
    === "Jac"
        <div class="code-block">
        ```jac
        obj Product {
            has name: str;
            has price: float;
            has quantity: int = 0;
            has total_value: float by postinit;  # Computed field

            def postinit {
                self.total_value = self.price * self.quantity;
            }

            def restock(amount: int) {
                self.quantity += amount;
                self.total_value = self.price * self.quantity;
            }
        }

        with entry {
            product = Product(name="Widget", price=9.99, quantity=10);
            print(f"{product.name}: ${product.total_value:.2f}");
            # Widget: $99.90

            product.restock(5);
            print(f"After restock: {product.quantity} units, ${product.total_value:.2f}");
            # After restock: 15 units, $149.85
        }
        ```
        </div>

    === "Python + Jac Library"
        <div class="code-block" data-lang="python">
        ```python
        from __future__ import annotations
        from jaclang.lib import Obj, field

        class Product(Obj):
            name: str
            price: float
            quantity: int = 0
            total_value: float = field(init=False)

            def __post_init__(self) -> None:
                self.total_value = self.price * self.quantity

            def restock(self, amount: int) -> None:
                self.quantity += amount
                self.total_value = self.price * self.quantity

        product = Product(name='Widget', price=9.99, quantity=10)
        print(f'{product.name}: ${product.total_value:.2f}')
        # Widget: $99.90

        product.restock(5)
        print(f'After restock: {product.quantity} units, ${product.total_value:.2f}')
        # After restock: 15 units, $149.85
        ```
        </div>

Compare to the Python version:
- No decorator import
- `by postinit` is cleaner than `field(init=False)`
- No explicit `self` in method signatures
- Same functionality, less ceremony

### Static Members and Access Control

!!! example "BankAccount with Static Members"
    === "Jac"
        <div class="code-block">
        ```jac
        obj BankAccount {
            has account_number: str;
            has :priv balance: float = 0.0;  # Private field

            static has total_accounts: int = 0;  # Class-level state

            def postinit {
                BankAccount.total_accounts += 1;
            }

            static def get_total -> int {
                return BankAccount.total_accounts;
            }

            def deposit(amount: float) {
                self.balance += amount;
            }
        }

        with entry {
            acc1 = BankAccount(account_number="A001");
            acc2 = BankAccount(account_number="A002");

            print(f"Total accounts: {BankAccount.get_total()}");
            # Total accounts: 2
        }
        ```
        </div>

    === "Python + Jac Library"
        <div class="code-block" data-lang="python">
        ```python
        from __future__ import annotations
        from jaclang.runtimelib.builtin import ClassVar
        from jaclang.lib import Obj

        class BankAccount(Obj):
            account_number: str
            balance: float = 0.0
            total_accounts: ClassVar[int] = 0

            def __post_init__(self) -> None:
                BankAccount.total_accounts += 1

            @staticmethod
            def get_total() -> int:
                return BankAccount.total_accounts

            def deposit(self, amount: float) -> None:
                self.balance += amount

        acc1 = BankAccount(account_number='A001')
        acc2 = BankAccount(account_number='A002')

        print(f'Total accounts: {BankAccount.get_total()}')
        # Total accounts: 2
        ```
        </div>

The `static has` keyword makes class-level state explicit, and `:priv` provides access control as a language feature rather than convention.

## Why This Matters

Dataclasses introduced in python 3.7 aren't just a convenience—they represent **fundamentally better class design**. The traditional Python class syntax with manual `__init__`, `__repr__`, and `__eq__` methods was always a design flaw, not a feature. Writing the same field name nine times isn't "explicit is better than implicit"—it's error-prone busywork.

The proof is in adoption: dataclasses have become the default recommendation for new Python code. They're not just for "simple data containers"—they're better for virtually any class with fields. The boilerplate generation isn't sacrificing anything; it's eliminating redundancy while maintaining full class functionality.

**The question becomes**: If dataclasses are fundamentally better, why are they a decorator rather than the default?

The answer is Python's evolutionary constraint. With millions of lines of existing code using traditional classes, Python couldn't change the default behavior of the `class` keyword. Decorators were the pragmatic path to introduce better semantics without breaking existing code.

**Jac's advantage** is starting fresh. Without legacy constraints, `obj` makes dataclass-style semantics the natural way to define classes with fields:

- **No decorator ceremony** - The better approach is built-in, not opt-in
- **Cleaner syntax** - Implicit `self`, `by postinit` instead of `field(init=False)`
- **Explicit intent** - `static has` distinguishes class variables from the instance variable default
- **Language-level features** - Access modifiers and instance variables as first-class concepts

If Python could redesign classes from scratch today, they'd likely look a lot more like Jac's `obj` than the current `class` syntax. Jac explores what becomes possible when you build the better design into the language from day one.

## Comparison

| Aspect | Python `@dataclass` | Jac `obj` |
|--------|---------------------|-----------|
| Syntax | Decorator on `class` | `obj` keyword |
| Self parameter | Explicit in methods | Implicit in methods |
| Mutable defaults | `field(default_factory=list)` | `has items: list = []` works safely |
| Post-init | `field(init=False)` + `__post_init__` | `by postinit` + `postinit` |
| Static members | `class_var: ClassVar[int]` | `static has count: int` |
| Access control | Convention (`_private`) | Language feature (`:priv`) |

---

## Try It Yourself

Want to experiment with Jac's `obj` keyword?

```bash
pip install jaclang
```

Create a file `objects.jac` with any of the examples above, then run:

```bash
jac run objects.jac
```

## Further Reading

- [PEP 557 - Data Classes](https://peps.python.org/pep-0557/)
- [Jac Language Documentation](https://www.jac-lang.org/)
- [Python dataclasses documentation](https://docs.python.org/3/library/dataclasses.html)
