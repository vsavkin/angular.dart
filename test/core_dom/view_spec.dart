library view_spec;

import '../_specs.dart';
import 'package:angular/application_factory.dart';

class Log {
  List<String> log = <String>[];

  add(String msg) => log.add(msg);
}

@Decorator(children: Directive.TRANSCLUDE_CHILDREN, selector: 'foo')
class LoggerViewDirective {
  LoggerViewDirective(ViewPort port, ViewFactory viewFactory,
      BoundViewFactory boundViewFactory, Logger logger) {
    assert(port != null);
    assert(viewFactory != null);
    assert(boundViewFactory != null);

    logger.add(port);
    logger.add(boundViewFactory);
    logger.add(viewFactory);
  }
}

@Decorator(selector: 'dir-a')
class ADirective {
  ADirective(Log log) {
    log.add('ADirective');
  }
}

@Decorator(selector: 'dir-b')
class BDirective {
  BDirective(Log log) {
    log.add('BDirective');
  }
}

@Formatter(name:'formatterA')
class AFormatter {
  Log log;

  AFormatter(this.log) {
    log.add('AFormatter');
  }

  call(value) => value;
}

@Formatter(name:'formatterB')
class BFormatter {
  Log log;

  BFormatter(this.log) {
    log.add('BFormatter');
  }

  call(value) => value;
}

class MockLightDom extends Mock implements DestinationLightDom {}

