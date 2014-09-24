part of angular.core.dom_internal;

@Injectable()
class TranscludingComponentFactory implements ComponentFactory {

  final Expando expando;
  final ViewCache viewCache;
  final CompilerConfig config;
  final DefaultPlatformShim platformShim;
  final TypeToUriMapper uriMapper;
  final ResourceUrlResolver resourceResolver;
  ComponentCssLoader cssLoader;

  TranscludingComponentFactory(this.expando, this.viewCache, this.config, this.platformShim,
      this.uriMapper, this.resourceResolver, Http http, TemplateCache templateCache,
      ComponentCssRewriter componentCssRewriter, dom.NodeTreeSanitizer treeSanitizer,
      CacheRegister cacheRegister) {
    final styleElementCache = new HashMap();
    cacheRegister.registerCache("TranscludingComponentFactoryStyles", styleElementCache);

    cssLoader = new ComponentCssLoader(http, templateCache, platformShim,
        componentCssRewriter, treeSanitizer, styleElementCache, resourceResolver);
  }

  bind(DirectiveRef ref, directives, injector) =>
      new BoundTranscludingComponentFactory(this, ref, directives, injector);
}

class BoundTranscludingComponentFactory implements BoundComponentFactory {
  final TranscludingComponentFactory _f;
  final DirectiveRef _ref;
  final DirectiveMap _directives;
  final Injector _injector;

  String _tag;
  async.Future<Iterable<dom.StyleElement>> _styleElementsFuture;
  List<dom.StyleElement> _styleElements;

  Component get _component => _ref.annotation as Component;
  async.Future<ViewFactory> _viewFactoryFuture;
  ViewFactory _viewFactory;

  BoundTranscludingComponentFactory(this._f, this._ref, this._directives, this._injector) {
    _tag = _ref.annotation.selector.toLowerCase();
    _styleElementsFuture = _f.cssLoader(_tag, _component.cssUrls, type: _ref.type)
        .then((styleElements) => _styleElements = styleElements);

    final viewCache = new ShimmingViewCache(_f.viewCache, _tag, _f.platformShim);

    _viewFactoryFuture = BoundComponentFactory._viewFactoryFuture(
        _component,
        viewCache,
        _directives,
        _f.uriMapper,
        _f.resourceResolver,
        _ref.type);

    if (_viewFactoryFuture != null) {
      _viewFactoryFuture.then((viewFactory) => _viewFactory = viewFactory);
    }
  }

  List<Key> get callArgs => _CALL_ARGS;
  static var _CALL_ARGS = [ DIRECTIVE_INJECTOR_KEY, SCOPE_KEY, VIEW_KEY,
                            VIEW_CACHE_KEY, HTTP_KEY, TEMPLATE_CACHE_KEY,
                            DIRECTIVE_MAP_KEY, NG_BASE_CSS_KEY, EVENT_HANDLER_KEY,
                            SHADOW_BOUNDARY_KEY];

  Function call(dom.Node node) {
    var element = node as dom.Element;
    return (DirectiveInjector injector, Scope scope, View view,
            ViewCache viewCache, Http http, TemplateCache templateCache,
            DirectiveMap directives, NgBaseCss baseCss, EventHandler eventHandler,
            ShadowBoundary shadowBoundary) {

      final shadowRoot = new EmulatedShadowRoot(element);
      final lightDom = new LightDom(element, scope)..pullNodes();

      final shadowScope = scope.createChild(new HashMap());
      List<async.Future> futures = <async.Future>[];
      TemplateLoader templateLoader = new TemplateLoader(shadowRoot, futures);

      final childInjector = new ComponentDirectiveInjector(injector, this._injector,
          eventHandler, shadowScope, templateLoader, shadowRoot, lightDom, view);

      if (_component.useNgBaseCss && baseCss.urls.isNotEmpty) {
        if (baseCss.styles == null) {
          final f = _f.cssLoader(_tag, baseCss.urls).then((cssList) {
            baseCss.styles = cssList;
            shadowBoundary.insertStyleElements(cssList);
          });
          futures.add(f);
        } else {
          shadowBoundary.insertStyleElements(baseCss.styles);
        }
      }

      if (_styleElementsFuture != null) {
        if (_styleElements == null) {
          final f = _styleElementsFuture.then(shadowBoundary.insertStyleElements);
          futures.add(f);
        } else {
          shadowBoundary.insertStyleElements(_styleElements);
        }
      }

      if (_viewFactoryFuture != null) {
        if (_viewFactory == null) {
          final f = _viewFactoryFuture.then((ViewFactory viewFactory) {
            lightDom.clearComponentElement();;
            lightDom.shadowDomView = viewFactory.call(childInjector.scope, childInjector);
          });
          futures.add(f);
        } else {
          lightDom.clearComponentElement();;
          lightDom.shadowDomView = _viewFactory.call(childInjector.scope, childInjector);
        }
      }

      childInjector.bindByKey(_ref.typeKey, _ref.factory, _ref.paramKeys, _ref.annotation.visibility);
      var controller = childInjector.getByKey(_ref.typeKey);
      shadowScope.context[_component.publishAs] = controller;
      BoundComponentFactory._setupOnShadowDomAttach(controller, templateLoader, shadowScope);

      return controller;
    };
  }
}
