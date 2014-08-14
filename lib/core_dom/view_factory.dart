part of angular.core.dom_internal;


/**
 * BoundViewFactory is a [ViewFactory] which does not need Injector because
 * it is pre-bound to an injector from the parent. This means that this
 * BoundViewFactory can only be used from within a specific Directive such
 * as [NgRepeat], but it can not be stored in a cache.
 *
 * The BoundViewFactory needs [Scope] to be created.
 */
@deprecated
class BoundViewFactory {
  ViewFactory viewFactory;
  DirectiveInjector directiveInjector;

  BoundViewFactory(this.viewFactory, this.directiveInjector);

  View call(Scope scope) => viewFactory(scope, directiveInjector);
}

class ViewFactory implements Function {
  final List<TaggedElementBinder> elementBinders;
  final List<dom.Node> templateNodes;
  final List<NodeLinkingInfo> nodeLinkingInfos;
  final Profiler _perf;
  String _debugHtml;

  ViewFactory(templateNodes, this.elementBinders, this._perf) :
      nodeLinkingInfos = computeNodeLinkingInfos(templateNodes),
      templateNodes = templateNodes
  {
    if (traceEnabled) {
      _debugHtml = templateNodes.map((dom.Node e) {
        if (e is dom.Element) {
          return (e as dom.Element).outerHtml;
        } else if (e is dom.Comment) {
          return '<!--${(e as dom.Comment).text}-->';
        } else {
          return e.text;
        }
      }).toList().join('');
    }
  }

  @deprecated
  BoundViewFactory bind(DirectiveInjector directiveInjector) =>
      new BoundViewFactory(this, directiveInjector);

  static Key _EVENT_HANDLER_KEY = new Key(EventHandler);

  View call(Scope scope, DirectiveInjector directiveInjector,
            [List<dom.Node> nodes /* TODO: document fragment */]) {
    var s = traceEnter1(View_create, _debugHtml);
    assert(scope != null);
    if (nodes == null) {
      nodes = cloneElements(templateNodes);
    }
    var view = new _ViewFactoryCall(this, scope, directiveInjector).createView(nodes);
    traceLeave(s);
    return view;
  }
}

class _ViewFactoryCall {
  final ViewFactory factory;
  final Scope scope;
  final DirectiveInjector rootInjector;
  final List<DirectiveInjector> elementInjectors;
  final _Hydrator hydrator = new _Hydrator();

  _ViewFactoryCall(ViewFactory factory, this.scope, this.rootInjector)
      : factory = factory,
      elementInjectors = new List<DirectiveInjector>(factory.elementBinders.length);

  View createView(List<dom.Node> nodeList) {
    final view = new View(nodeList, scope);

    var elementBinderIndex = 0;
    for (int i = 0; i < nodeList.length; i++) {
      final node = nodeList[i];
      final linkingInfo = factory.nodeLinkingInfos[i];

      if (linkingInfo.containsNgBinding) {
        bindTagged(elementBinderIndex, node, view);
        elementBinderIndex++;
      }

      if (linkingInfo.ngBindingChildren) {
        var elts = (node as dom.Element).querySelectorAll('.ng-binding');
        elts.forEach((el) {
          bindTagged(elementBinderIndex, el, view);
          elementBinderIndex++;
        });
      }

      if (!linkingInfo.isElement) {
        bindTagged(elementBinderIndex, node, view);
        elementBinderIndex++;
      }
    }

    hydrator.hydrate();
    return view;
  }

  void bindTagged(int elementBinderIndex, dom.Node node, View view) {
    final tagged = factory.elementBinders[elementBinderIndex];
    final binder = tagged.binder;
    final parentInjector = parentInjectorFor(tagged);

    final scopeForElement = scopeFor(parentInjector);
    final elementInjector = bindElement(binder, view, scopeForElement, node, parentInjector);
    elementInjectors[elementBinderIndex] = elementInjector;

    final scopeForTextNodes = scopeFor(elementInjector, parentInjector);
    bindTextNodes(tagged, node, view, scopeForTextNodes, elementInjector);
  }

  DirectiveInjector parentInjectorFor(TaggedElementBinder tagged) =>
      tagged.parentBinderOffset == -1 ? rootInjector : elementInjectors[tagged.parentBinderOffset];

  DirectiveInjector bindElement(ElementBinder binder, View view, Scope scope, dom.Node node,
      DirectiveInjector parentInjector) {
    if (binder == null || !binder.hasDirectivesOrEvents) return parentInjector;
    final injector = binder.setUp(view, scope, parentInjector, node);
    hydrator.addEntry(binder, injector);
    return injector;
  }

  void bindTextNodes(TaggedElementBinder tagged, dom.Node node, View view, Scope scope,
      DirectiveInjector parentInjector) {
    if (tagged.textBinders == null || tagged.textBinders.isEmpty) return;
    tagged.textBinders.forEach((textBinder) {
      bindTextNode(textBinder, node, view, scope, parentInjector);
    });
  }

  void bindTextNode(TaggedTextBinder tagged, dom.Node parentNode, View view, Scope scope,
      DirectiveInjector parentInjector) {
    final binder = tagged.binder;
    if (binder.hasDirectivesOrEvents) {
      final childNode = parentNode.childNodes[tagged.offsetIndex];
      final injector = binder.setUp(view, scope, parentInjector, childNode);
      hydrator.addEntry(binder, injector);
    }
  }

