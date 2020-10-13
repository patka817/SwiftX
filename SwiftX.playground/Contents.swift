import SwiftX


class Node<V> {
    @Observable var left: Node<V>?
    @Observable var right: Node<V>?
    @Observable var value: V?

    init(_ value: V) {
        self.value = value
    }

    init() { }
}

let master = Node("Test")
master.left = Node()

