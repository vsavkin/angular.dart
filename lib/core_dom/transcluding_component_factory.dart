part of angular.core.dom_internal;

abstract class _ContentStrategy {
  void attach();
  void detach();
  void insert(Iterable<dom.Node> nodes);
}

/**
 * A null implementation of the content tag that is used by Shadow DOM components.
 * The distirbution is handled by the browser, so Angular does nothing.
 */
class _ShadowDomContent implements _ContentStrategy {
  void attach(){}
  void detach(){}
  void insert(Iterable<dom.Node> nodes){}
}

/**
 * An implementation of the content tag that is used by transcluding components.
 * It is used when the content tag is not a direct child of another component,
 * and thus does not affect redistirbution.
 */
class _RenderedTranscludingContent implements _ContentStrategy {
  final SourceLightDom _sourceLightDom;
  final Content _content;

  static final dom.ScriptElement _beginScriptTemplate =
      new dom.ScriptElement()..classes.add("start-content-tag");

  static final dom.ScriptElement _endScriptTemplate =
      new dom.ScriptElement()..classes.add("end-content-tag");

  dom.ScriptElement _beginScript;
  dom.ScriptElement _endScript;

  _RenderedTranscludingContent(this._content, this._sourceLightDom);

  void attach(){
    _replaceContentElementWithScriptTags();
    _sourceLightDom.redistribute();
  }

  void detach(){
    _removeScriptTags();
    _sourceLightDom.redistribute();
  }

  void insert(Iterable<dom.Node> nodes){
    final p = _endScript.parent;
    if (p != null) p.insertAllBefore(nodes, _endScript);
  }

  void _replaceContentElementWithScriptTags() {
    _beginScript = _beginScriptTemplate.clone(true);
    _endScript = _endScriptTemplate.clone(true);

    final el = _content.element;
    el.parent.insertBefore(_beginScript, el);
    el.parent.insertBefore(_endScript, el);
    el.remove();
  }

  void _removeScriptTags() {
    _removeNodesBetweenScriptTags();
    _beginScript.remove();
    _endScript.remove();
  }

  void _removeNodesBetweenScriptTags() {
    final p = _beginScript.parent;
    for (var next = _beginScript.nextNode;
        next.nodeType != dom.Node.ELEMENT_NODE || next.attributes["end-content-tag"] != null;
        next = _beginScript.nextNode) {
      p.nodes.remove(next);
    }
  }
}

class _IntermediateTranscludingContent implements _ContentStrategy {
  final SourceLightDom _sourceLightDom;
  final DestinationLightDom _destinationLightDom;
  final Content _content;

  dom.ScriptElement _beginScript;
  dom.ScriptElement _endScript;

  _IntermediateTranscludingContent(this._content, this._sourceLightDom, this._destinationLightDom);

  void attach(){
    _sourceLightDom.redistribute();
  }

  void detach(){
    _sourceLightDom.redistribute();
  }

  void insert(Iterable<dom.Node> nodes){
    _content.element.nodes = nodes;
    _destinationLightDom.redistribute();
  }
}

@Decorator(selector: 'content')
class Content implements AttachAware, DetachAware {
  dom.Element element;

  @NgAttr('select')
  String select;

  final SourceLightDom _sourceLightDom;
  final DestinationLightDom _destinationLightDom;
  var _strategy;

  Content(this.element, this._sourceLightDom, this._destinationLightDom, View view) {
    view.addContent(this);
  }

  void attach() => strategy.attach();
  void detach() => strategy.detach();
  void insert(Iterable<dom.Node> nodes) => strategy.insert(nodes);

  _ContentStrategy get strategy {
    if (_strategy == null) _strategy = _createContentStrategy();
    return _strategy;
  }

  _ContentStrategy _createContentStrategy() {
    if (_sourceLightDom == null) {
      return new _ShadowDomContent();
    } else if (_destinationLightDom != null && _destinationLightDom.hasRoot(element)) {
      return new _IntermediateTranscludingContent(this, _sourceLightDom, _destinationLightDom);
    } else {
      return new _RenderedTranscludingContent(this, _sourceLightDom);
    }
  }
}



@Injectable()
abstract class SourceLightDom {
  void redistribute();
  void addContent(Content c);
  void removeContent(Content c);
}

@Injectable()
abstract class DestinationLightDom {
  void redistribute();
  void addViewPort(ViewPort viewPort);
  bool hasRoot(dom.Element element);
}

class LightDom implements SourceLightDom, DestinationLightDom {
  final dom.Element _componentElement;

  final List<dom.Node> _lightDomRootNodes = [];
  final Map<dom.Comment, ViewPort> _ports = {};

  final Scope _scope;

  View _shadowDomView;

  LightDom(this._componentElement, this._scope);

  void pullNodes() {
    _lightDomRootNodes.addAll(_componentElement.nodes);

    // This is needed because _lightDomRootNodes can contains viewports,
    // which cannot be detached.
    final fakeRoot = new dom.DivElement();
    fakeRoot.nodes.addAll(_lightDomRootNodes);

    _componentElement.nodes = [];
  }

  set shadowDomView(View view) {
    this._shadowDomView = view;
    _componentElement.nodes = view.nodes;
  }

