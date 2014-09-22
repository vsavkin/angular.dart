library angular.util;

import 'dart:collection';
import 'dart:async';

bool toBool(x) {
  if (x is bool) return x;
  if (x is num) return x != 0;
  return false;
}

typedef FnWith0Args();
typedef FnWith1Args(a0);
typedef FnWith2Args(a0, a1);
typedef FnWith3Args(a0, a1, a2);
typedef FnWith4Args(a0, a1, a2, a3);
typedef FnWith5Args(a0, a1, a2, a3, a4);

relaxFnApply(Function fn, List args) {
// Check the args.length to support functions with optional parameters.
  var argsLen = args.length;
  if (fn is Function && fn != null) {
    if (fn is FnWith5Args && argsLen > 4) {
      return fn(args[0], args[1], args[2], args[3], args[4]);
    } else if (fn is FnWith4Args && argsLen > 3) {
      return fn(args[0], args[1], args[2], args[3]);
    } else if (fn is FnWith3Args && argsLen > 2 ) {
      return fn(args[0], args[1], args[2]);
    } else if (fn is FnWith2Args && argsLen > 1 ) {
      return fn(args[0], args[1]);
    } else if (fn is FnWith1Args && argsLen > 0) {
      return fn(args[0]);
    } else if (fn is FnWith0Args) {
      return fn();
    } else {
      throw "Unknown function type, expecting 0 to 5 args.";
    }
  } else {
    throw "Missing function.";
  }
}

relaxFnArgs1(Function fn) {
  if (fn is FnWith3Args) return (_1) => fn(_1, null, null);
  if (fn is FnWith2Args) return (_1) => fn(_1, null);
  if (fn is FnWith1Args) return fn;
  if (fn is FnWith0Args) return (_1) => fn();
}

relaxFnArgs2(Function fn) {
  if (fn is FnWith2Args) return fn;
  if (fn is FnWith1Args) return (_1, _2) => fn(_1);
  if (fn is FnWith0Args) return (_1, _2) => fn();
}

relaxFnArgs3(Function fn) {
  if (fn is FnWith3Args) return fn;
  if (fn is FnWith2Args) return (_1, _2, _3) => fn(_1, null);
  if (fn is FnWith1Args) return (_1, _2, _3) => fn(_1);
  if (fn is FnWith0Args) return (_1, _2, _3) => fn();
}

relaxFnArgs(Function fn) {
  if (fn is FnWith5Args) {
    return ([a0, a1, a2, a3, a4]) => fn(a0, a1, a2, a3, a4);
  } else if (fn is FnWith4Args) {
    return ([a0, a1, a2, a3, a4]) => fn(a0, a1, a2, a3);
  } else if (fn is FnWith3Args) {
    return ([a0, a1, a2, a3, a4]) => fn(a0, a1, a2);
  } else if (fn is FnWith2Args) {
    return ([a0, a1, a2, a3, a4]) => fn(a0, a1);
  } else if (fn is FnWith1Args) {
    return ([a0, a1, a2, a3, a4]) => fn(a0);
  } else if (fn is FnWith0Args) {
    return ([a0, a1, a2, a3, a4]) => fn();
  } else {
    return ([a0, a1, a2, a3, a4]) {
      throw "Unknown function type, expecting 0 to 5 args.";
    };
  }
}

capitalize(String s) => s.substring(0, 1).toUpperCase() + s.substring(1);

String camelCase(String s) {
  var part = s.split('-').map((s) => s.toLowerCase());
  if (part.length <= 1) return part.join();
  return part.first + part.skip(1).map(capitalize).join();
}

/// Returns whether or not the given identifier is a reserved word in Dart.
bool isReservedWord(String identifier) => RESERVED_WORDS.contains(identifier);

final Set<String> RESERVED_WORDS = new Set<String>.from(const [
  "assert",
  "break",
  "case",
  "catch",
  "class",
  "const",
  "continue",
  "default",
  "do",
  "else",
  "enum",
  "extends",
  "false",
  "final",
  "finally",
  "for",
  "if",
  "in",
  "is",
  "new",
  "null",
  "rethrow",
  "return",
  "super",
  "switch",
  "this",
  "throw",
  "true",
  "try",
  "var",
  "void",
  "while",
  "with"
]);

/// Returns true iff o is [double.NAN].
/// In particular, returns false if o is null.
bool isNaN(Object o) => o is num && o.isNaN;

/// Returns true iff o1 == o2 or both are [double.NAN].
bool eqOrNaN(Object o1, Object o2) => o1 == o2 || (isNaN(o1) && isNaN(o2));

/// Merges two futures of iterables into one.
Future<Iterable> mergeFutures(Future<Iterable> f1, Future<Iterable> f2) {
  return Future.wait([f1, f2]).then((twoLists) {
    assert(twoLists.length == 2);
    return []..addAll(twoLists[0])..addAll(twoLists[1]);
  });
}

class LinkedListEntryGroup<T extends LinkedListEntry<T>> {
  LinkedListEntry<T> _first, _last;

  void add(LinkedListEntry<T> e) {
    if (_first == null) _first = e;
    _last = e;
  }

  void unlink() {
    if (_first == null) return;

    var curr = _first;
    while (true) {
      final next = curr.next;

      curr.unlink();

      if (curr == _last) return;
      curr = next;
    }
  }

  bool get isEmpty => _first == null;

  void moveAfter(LinkedListEntryGroup<T> group) {
    if (isEmpty) return;

    if (group == null) {
      _prepend();
    } else {
      _insertAfter(group);
    }
  }

  LinkedList<T> get _list => _first.list;

  void _prepend() {
    var curr = _last;
    var insertionPoint = _list.first;
    while (insertionPoint != _first) {
      final prev = curr.previous;

      curr.unlink();
      insertionPoint.insertBefore(curr);

      insertionPoint = curr;
      curr = prev;
    }
  }

  void _insertAfter(LinkedListEntryGroup<T> group) {
    var insertionPoint = group._last;
    if (insertionPoint.next == _first) return;
    var curr = _first;

    while (insertionPoint != _last) {
      final next = curr.next;

      curr.unlink();
      insertionPoint.insertAfter(curr);

      insertionPoint = curr;
      curr = next;
    }
  }

  void forEach(Function fn) {
    if (isEmpty) return;

    var curr = _first;
    while (true) {
      fn(curr);
      if (curr == _last) return;
      curr = curr.next;
    }
  }
}
