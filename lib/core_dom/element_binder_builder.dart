part of angular.core.dom_internal;

@Injectable()
class ElementBinderFactory {
  final Parser _parser;
  final Profiler _perf;
  final Expando _expando;
  final ComponentFactory _componentFactory;
  final TranscludingComponentFactory _transcludingComponentFactory;
  final ShadowDomComponentFactory _shadowDomComponentFactory;
  final ASTParser _astParser;

  ElementBinderFactory(this._parser, this._perf, this._expando, this._componentFactory,
      this._transcludingComponentFactory, this._shadowDomComponentFactory,
      this._astParser);

  // TODO: Optimize this to re-use a builder.
  ElementBinderBuilder builder(FormatterMap formatters) =>
    new ElementBinderBuilder(this, _astParser, formatters);

  ElementBinder binder(ElementBinderBuilder b) =>
      new ElementBinder(_perf, _expando, _parser, _componentFactory,
          _transcludingComponentFactory, _shadowDomComponentFactory,
          b.component, b.decorators, b.onEvents, b.bindAttrs, b.childMode);

  TemplateElementBinder templateBinder(ElementBinderBuilder b, ElementBinder transclude) =>
      new TemplateElementBinder(_perf, _expando, _parser, _componentFactory,
          _transcludingComponentFactory, _shadowDomComponentFactory,
          b.template, transclude, b.onEvents, b.bindAttrs, b.childMode);
}

/**
 * ElementBinderBuilder is an internal class for the Selector which is responsible for
 * building ElementBinders.
 */
class ElementBinderBuilder {
  static final RegExp _MAPPING = new RegExp(r'^(@|=>!|=>|<=>|&)\s*(.*)$');

  ElementBinderFactory _factory;
  ASTParser _astParser;
  FormatterMap _formatters;

  /// "on-*" attribute names and values, added by a [DirectiveSelector]
  final onEvents = <String, String>{};
  /// "bind-*" attribute names and values, added by a [DirectiveSelector]
  final bindAttrs = <String, AST>{};

  final decorators = <DirectiveRef>[];
  DirectiveRef template;
  DirectiveRef component;

  // Can be either COMPILE_CHILDREN or IGNORE_CHILDREN
  String childMode = Directive.COMPILE_CHILDREN;

  ElementBinderBuilder(this._factory, this._astParser, this._formatters);

  /**
   * Adds [DirectiveRef]s to this [ElementBinderBuilder].
   *
   * [addDirective] gets called from [Selector.matchElement] for each directive triggered by the
   * element.
   *
   * When the [Directive] annotation defines a `map`, the attribute mappings are added to the
   * [DirectiveRef].
   */
  addDirective(DirectiveRef ref) {
    var annotation = ref.annotation;
    var children = annotation.children;

    if (annotation.children == Directive.TRANSCLUDE_CHILDREN) {
      template = ref;
    } else if (annotation is Component) {
      component = ref;
    } else {
      decorators.add(ref);
    }

    if (annotation.children == Directive.IGNORE_CHILDREN) {
      childMode = annotation.children;
    }

    if (annotation.map != null) {
      annotation.map.forEach((attrName, mapping) {
        Match match = _MAPPING.firstMatch(mapping);
        if (match == null) {
          throw "Unknown mapping '$mapping' for attribute '$attrName'.";
        }
        var mode = match[1];
        var dstPath = match[2];

        String dstExpression = dstPath.isEmpty ? attrName : dstPath;
        AST dstAST = _astParser(dstExpression); // no formatters

        // Look up the value of attrName and compute an AST
        AST ast;
        if (mode != '@' && mode != '&') {
          var value = attrName == "." ? ref.value : (ref.element as dom.Element).attributes[attrName];
          if (value == null || value.isEmpty) { value = "''"; }
          ast = _astParser(value, formatters: _formatters);
        }

        ref.mappings.add(new MappingParts(attrName, ast, mode, dstAST, mapping));
      });
    }
  }

  /// Creates an returns an [ElementBinder] or a [TemplateElementBinder]
  ElementBinder get binder {
    var elBinder = _factory.binder(this);
    return template == null ? elBinder : _factory.templateBinder(this, elBinder);
  }
}