  void addViewPort(ViewPort viewPort) {
    _ports[viewPort.placeholder] = viewPort;
    redistribute();
  }

  //TODO: vsavkin Add dirty flag after implementing view-scoped dom writes.
  void redistribute() {
    _scope.rootScope.domWrite(() {
      redistributeNodes(_sortedContents, _expandedLightDomRootNodes);
    });
  }

  bool hasRoot(dom.Element element) =>
      _lightDomRootNodes.contains(element);

  List<Content> get _sortedContents {
    final res = [];
    _collectAllContentTags(_shadowDomView, res);
    return res;
  }

  void _collectAllContentTags(item, List<Content> acc) {
    if (item is Content) {
      acc.add(item);

    } else if (item is View) {
      for (final i in item.insertionPoints) {
        _collectAllContentTags(i, acc);
      }

    } else if (item is ViewPort) {
      for (final i in item.views) {
        _collectAllContentTags(i, acc);
      }
    }
  }

  List<dom.Node> get _expandedLightDomRootNodes {
    final list = [];
    for(final root in _lightDomRootNodes) {
      if (_ports.containsKey(root)) {
        list.addAll(_ports[root].nodes);
      } else if (root is dom.ContentElement) {
        list.addAll(root.nodes);
      } else {
        list.add(root);
      }
    }
    return list;
  }
}

void redistributeNodes(Iterable<Content> contents, List<dom.Node> nodes) {
  for (final content in contents) {
    final select = content.select;
    matchSelector(n) => n.nodeType == dom.Node.ELEMENT_NODE && n.matches(select);

    if (select == null) {
      content.insert(nodes);
      nodes.clear();
    } else {
      final matchingNodes = nodes.where(matchSelector);
      content.insert(matchingNodes);
      nodes.removeWhere(matchSelector);
    }
  }
}

@Injectable()
class TranscludingComponentFactory implements ComponentFactory {

  final Expando expando;
  final ViewCache viewCache;
  final CompilerConfig config;

  TranscludingComponentFactory(this.expando, this.viewCache, this.config);

  bind(DirectiveRef ref, directives) =>
      new BoundTranscludingComponentFactory(this, ref, directives);
}

class BoundTranscludingComponentFactory implements BoundComponentFactory {
  final TranscludingComponentFactory _f;
  final DirectiveRef _ref;
  final DirectiveMap _directives;

  Component get _component => _ref.annotation as Component;
  async.Future<ViewFactory> _viewFuture;

  BoundTranscludingComponentFactory(this._f, this._ref, this._directives) {
    _viewFuture = BoundComponentFactory._viewFuture(
        _component,
        _f.viewCache,
        _directives);
  }

  List<Key> get callArgs => _CALL_ARGS;
  static var _CALL_ARGS = [ DIRECTIVE_INJECTOR_KEY, SCOPE_KEY, VIEW_KEY,
                            VIEW_CACHE_KEY, HTTP_KEY, TEMPLATE_CACHE_KEY,
                            DIRECTIVE_MAP_KEY, NG_BASE_CSS_KEY, EVENT_HANDLER_KEY];
  Function call(dom.Node node) {
    // CSS is not supported.
    assert(_component.cssUrls == null ||
           _component.cssUrls.isEmpty);

    var element = node as dom.Element;
    return (DirectiveInjector injector, Scope scope, View view,
            ViewCache viewCache, Http http, TemplateCache templateCache,
            DirectiveMap directives, NgBaseCss baseCss, EventHandler eventHandler) {

      DirectiveInjector childInjector;
      var childInjectorCompleter; // Used if the ViewFuture is available before the childInjector.

      var component = _component;
      var lightDom = new LightDom(element, scope);

      // Append the component's template as children
      var elementFuture;

      if (_viewFuture != null) {
        elementFuture = _viewFuture.then((ViewFactory viewFactory) {
          lightDom.pullNodes();

          if (childInjector != null) {
            lightDom.shadowDomView = viewFactory.call(childInjector.scope, childInjector);
            return element;
          } else {
            childInjectorCompleter = new async.Completer();
            return childInjectorCompleter.future.then((childInjector) {
              lightDom.shadowDomView = viewFactory.call(childInjector.scope, childInjector);
              return element;
            });
          }
        });
      } else {
        elementFuture = new async.Future.microtask(() => lightDom.pullNodes());
      }
      TemplateLoader templateLoader = new TemplateLoader(elementFuture);

      Scope shadowScope = scope.createChild(new HashMap());

      childInjector = new TranscludingComponentDirectiveInjector(injector, injector.appInjector,
          eventHandler, shadowScope, view, templateLoader, new TransclusionBasedShadowRoot(element),
          lightDom);

      childInjector.bindByKey(_ref.typeKey, _ref.factory, _ref.paramKeys, _ref.annotation.visibility);

      if (childInjectorCompleter != null) {
        childInjectorCompleter.complete(childInjector);
      }

      var controller = childInjector.getByKey(_ref.typeKey);
      shadowScope.context[component.publishAs] = controller;
      BoundComponentFactory._setupOnShadowDomAttach(controller, templateLoader, shadowScope);
      return controller;
    };
  }
}
