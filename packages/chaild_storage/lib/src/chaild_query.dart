import 'dart:async';

/// A chainable, lazy query over a [ChaildCollection].
///
/// Implements [Future] so you can await it directly.
///
/// Example:
///   final results = await notes
///     .where('archived', isEqualTo: false)
///     .andGroup((q) => q
///       .where('pinned', isEqualTo: true)
///       .or('score', isGreaterThan: 100));
class ChaildQuery implements Future<List<Map<String, dynamic>>> {
  ChaildQuery(this._source) : _conditions = [];

  ChaildQuery._clone(this._source, List<_Condition> conditions)
      : _conditions = List.of(conditions);

  final List<Map<String, dynamic>> Function() _source;
  final List<_Condition> _conditions;

  // ─── Filter builders ──────────────────────────────────────────────────────

  ChaildQuery where(
    String field, {
    dynamic isEqualTo,
    dynamic isGreaterThan,
    dynamic isLessThan,
    String? contains,
  }) {
    return _append(_LeafCondition(
      field: field,
      isEqualTo: isEqualTo,
      isGreaterThan: isGreaterThan,
      isLessThan: isLessThan,
      contains: contains,
      connector: _Connector.and,
    ));
  }

  /// Add an AND condition.
  ChaildQuery and(
    String field, {
    dynamic isEqualTo,
    dynamic isGreaterThan,
    dynamic isLessThan,
    String? contains,
  }) {
    return _append(_LeafCondition(
      field: field,
      isEqualTo: isEqualTo,
      isGreaterThan: isGreaterThan,
      isLessThan: isLessThan,
      contains: contains,
      connector: _Connector.and,
    ));
  }

  /// Add an OR condition.
  ChaildQuery or(
    String field, {
    dynamic isEqualTo,
    dynamic isGreaterThan,
    dynamic isLessThan,
    String? contains,
  }) {
    return _append(_LeafCondition(
      field: field,
      isEqualTo: isEqualTo,
      isGreaterThan: isGreaterThan,
      isLessThan: isLessThan,
      contains: contains,
      connector: _Connector.or,
    ));
  }

  /// Add a grouped AND sub-query.
  ChaildQuery andGroup(ChaildQuery Function(ChaildQuery) builder) {
    final sub = builder(ChaildQuery(_source));
    return _append(_GroupCondition(sub._conditions, _Connector.and));
  }

  /// Add a grouped OR sub-query.
  ChaildQuery orGroup(ChaildQuery Function(ChaildQuery) builder) {
    final sub = builder(ChaildQuery(_source));
    return _append(_GroupCondition(sub._conditions, _Connector.or));
  }

  ChaildQuery _append(_Condition c) =>
      ChaildQuery._clone(_source, [..._conditions, c]);

  // ─── Execution ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _execute() {
    final items = _source();
    return items.where((item) => _evalAll(_conditions, item)).toList();
  }

  static bool _evalAll(List<_Condition> conds, Map<String, dynamic> item) {
    if (conds.isEmpty) return true;
    bool result = conds.first.eval(item);
    for (var i = 1; i < conds.length; i++) {
      final c = conds[i];
      if (c.connector == _Connector.and) {
        result = result && c.eval(item);
      } else {
        result = result || c.eval(item);
      }
    }
    return result;
  }

  // ─── Future<> implementation ──────────────────────────────────────────────

  @override
  Stream<List<Map<String, dynamic>>> asStream() =>
      Stream.fromFuture(Future.value(_execute()));

  @override
  Future<List<Map<String, dynamic>>> catchError(Function onError,
          {bool Function(Object error)? test}) =>
      Future.value(_execute()).catchError(onError, test: test);

  @override
  Future<R> then<R>(FutureOr<R> Function(List<Map<String, dynamic>> value) onValue,
          {Function? onError}) =>
      Future.value(_execute()).then(onValue, onError: onError);

  @override
  Future<List<Map<String, dynamic>>> timeout(Duration timeLimit,
          {FutureOr<List<Map<String, dynamic>>> Function()? onTimeout}) =>
      Future.value(_execute()).timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<List<Map<String, dynamic>>> whenComplete(FutureOr<void> Function() action) =>
      Future.value(_execute()).whenComplete(action);
}

// ─── Internal types ───────────────────────────────────────────────────────────

enum _Connector { and, or }

abstract class _Condition {
  _Connector get connector;
  bool eval(Map<String, dynamic> item);
}

class _LeafCondition implements _Condition {
  _LeafCondition({
    required this.field,
    this.isEqualTo,
    this.isGreaterThan,
    this.isLessThan,
    this.contains,
    required this.connector,
  });

  final String field;
  final dynamic isEqualTo;
  final dynamic isGreaterThan;
  final dynamic isLessThan;
  final String? contains;
  @override
  final _Connector connector;

  @override
  bool eval(Map<String, dynamic> item) {
    final v = item[field];
    if (isEqualTo != null && v != isEqualTo) return false;
    if (isGreaterThan != null && (v is! num || v <= isGreaterThan)) return false;
    if (isLessThan != null && (v is! num || v >= isLessThan)) return false;
    if (contains != null &&
        (v is! String || !v.toLowerCase().contains(contains!.toLowerCase()))) {
      return false;
    }
    return true;
  }
}

class _GroupCondition implements _Condition {
  _GroupCondition(this.children, this.connector);
  final List<_Condition> children;
  @override
  final _Connector connector;

  @override
  bool eval(Map<String, dynamic> item) =>
      ChaildQuery._evalAll(children, item);
}


