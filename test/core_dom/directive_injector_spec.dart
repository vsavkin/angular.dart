library directive_injector_spec;

import '../_specs.dart';
import 'package:angular/core_dom/directive_injector.dart';

void main() {
  describe('DirectiveInjector', () {

    var appInjector = new ModuleInjector([new Module()..bind(_Root)]);
    var div = new DivElement();
    var span = new SpanElement();
    var eventHandler = new EventHandler(null, null, null);

    describe('base', () {
      DirectiveInjector injector;
      Scope scope;
      View view;
      Animate animate;

      addDirective(Type type, [Visibility visibility]) {
        if (visibility == null) visibility = Visibility.LOCAL;
        var reflector = Module.DEFAULT_REFLECTOR;
        injector.bindByKey(
            new Key(type),
            reflector.factoryFor(type),
            reflector.parameterKeysFor(type),
            visibility);
      }

      beforeEach((Scope _scope, Animate _animate) {
        scope = _scope;
        animate = _animate;
        view = new View([], scope, eventHandler);
        injector = new DirectiveInjector(null, appInjector, div, new NodeAttrs(div), eventHandler,
            scope, view, animate);
      });

      it('should return basic types', () {
        expect(injector.parent is DefaultDirectiveInjector).toBe(true);
        expect(injector.appInjector).toBe(appInjector);
        expect(injector.scope).toBe(scope);
        expect(injector.get(Injector)).toBe(appInjector);
        expect(injector.get(DirectiveInjector)).toBe(injector);
        expect(injector.get(Scope)).toBe(scope);
        expect((injector.get(View))).toBe(view);
        expect(injector.get(Node)).toBe(div);
        expect(injector.get(Element)).toBe(div);
        expect((injector.get(NodeAttrs) as NodeAttrs).element).toBe(div);
        expect(injector.get(EventHandler)).toBe(eventHandler);
        expect(injector.get(Animate)).toBe(animate);
        expect((injector.get(ElementProbe) as ElementProbe).element).toBe(div);
      });

      it('should instantiate types', () {
        addDirective(_Type9);
        addDirective(_Type8);
        addDirective(_Type7);
        addDirective(_Type5);
        addDirective(_Type6);
        addDirective(_Type0);
        addDirective(_Type1);
        addDirective(_Type2);
        addDirective(_Type3);
        addDirective(_Type4);
        expect(() => addDirective(_TypeA))
            .toThrow('Maximum number of directives per element reached.');
        var root = injector.get(_Root);
        expect((injector.get(_Type9) as _Type9).type8.type7.type6.type5.type4.type3.type2.type1.type0.root)
            .toBe(root);
        expect(() => injector.get(_TypeA)).toThrow('No provider found for _TypeA');
      });

      describe('Visibility', () {
        DirectiveInjector childInjector;
        DirectiveInjector leafInjector;

        beforeEach(() {
          childInjector = new DirectiveInjector(injector, appInjector, span, null, null, null, null, null);
          leafInjector = new DirectiveInjector(childInjector, appInjector, span, null, null, null, null, null);
        });

        it('should not allow reseting visibility', () {
          addDirective(_Type0, Visibility.LOCAL);
          expect(() => addDirective(_Type0, Visibility.DIRECT_CHILD)).toThrow(
              'Can not set Visibility: DIRECT_CHILD on _Type0, it alread has Visibility: LOCAL');
        });

        it('should allow child injector to see types declared at parent injector', () {
          addDirective(_Children, Visibility.CHILDREN);
          _Children t = injector.get(_Children);
          expect(childInjector.get(_Children)).toBe(t);
          expect(leafInjector.get(_Children)).toBe(t);
        });

        it('should hide parent injector types when local visibility', () {
          addDirective(_Local, Visibility.LOCAL);
          _Local t = injector.getByKey(_LOCAL);
          expect(() => childInjector.get(_LOCAL)).toThrow();
          expect(() => leafInjector.get(_LOCAL)).toThrow();
        });
      });
    });
  });
}

var _CHILDREN = new Key(_Local);
var _LOCAL = new Key(_Local);
var _TYPE0 = new Key(_Local);

class _Children{}
class _Local{}
class _Direct{}
class _Any{}
class _Root{ }
class _Type0{ final _Root root;   _Type0(this.root); }
class _Type1{ final _Type0 type0; _Type1(this.type0); }
class _Type2{ final _Type1 type1; _Type2(this.type1); }
class _Type3{ final _Type2 type2; _Type3(this.type2); }
class _Type4{ final _Type3 type3; _Type4(this.type3); }
class _Type5{ final _Type4 type4; _Type5(this.type4); }
class _Type6{ final _Type5 type5; _Type6(this.type5); }
class _Type7{ final _Type6 type6; _Type7(this.type6); }
class _Type8{ final _Type7 type7; _Type8(this.type7); }
class _Type9{ final _Type8 type8; _Type9(this.type8); }
class _TypeA{ final _Type9 type9; _TypeA(this.type9); }

