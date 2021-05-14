# SwiftX

SwiftX is a functional reactive state management library, heavily inspired by the JavaScript library [MobX](https://github.com/mobxjs/mobx).

## Installation

Swift Package Manager (Xcode 11 and above)

* Select **File > Swift Packages > Add Package Dependency…** from the File menu.
* Paste https://github.com/patka817/SwiftX.git in the dialog box.
* Follow the Xcode's instruction to complete the installation.

## Usage

### Available functions

* `autorun(_ onChange: () -> Void)`

    Used for emitting side-effects whenever any `@Observable` or `Computed` value changes.
   
    Runs directly upon creation and every time any accessed (in the closure) observable property is changed.

    ---

* `reaction(_ trackFunc: () -> V, _ onChange: (V) -> Void)`

    Used for emitting side-effects whenever any `@Observable` or `Computed` value changes. 

    Runs `onChange` whenever any accessed observable property in the `trackFunc` closure is changed. Do **not** trigger side-effects in the `trackFunc`, use the `onChange` closure for them.

    `onChange` is **not** triggered upon creation (as opposed to `autorun`), only when the observed properties changes.

    ---

* `deepObserve(_ object: CodableObject, _ onChange: () -> Void)`

    Used for observing changes on a whole object-graph.

    Runs `onChange` whenever any `@Observable` property in any nested class/struct or on object itself is changed (as long as they are accessible through Codable, e.g. when encoding to JSON the property is serialized).

    ---

* `computed(_ computeClosure: () -> V) -> Computed<V>`

    Used for creating a new `Observable` which derives a new value from multiple `@Observable` and/or other `Computed` classes.

    Creates a `Computed` class that updates its `value` whenever any accessed `@Observable` or `Computed.value` property used in the `computeClosure` is changed.

    The `computeClosure` should derive a new value based on multiple `@Observable` and/or `Computed.value` properties. 
    
    The `Computed` class is observable itself, like the `@Observable` propertyWrapper, just access the `Computed` value inside a `reaction`, `autorun` etc to start observing it.

    ---

* `inTransaction(_ transaction: () -> Void)`

    Used for batching multiple updates on `@Observable` properties. Updating multiple `@Observable` values inside the transaction-closure will only trigger one update-cycle.

    ---

* `ObserverView(_ viewBuilder: () -> some View)` (SwiftUI)

    Used for triggering re-rendering of the wrapped SwiftUI-view whenever any accessed, in the viewBuilder-closure, observable value is changed.

    ---

All functions that triggers observing returns a `Cancellable` that is optional to keep (e.g. the reaction will be kept alive even if the `Cancellable` is not handled). 
**But you must manually cancel it to stop the reaction from observing and emitting side-effects.**

So you are probably always going to need to keep the returned `Cancellables` around..

### Examples

Simple usage by registering and listening for a single property by using the `reaction` function.

```swift
import SwiftX

struct AppState {
    @Observable var greeting = "Hello World"
}

let state = AppState()
let cancellable = reaction({
    return state.greeting
}, { greeting in
    myAwesomeFunc(greeting)
})

state.greeting = "Hej världen" // Will trigger a call to myAwesomeFunc once
````

---

It also works on lists, sets and dictionaries:

```swift

import SwiftX

struct AppState {
    @Observable var todos = [String]()
}

let state = AppState()

autorun {
    print("Todos are:\n\(state.todos.joined(separator: "\n"))")
}

state.todos.append("Dishes")
```
The `autorun` closure will be called twice here, once upon creation and then when the accessed property has been changed.

---

It is also possible to observe an object "deeply". That is, react whenever any observable property is changed on an object, no matter how nested the changed property is (as long as it is `Codable` to that path):

```swift
struct Person: Codable {
    @Observable var firstName: String
    @Observable var secondName: String
    @Observable var father: Person?
    
    enum CodingKey {
        case father
    }
    
    var description: String {
        "\(firstName) \(secondName)"
    }
}

var grandDad = Person(firstName: "Bob", secondName: "Anderson", father: nil)
var dad = Person(firstName: "Jack", secondName: "Anderson", father: grandDad)
var child = Person(firstName: "Nat", secondName: "Anderson", father: dad)

reaction({ child.father }, {
    print("Father changed")
})

deepObserve(child, {
    print("child: \(child.firstName)")
    print("father: \(child.father?.firstName)")
    print("grandfather: \(dad.father?.firstName)")
})

grandDad.firstName = "Anders"
```
**deepObserve** will be called once, since `Person` is `Codable` and the changed property is an `@Observable`.

**Note:** `reaction` will never get called, since it only listens on changes on `child.father`. 

---

Example of a potential pitfall:

```swift
struct Person: Codable {
    @Observable var firstName: String
    @Observable var secondName: String
    @Observable var father: Person?
    
    enum CodingKey {
        case father
    }
    
    var description: String {
        "\(firstName) \(secondName)"
    }
}

var grandDad = Person(firstName: "Bob", secondName: "Anderson", father: nil)
var dad = Person(firstName: "Jack", secondName: "Anderson", father: grandDad)
var child = Person(firstName: "Nat", secondName: "Anderson", father: dad)

reaction({ child.father }, {
    print("Father changed")
})

child.father.firstName = "Spooky"
```

The reaction will **not** be triggered when fathers first name changes, since the observing happens whenever the property `father` on the `child` object changes, e.g. the property is removed or replaced.

---

Example of using ObserverView

```swift
import SwiftX

struct AppState {
    @Observable var counter = 0
}

var state = AppState() // Probably not how you should do it in real life :)

struct CounterView: View {
    var body: some View {
        VStack {
            ObserverView {
                Text("Tapped \(state.counter) times")
            }
            Button("Increment", ....)
            Button("Decrement", ....)
        }
    }
}
```
Now whenever the `state.counter` is increased, the view will get re-rendered. It could be updated from a background thread or the buttons specified above and it would still be re-rendered correctly.

---

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License
[MIT](https://choosealicense.com/licenses/mit/)