  // TODO(misko): Remove this after we remove controllers. No controllers -> 1to1 Scope:View.
  Scope scopeFor(DirectiveInjector parent, [DirectiveInjector element]) {
    if (element != rootInjector && element != null && element.scope != null) {
      return element.scope;
    } else if (parent != rootInjector && parent != null && parent.scope != null) {
      return parent.scope;
    } else {
      return scope;
    }
  }
}

class _Hydrator extends LinkedList<_HydratorEntry> {
  void hydrate() {
    forEach((entry) => entry.hydrate());
  }

  void addEntry(ElementBinder binder, DirectiveInjector injector) {
    add(new _HydratorEntry(binder, injector));
  }
}

class _HydratorEntry extends LinkedListEntry<_HydratorEntry> {
  final ElementBinder binder;
  final DirectiveInjector directiveInjector;
  _HydratorEntry(this.binder, this.directiveInjector);

  void hydrate() {
    binder.hydrate(directiveInjector, directiveInjector.scope);
  }
}

class NodeLinkingInfo {
  /**
   * True if the Node has a 'ng-binding' class.
   */
  final bool containsNgBinding;

  /**
   * True if the Node is a [dom.Element], otherwise it is a Text or Comment node.
   * No other nodeTypes are allowed.
   */
  final bool isElement;

  /**
   * If true, some child has a 'ng-binding' class and the ViewFactory must search
   * for these children.
   */
  final bool ngBindingChildren;

  NodeLinkingInfo(this.containsNgBinding, this.isElement, this.ngBindingChildren);
}

computeNodeLinkingInfos(List<dom.Node> nodeList) {
  List<NodeLinkingInfo> list = new List<NodeLinkingInfo>(nodeList.length);

  for (int i = 0; i < nodeList.length; i++) {
    dom.Node node = nodeList[i];

    assert(node.nodeType == dom.Node.ELEMENT_NODE ||
    node.nodeType == dom.Node.TEXT_NODE ||
    node.nodeType == dom.Node.COMMENT_NODE);

    bool isElement = node.nodeType == dom.Node.ELEMENT_NODE;

    list[i] = new NodeLinkingInfo(
        isElement && (node as dom.Element).classes.contains('ng-binding'),
        isElement,
        isElement && (node as dom.Element).querySelectorAll('.ng-binding').length > 0);
  }
  return list;
}


/**
 * ViewCache is used to cache the compilation of templates into [View]s.
 * It can be used synchronously if HTML is known or asynchronously if the
 * template HTML needs to be looked up from the URL.
 */
@Injectable()
class ViewCache {
  // viewFactoryCache is unbounded
  // This cache contains both HTML and URL keys.
  final viewFactoryCache = new LruCache<String, ViewFactory>();
  final Http http;
  final TemplateCache templateCache;
  final Compiler compiler;
  final dom.NodeTreeSanitizer treeSanitizer;

  ViewCache(this.http, this.templateCache, this.compiler, this.treeSanitizer, CacheRegister cacheRegister) {
    cacheRegister.registerCache('ViewCache', viewFactoryCache);
  }

  ViewFactory fromHtml(String html, DirectiveMap directives) {
    ViewFactory viewFactory = viewFactoryCache.get(html);
    if (viewFactory == null) {
      var div = new dom.DivElement();
      div.setInnerHtml(html, treeSanitizer: treeSanitizer);
      viewFactory = compiler(div.nodes, directives);
      viewFactoryCache.put(html, viewFactory);
    }
    return viewFactory;
  }

  async.Future<ViewFactory> fromUrl(String url, DirectiveMap directives) {
    ViewFactory viewFactory = viewFactoryCache.get(url);
    if (viewFactory == null) {
      return http.get(url, cache: templateCache).then((resp) {
        var viewFactoryFromHttp = fromHtml(resp.responseText, directives);
        viewFactoryCache.put(url, viewFactoryFromHttp);
        return viewFactoryFromHttp;
      });
    }
    return new async.Future.value(viewFactory);
  }
}

class _AnchorAttrs extends NodeAttrs {
  DirectiveRef _directiveRef;

  _AnchorAttrs(DirectiveRef this._directiveRef): super(null);

  String operator [](name) => name == '.' ? _directiveRef.value : null;

  void observe(String attributeName, _AttributeChanged notifyFn) {
    notifyFn(attributeName == '.' ? _directiveRef.value : null);
  }
}

String _html(obj) {
  if (obj is String) {
    return obj;
  }
  if (obj is List) {
    return (obj as List).map((e) => _html(e)).join();
  }
  if (obj is dom.Element) {
    var text = (obj as dom.Element).outerHtml;
    return text.substring(0, text.indexOf('>') + 1);
  }
  return obj.nodeName;
}

/**
 * [ElementProbe] is attached to each [Element] in the DOM. Its sole purpose is
 * to allow access to the [Injector], [Scope], and Directives for debugging and
 * automated test purposes. The information here is not used by Angular in any
 * way.
 *
 * see: [ngInjector], [ngScope], [ngDirectives]
 */
class ElementProbe {
  final ElementProbe parent;
  final dom.Node element;
  final DirectiveInjector injector;
  final Scope scope;
  List get directives => injector.directives;
  final bindingExpressions = <String>[];
  final modelExpressions = <String>[];

  ElementProbe(this.parent, this.element, this.injector, this.scope);

  dynamic directive(Type type) => injector.get(type);
}