main() {
  var viewFactoryFactory = (a,b,c,d) => new WalkingViewFactory(a,b,c,d);
  describe('View', () {
    Element rootElement;

    var expando = new Expando();
    View a, b;
    var viewCache;

    ViewPort createViewPort({injector, lightDom}) {
      final scope = injector.get(Scope);
      final parentView = new View([], scope, null);

      return new ViewPort(injector.get(DirectiveInjector), scope, parentView,
          rootElement.childNodes[0], injector.get(Animate), lightDom);
    }

    beforeEach((Profiler perf, Injector injector) {
      rootElement = e('<div></div>');
      rootElement.innerHtml = '<!-- anchor -->';

      var scope = injector.get(Scope);
      a = (viewFactoryFactory(es('<span>A</span>a'), [], perf, expando))(scope, injector.get(DirectiveInjector));
      b = (viewFactoryFactory(es('<span>B</span>b'), [], perf, expando))(scope, injector.get(DirectiveInjector));
    });

    describe('mutation', () {
      ViewPort viewPort;

      beforeEach((Injector injector) {
        viewPort = createViewPort(injector: injector);
      });


      describe('insertAfter', () {
        it('should insert block after anchor view', (RootScope scope) {
          viewPort.insert(a);
          scope.flush();

          expect(rootElement).toHaveHtml('<!-- anchor --><span>A</span>a');
        });


        it('should insert multi element view after another multi element view', (RootScope scope) {
          viewPort.insert(a);
          viewPort.insert(b, insertAfter: a);
          scope.flush();

          expect(rootElement).toHaveHtml('<!-- anchor --><span>A</span>a<span>B</span>b');
        });


        it('should insert multi element view before another multi element view', (RootScope scope) {
          viewPort.insert(b);
          viewPort.insert(a);
          scope.flush();

          expect(rootElement).toHaveHtml('<!-- anchor --><span>A</span>a<span>B</span>b');
        });
      });


      describe('remove', () {
        beforeEach((RootScope scope) {
          viewPort.insert(a);
          viewPort.insert(b, insertAfter: a);
          scope.flush();

          expect(rootElement.text).toEqual('AaBb');
        });

        it('should remove the last view', (RootScope scope) {
          viewPort.remove(b);
          scope.flush();
          expect(rootElement).toHaveHtml('<!-- anchor --><span>A</span>a');
        });

        it('should remove child views from parent pseudo black', (RootScope scope) {
          viewPort.remove(a);
          scope.flush();
          expect(rootElement).toHaveHtml('<!-- anchor --><span>B</span>b');
        });

        // TODO(deboer): Make this work again.
        /*
        xit('should remove', (Logger logger, Injector injector, Profiler perf, ElementBinderFactory ebf) {
          anchor.remove(a);
          anchor.remove(b);

          // TODO(dart): I really want to do this:
          // class Directive {
          //   Directive(ViewPort $anchor, Logger logger) {
          //     logger.add($anchor);
          //   }
          // }

          var directiveRef = new DirectiveRef(null,
                                              LoggerViewDirective,
                                              new Decorator(children: Directive.TRANSCLUDE_CHILDREN, selector: 'foo'),
                                              '');
          directiveRef.viewFactory = viewFactoryFactory($('<b>text</b>'), [], perf, new Expando());
          var binder = ebf.binder();
          binder.setTemplateInfo(0, [ directiveRef ]);
          var outerViewType = viewFactoryFactory(
              $('<!--start--><!--end-->'),
              [binder],
              perf,
              new Expando());

          var outerView = outerViewType(injector);
          // The LoggerViewDirective caused a ViewPort for innerViewType to
          // be created at logger[0];
          ViewPort outerAnchor = logger[0];
          BoundViewFactory outterBoundViewFactory = logger[1];

          anchor.insert(outerView);
          // outterAnchor is a ViewPort, but it has "elements" set to the 0th element
          // of outerViewType.  So, calling insertAfter() will insert the new
          // view after the <!--start--> element.
          outerAnchor.insert(outterBoundViewFactory(null));

          expect(rootElement.text).toEqual('text');

          anchor.remove(outerView);

          expect(rootElement.text).toEqual('');
        });
        */
      });


      describe('moveAfter', () {
        beforeEach((RootScope scope) {
          viewPort.insert(a);
          viewPort.insert(b, insertAfter: a);
          scope.flush();

          expect(rootElement.text).toEqual('AaBb');
        });


        it('should move last to middle', (RootScope scope) {
          viewPort.move(a, moveAfter: b);
          scope.flush();
          expect(rootElement).toHaveHtml('<!-- anchor --><span>B</span>b<span>A</span>a');
        });
      });


      describe("light dom notification", () {
        ViewPort viewPort;
        MockLightDom lightDom;
        Scope scope;

        beforeEach((Injector injector) {
          lightDom = new MockLightDom();

          viewPort = createViewPort(injector: injector, lightDom: lightDom);
        });

        it('should notify light on insert', (RootScope scope) {
          viewPort.insert(a);
          scope.flush();

          lightDom.getLogs(callsTo('redistribute')).verify(happenedOnce);
        });

        it('should notify light on remove', (RootScope scope) {
          viewPort.insert(a);
          scope.flush();
          lightDom.clearLogs();

          viewPort.remove(a);
          scope.flush();

          lightDom.getLogs(callsTo('redistribute')).verify(happenedOnce);
        });

        it('should notify light on move', (RootScope scope) {
          viewPort.insert(a);
          viewPort.insert(b, insertAfter: a);
          scope.flush();
          lightDom.clearLogs();

          viewPort.move(a, moveAfter: b);
          scope.flush();

          lightDom.getLogs(callsTo('redistribute')).verify(happenedOnce);
        });
      });
    });

    describe("nodes", () {
      ViewPort viewPort;

      beforeEach((Injector injector) {
        viewPort = createViewPort(injector: injector);
      });

      it("should return all the nodes from all the views", (RootScope scope) {
        viewPort.insert(a);
        viewPort.insert(b, insertAfter: a);

        scope.flush();

        expect(viewPort.nodes).toHaveText("AaBb");
      });

      it("should return an empty list when no views", () {
        expect(viewPort.nodes).toEqual([]);
      });
    });


    describe('deferred', () {

      it('should load directives/formatters from the child injector', (RootScope scope) {
        Module rootModule = new Module()
          ..bind(Probe)
          ..bind(Log)
          ..bind(AFormatter)
          ..bind(ADirective)
          ..bind(Node, toFactory: () => document.body, inject: []);

        Injector rootInjector = applicationFactory()
            .addModule(rootModule)
            .createInjector();
        Log log = rootInjector.get(Log);
        Scope rootScope = rootInjector.get(Scope);

        Compiler compiler = rootInjector.get(Compiler);
        DirectiveMap directives = rootInjector.get(DirectiveMap);
        compiler(es('<dir-a>{{\'a\' | formatterA}}</dir-a><dir-b></dir-b>'), directives)(rootScope, rootInjector.get(DirectiveInjector));
        rootScope.apply();

        expect(log.log, equals(['AFormatter', 'ADirective']));


        Module childModule = new Module()
          ..bind(BFormatter)
          ..bind(BDirective);

        var childInjector = forceNewDirectivesAndFormatters(rootInjector, null, [childModule]);

        DirectiveMap newDirectives = childInjector.get(DirectiveMap);
        var scope = childInjector.get(Scope);
        compiler(es('<dir-a probe="dirA"></dir-a>{{\'a\' | formatterA}}'
            '<dir-b probe="dirB"></dir-b>{{\'b\' | formatterB}}'), newDirectives)(scope, childInjector.get(DirectiveInjector));
        rootScope.apply();

        expect(log.log, equals(['AFormatter', 'ADirective', 'BFormatter', 'ADirective', 'BDirective']));
      });

    });

    //TODO: tests for attach/detach
    //TODO: animation/transitions
    //TODO: tests for re-usability of views

  });
}
